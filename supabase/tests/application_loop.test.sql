begin;
set local search_path=public,extensions;
select no_plan();
select is((select daily_apply_cap from public.app_config),25,'default cap is 25');
select is((select undo_seconds from public.app_config),5,'default undo is five seconds');
select is((select reject_undo_seconds from public.app_config),10,'reject undo is ten seconds');
-- Long windows make pending/undo assertions deterministic; expiry tests move
-- persisted timestamps into the past rather than sleeping inside transactions.
update public.app_config set undo_seconds=3600,reject_undo_seconds=3600;
insert into auth.users(id,email,raw_user_meta_data) values
 ('91000000-0000-0000-0000-000000000001','avery.private@example.test','{"role":"candidate"}'),
 ('91000000-0000-0000-0000-000000000002','a7-other@example.test','{"role":"candidate"}'),
 ('91000000-0000-0000-0000-000000000003','a7-owner@example.test','{"role":"recruiter"}'),
 ('91000000-0000-0000-0000-000000000004','a7-other-owner@example.test','{"role":"recruiter"}'),
 ('91000000-0000-0000-0000-000000000005','a7-draft@example.test','{"role":"candidate"}'),
 ('91000000-0000-0000-0000-000000000006','a7-cap@example.test','{"role":"candidate"}');
update public.profiles set display_name='Avery Private' where id='91000000-0000-0000-0000-000000000001';
update public.profiles set display_name='Demo Hiring Lead' where id='91000000-0000-0000-0000-000000000003';
insert into public.companies(id,name,created_by) values
 ('92000000-0000-0000-0000-000000000001','Loop One','91000000-0000-0000-0000-000000000003'),
 ('92000000-0000-0000-0000-000000000002','Loop Two','91000000-0000-0000-0000-000000000004');
insert into public.recruiters(profile_id,company_id,company_role) values
 ('91000000-0000-0000-0000-000000000003','92000000-0000-0000-0000-000000000001','owner'),
 ('91000000-0000-0000-0000-000000000004','92000000-0000-0000-0000-000000000002','owner');
insert into public.profile_versions(id,candidate_id,version,source,confirmed,total_years) values
 ('93000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001',1,'manual',true,4),
 ('93000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000002',1,'manual',true,1),
 ('93000000-0000-0000-0000-000000000006','91000000-0000-0000-0000-000000000006',1,'manual',true,3);
update public.candidates set active_version_id=('93000000-0000-0000-0000-'||right(profile_id::text,12))::uuid
 where profile_id in ('91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000006');
insert into public.candidate_skills(profile_version_id,skill_id,raw_name,years,evidence,source)
 select id,(select id from public.skills where name='Flutter'),'Flutter',total_years,
 'Avery built Flutter apps. Email avery.private@example.test, phone (555) 123-4567, https://example.test/avery','user'
 from public.profile_versions where id::text like '93000000-%';
insert into public.jobs(id,company_id,created_by,title,raw_description,status,parse_status,published_at,expires_at)
 select ('94000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,'92000000-0000-0000-0000-000000000001',
 '91000000-0000-0000-0000-000000000003','Loop Job '||n,'Synthetic Flutter role','OPEN','READY',now(),now()+interval '60 days'
 from generate_series(1,32) n;
insert into public.job_requirements(job_id,skill_id,min_years,required,weight)
 select id,(select id from public.skills where name='Flutter'),4,true,2 from public.jobs where id::text like '94000000-%';
update public.jobs set status='DRAFT' where id='94000000-0000-0000-0000-000000000030';
update public.jobs set expires_at=now()-interval '1 day' where id='94000000-0000-0000-0000-000000000031';
create temp table fx(k text primary key,v jsonb);
grant all on fx to authenticated;
create function pg_temp.claim(who text) returns void language sql as $$
 select set_config('request.jwt.claims',json_build_object('sub','91000000-0000-0000-0000-'||lpad(who,12,'0'),'role','authenticated')::text,true)
$$;
create function pg_temp.app(k text) returns uuid language sql as $$select (v->>'application_id')::uuid from fx where fx.k=$1$$;
create function pg_temp.sw(k text) returns uuid language sql as $$select (v->>'swipe_id')::uuid from fx where fx.k=$1$$;

set local role authenticated;
select pg_temp.claim('5');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000001','right')$$,'P0001','profile_not_confirmed','unconfirmed profile cannot apply');
select pg_temp.claim('3');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000001','right')$$,'P0001','not_candidate','recruiter cannot swipe');
select pg_temp.claim('1');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000030','right')$$,'P0001','job_not_open','draft job cannot be swiped');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000031','right')$$,'P0001','job_not_open','expired job cannot be swiped');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000001',null)$$,'P0001','invalid_direction','null direction denied');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000001','right','salary')$$,'P0001','invalid_reason','right swipe cannot have pass reason');
insert into fx values('one',public.swipe('94000000-0000-0000-0000-000000000001','right'));
select ok(pg_temp.app('one') is not null,'right swipe creates application');
select is((select match_score::integer from public.applications where id=pg_temp.app('one')),100,'real B scorer used, no 50-point stub');
select is((select scoring_version from public.applications where id=pg_temp.app('one')),'v2','scoring version captured');
select is((select profile_version_id from public.applications where id=pg_temp.app('one')),'93000000-0000-0000-0000-000000000001'::uuid,'profile snapshot captured');
select is((select count(*)::int from public.status_events where application_id=pg_temp.app('one')),1,'apply audit event written');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000001','left')$$,'P0001','already_swiped','duplicate swipe denied');
select throws_ok($$select public.set_pass_reason(pg_temp.sw('one'),'salary')$$,'P0001','not_left_swipe','right swipe reason edit denied');
select throws_ok($$select public.get_application_contact(pg_temp.app('one'))$$,'P0001','contact_not_available','contact hidden before interview');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001')$$,'P0001','not_recruiter','candidate cannot query board');
insert into fx values('left',public.swipe('94000000-0000-0000-0000-000000000002','left'));
select is(pg_temp.app('left'),null::uuid,'left swipe creates no application');
select lives_ok($$select public.set_pass_reason(pg_temp.sw('left'),'salary')$$,'pass reason saved');
select is((select pass_reason::text from public.swipes where id=pg_temp.sw('left')),'salary','pass reason persisted');
select lives_ok($$select public.undo_swipe(pg_temp.sw('left'))$$,'left swipe can undo within window');
select is((select count(*)::int from public.swipes where id=pg_temp.sw('left')),0,'undone pass removed');
insert into fx values('undo',public.swipe('94000000-0000-0000-0000-000000000002','right'));
select lives_ok($$select public.undo_swipe(pg_temp.sw('undo'))$$,'right apply can undo');
select is((select count(*)::int from public.applications where id=pg_temp.app('undo')),0,'undo removes application');
select is((select count(*)::int from public.status_events where application_id=pg_temp.app('undo')),0,'undo removes pending event');
select pg_temp.claim('2');
select throws_ok($$select public.undo_swipe(pg_temp.sw('one'))$$,'P0001','not_owner','another candidate cannot undo');
select throws_ok($$select public.withdraw(pg_temp.app('one'))$$,'P0001','not_owner','another candidate cannot withdraw');
insert into fx values('two',public.swipe('94000000-0000-0000-0000-000000000001','right'));
select pg_temp.claim('3');
select is(public.get_board('94000000-0000-0000-0000-000000000001'),'[]'::jsonb,'pending applications invisible to board');
select is((select count(*)::int from public.applications where id in (pg_temp.app('one'),pg_temp.app('two'))),0,'pending applications hidden by table RLS');
select throws_ok($$select public.get_candidate_detail(pg_temp.app('one'))$$,'P0001','application_not_committed','pending detail denied');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','application_not_committed','pending advance denied');
select throws_ok($$select public.reject(pg_temp.app('one'))$$,'P0001','application_not_committed','pending reject denied');
reset role;
update public.applications set committed_at=now()-interval '1 second' where id=pg_temp.app('one');
update public.applications set committed_at=now()-interval '2 seconds' where id=pg_temp.app('two');
set local role authenticated;
select pg_temp.claim('1');
select throws_ok($$select public.undo_swipe(pg_temp.sw('one'))$$,'P0001','undo_window_expired','committed apply cannot undo');
select pg_temp.claim('4');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001')$$,'P0001','not_owner','other company cannot query board');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','not_owner','other company cannot advance');
select throws_ok($$select public.get_candidate_detail(pg_temp.app('one'))$$,'P0001','not_owner','other company cannot query detail');
select is((select count(*)::int from public.applications where id in (pg_temp.app('one'),pg_temp.app('two'))),0,'other company cannot read raw applications');
select pg_temp.claim('3');
insert into fx values('board',public.get_board('94000000-0000-0000-0000-000000000001'));
select is(jsonb_array_length((select v from fx where k='board')),2,'committed board contains both applicants');
select is((select v->0->>'application_id' from fx where k='board'),pg_temp.app('one')::text,'board ordered by score before arrival');
select is((select array_agg(k order by k) from jsonb_object_keys((select v->0 from fx where k='board')) k),
 array['application_id','band','committed_at','gaps','handle','match_score','status','top_skills','total_years'],'blind tile key set exact');
select ok(not(public.get_candidate_detail(pg_temp.app('one')) ? 'identity'),'identity absent before advance');
select ok(public.get_candidate_detail(pg_temp.app('one'))::text not like '%Avery%','known first name redacted from evidence');
select ok(public.get_candidate_detail(pg_temp.app('one'))::text not like '%avery.private@example.test%','email redacted from evidence');
select ok(public.get_candidate_detail(pg_temp.app('one'))::text not like '%123-4567%','phone redacted from evidence');
select ok(public.get_candidate_detail(pg_temp.app('one'))::text not like '%https://%','contact links redacted from evidence');
select is(jsonb_array_length(public.get_board('94000000-0000-0000-0000-000000000001','{"min_score":99}')),1,'minimum score filter');
select is(jsonb_array_length(public.get_board('94000000-0000-0000-0000-000000000001','{}',1,1)),1,'pagination honored');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001','{"unknown":true}')$$,'P0001','invalid_filters','unknown board filters denied');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001','{"statuses":"APPLIED"}')$$,'P0001','invalid_filters','wrong filter type denied');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001','{"statuses":["ADMIN"]}')$$,'P0001','invalid_filters','invalid status filter denied');
select throws_ok($$select public.get_board('94000000-0000-0000-0000-000000000001','{}',0,0)$$,'P0001','invalid_pagination','invalid board limit denied');
select lives_ok($$select public.open_application(pg_temp.app('one'))$$,'opening applied application starts review');
select lives_ok($$select public.open_application(pg_temp.app('one'))$$,'opening review is idempotent');
select is((select count(*)::int from public.status_events where application_id=pg_temp.app('one')),2,'idempotent open adds no extra event');
select lives_ok($$select public.advance(pg_temp.app('one'),'Please suggest interview times')$$,'reviewed application advances');
select is(public.get_candidate_detail(pg_temp.app('one'))->'identity'->>'display_name','Avery Private','advanced detail reveals identity');
select is(jsonb_array_length(public.get_interview_list('94000000-0000-0000-0000-000000000001')),1,'interview list shows advanced applicant');
select lives_ok($$select public.reject(pg_temp.app('one'),'INTERNAL_ONLY')$$,'interview applicant may be rejected');
select ok(not(public.get_candidate_detail(pg_temp.app('one')) ? 'identity'),'identity hidden again after rejection');
select is((select reason from public.application_reject_reasons where application_id=pg_temp.app('one')),'INTERNAL_ONLY','internal reason stored separately');
select lives_ok($$select public.undo_reject(pg_temp.app('one'))$$,'reject undo restores previous state');
select is((select status::text from public.applications where id=pg_temp.app('one')),'INTERVIEW_REQUESTED','reject undo restores interview');
select is((select count(*)::int from public.application_reject_reasons where application_id=pg_temp.app('one')),0,'undo removes internal rejection reason');
select pg_temp.claim('1');
select is(public.get_application_contact(pg_temp.app('one'))->>'email','a7-owner@example.test','candidate gets advancing recruiter contact');
select lives_ok($$select public.withdraw(pg_temp.app('one'))$$,'owning candidate withdraws');
select throws_ok($$select public.get_application_contact(pg_temp.app('one'))$$,'P0001','contact_not_available','contact unavailable after withdrawal');
select is((select count(*)::int from public.swipes where id=pg_temp.sw('one')),1,'withdraw retains right swipe for cap');
select is((select count(*)::int from public.application_reject_reasons where application_id=pg_temp.app('one')),0,'candidate cannot read rejection reasons');
select pg_temp.claim('3');
select lives_ok($$select public.reject(pg_temp.app('two'),'INTERNAL_ONLY')$$,'reject writes private reason');
select pg_temp.claim('2');
select is((select count(*)::int from public.application_reject_reasons where application_id=pg_temp.app('two')),0,'rejected candidate cannot read reason');
reset role;
update public.applications set rejected_at=now()-interval '2 hours' where id=pg_temp.app('two');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.undo_reject(pg_temp.app('two'))$$,'P0001','undo_window_expired','reject undo expires');

-- Exactly 25 accepted right swipes, followed by rejection of the 26th.
select pg_temp.claim('6');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000001','right')$$,'cap accepts apply 1');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000002','right')$$,'cap accepts apply 2');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000003','right')$$,'cap accepts apply 3');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000004','right')$$,'cap accepts apply 4');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000005','right')$$,'cap accepts apply 5');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000006','right')$$,'cap accepts apply 6');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000007','right')$$,'cap accepts apply 7');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000008','right')$$,'cap accepts apply 8');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000009','right')$$,'cap accepts apply 9');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000010','right')$$,'cap accepts apply 10');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000011','right')$$,'cap accepts apply 11');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000012','right')$$,'cap accepts apply 12');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000013','right')$$,'cap accepts apply 13');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000014','right')$$,'cap accepts apply 14');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000015','right')$$,'cap accepts apply 15');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000016','right')$$,'cap accepts apply 16');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000017','right')$$,'cap accepts apply 17');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000018','right')$$,'cap accepts apply 18');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000019','right')$$,'cap accepts apply 19');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000020','right')$$,'cap accepts apply 20');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000021','right')$$,'cap accepts apply 21');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000022','right')$$,'cap accepts apply 22');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000023','right')$$,'cap accepts apply 23');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000024','right')$$,'cap accepts apply 24');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000025','right')$$,'cap accepts apply 25');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000026','right')$$,'P0001','daily_cap_reached','26th apply rejected');
select is((select count(*)::int from public.swipes where candidate_id='91000000-0000-0000-0000-000000000006' and direction='right'),25,'cap leaves exactly 25 right swipes');
select lives_ok($$select public.withdraw((select id from public.applications where candidate_id='91000000-0000-0000-0000-000000000006' and job_id='94000000-0000-0000-0000-000000000001'))$$,'cap candidate withdraws one');
select throws_ok($$select public.swipe('94000000-0000-0000-0000-000000000026','right')$$,'P0001','daily_cap_reached','withdraw does not refund cap');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000026','left')$$,'pass remains possible at cap');
reset role;
update public.applications set status='APPLIED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.open_application(pg_temp.app('one'))$$,'state machine permits open_application from APPLIED');
reset role;
update public.applications set status='UNDER_REVIEW',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.open_application(pg_temp.app('one'))$$,'state machine permits open_application from UNDER_REVIEW');
reset role;
update public.applications set status='INTERVIEW_REQUESTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.open_application(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies open_application from INTERVIEW_REQUESTED');
reset role;
update public.applications set status='NOT_SELECTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.open_application(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies open_application from NOT_SELECTED');
reset role;
update public.applications set status='WITHDRAWN',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.open_application(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies open_application from WITHDRAWN');
reset role;
update public.applications set status='JOB_CLOSED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.open_application(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies open_application from JOB_CLOSED');
reset role;
update public.applications set status='APPLIED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.advance(pg_temp.app('one'))$$,'state machine permits advance from APPLIED');
reset role;
update public.applications set status='UNDER_REVIEW',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.advance(pg_temp.app('one'))$$,'state machine permits advance from UNDER_REVIEW');
reset role;
update public.applications set status='INTERVIEW_REQUESTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies advance from INTERVIEW_REQUESTED');
reset role;
update public.applications set status='NOT_SELECTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies advance from NOT_SELECTED');
reset role;
update public.applications set status='WITHDRAWN',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies advance from WITHDRAWN');
reset role;
update public.applications set status='JOB_CLOSED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.advance(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies advance from JOB_CLOSED');
reset role;
update public.applications set status='APPLIED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.reject(pg_temp.app('one'))$$,'state machine permits reject from APPLIED');
reset role;
update public.applications set status='UNDER_REVIEW',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.reject(pg_temp.app('one'))$$,'state machine permits reject from UNDER_REVIEW');
reset role;
update public.applications set status='INTERVIEW_REQUESTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select lives_ok($$select public.reject(pg_temp.app('one'))$$,'state machine permits reject from INTERVIEW_REQUESTED');
reset role;
update public.applications set status='NOT_SELECTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.reject(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies reject from NOT_SELECTED');
reset role;
update public.applications set status='WITHDRAWN',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.reject(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies reject from WITHDRAWN');
reset role;
update public.applications set status='JOB_CLOSED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('3');
select throws_ok($$select public.reject(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies reject from JOB_CLOSED');
reset role;
update public.applications set status='APPLIED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select lives_ok($$select public.withdraw(pg_temp.app('one'))$$,'state machine permits withdraw from APPLIED');
reset role;
update public.applications set status='UNDER_REVIEW',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select lives_ok($$select public.withdraw(pg_temp.app('one'))$$,'state machine permits withdraw from UNDER_REVIEW');
reset role;
update public.applications set status='INTERVIEW_REQUESTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select lives_ok($$select public.withdraw(pg_temp.app('one'))$$,'state machine permits withdraw from INTERVIEW_REQUESTED');
reset role;
update public.applications set status='NOT_SELECTED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select throws_ok($$select public.withdraw(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies withdraw from NOT_SELECTED');
reset role;
update public.applications set status='WITHDRAWN',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select throws_ok($$select public.withdraw(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies withdraw from WITHDRAWN');
reset role;
update public.applications set status='JOB_CLOSED',previous_status=null,rejected_at=null where id=pg_temp.app('one');
set local role authenticated;
select pg_temp.claim('1');
select throws_ok($$select public.withdraw(pg_temp.app('one'))$$,'P0001','invalid_transition','state machine denies withdraw from JOB_CLOSED');
reset role;
select ok(not has_function_privilege('authenticated','public.change_application(uuid,text,text)','EXECUTE'),'internal dispatcher not callable by clients');
select ok(not has_function_privilege('authenticated','public.application_tile(public.applications)','EXECUTE'),'internal tile cannot bypass ownership');
select ok(not has_function_privilege('authenticated','public.blind_evidence(text,uuid)','EXECUTE'),'internal redactor cannot query arbitrary identities');
select ok(not has_function_privilege('anon','public.swipe(uuid,public.swipe_direction,public.pass_reason)','EXECUTE'),'anonymous swipe denied');
select ok(not has_function_privilege('anon','public.get_board(uuid,jsonb,integer,integer)','EXECUTE'),'anonymous board denied');
-- UTC cap boundaries do not depend on the client's/session timezone.
update public.swipes set created_at=(date_trunc('day',clock_timestamp() at time zone 'UTC') at time zone 'UTC')-interval '1 microsecond'
 where candidate_id='91000000-0000-0000-0000-000000000006' and direction='right';
set local time zone 'Pacific/Honolulu';
set local role authenticated;
select pg_temp.claim('6');
select lives_ok($$select public.swipe('94000000-0000-0000-0000-000000000027','right')$$,'previous UTC day swipes do not consume today cap');
reset role;
-- A long transaction must not hold the undo window open via transaction now().
update public.applications set committed_at=clock_timestamp()+interval '50 milliseconds',status='APPLIED' where id=pg_temp.app('one');
select pg_sleep(0.10);
set local role authenticated;
select pg_temp.claim('1');
select throws_ok($$select public.undo_swipe(pg_temp.sw('one'))$$,'P0001','undo_window_expired','wall clock bounds undo even inside old transaction');
reset role;
select * from finish();
rollback;
