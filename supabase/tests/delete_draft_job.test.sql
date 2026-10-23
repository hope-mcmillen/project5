begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('95100000-0000-0000-0000-000000000001','dd-owner@example.test','{"role":"recruiter"}'),
 ('95100000-0000-0000-0000-000000000002','dd-member@example.test','{"role":"recruiter"}'),
 ('95100000-0000-0000-0000-000000000003','dd-other@example.test','{"role":"recruiter"}'),
 ('95100000-0000-0000-0000-000000000004','dd-candidate@example.test','{"role":"candidate"}'),
 ('95100000-0000-0000-0000-000000000005','dd-loner@example.test','{"role":"recruiter"}');
insert into public.companies(id,name) values
 ('96100000-0000-0000-0000-000000000001','Delete Draft One'),
 ('96100000-0000-0000-0000-000000000003','Delete Draft Other');
insert into public.recruiters(profile_id,company_id,company_role) values
 ('95100000-0000-0000-0000-000000000001','96100000-0000-0000-0000-000000000001','owner'),
 ('95100000-0000-0000-0000-000000000002','96100000-0000-0000-0000-000000000001','member'),
 ('95100000-0000-0000-0000-000000000003','96100000-0000-0000-0000-000000000003','owner');
insert into public.jobs(id,company_id,created_by,title,raw_description,status) values
 ('97100000-0000-0000-0000-000000000001','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Owner draft','Synthetic','DRAFT'),
 ('97100000-0000-0000-0000-000000000002','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Member draft','Synthetic','DRAFT'),
 ('97100000-0000-0000-0000-000000000003','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Kept draft','Synthetic','DRAFT'),
 ('97100000-0000-0000-0000-000000000004','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Open job','Synthetic','OPEN'),
 ('97100000-0000-0000-0000-000000000005','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Paused job','Synthetic','PAUSED'),
 ('97100000-0000-0000-0000-000000000006','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Closed job','Synthetic','CLOSED'),
 ('97100000-0000-0000-0000-000000000007','96100000-0000-0000-0000-000000000001','95100000-0000-0000-0000-000000000001','Swiped draft','Synthetic','DRAFT');
insert into public.job_requirements(job_id,skill_id,required,min_years,weight)
 select '97100000-0000-0000-0000-000000000001',id,true,2,2 from public.skills where name='Flutter';
-- Impossible through the app (swipe() needs OPEN); proves the RPC never cascades candidate data.
insert into public.swipes(candidate_id,job_id,direction) values
 ('95100000-0000-0000-0000-000000000004','97100000-0000-0000-0000-000000000007','right');

select ok(not has_function_privilege('anon','public.delete_draft_job(uuid)','EXECUTE'),'anon cannot execute delete_draft_job');
select ok(has_function_privilege('authenticated','public.delete_draft_job(uuid)','EXECUTE'),'authenticated can execute delete_draft_job');
select ok(not has_table_privilege('authenticated','public.jobs','DELETE'),'direct job delete revoked');

set local role anon;
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000003')$$,'42501',null,'anon cannot delete drafts');
reset role;

set local role authenticated;
set local request.jwt.claims='{"sub":"95100000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000003')$$,'P0001','not_company_recruiter','candidate cannot delete drafts');
set local request.jwt.claims='{"sub":"95100000-0000-0000-0000-000000000005","role":"authenticated"}';
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000003')$$,'P0001','not_company_recruiter','recruiter without a company cannot delete drafts');
set local request.jwt.claims='{"sub":"95100000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000003')$$,'P0001','not_company_recruiter','other company cannot delete drafts');

set local request.jwt.claims='{"sub":"95100000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-0000000000ff')$$,'P0001','job_not_found','missing job reported');
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000004')$$,'P0001','job_not_draft','open job cannot be deleted');
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000005')$$,'P0001','job_not_draft','paused job cannot be deleted');
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000006')$$,'P0001','job_not_draft','closed job cannot be deleted');
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000007')$$,'P0001','job_not_draft','draft with swipes cannot be deleted');
select throws_ok($$delete from public.jobs where id='97100000-0000-0000-0000-000000000004'$$,'42501',null,'recruiter cannot delete jobs directly');
select lives_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000001')$$,'owner deletes own draft');

set local request.jwt.claims='{"sub":"95100000-0000-0000-0000-000000000002","role":"authenticated"}';
select lives_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000002')$$,'member deletes company draft');
select throws_ok($$select public.delete_draft_job('97100000-0000-0000-0000-000000000002')$$,'P0001','job_not_found','deleted draft is gone');
reset role;

select is((select count(*)::int from public.jobs where id in ('97100000-0000-0000-0000-000000000001','97100000-0000-0000-0000-000000000002')),0,'deleted drafts removed');
select is((select count(*)::int from public.job_requirements where job_id='97100000-0000-0000-0000-000000000001'),0,'deleted draft requirements removed');
select is((select count(*)::int from public.jobs where id in ('97100000-0000-0000-0000-000000000003','97100000-0000-0000-0000-000000000004',
 '97100000-0000-0000-0000-000000000005','97100000-0000-0000-0000-000000000006','97100000-0000-0000-0000-000000000007')),5,'other jobs untouched');
select is((select count(*)::int from public.swipes where job_id='97100000-0000-0000-0000-000000000007'),1,'swipes untouched');
select * from finish();
rollback;
