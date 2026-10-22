-- B5 / AI-10: nearest canonical skills for skill normalization (PRD §8.3).
-- Depends on public.skills from A's PL-05 migration; it must sort after it.
-- Rename this file's timestamp if A's migrations land later (TEAM_PLAN: B
-- rebases onto the newest migration before merging).
--
-- Called by Edge Functions (normalize.ts) with the service-role client.
-- Threshold 0.89 was tuned on supabase/tests/fixtures/alias_pairs.json.

create or replace function public.match_skills(
  p_embedding extensions.vector(1536),
  p_threshold double precision default 0.89,
  p_k integer default 3
)
returns table (skill_id uuid, name text, similarity double precision)
language sql
stable
set search_path = public, extensions
as $$
  -- Nearest k first (ORDER BY distance + LIMIT uses the HNSW index), then the cutoff.
  -- Only vectors from the pinned model are comparable (PRD §9.3).
  select nearest.id, nearest.name, nearest.similarity
  from (
    select s.id, s.name, 1 - (s.embedding <=> p_embedding) as similarity
    from public.skills s
    where s.embedding is not null
      and s.embedding_model = 'gemini-embedding-001@1536'
    order by s.embedding <=> p_embedding
    limit greatest(p_k, 1)
  ) nearest
  where nearest.similarity >= p_threshold
  order by nearest.similarity desc;
$$;

comment on function public.match_skills(extensions.vector, double precision, integer) is
  'Nearest canonical skills by cosine similarity (B5). Edge Functions only.';

-- Not part of the app-facing API: only the service role (Edge Functions) may call it.
revoke execute on function public.match_skills(extensions.vector, double precision, integer) from public, anon, authenticated;
grant execute on function public.match_skills(extensions.vector, double precision, integer) to service_role;
