-- A2: reference DDL from docs/schema.sql, with explicit privileges and RLS.
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
  provider       text not null,          -- gemini | mock
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


alter table public.jobs enable row level security;
revoke all on public.jobs from anon, authenticated;
grant all on public.jobs to service_role;
alter table public.job_requirements enable row level security;
revoke all on public.job_requirements from anon, authenticated;
grant all on public.job_requirements to service_role;
alter table public.swipes enable row level security;
revoke all on public.swipes from anon, authenticated;
grant all on public.swipes to service_role;
alter table public.applications enable row level security;
revoke all on public.applications from anon, authenticated;
grant all on public.applications to service_role;
alter table public.application_reject_reasons enable row level security;
revoke all on public.application_reject_reasons from anon, authenticated;
grant all on public.application_reject_reasons to service_role;
alter table public.status_events enable row level security;
revoke all on public.status_events from anon, authenticated;
grant all on public.status_events to service_role;
alter table public.llm_usage enable row level security;
revoke all on public.llm_usage from anon, authenticated;
grant all on public.llm_usage to service_role;
alter table public.device_tokens enable row level security;
revoke all on public.device_tokens from anon, authenticated;
grant all on public.device_tokens to service_role;

create trigger jobs_touch before update on public.jobs for each row execute function public.touch_updated_at();
create trigger applications_touch before update on public.applications for each row execute function public.touch_updated_at();
create trigger device_tokens_touch before update on public.device_tokens for each row execute function public.touch_updated_at();

-- Avoid jobs <-> applications policy recursion while keeping the lookup self-only.
create function public.has_my_application(p_job_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.applications
    where job_id = p_job_id and candidate_id = (select auth.uid()))
$$;
revoke all on function public.has_my_application(uuid) from public, anon;
grant execute on function public.has_my_application(uuid) to authenticated, service_role;
create policy jobs_read on public.jobs for select to authenticated using (
  ((select public.current_app_role()) = 'candidate' and (status = 'OPEN' or public.has_my_application(id)))
  or company_id = (select public.my_company_id()));
create policy jobs_insert_company on public.jobs for insert to authenticated
  with check (company_id = (select public.my_company_id())
    and (select public.current_app_role()) = 'recruiter' and created_by = (select auth.uid()));
create policy jobs_update_company on public.jobs for update to authenticated
  using (company_id = (select public.my_company_id()))
  with check (company_id = (select public.my_company_id()));
create policy jobs_delete_company on public.jobs for delete to authenticated
  using (company_id = (select public.my_company_id()));
create policy requirements_read on public.job_requirements for select to authenticated
  using (exists (select 1 from public.jobs j where j.id = job_id));
-- Requirement mutation goes through save_requirements (limits + embedding/rescoring).
create policy swipes_read_self on public.swipes for select to authenticated
  using (candidate_id = (select auth.uid()));
create policy applications_read on public.applications for select to authenticated using (
  candidate_id = (select auth.uid()) or (committed_at <= now() and exists (
    select 1 from public.jobs j where j.id = job_id and j.company_id = (select public.my_company_id()))));
create policy reasons_read_company on public.application_reject_reasons for select to authenticated
  using (exists (select 1 from public.applications a join public.jobs j on j.id = a.job_id
    where a.id = application_id and j.company_id = (select public.my_company_id()) and a.committed_at <= now()));
create policy events_read on public.status_events for select to authenticated
  using (exists (select 1 from public.applications a where a.id = application_id));
-- llm_usage has no client policies or privileges. Service role only.
create policy tokens_self on public.device_tokens for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));


grant select on public.jobs, public.job_requirements, public.swipes, public.applications,
  public.application_reject_reasons, public.status_events to authenticated;
grant insert (id, company_id, created_by, title, raw_description, location, remote,
  job_type, sponsorship, salary_min, salary_max) on public.jobs to authenticated;
grant update (title, raw_description, location, remote, job_type, sponsorship, salary_min, salary_max)
  on public.jobs to authenticated;
grant delete on public.jobs to authenticated;
grant select, insert, update, delete on public.device_tokens to authenticated;
grant all on sequence public.status_events_id_seq, public.llm_usage_id_seq to service_role;
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
join public.companies c on c.id = j.company_id
where a.candidate_id = (select auth.uid());

revoke all on public.company_jobs_overview, public.my_applications from anon, authenticated;
grant select on public.company_jobs_overview, public.my_applications to authenticated, service_role;
alter publication supabase_realtime add table public.resumes, public.applications, public.jobs;

