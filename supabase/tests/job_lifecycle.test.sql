begin;
set local search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data) values
 ('95000000-0000-0000-0000-000000000001','a8-recruiter@example.test','{"role":"recruiter"}'),
 ('95000000-0000-0000-0000-000000000002','a8-candidate@example.test','{"role":"candidate"}'),
 ('95000000-0000-0000-0000-000000000003','a8-other@example.test','{"role":"recruiter"}');
insert into public.companies(id,name) values
 ('96000000-0000-0000-0000-000000000001','Job Lifecycle One'),
 ('96000000-0000-0000-0000-000000000003','Job Lifecycle Other');
insert into public.recruiters(profile_id,company_id,company_role) values
 ('95000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001','owner'),
 ('95000000-0000-0000-0000-000000000003','96000000-0000-0000-0000-000000000003','owner');
insert into public.jobs(id,company_id,created_by,title,raw_description) values
 ('97000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','Flutter Developer','Synthetic');
insert into public.profile_versions(id,candidate_id,version,confirmed,total_years) values
 ('98000000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000002',1,true,4);
insert into public.candidate_skills(profile_version_id,skill_id,raw_name,years)
 select '98000000-0000-0000-0000-000000000002',id,'Flutter',4 from public.skills where name='Flutter';
create temp table fx(k text primary key,v jsonb);
grant all on fx to authenticated;
insert into fx values('flutter',(select jsonb_build_array(jsonb_build_object('skill_id',id,'required',true,'min_years',2,'weight',2,'evidence','Flutter role')) from public.skills where name='Flutter')),
 ('dart',(select jsonb_build_array(jsonb_build_object('skill_id',id,'required',true,'min_years',2,'weight',2,'evidence','Dart role')) from public.skills where name='Dart'));
set local role authenticated;
set local request.jwt.claims='{"sub":"95000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'P0001','not_recruiter','candidate cannot publish jobs');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001','[]')$$,'P0001','not_recruiter','candidate cannot set requirements');
set local request.jwt.claims='{"sub":"95000000-0000-0000-0000-000000000003","role":"authenticated"}';
select throws_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'P0001','not_owner','other company cannot publish jobs');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001','[]')$$,'P0001','not_owner','other company cannot edit requirements');
set local request.jwt.claims='{"sub":"95000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'P0001','requirements_not_ready','unparsed draft cannot publish');
select throws_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','PAUSED')$$,'P0001','invalid_transition','draft cannot pause');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',null)$$,'P0001','invalid_requirements','null requirements denied');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001','{}')$$,'P0001','invalid_requirements','nonarray requirements denied');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001','[{"skill_id":"bad","required":true,"min_years":0,"weight":2}]')$$,'P0001','invalid_requirements','bad skill ID denied');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select v||v from fx where k='flutter'))$$,'P0001','invalid_requirements','duplicate skill denied');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select jsonb_agg(jsonb_build_object('skill_id',id,'required',true,'min_years',0,'weight',2)) from (select id from public.skills order by id limit 9) s))$$,'P0001','invalid_requirements','nine required skills denied');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select jsonb_agg(jsonb_build_object('skill_id',id,'required',false,'min_years',0,'weight',2)) from (select id from public.skills order by id limit 16) s))$$,'P0001','invalid_requirements','sixteen total requirements denied');
select lives_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select v from fx where k='flutter'))$$,'owner saves validated requirements');
select ok((select embedding is not null and embedding_model='gemini-embedding-001@1536' and parse_status='READY' from public.jobs where id='97000000-0000-0000-0000-000000000001'),'job centroid and readiness saved');
select lives_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'validated draft publishes');
select ok((select published_at is not null and expires_at>now()+interval '59 days' and expires_at<now()+interval '61 days' from public.jobs where id='97000000-0000-0000-0000-000000000001'),'first publish sets sixty-day expiry');
insert into fx values('published',(select to_jsonb(published_at) from public.jobs where id='97000000-0000-0000-0000-000000000001'));
select lives_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','PAUSED')$$,'open job pauses');
select lives_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'paused job resumes');
select is((select to_jsonb(published_at) from public.jobs where id='97000000-0000-0000-0000-000000000001'),(select v from fx where k='published'),'resume does not reset freshness');
reset role;
insert into public.applications(id,candidate_id,job_id,profile_version_id,match_score,breakdown,scoring_version,committed_at)
 select '99000000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000002',
 (public.compute_match('98000000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000001')->>'score')::integer,
 public.compute_match('98000000-0000-0000-0000-000000000002','97000000-0000-0000-0000-000000000001')->'breakdown','v2',now()-interval '1 second';
set local role authenticated;
select is((select match_score::integer from public.applications where id='99000000-0000-0000-0000-000000000002'),100,'original applicant matches Flutter');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001','[]')$$,'P0001','invalid_requirements','live job cannot lose all requirements');
select lives_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select v from fx where k='dart'))$$,'live requirements can be edited');
select is((select match_score::integer from public.applications where id='99000000-0000-0000-0000-000000000002'),0,'live applicant re-scored through B formula');
select ok((select rescored_at is not null from public.jobs where id='97000000-0000-0000-0000-000000000001'),'re-score timestamp written');
select lives_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','CLOSED')$$,'open job closes');
select is((select status::text from public.applications where id='99000000-0000-0000-0000-000000000002'),'JOB_CLOSED','closing job cascades applicant state');
select is((select count(*)::int from public.status_events where application_id='99000000-0000-0000-0000-000000000002' and to_status='JOB_CLOSED'),1,'closing job audited');
select throws_ok($$select public.set_job_status('97000000-0000-0000-0000-000000000001','OPEN')$$,'P0001','invalid_transition','closed job cannot reopen');
select throws_ok($$select public.save_requirements('97000000-0000-0000-0000-000000000001',(select v from fx where k='flutter'))$$,'P0001','invalid_transition','closed requirements immutable');
reset role;
update public.applications set status='NOT_SELECTED',previous_status='APPLIED',rejected_at=clock_timestamp() where id='99000000-0000-0000-0000-000000000002';
set local role authenticated;
select throws_ok($$select public.undo_reject('99000000-0000-0000-0000-000000000002')$$,'P0001','invalid_transition','reject undo cannot resurrect applicant on closed job');
reset role;
select * from finish();
rollback;
