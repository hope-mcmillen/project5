begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select is((select count(*)::int from pg_tables where schemaname = 'public'
  and tablename in ('profiles','companies','recruiters','company_invites','app_config',
    'skills','skill_relations','candidates','resumes','profile_versions','candidate_skills',
    'jobs','job_requirements','swipes','applications','application_reject_reasons',
    'status_events','llm_usage','device_tokens','candidate_experiences') and rowsecurity), 20, 'all 20 tables enforce RLS');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'role', 'UPDATE'), 'client cannot change role');
select ok(not has_column_privilege('authenticated', 'public.candidates', 'active_version_id', 'UPDATE'), 'client cannot activate an unconfirmed profile');
select ok(not has_column_privilege('authenticated', 'public.resumes', 'status', 'INSERT'), 'client cannot forge parse status');
select ok(not has_table_privilege('authenticated', 'public.applications', 'INSERT'), 'application creation requires swipe RPC');
select ok(not has_table_privilege('authenticated', 'public.applications', 'UPDATE'), 'status changes require RPC');
select ok(not has_column_privilege('authenticated', 'public.jobs', 'status', 'UPDATE'), 'job lifecycle requires RPC');
select ok(not has_table_privilege('authenticated', 'public.job_requirements', 'INSERT'), 'requirements require validation RPC');
select ok(not has_table_privilege('authenticated', 'public.llm_usage', 'SELECT'), 'usage logs are service only');
select ok(not has_table_privilege('anon', 'public.profiles', 'SELECT'), 'anonymous profile reads denied');
select ok((select reloptions @> array['security_invoker=true'] from pg_class where oid = 'public.my_applications'::regclass), 'pipeline view uses caller RLS');
select ok((select reloptions @> array['security_invoker=true'] from pg_class where oid = 'public.company_jobs_overview'::regclass), 'overview view uses caller RLS');
select is((select count(*)::int from pg_publication_tables where pubname = 'supabase_realtime'
  and schemaname = 'public' and tablename in ('resumes','applications','jobs')), 3, 'UI tables are published');

insert into auth.users (id, email, raw_user_meta_data) values
 ('10000000-0000-0000-0000-000000000001','a2-candidate1@example.test','{"role":"candidate"}'),
 ('10000000-0000-0000-0000-000000000002','a2-candidate2@example.test','{"role":"candidate"}'),
 ('10000000-0000-0000-0000-000000000003','a2-recruiter1@example.test','{"role":"recruiter"}'),
 ('10000000-0000-0000-0000-000000000004','a2-recruiter2@example.test','{"role":"recruiter"}');
insert into public.profiles (id,role) values
 ('10000000-0000-0000-0000-000000000001','candidate'),
 ('10000000-0000-0000-0000-000000000002','candidate'),
 ('10000000-0000-0000-0000-000000000003','recruiter'),
 ('10000000-0000-0000-0000-000000000004','recruiter') on conflict (id) do nothing;
insert into public.companies (id,name,created_by) values
 ('20000000-0000-0000-0000-000000000001','A2 One','10000000-0000-0000-0000-000000000003'),
 ('20000000-0000-0000-0000-000000000002','A2 Two','10000000-0000-0000-0000-000000000004');
insert into public.recruiters (profile_id,company_id,company_role) values
 ('10000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','owner'),
 ('10000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000002','owner');
insert into public.candidates (profile_id) values
 ('10000000-0000-0000-0000-000000000001'),('10000000-0000-0000-0000-000000000002') on conflict do nothing;
insert into public.profile_versions (id,candidate_id,version,confirmed) values
 ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',1,true),
 ('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002',1,true);
insert into public.jobs (id,company_id,title,raw_description,status) values
 ('40000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Open','Synthetic','OPEN'),
 ('40000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002','Draft','Synthetic','DRAFT'),
 ('40000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','Closed','Synthetic','CLOSED');
insert into public.applications (id,candidate_id,job_id,profile_version_id,match_score,scoring_version,committed_at) values
 ('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',80,'v1',now()+interval '1 hour'),
 ('50000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000002',75,'v1',now()-interval '1 minute'),
 ('50000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001',70,'v1',now()-interval '1 minute');
insert into public.application_reject_reasons (application_id,reason) values
 ('50000000-0000-0000-0000-000000000002','internal only');

set local role authenticated;
set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.profiles where id::text like '10000000-%'),1,'candidate sees own profile only');
select is((select count(*)::int from public.candidates where profile_id::text like '10000000-%'),1,'candidate sees own candidate row only');
select is((select count(*)::int from public.profile_versions where id::text like '30000000-%'),1,'candidate sees own versions only');
select lives_ok($$update public.profiles set display_name='A2 Updated' where id='10000000-0000-0000-0000-000000000001'$$,'self can update display name');
select throws_ok($$update public.profiles set role='recruiter' where id='10000000-0000-0000-0000-000000000001'$$,'42501',null,'self cannot change role');
select is((select count(*)::int from public.jobs where id::text like '40000000-%'),2,'candidate sees open and own applied closed jobs');
select is((select count(*)::int from public.applications where id::text like '50000000-%'),2,'candidate sees own pending and committed applications');
select is((select count(*)::int from public.my_applications where id::text like '50000000-%'),2,'pipeline obeys self-only scope');
select is((select count(*)::int from public.application_reject_reasons),0,'candidate cannot read internal reasons');
select throws_ok($$insert into public.resumes(candidate_id,storage_path,file_hash,mime_type) values ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002/x.pdf','abc','application/pdf')$$,'42501',null,'cannot register a resume in another users folder');
select lives_ok($$insert into public.resumes(candidate_id,storage_path,file_hash,mime_type) values ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001/x.pdf','abc','application/pdf')$$,'can register own resume');

set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is(public.current_app_role()::text,'recruiter','role helper uses database role');
select is(public.my_company_id(),'20000000-0000-0000-0000-000000000001'::uuid,'company helper identifies caller');
select is((select count(*)::int from public.recruiters where profile_id::text like '10000000-%'),1,'no recursive recruiter RLS and own company only');
select is((select count(*)::int from public.candidates),0,'recruiter cannot read candidate identities');
select is((select count(*)::int from public.profile_versions),0,'recruiter cannot read profiles directly');
select is((select count(*)::int from public.resumes),0,'recruiter cannot read private resume rows');
select is((select count(*)::int from public.applications where id::text like '50000000-%'),2,'recruiter sees only committed company applications');
select is((select count(*)::int from public.my_applications),0,'candidate pipeline is empty for recruiter');
select is((select count(*)::int from public.application_reject_reasons),1,'company recruiter can read internal reason');
select lives_ok($$update public.companies set name='A2 Owner Updated' where id='20000000-0000-0000-0000-000000000001'$$,'owner can edit company');
select lives_ok($$update public.companies set name='A2 Unauthorized' where id='20000000-0000-0000-0000-000000000002'$$,'cross-company update silently affects no rows');
select isnt((select name from public.companies where id='20000000-0000-0000-0000-000000000002'),'A2 Unauthorized','other company unchanged');
select is((select total_count::int from public.company_jobs_overview where id='40000000-0000-0000-0000-000000000001'),1,'overview excludes pending swipe');

set local request.jwt.claims = '{"sub":"10000000-0000-0000-0000-000000000004","role":"authenticated"}';
select is((select count(*)::int from public.applications where id::text like '50000000-%'),0,'other company cannot read applications');
select is((select count(*)::int from public.application_reject_reasons),0,'other company cannot read reject reasons');

set local role anon;
select is((select count(*)::int from public.companies where id::text like '20000000-%'),2,'anonymous users may read public companies');
select throws_ok('select * from public.profiles','42501',null,'anonymous users cannot read profiles');
select throws_ok('select * from public.applications','42501',null,'anonymous users cannot read applications');
reset role;
select * from finish();
rollback;
