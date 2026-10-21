begin;
set local search_path=public,extensions;
select plan(12);
select is((select count(*)::int from public.skills where is_seed),343,'all taxonomy skills seeded');
select is((select count(*)::int from public.skill_relations),132,'all taxonomy relations seeded');
select is((select count(*)::int from public.skills where embedding is not null and embedding_model='gemini-embedding-001@1536'),343,'all taxonomy vectors precomputed');
select is((select count(*)::int from public.companies where is_seed),3,'three demo companies');
select is((select count(*)::int from public.companies where is_seed and verified),1,'one verified demo company');
select is((select count(*)::int from public.candidates where is_seed),30,'thirty demo candidates');
select is((select count(*)::int from public.profile_versions where is_seed and confirmed),30,'demo profiles confirmed');
select is((select count(*)::int from public.applications where is_seed),60,'sixty demo applications');
select is((select count(distinct status)::int from public.applications where is_seed),6,'every application state covered');
select is((select count(*)::int from public.recruiters r join public.profiles p on p.id=r.profile_id where p.is_seed),4,'four demo recruiters');
select is((select count(*)::int from auth.identities i join public.profiles p on p.id=i.user_id where p.is_seed and i.provider='email'),2,'both login accounts have Auth identities');
select ok(not exists(select 1 from public.applications a where a.is_seed and
 a.match_score<>(public.compute_match(a.profile_version_id,a.job_id)->>'score')::integer),'seed scores equal live SQL scorer');
select * from finish();
rollback;
