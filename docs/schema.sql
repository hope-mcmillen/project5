-- =============================================================================
-- ResuRhombus: reference database schema (Supabase / Postgres 15+)
-- =============================================================================
-- Companion to docs/SCHEMA.md. This file is the agreed target schema.
-- Person A turns it into ordered migrations in supabase/migrations/:
--   PL-04  identity & companies   (types, profiles, companies, recruiters, company_invites, app_config)
--   PL-05  candidates & skills    (vector, skills, skill_relations, candidates, resumes,
--                                  profile_versions, candidate_skills)
--   PL-06  jobs & the loop        (jobs, job_requirements, swipes, applications,
--                                  application_reject_reasons, status_events, llm_usage, views)
-- RLS is ENABLED on every table here. The actual policies are written in those
-- migrations (summary in docs/SCHEMA.md §4). RPC bodies are separate tasks
-- (signatures in docs/SCHEMA.md §5).
-- Every demo row created by seed.sql sets is_seed = true.
-- =============================================================================

create extension if not exists vector with schema extensions;
create extension if not exists pgcrypto with schema extensions;

-- -----------------------------------------------------------------------------
-- Enum types
-- -----------------------------------------------------------------------------
create type public.app_role           as enum ('candidate', 'recruiter');
create type public.company_role       as enum ('owner', 'member');
create type public.resume_status      as enum ('UPLOADED', 'PARSING_LAYOUT', 'EXTRACTING', 'NORMALIZING', 'READY', 'FAILED');
create type public.parse_status       as enum ('PENDING', 'READY', 'FAILED');
create type public.profile_source     as enum ('resume', 'manual');
create type public.skill_source       as enum ('ai', 'user');
create type public.job_status         as enum ('DRAFT', 'OPEN', 'PAUSED', 'CLOSED');
create type public.remote_type        as enum ('onsite', 'hybrid', 'remote');
create type public.job_type           as enum ('full_time', 'part_time', 'contract', 'internship');
create type public.swipe_direction    as enum ('left', 'right');
create type public.pass_reason        as enum ('location', 'salary', 'stack', 'seniority', 'company');
create type public.application_status as enum ('APPLIED', 'UNDER_REVIEW', 'INTERVIEW_REQUESTED', 'NOT_SELECTED', 'WITHDRAWN', 'JOB_CLOSED');

-- -----------------------------------------------------------------------------
-- Shared trigger: keep updated_at current
-- -----------------------------------------------------------------------------
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- =============================================================================
-- PL-04: identity & companies
-- =============================================================================

-- One row per auth user. Created by the handle_new_user() trigger (PL-07).
-- role is null only for OAuth users who haven't picked a role yet (US-02).
create table public.profiles (
  id                 uuid primary key references auth.users (id) on delete cascade,
  role               public.app_role,
  display_name       text,
  terms_accepted_at  timestamptz,
  is_seed            boolean not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table public.companies (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(trim(name)) between 1 and 120),
  website     text,
  logo_path   text,                              -- Storage: company-logos/{id}/logo.png (public bucket)
  verified    boolean not null default false,    -- email domain matched website host (PL-26)
  created_by  uuid references public.profiles (id) on delete set null,
  is_seed     boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- A recruiter belongs to exactly one company (PRD A-3).
create table public.recruiters (
  profile_id    uuid primary key references public.profiles (id) on delete cascade,
  company_id    uuid not null references public.companies (id) on delete cascade,
  company_role  public.company_role not null default 'member',
  created_at    timestamptz not null default now()
);
create index recruiters_company_idx on public.recruiters (company_id);

create table public.company_invites (
  code        text primary key check (code ~ '^[A-HJKMNP-Z2-9]{8}$'),  -- unambiguous alphabet
  company_id  uuid not null references public.companies (id) on delete cascade,
  created_by  uuid references public.profiles (id) on delete set null,
  expires_at  timestamptz not null,
  revoked_at  timestamptz,
  max_uses    int not null default 10 check (max_uses > 0),
  uses        int not null default 0 check (uses >= 0),
  created_at  timestamptz not null default now()
);
create index company_invites_company_idx on public.company_invites (company_id);

-- Single-row tunables read by RPCs.
create table public.app_config (
  id               boolean primary key default true check (id),
  daily_apply_cap  int  not null default 25,
  scoring_version  text not null default 'v1',
  undo_seconds     int  not null default 5,
  reject_undo_seconds int not null default 10
);
insert into public.app_config default values;

-- =============================================================================
-- PL-05: candidates & skills
-- =============================================================================

-- Canonical skill taxonomy (AI-01). Seeded, read-only to clients.
create table public.skills (
  id               uuid primary key default gen_random_uuid(),
  name             text not null unique,
  category         text not null,                 -- Languages | Frameworks | Data | Cloud/DevOps | Tools | Domain
  aliases          text[] not null default '{}',  -- lowercase alternate spellings
  embedding        extensions.vector(1536),       -- text-embedding-3-small
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

-- =============================================================================
-- PL-06: jobs & the loop
-- =============================================================================

create table public.jobs (
  id               uuid primary key default gen_random_uuid(),
  company_id       uuid not null references public.companies (id) on delete cascade,
  created_by       uuid references public.profiles (id) on delete set null,
  title            text,
  raw_description  text not null check (length(raw_description) <= 20000),
  parse_status     public.parse_status not null default 'PENDING',
  status           public.job_status not null default 'DRAFT',
  location         text,
  remote           public.remote_type,
  job_type         public.job_type,
  sponsorship      boolean not null default false,
  salary_min       int check (salary_min is null or salary_min >= 0),
  salary_max       int,
  embedding        extensions.vector(1536),
  embedding_model  text,
  published_at     timestamptz,
  expires_at       timestamptz,                      -- published_at + 60 days (R-JOB-4)
  rescored_at      timestamptz,
  is_seed          boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  check (salary_max is null or salary_min is null or salary_max >= salary_min)
);
create index jobs_company_idx   on public.jobs (company_id, status);
create index jobs_open_idx      on public.jobs (status) where status = 'OPEN';
create index jobs_embedding_idx on public.jobs using hnsw (embedding extensions.vector_cosine_ops);

-- Max 15 per job, max 8 required (R-JOB-2): enforced in save_requirements().
create table public.job_requirements (
  id         uuid primary key default gen_random_uuid(),
  job_id     uuid not null references public.jobs (id) on delete cascade,
  skill_id   uuid not null references public.skills (id),
  required   boolean not null default true,
  min_years  numeric(3,1) not null default 0 check (min_years >= 0),
  weight     smallint not null default 2 check (weight between 1 and 3),  -- required=2, preferred=1 by default
  evidence   text,
  unique (job_id, skill_id)
);

create table public.swipes (
  id            uuid primary key default gen_random_uuid(),
  candidate_id  uuid not null references public.candidates (profile_id) on delete cascade,
  job_id        uuid not null references public.jobs (id) on delete cascade,
  direction     public.swipe_direction not null,
  pass_reason   public.pass_reason,
  is_seed       boolean not null default false,
  created_at    timestamptz not null default now(),
  unique (candidate_id, job_id),
  check (direction = 'left' or pass_reason is null)
);
create index swipes_candidate_day_idx on public.swipes (candidate_id, created_at) where direction = 'right';

create table public.applications (
  id                  uuid primary key default gen_random_uuid(),
  swipe_id            uuid unique references public.swipes (id) on delete cascade,
  candidate_id        uuid references public.candidates (profile_id) on delete set null,  -- null after anonymize
  job_id              uuid not null references public.jobs (id) on delete cascade,
  profile_version_id  uuid references public.profile_versions (id) on delete set null,     -- snapshot at apply time
  status              public.application_status not null default 'APPLIED',
  previous_status     public.application_status,          -- for undo_reject
  match_score         smallint not null check (match_score between 0 and 100),
  breakdown           jsonb not null default '[]'::jsonb, -- per-requirement scores (radar + gap list)
  scoring_version     text not null,
  committed_at        timestamptz not null,               -- now() + undo window; hidden from recruiters until then
  advanced_by         uuid references public.profiles (id) on delete set null,
  interview_note      text,
  rejected_at         timestamptz,
  anonymized          boolean not null default false,
  is_seed             boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (candidate_id, job_id)
);
create index applications_board_idx     on public.applications (job_id, match_score desc, committed_at);
create index applications_candidate_idx on public.applications (candidate_id, updated_at desc);

-- Recruiter-only, so a reason can never reach a candidate (R-TRI-4).
create table public.application_reject_reasons (
  application_id  uuid primary key references public.applications (id) on delete cascade,
  reason          text,
  created_by      uuid references public.profiles (id) on delete set null,
  created_at      timestamptz not null default now()
);

create table public.status_events (
  id              bigint generated always as identity primary key,
  application_id  uuid not null references public.applications (id) on delete cascade,
  from_status     public.application_status,
  to_status       public.application_status not null,
  actor_id        uuid references public.profiles (id) on delete set null,  -- null = system
  created_at      timestamptz not null default now()
);
create index status_events_application_idx on public.status_events (application_id, created_at);

create table public.llm_usage (
  id             bigint generated always as identity primary key,
  function_name  text not null,          -- parse-resume | parse-job | embed
  provider       text not null,          -- openai | azure | mock
  model          text not null,
  input_tokens   int not null default 0,
  output_tokens  int not null default 0,
  latency_ms     int,
  user_id        uuid references public.profiles (id) on delete set null,
  created_at     timestamptz not null default now()
);
create index llm_usage_day_idx on public.llm_usage (created_at);

-- Later (PL-22): FCM tokens for push notifications.
create table public.device_tokens (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  token       text not null,
  platform    text not null check (platform in ('android', 'web')),
  updated_at  timestamptz not null default now(),
  primary key (user_id, token)
);

-- -----------------------------------------------------------------------------
-- updated_at triggers
-- -----------------------------------------------------------------------------
create trigger profiles_touch     before update on public.profiles     for each row execute function public.touch_updated_at();
create trigger companies_touch    before update on public.companies    for each row execute function public.touch_updated_at();
create trigger candidates_touch   before update on public.candidates   for each row execute function public.touch_updated_at();
create trigger resumes_touch      before update on public.resumes      for each row execute function public.touch_updated_at();
create trigger jobs_touch         before update on public.jobs         for each row execute function public.touch_updated_at();
create trigger applications_touch before update on public.applications for each row execute function public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- Views (security_invoker = RLS of the caller applies)
-- -----------------------------------------------------------------------------

-- Recruiter jobs list with counts (US-38).
create view public.company_jobs_overview with (security_invoker = true) as
select
  j.id, j.company_id, j.title, j.status, j.published_at, j.expires_at,
  count(a.id) filter (where a.status = 'APPLIED' and a.committed_at <= now())                         as new_count,
  count(a.id) filter (where a.committed_at <= now() and a.status not in ('WITHDRAWN', 'JOB_CLOSED')) as total_count
from public.jobs j
left join public.applications a on a.job_id = j.id
group by j.id;

-- Candidate pipeline with job info, without recruiter-only fields (US-25).
create view public.my_applications with (security_invoker = true) as
select
  a.id, a.job_id, a.status, a.match_score, a.breakdown, a.committed_at,
  a.interview_note, a.created_at, a.updated_at,
  j.title as job_title, c.name as company_name, c.verified as company_verified
from public.applications a
join public.jobs j on j.id = a.job_id
join public.companies c on c.id = j.company_id;

-- -----------------------------------------------------------------------------
-- Row-Level Security: enabled everywhere; policies live in the migrations.
-- -----------------------------------------------------------------------------
alter table public.profiles                   enable row level security;
alter table public.companies                  enable row level security;
alter table public.recruiters                 enable row level security;
alter table public.company_invites            enable row level security;
alter table public.app_config                 enable row level security;
alter table public.skills                     enable row level security;
alter table public.skill_relations            enable row level security;
alter table public.candidates                 enable row level security;
alter table public.resumes                    enable row level security;
alter table public.profile_versions           enable row level security;
alter table public.candidate_skills           enable row level security;
alter table public.jobs                       enable row level security;
alter table public.job_requirements           enable row level security;
alter table public.swipes                     enable row level security;
alter table public.applications               enable row level security;
alter table public.application_reject_reasons enable row level security;
alter table public.status_events              enable row level security;
alter table public.llm_usage                  enable row level security;
alter table public.device_tokens              enable row level security;

-- -----------------------------------------------------------------------------
-- Realtime (PL-21)
-- -----------------------------------------------------------------------------
alter publication supabase_realtime add table public.resumes, public.applications, public.jobs;
