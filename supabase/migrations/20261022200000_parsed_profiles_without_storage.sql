-- Resume parsing without storing the resume. parse-resume now reads the
-- uploaded file in memory and saves only what it verified: a draft
-- profile_versions row (resume_id null, source 'resume'), its candidate_skills,
-- and the candidate's experiences. The resumes table and bucket stay for seed
-- data and older uploads, but new parses never write to them.

alter table public.profile_versions
  add column schema_version int,  -- EXTRACTION_SCHEMA_VERSION that produced an AI draft
  add column llm_model text;

create type public.experience_kind as enum ('job', 'internship', 'research', 'project', 'volunteer', 'other');

-- One row per verified experience entry, in resume order (most recent first).
-- Like candidate_skills, rows belong to a profile version, so every version is
-- a self-contained snapshot. Dates are "YYYY-MM", "YYYY", or (end) "present";
-- years math happens in code before saving and is stored on the version.
create table public.candidate_experiences (
  id                  uuid primary key default gen_random_uuid(),
  profile_version_id  uuid not null references public.profile_versions (id) on delete cascade,
  sort_order          int  not null check (sort_order >= 0),
  kind                public.experience_kind not null default 'job',
  title               text not null check (length(title) between 1 and 200),
  organization        text check (organization is null or length(organization) between 1 and 200),
  start_month         text check (start_month ~ '^\d{4}(-(0[1-9]|1[0-2]))?$'),
  end_month           text check (end_month ~ '^(\d{4}(-(0[1-9]|1[0-2]))?|present)$'),
  highlights          text[] not null default '{}' check (cardinality(highlights) <= 6),
  skills_used         text[] not null default '{}',
  evidence            text not null,
  unique (profile_version_id, sort_order)
);

alter table public.candidate_experiences enable row level security;
revoke all on public.candidate_experiences from anon, authenticated;
grant all on public.candidate_experiences to service_role;
grant select on public.candidate_experiences to authenticated;
create policy candidate_experiences_read_self on public.candidate_experiences for select to authenticated
  using (exists (select 1 from public.profile_versions v
    where v.id = profile_version_id and v.candidate_id = (select auth.uid())));

-- Saves a parsed draft in one transaction: the next profile_versions row, its
-- candidate_skills (merged exactly like save_resume_draft), and its
-- experiences. Service role only; parse-resume passes the caller's id from
-- their verified JWT, and this re-checks that they are a candidate.
--
-- p_skills:      [{ "skill_id": uuid|null, "raw_name": text, "years": number|null, "evidence": text }]
-- p_experiences: [{ "kind", "title", "organization", "start", "end", "highlights": [text], "skills_used": [text], "evidence" }]
create or replace function public.save_parsed_profile(
  p_candidate_id uuid,
  p_schema_version integer,
  p_llm_model text,
  p_total_years numeric,
  p_education jsonb,
  p_skills jsonb,
  p_experiences jsonb
)
returns table (profile_version_id uuid, version integer)
language plpgsql
set search_path = public
as $$
declare
  v_version integer;
  v_id uuid;
begin
  if not exists (select 1 from public.profiles p where p.id = p_candidate_id and p.role = 'candidate') then
    raise exception 'not_candidate' using errcode = 'P0001';
  end if;
  -- Serialize version numbering per candidate (same lock as create_manual_profile).
  perform 1 from public.candidates c where c.profile_id = p_candidate_id for update;
  if not found then
    raise exception 'not_candidate' using errcode = 'P0001';
  end if;
  select coalesce(max(pv.version), 0) + 1 into v_version
  from public.profile_versions pv where pv.candidate_id = p_candidate_id;

  insert into public.profile_versions
    (candidate_id, resume_id, version, source, total_years, education, schema_version, llm_model)
  values (p_candidate_id, null, v_version, 'resume', p_total_years, coalesce(p_education, '[]'::jsonb),
    p_schema_version, p_llm_model)
  returning id into v_id;

  insert into public.candidate_skills (profile_version_id, skill_id, raw_name, years, evidence, source)
  select distinct on (coalesce(s.skill_id::text, lower(s.raw_name)))
    v_id, s.skill_id, s.raw_name, s.years, s.evidence, 'ai'
  from (
    select x.skill_id, x.raw_name, x.evidence, x.ord,
           max(x.years) over (partition by coalesce(x.skill_id::text, lower(x.raw_name))) as years
    from (
      select (e.j ->> 'skill_id')::uuid as skill_id, trim(e.j ->> 'raw_name') as raw_name,
             (e.j ->> 'years')::numeric as years, e.j ->> 'evidence' as evidence, e.ord
      from jsonb_array_elements(coalesce(p_skills, '[]'::jsonb)) with ordinality as e(j, ord)
    ) x
    where x.raw_name <> ''
  ) s
  order by coalesce(s.skill_id::text, lower(s.raw_name)), s.ord;

  insert into public.candidate_experiences
    (profile_version_id, sort_order, kind, title, organization, start_month, end_month, highlights, skills_used, evidence)
  select v_id, (e.ord - 1)::int, (e.j ->> 'kind')::public.experience_kind, btrim(e.j ->> 'title'),
    nullif(btrim(e.j ->> 'organization'), ''), e.j ->> 'start', e.j ->> 'end',
    array(select jsonb_array_elements_text(coalesce(e.j -> 'highlights', '[]'::jsonb))),
    array(select jsonb_array_elements_text(coalesce(e.j -> 'skills_used', '[]'::jsonb))),
    e.j ->> 'evidence'
  from jsonb_array_elements(coalesce(p_experiences, '[]'::jsonb)) with ordinality as e(j, ord);

  return query select v_id, v_version;
end;
$$;

revoke execute on function public.save_parsed_profile(uuid, integer, text, numeric, jsonb, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.save_parsed_profile(uuid, integer, text, numeric, jsonb, jsonb, jsonb)
  to service_role;

-- Editing a confirmed profile: copy the active version (skills with their
-- provenance, experiences, totals) into a new draft for the candidate to
-- review. confirm_profile then works on the copy, and the confirmed snapshot
-- that applications point to never changes. Without an active version this
-- is create_manual_profile().
create function public.create_review_draft() returns public.profile_versions
language plpgsql security definer set search_path = public as $$
declare
  caller uuid := (select auth.uid());
  active public.profile_versions;
  next_version integer;
  result public.profile_versions;
begin
  if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
    raise exception using errcode = 'P0001', message = 'not_candidate';
  end if;
  perform 1 from public.candidates where profile_id = caller for update;
  if not found then raise exception using errcode = 'P0001', message = 'not_candidate'; end if;
  select v.* into active from public.profile_versions v
    join public.candidates c on c.active_version_id = v.id
    where c.profile_id = caller;
  if not found then return public.create_manual_profile(); end if;

  select coalesce(max(version), 0) + 1 into next_version from public.profile_versions where candidate_id = caller;
  insert into public.profile_versions
    (candidate_id, resume_id, version, source, total_years, education, schema_version, llm_model)
  values (caller, active.resume_id, next_version, active.source, active.total_years, active.education,
    active.schema_version, active.llm_model)
  returning * into result;

  insert into public.candidate_skills (profile_version_id, skill_id, raw_name, years, evidence, source)
  select result.id, skill_id, raw_name, years, evidence, source
  from public.candidate_skills where profile_version_id = active.id;

  insert into public.candidate_experiences
    (profile_version_id, sort_order, kind, title, organization, start_month, end_month, highlights, skills_used, evidence)
  select result.id, sort_order, kind, title, organization, start_month, end_month, highlights, skills_used, evidence
  from public.candidate_experiences where profile_version_id = active.id;

  return result;
end;
$$;
revoke all on function public.create_review_draft() from public, anon;
grant execute on function public.create_review_draft() to authenticated;
