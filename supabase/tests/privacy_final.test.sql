begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data) values
 ('a1000000-0000-0000-0000-000000000001','hiring@acme.test',now(),'{"role":"recruiter"}'),
 ('a1000000-0000-0000-0000-000000000002','unconfirmed@acme.test',null,'{"role":"recruiter"}'),
 ('a1000000-0000-0000-0000-000000000003','owner@gmail.com',now(),'{"role":"recruiter"}'),
 ('a1000000-0000-0000-0000-000000000004','candidate@private.test',now(),'{"role":"candidate"}');
select ok(public.company_domain_verified('a1000000-0000-0000-0000-000000000001','https://www.acme.test/jobs'),'confirmed exact host verifies');
select ok(public.company_domain_verified('a1000000-0000-0000-0000-000000000001','HTTPS://WWW.ACME.TEST:443/jobs'),'host matching ignores case and port');
select ok(not public.company_domain_verified('a1000000-0000-0000-0000-000000000001','https://acme.test.evil.test'),'suffix spoof denied');
select ok(not public.company_domain_verified('a1000000-0000-0000-0000-000000000001','https://sub.acme.test'),'subdomain is not an exact match');
select ok(not public.company_domain_verified('a1000000-0000-0000-0000-000000000002','https://acme.test'),'unconfirmed email denied');
select ok(not public.company_domain_verified('a1000000-0000-0000-0000-000000000003','https://gmail.com'),'free mail denied');
select ok(not public.company_domain_verified('a1000000-0000-0000-0000-000000000001',null),'missing website unverified');
select ok(not has_function_privilege('authenticated','public.company_domain_verified(uuid,text)','execute'),'internal email lookup is not callable by client');
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000001","role":"authenticated"}',true);
set local role authenticated;
select is((public.create_company('Acme','https://www.acme.test')).verified,true,'company RPC returns verified badge');
update public.companies set website='https://elsewhere.test' where created_by=auth.uid();
select is((select verified from public.companies where created_by=auth.uid()),false,'website edits invalidate verification');
select throws_ok('select public.prepare_account_deletion()','P0001','not_candidate','recruiter deletion refused');
select throws_ok($$select public.get_resume_access('50000000-0000-0000-0000-000000000001')$$,'P0001','not_owner','unknown application hidden');
reset role;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-000000000004","role":"authenticated"}',true);
set local role authenticated;
select throws_ok($$select public.get_resume_access('50000000-0000-0000-0000-000000000001')$$,'P0001','not_recruiter','candidate cannot get recruiter link');
select lives_ok('select public.prepare_account_deletion()','candidate can prepare deletion');
select lives_ok('select public.prepare_account_deletion()','preparation can be retried');
reset role;
select is((select count(*)::int from public.candidates where profile_id='a1000000-0000-0000-0000-000000000004'),0,'candidate removed');
select is((select count(*)::int from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename in ('resumes','applications','jobs')),3,'all three live tables published');
select ok(not has_function_privilege('anon','public.prepare_account_deletion()','execute'),'anonymous deletion denied');
select ok(not has_function_privilege('anon','public.get_resume_access(uuid)','execute'),'anonymous resume lookup denied');
select * from finish();
rollback;
