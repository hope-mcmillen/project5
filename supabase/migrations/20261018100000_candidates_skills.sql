-- A2: reference DDL from docs/schema.sql, with explicit privileges and RLS.
create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;
-- Canonical skill taxonomy (AI-01). Seeded, read-only to clients.
create table public.skills (
  id               uuid primary key default gen_random_uuid(),
  name             text not null unique,
  category         text not null,                 -- Languages | Frameworks | Data | Cloud/DevOps | Tools | Domain
  aliases          text[] not null default '{}',  -- lowercase alternate spellings
  embedding        extensions.vector(1536),       -- gemini-embedding-001 @ 1536 dims
  embedding_model  text,
  is_seed          boolean not null default true
);
create index skills_aliases_idx   on public.skills using gin (aliases);
create index skills_embedding_idx on public.skills using hnsw (embedding extensions.vector_cosine_ops);

-- Curated partial credit between related skills (e.g. MySQL -> PostgreSQL 0.6).
create table public.skill_relations (
  skill_id          uuid not null references public.skills (id) on delete cascade,
  related_skill_id  uuid not null references public.skills (id) on delete cascade,
  credit            numeric(3,2) not null check (credit > 0 and credit < 1),
  primary key (skill_id, related_skill_id),
  check (skill_id <> related_skill_id)
);

create table public.candidates (
  profile_id         uuid primary key references public.profiles (id) on delete cascade,
  active_version_id  uuid,                            -- FK added below (circular reference)
  -- Hard filters for get_feed (US-12). Shape:
  -- { "locations": ["Baton Rouge, LA"], "remote": ["remote","hybrid"],
  --   "job_types": ["full_time"], "needs_sponsorship": false, "salary_min": 70000,
  --   "include_stretch": false }
  preferences        jsonb not null default '{}'::jsonb,
  discoverable       boolean not null default false,  -- Phase 2 outbound sourcing
  is_seed            boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.resumes (
  id              uuid primary key default gen_random_uuid(),
  candidate_id    uuid not null references public.candidates (profile_id) on delete cascade,
  storage_path    text not null unique,             -- resumes/{auth.uid()}/{uuid}.{pdf|docx}
  file_hash       text not null,                    -- sha256, used for extraction cache
  mime_type       text not null check (mime_type in (
                    'application/pdf',
                    'application/vnd.openxmlformats-officedocument.wordprocessingml.document')),
  status          public.resume_status not null default 'UPLOADED',
  failure_reason  text check (failure_reason in ('unreadable_scan', 'timeout', 'too_long', 'budget_exceeded', 'internal')),
  extraction      jsonb,                            -- validated LLM output (schema in _shared/schemas.ts)
  schema_version  int,
  llm_provider    text,
  llm_model       text,
  is_seed         boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index resumes_candidate_idx on public.resumes (candidate_id, created_at desc);
create index resumes_hash_idx      on public.resumes (file_hash);

-- Each resume upload (or manual entry) creates a new version (C-ON-6).
create table public.profile_versions (
  id               uuid primary key default gen_random_uuid(),
  candidate_id     uuid not null references public.candidates (profile_id) on delete cascade,
  resume_id        uuid references public.resumes (id) on delete set null,
  version          int  not null,
  source           public.profile_source not null default 'resume',
  confirmed        boolean not null default false,
  confirmed_at     timestamptz,
  total_years      numeric(4,1),
  education        jsonb not null default '[]'::jsonb,   -- [{ "level": "BS", "field": "Computer Science" }]
  embedding        extensions.vector(1536),
  embedding_model  text,
  is_seed          boolean not null default false,
  created_at       timestamptz not null default now(),
  unique (candidate_id, version)
);
create index profile_versions_embedding_idx on public.profile_versions using hnsw (embedding extensions.vector_cosine_ops);

alter table public.candidates
  add constraint candidates_active_version_fk
  foreign key (active_version_id) references public.profile_versions (id) on delete set null;

create table public.candidate_skills (
  id                  uuid primary key default gen_random_uuid(),
  profile_version_id  uuid not null references public.profile_versions (id) on delete cascade,
  skill_id            uuid references public.skills (id),   -- null = unmapped (kept, not scored)
  raw_name            text not null,
  years               numeric(3,1) check (years is null or years >= 0),  -- null = listed, not evidenced
  evidence            text,
  source              public.skill_source not null default 'ai'
);
create unique index candidate_skills_unique_idx
  on public.candidate_skills (profile_version_id, coalesce(skill_id::text, lower(raw_name)));


alter table public.skills enable row level security;
revoke all on public.skills from anon, authenticated;
grant all on public.skills to service_role;
alter table public.skill_relations enable row level security;
revoke all on public.skill_relations from anon, authenticated;
grant all on public.skill_relations to service_role;
alter table public.candidates enable row level security;
revoke all on public.candidates from anon, authenticated;
grant all on public.candidates to service_role;
alter table public.resumes enable row level security;
revoke all on public.resumes from anon, authenticated;
grant all on public.resumes to service_role;
alter table public.profile_versions enable row level security;
revoke all on public.profile_versions from anon, authenticated;
grant all on public.profile_versions to service_role;
alter table public.candidate_skills enable row level security;
revoke all on public.candidate_skills from anon, authenticated;
grant all on public.candidate_skills to service_role;

create trigger candidates_touch before update on public.candidates for each row execute function public.touch_updated_at();
create trigger resumes_touch before update on public.resumes for each row execute function public.touch_updated_at();

create policy skills_read on public.skills for select to anon, authenticated using (true);
create policy skill_relations_read on public.skill_relations for select to anon, authenticated using (true);
create policy candidates_read_self on public.candidates for select to authenticated
  using (profile_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate');
create policy candidates_update_self on public.candidates for update to authenticated
  using (profile_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate')
  with check (profile_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate');
create policy resumes_read_self on public.resumes for select to authenticated
  using (candidate_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate');
create policy resumes_insert_self on public.resumes for insert to authenticated
  with check (candidate_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate'
    and split_part(storage_path, '/', 1) = (select auth.uid())::text);
create policy versions_read_self on public.profile_versions for select to authenticated
  using (candidate_id = (select auth.uid()) and (select public.current_app_role()) = 'candidate');
create policy candidate_skills_read_self on public.candidate_skills for select to authenticated
  using (exists (select 1 from public.profile_versions v
    where v.id = profile_version_id and v.candidate_id = (select auth.uid())));


grant select on public.skills, public.skill_relations to anon, authenticated;
grant select on public.candidates, public.resumes, public.profile_versions, public.candidate_skills to authenticated;
-- Preferences are validated by save_preferences; active_version_id only by confirm_profile.
grant update (discoverable) on public.candidates to authenticated;
grant insert (id, candidate_id, storage_path, file_hash, mime_type) on public.resumes to authenticated;

