-- B9 get_feed tests (pgTAP). Run with `supabase test db`.
-- Self-contained: inserts its own skills/companies/jobs and rolls back.
begin;
select plan(27);

-- --- fixtures -------------------------------------------------------------------
-- Isolate from seed/demo data: only this file's jobs are OPEN (rolled back at the end).
update public.jobs set status = 'CLOSED' where status = 'OPEN';
insert into public.skills (name, category) values ('Flutter', 'Frameworks'), ('Dart', 'Languages'), ('Kubernetes', 'Cloud/DevOps')
on conflict (name) do nothing;

create temp table ids (k text primary key, id uuid) on commit drop;
insert into ids values
  ('cand', 'aaaaaaaa-0000-4000-8000-00000000000a'), ('cand2', 'aaaaaaaa-0000-4000-8000-00000000000b'),
  ('rec', 'aaaaaaaa-0000-4000-8000-00000000000c'),
  ('coA', 'cccccccc-0000-4000-8000-00000000000a'), ('coB', 'cccccccc-0000-4000-8000-00000000000b'),
  ('coX', 'cccccccc-0000-4000-8000-00000000000c');
create function pg_temp.id(k text) returns uuid language sql as $$ select id from ids where ids.k = $1 $$;
create function pg_temp.skill(n text) returns uuid language sql as $$ select id from public.skills where name = $1 $$;
-- Act as a user: auth.uid() reads request.jwt.claim(s).sub.
create function pg_temp.as_user(u uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(u::text, ''), true),
         set_config('request.jwt.claims', case when u is null then '' else json_build_object('sub', u)::text end, true);
$$;
create function pg_temp.feed(lim integer default 20, cur text default null) returns jsonb language sql as $$
  select public.get_feed(lim, cur);
$$;
create function pg_temp.titles(f jsonb) returns text[] language sql as $$
  select coalesce(array_agg(c ->> 'title' order by o), '{}') from jsonb_array_elements(f -> 'cards') with ordinality t(c, o);
$$;

insert into auth.users (id) select pg_temp.id(k) from (values ('cand'), ('cand2'), ('rec')) v(k);
insert into public.profiles (id, role) values
  (pg_temp.id('cand'), 'candidate'), (pg_temp.id('cand2'), 'candidate'), (pg_temp.id('rec'), 'recruiter')
on conflict (id) do update set role = excluded.role;
insert into public.candidates (profile_id) values (pg_temp.id('cand')), (pg_temp.id('cand2'));
insert into public.profile_versions (id, candidate_id, version, confirmed)
values ('dddddddd-0000-4000-8000-00000000000a', pg_temp.id('cand'), 1, true),
       ('dddddddd-0000-4000-8000-00000000000b', pg_temp.id('cand2'), 1, false);
insert into public.candidate_skills (profile_version_id, skill_id, raw_name, years) values
  ('dddddddd-0000-4000-8000-00000000000a', pg_temp.skill('Flutter'), 'Flutter', 4),
  ('dddddddd-0000-4000-8000-00000000000a', pg_temp.skill('Dart'), 'Dart', 4);
update public.candidates set active_version_id = 'dddddddd-0000-4000-8000-00000000000a' where profile_id = pg_temp.id('cand');
update public.candidates set active_version_id = 'dddddddd-0000-4000-8000-00000000000b' where profile_id = pg_temp.id('cand2');

insert into public.companies (id, name, verified) values
  (pg_temp.id('coA'), 'Alpha', true), (pg_temp.id('coB'), 'Bravo', false), (pg_temp.id('coX'), 'Xray', false);

-- Jobs: title doubles as a label. All Flutter+Dart required unless noted.
insert into public.jobs (id, company_id, title, raw_description, status, remote, location, job_type, sponsorship,
                         salary_min, salary_max, published_at, expires_at) values
  ('eeeeeeee-0000-4000-8000-000000000001', pg_temp.id('coA'), 'A1', 'x', 'OPEN', 'hybrid', 'Baton Rouge, LA', 'full_time', false, 90000, 110000, now(), now() + interval '60 days'),
  ('eeeeeeee-0000-4000-8000-000000000002', pg_temp.id('coA'), 'A2', 'x', 'OPEN', 'hybrid', 'Baton Rouge, LA', 'full_time', false, 90000, 110000, now(), now() + interval '60 days'),
  ('eeeeeeee-0000-4000-8000-000000000003', pg_temp.id('coA'), 'A3', 'x', 'OPEN', 'hybrid', 'Baton Rouge, LA', 'full_time', false, 90000, 110000, now(), now() + interval '60 days'),
  ('eeeeeeee-0000-4000-8000-000000000004', pg_temp.id('coB'), 'B-k8s', 'x', 'OPEN', 'remote', null, 'full_time', true, 120000, 150000, now(), now() + interval '60 days'),
  ('eeeeeeee-0000-4000-8000-000000000005', pg_temp.id('coB'), 'B-old', 'x', 'OPEN', 'remote', null, 'contract', true, 60000, 70000, now() - interval '40 days', now() + interval '20 days'),
  ('eeeeeeee-0000-4000-8000-000000000006', pg_temp.id('coX'), 'X-draft', 'x', 'DRAFT', null, null, null, false, null, null, null, null),
  ('eeeeeeee-0000-4000-8000-000000000007', pg_temp.id('coX'), 'X-expired', 'x', 'OPEN', null, null, null, false, null, null, now() - interval '70 days', now() - interval '10 days'),
  ('eeeeeeee-0000-4000-8000-000000000008', pg_temp.id('coX'), 'X-swiped', 'x', 'OPEN', null, null, null, false, null, null, now(), now() + interval '60 days'),
  ('eeeeeeee-0000-4000-8000-000000000009', pg_temp.id('coX'), 'X-austin', 'x', 'OPEN', 'onsite', 'Austin, TX', 'full_time', false, 100000, 120000, now() - interval '20 days', now() + interval '40 days');
-- Ranks (match 100 everywhere except B-k8s): A1–A3 ≥ 0.90 (fresh); X-austin ≤ 0.85 (20 days old);
-- B-old ≤ 0.80 (40 days old). So by rank alone the deck would open A, A, A.
insert into public.job_requirements (job_id, skill_id, required, min_years, weight)
select j.id, s.id, true, 2, 2
from public.jobs j cross join public.skills s
where j.title in ('A1', 'A2', 'A3', 'B-old', 'X-draft', 'X-expired', 'X-swiped', 'X-austin') and s.name in ('Flutter', 'Dart');
-- B-k8s: Kubernetes required (missing), Flutter preferred → 0.85 × 0 + 0.15 × 1 = 15, below the stretch line
insert into public.job_requirements (job_id, skill_id, required, min_years, weight) values
  ('eeeeeeee-0000-4000-8000-000000000004', pg_temp.skill('Flutter'), false, 0, 1),
  ('eeeeeeee-0000-4000-8000-000000000004', pg_temp.skill('Kubernetes'), true, 0, 2);
insert into public.swipes (candidate_id, job_id, direction) values (pg_temp.id('cand'), 'eeeeeeee-0000-4000-8000-000000000008', 'right');

-- --- access ---------------------------------------------------------------------
select pg_temp.as_user(null);
select throws_ok($$ select pg_temp.feed() $$, 'P0001', 'not_candidate', 'anonymous caller is rejected');
select pg_temp.as_user(pg_temp.id('rec'));
select throws_ok($$ select pg_temp.feed() $$, 'P0001', 'not_candidate', 'recruiters have no feed');
select pg_temp.as_user(pg_temp.id('cand2'));
select throws_ok($$ select pg_temp.feed() $$, 'P0001', 'profile_not_confirmed', 'an unconfirmed profile has no feed');

select pg_temp.as_user(pg_temp.id('cand'));
select throws_ok($$ select pg_temp.feed(5, 'not-a-cursor') $$, 'P0001', 'invalid_cursor', 'garbage cursor is rejected');

-- --- filtering ------------------------------------------------------------------
select is(
  (select array_agg(t order by t) from unnest(pg_temp.titles(pg_temp.feed())) t),
  array['A1', 'A2', 'A3', 'B-old', 'X-austin'],
  'only OPEN, unexpired, unswiped jobs scoring >= 50'
);
select is((pg_temp.feed() -> 'next_cursor'), 'null'::jsonb, 'no next_cursor when everything fits');

update public.candidates set preferences = '{"include_stretch": true}' where profile_id = pg_temp.id('cand');
select ok('B-k8s' = any(pg_temp.titles(pg_temp.feed())), 'include_stretch shows matches below 50');
select is(
  (select (c ->> 'match_score')::int from jsonb_array_elements(pg_temp.feed() -> 'cards') c where c ->> 'title' = 'B-k8s'),
  15, 'stretch card carries its real score'
);

update public.candidates set preferences = '{"remote": ["remote", "hybrid"]}' where profile_id = pg_temp.id('cand');
select ok(not 'X-austin' = any(pg_temp.titles(pg_temp.feed())), 'remote filter drops onsite jobs');
update public.candidates set preferences = '{"locations": ["baton rouge, la"]}' where profile_id = pg_temp.id('cand');
select is(
  (select array_agg(t order by t) from unnest(pg_temp.titles(pg_temp.feed())) t),
  array['A1', 'A2', 'A3', 'B-old'], 'location filter is case-insensitive and lets remote jobs through'
);
update public.candidates set preferences = '{"job_types": ["contract"]}' where profile_id = pg_temp.id('cand');
select is(pg_temp.titles(pg_temp.feed()), array['B-old'], 'job type filter');
update public.candidates set preferences = '{"needs_sponsorship": true}' where profile_id = pg_temp.id('cand');
select is(pg_temp.titles(pg_temp.feed()), array['B-old'], 'sponsorship filter (B-k8s sponsors but is below 50)');
update public.candidates set preferences = '{"salary_min": 105000}' where profile_id = pg_temp.id('cand');
select is(
  (select array_agg(t order by t) from unnest(pg_temp.titles(pg_temp.feed())) t),
  array['A1', 'A2', 'A3', 'X-austin'], 'salary floor compares against salary_max'
);
update public.candidates set preferences = '{}' where profile_id = pg_temp.id('cand');

-- --- ranking and diversity --------------------------------------------------------
select ok(
  (select bool_and(not (c1 = c2 and c2 = c3)) from (
    select c ->> 'company' as c1,
           lead(c ->> 'company') over (order by o) as c2,
           lead(c ->> 'company', 2) over (order by o) as c3
    from jsonb_array_elements(pg_temp.feed() -> 'cards') with ordinality t(c, o)) w
   where c3 is not null),
  'no company three times in a row'
);
select is(
  (pg_temp.titles(pg_temp.feed()))[3], 'X-austin',
  'by rank the deck opens A, A, A; diversity pulls the next company up to third'
);

-- --- paging ---------------------------------------------------------------------------
create temp table p1 on commit drop as select pg_temp.feed(2) as f;
select is(jsonb_array_length((select f from p1) -> 'cards'), 2, 'page 1 has p_limit cards');
select isnt((select f from p1) ->> 'next_cursor', null, 'page 1 has a next_cursor');
create temp table p2 on commit drop as select pg_temp.feed(2, (select f ->> 'next_cursor' from p1)) as f;
create temp table p3 on commit drop as select pg_temp.feed(2, (select f ->> 'next_cursor' from p2)) as f;
select is(
  (select array_agg(t order by t) from (
     select unnest(pg_temp.titles(f)) t from p1 union all select unnest(pg_temp.titles(f)) from p2
     union all select unnest(pg_temp.titles(f)) from p3) u),
  array['A1', 'A2', 'A3', 'B-old', 'X-austin'], 'pages cover every card exactly once'
);
select is((select f -> 'next_cursor' from p3), 'null'::jsonb, 'last page has no next_cursor');
select ok(
  (select bool_and(not (a = b and b = c)) from (
     select x as a, lead(x) over (order by o) as b, lead(x, 2) over (order by o) as c
     from (select c ->> 'company' as x, row_number() over () as o from (
             select jsonb_array_elements(f -> 'cards') c from p1 union all
             select jsonb_array_elements(f -> 'cards') from p2 union all
             select jsonb_array_elements(f -> 'cards') from p3) z) y) w where c is not null),
  'diversity holds across page boundaries'
);

-- --- pass reasons move Feed Rank, never match_score ------------------------------------
insert into public.swipes (candidate_id, job_id, direction, pass_reason)
values (pg_temp.id('cand'), 'eeeeeeee-0000-4000-8000-000000000002', 'left', 'company');
select is(
  array[
    public.feed_affinity(pg_temp.id('cand'), pg_temp.id('coA'), 'hybrid', 110000, 100),
    public.feed_affinity(pg_temp.id('cand'), pg_temp.id('coB'), 'remote', 70000, 100)],
  array[0, 0.5]::numeric[],
  'a company pass zeroes that company''s affinity; others stay neutral'
);
select is(
  (select array_agg(distinct (c ->> 'match_score')::int) from jsonb_array_elements(pg_temp.feed() -> 'cards') c
   where c ->> 'title' in ('A1', 'A3')),
  array[100], 'match_score is unchanged by the pass'
);

-- --- card shape and helpers --------------------------------------------------------------
select is(
  (select array_agg(k order by k) from jsonb_object_keys(pg_temp.feed() -> 'cards' -> 0) k),
  array['band', 'breakdown', 'company', 'gaps', 'job_id', 'job_type', 'location', 'match_score', 'published_at',
        'remote', 'required_gaps', 'salary_max', 'salary_min', 'sponsorship', 'title', 'top_matches'],
  'cards have exactly the API_CONTRACT §6 fields'
);
select ok(public.feed_exploration('eeeeeeee-0000-4000-8000-000000000001') between 0 and 1, 'exploration is in [0, 1]');
select is(
  array[public.feed_freshness(now()), public.feed_freshness(now() - interval '15 days'), public.feed_freshness(now() - interval '40 days')],
  array[1, 0.5, 0]::numeric[], 'freshness: 1 today, 0.5 at 15 days, 0 after 30'
);
select is(
  (select bool_and(not has_function_privilege(r, 'public.get_feed(integer, text)', 'execute')) from unnest(array['anon']) r)
  and has_function_privilege('authenticated', 'public.get_feed(integer, text)', 'execute')
  and not has_function_privilege('authenticated', 'public.compute_match(uuid, uuid)', 'execute'),
  true, 'authenticated can call get_feed; anon cannot; compute_match stays internal'
);

-- A job with no stored vector still competes in the prefilter (it ranks by skill overlap).
update public.jobs set embedding = null where id = 'eeeeeeee-0000-4000-8000-000000000001';
update public.jobs j set embedding = public.skills_centroid(array(
  select skill_id from public.job_requirements jr where jr.job_id = j.id))
where j.id <> 'eeeeeeee-0000-4000-8000-000000000001' and j.title in ('A2', 'A3', 'B-old', 'X-austin', 'B-k8s');
select ok('A1' = any(pg_temp.titles(pg_temp.feed())), 'a job without a stored vector still appears');

select * from finish();
rollback;
