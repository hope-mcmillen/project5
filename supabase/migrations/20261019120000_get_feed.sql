-- B9 / AI-15: the candidate's ranked deck (PRD §8.6, API_CONTRACT §6).
-- Depends on A's tables and on compute_match / skills_centroid (B8 / B7).
--
--   1. caller must be a candidate with a confirmed active profile version
--   2. hard filters: OPEN, not expired, not swiped, preferences (remote, location,
--      job type, sponsorship, salary floor)
--   3. prefilter: the 500 jobs whose requirement weight the candidate covers best
--      (exact or related skills). A job sharing no skill would score 0, so it's
--      skipped. Vector distance only breaks ties: measured on 600 jobs, centroid
--      vectors put score-0 DevOps jobs closer to a Flutter developer than a
--      score-100 Flutter job, so distance alone dropped the best match.
--   4. compute_match() for each; drop < 50 unless include_stretch
--   5. Feed Rank = 0.70·match + 0.15·freshness + 0.10·affinity + 0.05·exploration
--   6. keyset page by (rank desc, job_id); within the page no company appears
--      3 times in a row, continuing the run from the previous page
--
-- Feed Rank only orders the deck: swipes and pass reasons never change match_score.

-- Ranking pieces, each in [0, 1]. Separate functions so they're testable on their own.

-- 1 on the day a job is published, falling linearly to 0 after 30 days. Whole days,
-- so ranks (and cursors) stay stable for a whole day.
create or replace function public.feed_freshness(p_published_at timestamptz)
returns numeric
language sql
stable
as $$
  select greatest(0, 1 - (current_date - coalesce(p_published_at, now())::date) / 30.0)::numeric;
$$;

-- Deterministic per (job, day) noise so the deck isn't identical every day.
create or replace function public.feed_exploration(p_job_id uuid)
returns numeric
language sql
stable
as $$
  select (('x' || substr(md5(p_job_id::text || current_date::text), 1, 8))::bit(32)::bigint / 4294967296.0)::numeric;
$$;

-- Preference affinity from the candidate's pass reasons (PRD §8.6, v1 rules):
--   neutral 0.5
--   'company' pass on this job's company        → 0
--   ≥ 1 'salary' pass and this job pays more than the best-paying job they passed for salary → +0.25
--   ≥ 2 'location' passes and this job is remote → +0.25
--   ≥ 2 'stack' passes                           → +0.25 × (match_score / 100 − 0.5), favoring closer matches
create or replace function public.feed_affinity(
  p_candidate_id uuid,
  p_company_id uuid,
  p_remote public.remote_type,
  p_salary_max integer,
  p_match_score integer
)
returns numeric
language sql
stable
set search_path = public
as $$
  with passes as (
    select s.pass_reason, j.company_id, j.salary_max
    from public.swipes s join public.jobs j on j.id = s.job_id
    where s.candidate_id = p_candidate_id and s.direction = 'left' and s.pass_reason is not null
  ),
  p as (
    select
      bool_or(pass_reason = 'company' and company_id = p_company_id) as company_blocked,
      max(salary_max) filter (where pass_reason = 'salary') as passed_salary,
      count(*) filter (where pass_reason = 'salary') as salary_n,
      count(*) filter (where pass_reason = 'location') as location_n,
      count(*) filter (where pass_reason = 'stack') as stack_n
    from passes
  )
  select case when coalesce(p.company_blocked, false) then 0
    else greatest(0, least(1, 0.5
      + case when p.salary_n >= 1 and p_salary_max is not null and p_salary_max > coalesce(p.passed_salary, 0) then 0.25 else 0 end
      + case when p.location_n >= 2 and p_remote = 'remote' then 0.25 else 0 end
      + case when p.stack_n >= 2 then 0.25 * (p_match_score / 100.0 - 0.5) else 0 end))
  end::numeric
  from p;
$$;

-- Cursor: base64url(JSON {"r": rank, "j": job_id, "c": [last two company ids served]}).
create or replace function public.get_feed(p_limit integer default 20, p_cursor text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_prefs jsonb;
  v_version uuid;
  v_vector extensions.vector(1536);
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_after_rank numeric;
  v_after_job uuid;
  v_run uuid[] := '{}';
  v_cursor jsonb;
  v_include_stretch boolean;
  v_page jsonb[] := '{}';
  v_pending jsonb[];
  v_card jsonb;
  v_i integer;
  v_picked integer;
  v_last_rank numeric;
  v_last_job uuid;
  v_more boolean;
begin
  if v_uid is null or not exists (select 1 from public.profiles where id = v_uid and role = 'candidate') then
    raise exception 'not_candidate' using errcode = 'P0001';
  end if;

  select c.preferences, c.active_version_id into v_prefs, v_version
  from public.candidates c
  join public.profile_versions pv on pv.id = c.active_version_id and pv.confirmed
  where c.profile_id = v_uid;
  if v_version is null then
    raise exception 'profile_not_confirmed' using errcode = 'P0001';
  end if;
  v_include_stretch := coalesce((v_prefs ->> 'include_stretch')::boolean, false);

  if p_cursor is not null then
    begin
      v_cursor := convert_from(decode(
        rpad(translate(p_cursor, '-_', '+/'), (length(p_cursor) + 3) / 4 * 4, '='), 'base64'), 'UTF8')::jsonb;
      v_after_rank := (v_cursor ->> 'r')::numeric;
      v_after_job := (v_cursor ->> 'j')::uuid;
      v_run := coalesce(array(select jsonb_array_elements_text(v_cursor -> 'c')::uuid), '{}');
      if v_after_rank is null or v_after_job is null then raise exception 'bad'; end if;
    exception when others then
      raise exception 'invalid_cursor' using errcode = 'P0001';
    end;
  end if;

  -- Profile vector: the confirmed one if set, else the centroid of its mapped skills (PRD Q14).
  select coalesce(pv.embedding, public.skills_centroid(array(
           select cs.skill_id from public.candidate_skills cs
           where cs.profile_version_id = pv.id and cs.skill_id is not null)))
  into v_vector
  from public.profile_versions pv where pv.id = v_version;

  -- Rank every eligible job (scores only), keep the page after the cursor, and build the
  -- card JSON only for those rows: building it for all 500 tripled the latency.
  with have as (
    select cs.skill_id from public.candidate_skills cs
    where cs.profile_version_id = v_version and cs.skill_id is not null
  ),
  -- Skills the candidate covers and how much: 1 for their own, the best relation credit otherwise.
  reach as (
    select x.skill_id, max(x.credit) as credit
    from (
      select h.skill_id, 1.0::numeric as credit from have h
      union all
      select sr.related_skill_id, sr.credit from public.skill_relations sr join have h on h.skill_id = sr.skill_id
    ) x
    group by x.skill_id
  )
  select array_agg(c.card order by top.rank desc, top.job_id)
  into v_pending
  from (
    select x.*
    from (
      select j.id as job_id, j.company_id, j.title, j.location, j.remote, j.job_type, j.sponsorship,
             j.salary_min, j.salary_max, j.published_at, m.match, (m.match ->> 'score')::integer as score,
             round(
               0.70 * (m.match ->> 'score')::numeric / 100
               + 0.15 * public.feed_freshness(j.published_at)
               + 0.10 * public.feed_affinity(v_uid, j.company_id, j.remote, j.salary_max, (m.match ->> 'score')::integer)
               + 0.05 * public.feed_exploration(j.id), 6) as rank
      from (
        select j0.*
        from public.jobs j0
        cross join lateral (
          select sum(jr.weight * coalesce(r.credit, 0)) / nullif(sum(jr.weight), 0) as overlap
          from public.job_requirements jr
          left join reach r on r.skill_id = jr.skill_id
          where jr.job_id = j0.id
        ) o
        where j0.status = 'OPEN'
          and o.overlap > 0
          and (j0.expires_at is null or j0.expires_at > now())
          and not exists (select 1 from public.swipes s where s.candidate_id = v_uid and s.job_id = j0.id)
          -- remote preference: unknown remote type passes
          and (jsonb_array_length(coalesce(v_prefs -> 'remote', '[]')) = 0 or j0.remote is null
               or v_prefs -> 'remote' ? j0.remote::text)
          -- location: remote jobs and unknown locations pass
          and (jsonb_array_length(coalesce(v_prefs -> 'locations', '[]')) = 0 or j0.remote = 'remote' or j0.location is null
               or exists (select 1 from jsonb_array_elements_text(v_prefs -> 'locations') l
                          where lower(trim(l)) = lower(trim(j0.location))))
          and (jsonb_array_length(coalesce(v_prefs -> 'job_types', '[]')) = 0 or j0.job_type is null
               or v_prefs -> 'job_types' ? j0.job_type::text)
          and (not coalesce((v_prefs ->> 'needs_sponsorship')::boolean, false) or j0.sponsorship)
          and ((v_prefs ->> 'salary_min') is null or j0.salary_max is null
               or j0.salary_max >= (v_prefs ->> 'salary_min')::integer)
        order by o.overlap desc, j0.embedding <=> v_vector nulls last, j0.id
        limit 500
      ) j
      cross join lateral (select public.compute_match(v_version, j.id) as match) m
    ) x
    where (v_include_stretch or x.score >= 50)
      -- strictly after the cursor in (rank desc, job_id asc) order
      and (v_after_rank is null or x.rank < v_after_rank or (x.rank = v_after_rank and x.job_id > v_after_job))
    order by x.rank desc, x.job_id
    limit v_limit + 1
  ) top
  cross join lateral (
    select jsonb_build_object(
      'job_id', top.job_id,
      'title', top.title,
      'company', (select jsonb_build_object('id', co.id, 'name', co.name, 'verified', co.verified)
                  from public.companies co where co.id = top.company_id),
      'location', top.location, 'remote', top.remote, 'job_type', top.job_type,
      'sponsorship', top.sponsorship, 'salary_min', top.salary_min, 'salary_max', top.salary_max,
      'published_at', top.published_at,
      'match_score', top.score,
      'band', public.match_band(top.score),
      'top_matches', coalesce((select jsonb_agg(t.e ->> 'name') from (
          select e from jsonb_array_elements(top.match -> 'breakdown') e
          where e ->> 'matched_via' <> 'none'
          order by (e ->> 'required')::boolean desc, (e ->> 'score')::numeric desc, e ->> 'name' collate "C"
          limit 3) t), '[]'::jsonb),
      'gaps', coalesce((select jsonb_agg(e ->> 'name') from jsonb_array_elements(top.match -> 'breakdown') e
                        where e ->> 'matched_via' = 'none'), '[]'::jsonb),
      'required_gaps', coalesce((select jsonb_agg(e ->> 'name') from jsonb_array_elements(top.match -> 'breakdown') e
                                 where e ->> 'matched_via' = 'none' and (e ->> 'required')::boolean), '[]'::jsonb),
      'breakdown', top.match -> 'breakdown',
      '_rank', top.rank,
      '_company', top.company_id
    ) as card
  ) c;

  v_pending := coalesce(v_pending, '{}');
  v_more := cardinality(v_pending) > v_limit;
  if v_more then v_pending := v_pending[1:v_limit]; end if;

  -- The page is the top v_limit by rank; reorder within it so no company appears 3 times in a row.
  -- Best effort: if only one company remains, it repeats rather than dropping cards.
  while cardinality(v_pending) > 0 loop
    v_picked := 1;
    for v_i in 1 .. cardinality(v_pending) loop
      if cardinality(v_run) < 2
         or not ((v_pending[v_i] ->> '_company')::uuid = v_run[1] and v_run[1] = v_run[2]) then
        v_picked := v_i;
        exit;
      end if;
    end loop;
    v_card := v_pending[v_picked];
    v_page := v_page || v_card;
    v_run := array[(v_card ->> '_company')::uuid] || v_run[1:1];
    v_pending := v_pending[1:v_picked - 1] || v_pending[v_picked + 1:];
  end loop;

  -- Cursor: the lowest-ranked card served (cards above it were all served on this page).
  select (c ->> '_rank')::numeric, (c ->> 'job_id')::uuid into v_last_rank, v_last_job
  from unnest(v_page) c
  order by (c ->> '_rank')::numeric, (c ->> 'job_id')::uuid desc
  limit 1;

  return jsonb_build_object(
    'cards', coalesce((select jsonb_agg(c - '_rank' - '_company' order by o) from unnest(v_page) with ordinality as t(c, o)), '[]'::jsonb),
    'next_cursor', case when v_more then
      rtrim(translate(encode(convert_to(jsonb_build_object(
        'r', v_last_rank, 'j', v_last_job, 'c', to_jsonb(v_run))::text, 'UTF8'), 'base64'), '+/' || chr(10), '-_'), '=')
    end
  );
end;
$$;

comment on function public.get_feed(integer, text) is
  'Candidate deck: hard filters → ANN prefilter → compute_match → Feed Rank → diversity (B9, API_CONTRACT §6).';

revoke execute on function public.get_feed(integer, text) from public, anon;
grant execute on function public.get_feed(integer, text) to authenticated, service_role;
do $$
declare f text;
begin
  foreach f in array array[
    'public.feed_freshness(timestamptz)',
    'public.feed_exploration(uuid)',
    'public.feed_affinity(uuid, uuid, public.remote_type, integer, integer)'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
