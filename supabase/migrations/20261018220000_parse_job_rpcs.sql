-- B7 / AI-12: parse-job support. Depends on A's PL-05/PL-06 tables (skills,
-- jobs, job_requirements); sorts after them. Service role only.

-- Unit-length average of the given skills' taxonomy embeddings. Gives a job (or
-- a profile) a retrieval vector for get_feed's ANN prefilter without any AI call,
-- and it can be recomputed in SQL whenever requirements or skills change
-- (e.g. by save_requirements / confirm_profile). Null when no skill has a vector.
create or replace function public.skills_centroid(p_skill_ids uuid[])
returns extensions.vector(1536)
language sql
stable
set search_path = public, extensions
as $$
  select extensions.l2_normalize(extensions.avg(s.embedding))
  from public.skills s
  where s.id = any(p_skill_ids)
    and s.embedding is not null
    and s.embedding_model = 'gemini-embedding-001@1536';
$$;

-- Start (or restart) parsing a DRAFT job. False if the job isn't a draft.
create or replace function public.start_job_parse(p_job_id uuid)
returns boolean
language sql
set search_path = public
as $$
  with started as (
    update public.jobs set parse_status = 'PENDING'
    where id = p_job_id and status = 'DRAFT'
    returning 1
  )
  select exists (select 1 from started);
$$;

-- Mark a pending parse FAILED (timeouts, AI errors). Never touches READY.
create or replace function public.fail_job_parse(p_job_id uuid)
returns boolean
language sql
set search_path = public
as $$
  with failed as (
    update public.jobs set parse_status = 'FAILED'
    where id = p_job_id and parse_status = 'PENDING'
    returning 1
  )
  select exists (select 1 from failed);
$$;

-- Save draft requirements in one transaction: replace the job's requirements,
-- pre-fill job fields the recruiter hasn't set, recompute the job embedding,
-- and set parse_status READY. Raises 'job_not_pending' if the job was published
-- or its parse failed (e.g. timed out) meanwhile, and 'too_many_requirements'
-- past 15 total / 8 required (same limits as save_requirements).
--
-- p_fields: { title, location, remote, job_type, sponsorship, salary_min, salary_max } (nulls ignored)
-- p_requirements: [{ skill_id, required, min_years, weight, evidence }]
-- Returns the saved requirements with skill name and category, required first.
create or replace function public.save_job_draft(p_job_id uuid, p_fields jsonb, p_requirements jsonb)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_total integer;
  v_required integer;
  v_min integer;
  v_max integer;
begin
  perform 1 from public.jobs j
  where j.id = p_job_id and j.status = 'DRAFT' and j.parse_status = 'PENDING'
  for update;
  if not found then
    raise exception 'job_not_pending' using errcode = 'P0001';
  end if;

  select count(*), count(*) filter (where (r ->> 'required')::boolean)
  into v_total, v_required
  from jsonb_array_elements(coalesce(p_requirements, '[]'::jsonb)) r;
  if v_total > 15 or v_required > 8 then
    raise exception 'too_many_requirements' using errcode = 'P0001';
  end if;

  delete from public.job_requirements where job_id = p_job_id;
  insert into public.job_requirements (job_id, skill_id, required, min_years, weight, evidence)
  select p_job_id, (r ->> 'skill_id')::uuid, (r ->> 'required')::boolean,
         coalesce((r ->> 'min_years')::numeric, 0), (r ->> 'weight')::smallint, r ->> 'evidence'
  from jsonb_array_elements(coalesce(p_requirements, '[]'::jsonb)) r;

  -- Salary: keep the pair only if it's consistent.
  v_min := (p_fields ->> 'salary_min')::integer;
  v_max := (p_fields ->> 'salary_max')::integer;
  if v_min is not null and v_max is not null and v_max < v_min then
    v_min := null;
    v_max := null;
  end if;

  update public.jobs j set
    title       = coalesce(j.title, nullif(trim(p_fields ->> 'title'), '')),
    location    = coalesce(j.location, nullif(trim(p_fields ->> 'location'), '')),
    remote      = coalesce(j.remote, (p_fields ->> 'remote')::public.remote_type),
    job_type    = coalesce(j.job_type, (p_fields ->> 'job_type')::public.job_type),
    sponsorship = coalesce((p_fields ->> 'sponsorship')::boolean, j.sponsorship),
    salary_min  = case when j.salary_min is null and j.salary_max is null then v_min else j.salary_min end,
    salary_max  = case when j.salary_min is null and j.salary_max is null then v_max else j.salary_max end,
    embedding   = public.skills_centroid(array(select skill_id from public.job_requirements where job_id = p_job_id)),
    embedding_model = case
      when exists (select 1 from public.job_requirements where job_id = p_job_id) then 'gemini-embedding-001@1536'
    end,
    parse_status = 'READY'
  where j.id = p_job_id;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', jr.id, 'skill_id', jr.skill_id, 'name', s.name, 'category', s.category,
      'required', jr.required, 'min_years', jr.min_years, 'weight', jr.weight, 'evidence', jr.evidence
    ) order by jr.required desc, jr.weight desc, s.name)
    from public.job_requirements jr join public.skills s on s.id = jr.skill_id
    where jr.job_id = p_job_id
  ), '[]'::jsonb);
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.skills_centroid(uuid[])',
    'public.start_job_parse(uuid)',
    'public.fail_job_parse(uuid)',
    'public.save_job_draft(uuid, jsonb, jsonb)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
