-- B6 / AI-07: atomic status changes and draft saving for the parse-resume
-- Edge Function. Depends on A's PL-05 tables (resumes, profile_versions,
-- candidate_skills); sorts after them. Service role only.
--
-- Status machine (SCHEMA §3): UPLOADED → PARSING_LAYOUT → EXTRACTING →
-- NORMALIZING → READY | FAILED. Every transition is a compare-and-set, so a
-- parse that hit the 60 s timeout (and was marked FAILED) can't later write READY.

-- Claim a resume for parsing. Succeeds from UPLOADED or FAILED (retry), or from a
-- parsing state whose last update is older than p_stale_seconds (a crashed run).
create or replace function public.claim_resume_parse(p_resume_id uuid, p_stale_seconds integer default 120)
returns boolean
language sql
set search_path = public
as $$
  with claimed as (
    update public.resumes
    set status = 'PARSING_LAYOUT', failure_reason = null
    where id = p_resume_id
      and (
        status in ('UPLOADED', 'FAILED')
        or (status in ('PARSING_LAYOUT', 'EXTRACTING', 'NORMALIZING')
            and updated_at < now() - make_interval(secs => p_stale_seconds))
      )
    returning 1
  )
  select exists (select 1 from claimed);
$$;

-- Move one step forward, only if the row is still where the caller left it.
create or replace function public.advance_resume_status(
  p_resume_id uuid,
  p_from public.resume_status,
  p_to public.resume_status
)
returns boolean
language sql
set search_path = public
as $$
  with moved as (
    update public.resumes set status = p_to
    where id = p_resume_id and status = p_from
      and (p_from, p_to) in (('PARSING_LAYOUT', 'EXTRACTING'), ('EXTRACTING', 'NORMALIZING'))
    returning 1
  )
  select exists (select 1 from moved);
$$;

-- Mark a parse FAILED. Only touches rows that are mid-parse, so it never
-- overwrites READY or an earlier failure reason.
create or replace function public.fail_resume_parse(p_resume_id uuid, p_reason text)
returns boolean
language sql
set search_path = public
as $$
  with failed as (
    update public.resumes set status = 'FAILED', failure_reason = p_reason
    where id = p_resume_id and status in ('PARSING_LAYOUT', 'EXTRACTING', 'NORMALIZING')
    returning 1
  )
  select exists (select 1 from failed);
$$;

-- Save the draft profile in one transaction: next profile_versions row, its
-- candidate_skills, and the resume's extraction + READY. Raises
-- 'resume_not_normalizing' if the parse was failed (e.g. timed out) meanwhile.
--
-- p_skills: [{ "skill_id": uuid|null, "raw_name": text, "years": number|null, "evidence": text }]
-- Rows with the same skill_id (or, when unmapped, the same lowercase raw_name)
-- are merged: the most years and the first evidence win.
create or replace function public.save_resume_draft(
  p_resume_id uuid,
  p_file_hash text,
  p_extraction jsonb,
  p_schema_version integer,
  p_llm_provider text,
  p_llm_model text,
  p_total_years numeric,
  p_education jsonb,
  p_skills jsonb
)
returns table (profile_version_id uuid, version integer)
language plpgsql
set search_path = public
as $$
declare
  v_candidate uuid;
  v_version integer;
  v_id uuid;
begin
  select r.candidate_id into v_candidate
  from public.resumes r
  where r.id = p_resume_id and r.status = 'NORMALIZING'
  for update;
  if not found then
    raise exception 'resume_not_normalizing' using errcode = 'P0001';
  end if;

  -- Serialize version numbering per candidate (two resumes parsing at once).
  perform 1 from public.candidates c where c.profile_id = v_candidate for update;
  select coalesce(max(pv.version), 0) + 1 into v_version
  from public.profile_versions pv where pv.candidate_id = v_candidate;

  insert into public.profile_versions (candidate_id, resume_id, version, source, total_years, education)
  values (v_candidate, p_resume_id, v_version, 'resume', p_total_years, coalesce(p_education, '[]'::jsonb))
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

  update public.resumes
  set status = 'READY', failure_reason = null, file_hash = p_file_hash, extraction = p_extraction,
      schema_version = p_schema_version, llm_provider = p_llm_provider, llm_model = p_llm_model
  where id = p_resume_id;

  return query select v_id, v_version;
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.claim_resume_parse(uuid, integer)',
    'public.advance_resume_status(uuid, public.resume_status, public.resume_status)',
    'public.fail_resume_parse(uuid, text)',
    'public.save_resume_draft(uuid, text, jsonb, integer, text, text, numeric, jsonb, jsonb)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
