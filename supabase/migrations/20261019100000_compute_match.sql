-- B8 / AI-14: Match Score v2 (PRD §8.4, v0.7). Depends on A's tables (skills,
-- skill_relations, candidate_skills, job_requirements); sorts after them.
-- The TypeScript mirror is supabase/functions/_shared/score.ts: change both
-- together, bump app_config.scoring_version, and re-run the regression in
-- supabase/tests/fixtures/match_pairs.json.

-- PRD §3.3 score bands, for boards, feeds, and seed data.
create or replace function public.match_band(p_score integer)
returns text
language sql
immutable
as $$
  select case
    when p_score >= 85 then 'Strong'
    when p_score >= 70 then 'Good'
    when p_score >= 50 then 'Stretch'
    else 'Low'
  end;
$$;

-- { "score": 0-100, "breakdown": [ one entry per job requirement, SCHEMA §6 ] }
--   coverage = 1 exact | best skill_relations.credit | 0
--   depth    = min_years = 0 → 1; years unknown → 0.5; else min(1, years / min_years)
--   score_r  = coverage × (0.6 + 0.4 × depth)
--   req/pref = Σw·score_r / Σw over required / preferred requirements
--   score    = round(100 × clamp(0.85 × req + 0.15 × pref, 0, 1)); one group only → its average
-- v2 replaced v1's single average minus 0.15 per missing required skill after the
-- AI-17 regression (74 labeled pairs: 70% → 84% band agreement).
-- Swipes and pass reasons never enter this function (Match Score ≠ Feed Rank).
create or replace function public.compute_match(p_profile_version_id uuid, p_job_id uuid)
returns jsonb
language sql
stable
set search_path = public
as $$
  with cand as (
    select cs.skill_id, cs.years
    from public.candidate_skills cs
    where cs.profile_version_id = p_profile_version_id and cs.skill_id is not null
  ),
  req as (
    select jr.skill_id, s.name, s.category, jr.required, jr.min_years, jr.weight
    from public.job_requirements jr
    join public.skills s on s.id = jr.skill_id
    where jr.job_id = p_job_id
  ),
  matched as (
    select r.*,
           coalesce(m.coverage, 0) as coverage,
           m.years as candidate_years,
           coalesce(m.via, 'none') as matched_via
    from req r
    left join lateral (
      select c.coverage, c.years, c.via
      from (
        select 1.0::numeric as coverage, cand.years, 'exact' as via, 0 as pri
        from cand where cand.skill_id = r.skill_id
        union all
        select sr.credit, cand.years, 'related', 1
        from cand
        join public.skill_relations sr on sr.skill_id = cand.skill_id and sr.related_skill_id = r.skill_id
      ) c
      order by c.coverage desc, c.pri, c.years desc nulls last
      limit 1
    ) m on true
  ),
  scored as (
    select m.*,
           case
             when m.min_years = 0 then 1.0
             when m.candidate_years is null then 0.5
             else least(1.0, m.candidate_years / m.min_years)
           end as depth
    from matched m
  ),
  final as (
    select s.*, s.coverage * (0.6 + 0.4 * s.depth) as req_score from scored s
  ),
  agg as (
    select
      sum(f.weight * f.req_score) filter (where f.required) / nullif(sum(f.weight) filter (where f.required), 0) as req,
      sum(f.weight * f.req_score) filter (where not f.required) / nullif(sum(f.weight) filter (where not f.required), 0) as pref
    from final f
  )
  select jsonb_build_object(
    'score',
    -- Round to 6 decimals first: averages like 5/6 are truncated decimals, so an exact .5
    -- (e.g. 80.5) would otherwise round down. The TypeScript mirror does the same.
    (select round(round(100 * greatest(0, least(1,
       case when a.req is null then coalesce(a.pref, 0)
            when a.pref is null then a.req
            else 0.85 * a.req + 0.15 * a.pref end)), 6))::integer
     from agg a),
    'breakdown',
    coalesce(jsonb_agg(jsonb_build_object(
      'skill_id', f.skill_id, 'name', f.name, 'category', f.category,
      'required', f.required, 'weight', f.weight, 'min_years', f.min_years,
      'candidate_years', f.candidate_years, 'matched_via', f.matched_via,
      'coverage', round(f.coverage, 3), 'depth', round(f.depth, 3), 'score', round(f.req_score, 3)
    ) order by f.required desc, f.weight desc, f.name collate "C") filter (where f.skill_id is not null), '[]'::jsonb)
  )
  from final f;
$$;

comment on function public.compute_match(uuid, uuid) is
  'Match Score v2 (PRD §8.4). Mirror: supabase/functions/_shared/score.ts.';

-- Scores stored on applications record which formula produced them (X-5).
alter table public.app_config alter column scoring_version set default 'v2';
update public.app_config set scoring_version = 'v2';

-- Not called by the app directly: other RPCs (swipe, get_feed, get_board) use it.
revoke execute on function public.compute_match(uuid, uuid) from public, anon, authenticated;
grant execute on function public.compute_match(uuid, uuid) to service_role;
