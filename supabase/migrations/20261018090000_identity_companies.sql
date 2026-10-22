-- A2: reference DDL from docs/schema.sql, with explicit privileges and RLS.
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


alter table public.profiles enable row level security;
revoke all on public.profiles from anon, authenticated;
grant all on public.profiles to service_role;
alter table public.companies enable row level security;
revoke all on public.companies from anon, authenticated;
grant all on public.companies to service_role;
alter table public.recruiters enable row level security;
revoke all on public.recruiters from anon, authenticated;
grant all on public.recruiters to service_role;
alter table public.company_invites enable row level security;
revoke all on public.company_invites from anon, authenticated;
grant all on public.company_invites to service_role;
alter table public.app_config enable row level security;
revoke all on public.app_config from anon, authenticated;
grant all on public.app_config to service_role;

create trigger profiles_touch before update on public.profiles for each row execute function public.touch_updated_at();
create trigger companies_touch before update on public.companies for each row execute function public.touch_updated_at();

-- These small definer helpers avoid recursive policies on profiles/recruiters.
create function public.current_app_role() returns public.app_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = (select auth.uid())
$$;
create function public.my_company_id() returns uuid
language sql stable security definer set search_path = public as $$
  select company_id from public.recruiters where profile_id = (select auth.uid())
$$;
create function public.my_owned_company_id() returns uuid
language sql stable security definer set search_path = public as $$
  select company_id from public.recruiters
  where profile_id = (select auth.uid()) and company_role = 'owner'
$$;
revoke all on function public.current_app_role(), public.my_company_id(), public.my_owned_company_id() from public, anon;
grant execute on function public.current_app_role(), public.my_company_id(), public.my_owned_company_id() to authenticated, service_role;
create policy profiles_read_self on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy companies_read on public.companies for select to anon, authenticated using (true);
create policy companies_update_owner on public.companies for update to authenticated
  using (id = (select public.my_owned_company_id()))
  with check (id = (select public.my_owned_company_id()));
create policy recruiters_read_company on public.recruiters for select to authenticated
  using (company_id = (select public.my_company_id()));
create policy invites_read_owner on public.company_invites for select to authenticated
  using (company_id = (select public.my_owned_company_id()));
create policy config_read on public.app_config for select to anon, authenticated using (true);


grant select on public.profiles, public.recruiters, public.company_invites to authenticated;
-- role is immutable for direct clients; set_initial_role is the only entry point.
grant update (display_name, terms_accepted_at) on public.profiles to authenticated;
grant select on public.companies, public.app_config to anon, authenticated;
grant update (name, website, logo_path) on public.companies to authenticated;
