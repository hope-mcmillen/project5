-- Houston demo jobs (supabase/seed/houston_jobs.sql, loaded by `supabase db reset`). Run with `supabase test db`.
-- Checks the seed is complete and that get_feed() actually deals these jobs to a typical candidate.
begin;
set local search_path = public, extensions;
select plan(20);

create function pg_temp.hjobs() returns setof public.jobs language sql as $$
  select * from public.jobs where id::text like '484f5553-0001-%'
$$;

-- --- seed shape -------------------------------------------------------------------
select is((select count(*)::int from public.companies where id::text like '484f5553-0000-%' and is_seed), 18,
  'eighteen Houston demo companies');
select is((select count(*)::int from pg_temp.hjobs() where is_seed and status = 'OPEN' and parse_status = 'READY'), 80,
  'eighty OPEN, parsed Houston demo jobs');
select ok(not exists (select 1 from pg_temp.hjobs() where published_at > now() or expires_at <= now() + interval '30 days'
                      or expires_at <> published_at + interval '60 days'),
  'every job is published and stays open at least 30 more days (expires = published + 60 days)');
select ok(not exists (select 1 from pg_temp.hjobs() j
                      where (select count(*) from public.job_requirements jr where jr.job_id = j.id) not between 3 and 10),
  'every job has 3-10 requirements');
select ok(not exists (select 1 from pg_temp.hjobs() j
                      where (select count(*) filter (where jr.required) from public.job_requirements jr where jr.job_id = j.id)
                            not between 1 and 8),
  'every job has 1-8 required skills (R-JOB-2)');
select ok(not exists (select 1 from public.job_requirements where job_id::text like '484f5553-0001-%'
                      and not ((required and weight in (2, 3)) or (not required and weight = 1))),
  'required skills weigh 2-3, preferred weigh 1');
select is((select count(*)::int from pg_temp.hjobs() where embedding is not null and embedding_model = 'gemini-embedding-001@1536'), 80,
  'every job has a precomputed vector');
select ok(not exists (select 1 from pg_temp.hjobs() j
                      where j.embedding <=> public.skills_centroid(array(
                        select jr.skill_id from public.job_requirements jr where jr.job_id = j.id)) > 1e-6),
  'job vectors equal the centroid of their requirement skills');
select ok(not exists (select 1 from pg_temp.hjobs() where salary_min is null or salary_max is null or salary_min > salary_max),
  'every job has a salary range');
select is((select count(distinct job_type)::int from pg_temp.hjobs()), 4, 'internship, full-time, part-time and contract');
select is((select count(distinct remote)::int from pg_temp.hjobs()), 3, 'on-site, hybrid and remote');
select cmp_ok((select count(*)::int from pg_temp.hjobs() where location in ('Houston, TX', 'The Woodlands, TX', 'Sugar Land, TX',
  'Katy, TX', 'Pasadena, TX', 'Pearland, TX', 'La Porte, TX', 'Webster, TX')), '>=', 70, 'mostly Greater Houston');

-- --- feed ---------------------------------------------------------------------------
-- A typical CS student (the generator's "student" profile), with no preferences.
create function pg_temp.as_user(u uuid) returns void language sql as $$
  select set_config('request.jwt.claim.sub', coalesce(u::text, ''), true),
         set_config('request.jwt.claims', case when u is null then '' else json_build_object('sub', u)::text end, true);
$$;
create function pg_temp.houston_cards(f jsonb) returns int language sql as $$
  select count(*)::int from jsonb_array_elements(f -> 'cards') c where c -> 'company' ->> 'id' like '484f5553-%'
$$;
insert into auth.users (id) values ('484f5553-00fe-4000-8000-000000000001');
insert into public.profiles (id, role) values ('484f5553-00fe-4000-8000-000000000001', 'candidate')
on conflict (id) do update set role = excluded.role;
insert into public.candidates (profile_id) values ('484f5553-00fe-4000-8000-000000000001') on conflict do nothing;
insert into public.profile_versions (id, candidate_id, version, confirmed)
values ('484f5553-00fe-4000-8000-000000000002', '484f5553-00fe-4000-8000-000000000001', 1, true);
insert into public.candidate_skills (profile_version_id, skill_id, raw_name, years)
select '484f5553-00fe-4000-8000-000000000002', s.id, s.name, v.years
from (values ('Python', 2), ('Java', 2), ('C++', 1), ('SQL', 1), ('Git', 2), ('JavaScript', 1), ('HTML', 1), ('CSS', 1),
             ('Flutter', 1), ('Dart', 1), ('Data Structures', 2), ('Algorithms', 2), ('Object-Oriented Programming', 2),
             ('Linux', 1)) v (name, years)
join public.skills s on s.name = v.name;
update public.candidates set active_version_id = '484f5553-00fe-4000-8000-000000000002', preferences = '{}'
where profile_id = '484f5553-00fe-4000-8000-000000000001';

select pg_temp.as_user('484f5553-00fe-4000-8000-000000000001');
create temp table feeds (k text primary key, f jsonb) on commit drop;
insert into feeds values ('none', public.get_feed(50));
select cmp_ok(pg_temp.houston_cards((select f from feeds where k = 'none')), '>=', 15,
  'a student with no preferences gets at least 15 Houston cards');
select ok(not exists (select 1 from jsonb_array_elements((select f from feeds where k = 'none') -> 'cards') c
                      where (c ->> 'match_score')::int < 50),
  'default deck only shows matches of 50 and up');
select cmp_ok((select count(distinct c -> 'company' ->> 'id')::int
               from jsonb_array_elements((select f from feeds where k = 'none') -> 'cards') c
               where c -> 'company' ->> 'id' like '484f5553-%'), '>=', 8,
  'the deck spans many Houston companies');

-- Location preference "Houston, TX": Houston jobs and remote jobs elsewhere still show.
update public.candidates set preferences = '{"locations": ["Houston, TX"]}'
where profile_id = '484f5553-00fe-4000-8000-000000000001';
insert into feeds values ('houston', public.get_feed(50));
select cmp_ok(pg_temp.houston_cards((select f from feeds where k = 'houston')), '>=', 12,
  'a Houston location preference still leaves at least 12 Houston cards');
select ok(not exists (select 1 from jsonb_array_elements((select f from feeds where k = 'houston') -> 'cards') c
                      where c ->> 'location' <> 'Houston, TX' and c ->> 'remote' <> 'remote'),
  'location filter keeps only Houston or remote jobs');

-- Internships only, on-site or hybrid.
update public.candidates set preferences = '{"job_types": ["internship"], "remote": ["onsite", "hybrid"]}'
where profile_id = '484f5553-00fe-4000-8000-000000000001';
insert into feeds values ('intern', public.get_feed(50));
select cmp_ok(pg_temp.houston_cards((select f from feeds where k = 'intern')), '>=', 6,
  'an internship-only student still gets at least 6 Houston internships');

-- include_stretch shows every job that shares a skill, so the deck is much fuller.
update public.candidates set preferences = '{"include_stretch": true}'
where profile_id = '484f5553-00fe-4000-8000-000000000001';
insert into feeds values ('stretch', public.get_feed(50));
select cmp_ok(pg_temp.houston_cards((select f from feeds where k = 'stretch')), '>=', 40,
  'include_stretch opens up at least 40 Houston cards');

-- Swiping removes a card from the deck.
update public.candidates set preferences = '{}' where profile_id = '484f5553-00fe-4000-8000-000000000001';
insert into public.swipes (candidate_id, job_id, direction, pass_reason)
select '484f5553-00fe-4000-8000-000000000001', (c ->> 'job_id')::uuid, 'left', 'stack'
from jsonb_array_elements((select f from feeds where k = 'none') -> 'cards') c
where c -> 'company' ->> 'id' like '484f5553-%' limit 1;
select is(pg_temp.houston_cards(public.get_feed(50)), pg_temp.houston_cards((select f from feeds where k = 'none')) - 1,
  'a passed Houston job leaves the deck');

select * from finish();
rollback;
