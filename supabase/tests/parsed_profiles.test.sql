-- Resume parsing without storage (migration 20261022200000): save_parsed_profile
-- writes a draft version, merged skills, and experiences; candidate_experiences
-- is read-own; create_review_draft copies the active version for editing.
begin;
set local search_path=public,extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data) values
 ('91000000-0000-0000-0000-000000000001','parse-one@example.test','{"role":"candidate"}'),
 ('91000000-0000-0000-0000-000000000002','parse-two@example.test','{"role":"candidate"}'),
 ('91000000-0000-0000-0000-000000000003','parse-recruiter@example.test','{"role":"recruiter"}');
create temp table fixture(k text primary key,v uuid);
grant all on fixture to authenticated;
insert into fixture values ('flutter',(select id from public.skills where name='Flutter')),('dart',(select id from public.skills where name='Dart'));

create temp table payload(k text primary key,j jsonb);
grant all on payload to authenticated;
insert into payload values
 ('skills',jsonb_build_array(
   jsonb_build_object('skill_id',(select v from fixture where k='flutter'),'raw_name','Flutter','years',2,'evidence','Built Flutter apps'),
   jsonb_build_object('skill_id',(select v from fixture where k='flutter'),'raw_name','flutter','years',4.5,'evidence','Flutter at work'),
   jsonb_build_object('skill_id',(select v from fixture where k='dart'),'raw_name','Dart','years',null,'evidence','Dart projects'),
   jsonb_build_object('skill_id',null,'raw_name','Codemagic','years',1,'evidence','Codemagic CI'))),
 ('experiences','[
   {"kind":"job","title":"Mobile Developer","organization":"Bayou Apps","start":"2022-03","end":"present",
    "highlights":["Built Flutter apps"],"skills_used":["Flutter","Dart"],"evidence":"Mobile Developer, Bayou Apps"},
   {"kind":"project","title":"Campus Map","organization":null,"start":"2021","end":null,
    "highlights":[],"skills_used":[],"evidence":"Campus Map"}]'),
 ('education','[{"level":"BS","field":null}]');

-- Privileges: only the service role (parse-resume) may save parsed drafts.
select ok(has_function_privilege('service_role','public.save_parsed_profile(uuid,integer,text,numeric,jsonb,jsonb,jsonb)','EXECUTE'),'service role saves parsed drafts');
select ok(not has_function_privilege('authenticated','public.save_parsed_profile(uuid,integer,text,numeric,jsonb,jsonb,jsonb)','EXECUTE'),'clients cannot save parsed drafts');
select ok(not has_function_privilege('anon','public.save_parsed_profile(uuid,integer,text,numeric,jsonb,jsonb,jsonb)','EXECUTE'),'anonymous cannot save parsed drafts');
select ok(has_function_privilege('authenticated','public.create_review_draft()','EXECUTE'),'clients may start a review draft');
select ok(not has_function_privilege('anon','public.create_review_draft()','EXECUTE'),'anonymous cannot start a review draft');

-- save_parsed_profile (as parse-resume would call it) --------------------------
insert into fixture select 'v1',s.profile_version_id from public.save_parsed_profile(
 '91000000-0000-0000-0000-000000000001',3,'gemini-test-flash',6.5,
 (select j from payload where k='education'),(select j from payload where k='skills'),(select j from payload where k='experiences')) s;
select ok((select version=1 and source='resume' and resume_id is null and confirmed=false
  and schema_version=3 and llm_model='gemini-test-flash' and total_years=6.5
  from public.profile_versions where id=(select v from fixture where k='v1')),'draft saved without a resume row');
select is((select education from public.profile_versions where id=(select v from fixture where k='v1')),'[{"level":"BS","field":null}]'::jsonb,'education saved as given');
select is((select count(*)::int from public.candidate_skills where profile_version_id=(select v from fixture where k='v1')),3,'duplicate canonical skills merged');
select ok((select years=4.5 and evidence='Built Flutter apps' and source='ai' from public.candidate_skills
  where profile_version_id=(select v from fixture where k='v1') and skill_id=(select v from fixture where k='flutter')),'merge keeps most years and first evidence');
select is((select count(*)::int from public.candidate_skills where profile_version_id=(select v from fixture where k='v1') and skill_id is null),1,'unmapped skill kept');
select is(array(select title from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1') order by sort_order),
  array['Mobile Developer','Campus Map'],'experiences saved in resume order');
select ok((select kind='job' and organization='Bayou Apps' and start_month='2022-03' and end_month='present'
  and highlights=array['Built Flutter apps'] and skills_used=array['Flutter','Dart']
  from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1') and sort_order=0),'experience fields saved');
select ok((select kind='project' and organization is null and start_month='2021' and end_month is null and highlights='{}'
  from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1') and sort_order=1),'nulls and empty highlights saved');

insert into fixture select 'v2',s.profile_version_id from public.save_parsed_profile(
 '91000000-0000-0000-0000-000000000001',3,'gemini-test-flash',1,'[]','[]','[]') s;
select is((select version from public.profile_versions where id=(select v from fixture where k='v2')),2,'next parse becomes version two');

select throws_ok($$select * from public.save_parsed_profile('91000000-0000-0000-0000-000000000003',3,'m',0,'[]','[]','[]')$$,'P0001','not_candidate','recruiter cannot receive a parsed draft');
select throws_ok($$select * from public.save_parsed_profile('99999999-9999-4999-8999-999999999999',3,'m',0,'[]','[]','[]')$$,'P0001','not_candidate','unknown user cannot receive a parsed draft');
select throws_ok($$select * from public.save_parsed_profile('91000000-0000-0000-0000-000000000001',3,'m',0,'[]','[]',
  '[{"kind":"job","title":"X","organization":null,"start":"2022-13","end":null,"highlights":[],"skills_used":[],"evidence":"X"}]')$$,'23514',null,'invalid month rejected');
select throws_ok($$select * from public.save_parsed_profile('91000000-0000-0000-0000-000000000001',3,'m',0,'[]','[]',
  '[{"kind":"gig","title":"X","organization":null,"start":null,"end":null,"highlights":[],"skills_used":[],"evidence":"X"}]')$$,'22P02',null,'unknown experience kind rejected');
select throws_ok($$select * from public.save_parsed_profile('91000000-0000-0000-0000-000000000001',3,'m',0,'[]','[]',
  '[{"kind":"job","title":" ","organization":null,"start":null,"end":null,"highlights":[],"skills_used":[],"evidence":"X"}]')$$,'23514',null,'blank title rejected');
select is((select count(*)::int from public.profile_versions where candidate_id='91000000-0000-0000-0000-000000000001'),2,'failed saves leave no partial version');

-- candidate_experiences RLS ----------------------------------------------------
set local role authenticated;
set local request.jwt.claims='{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is((select count(*)::int from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1')),2,'candidate reads own experiences');
select throws_ok($$insert into public.candidate_experiences(profile_version_id,sort_order,title,evidence) values((select v from fixture where k='v1'),5,'Fake','Fake')$$,'42501',null,'candidate cannot insert experiences directly');
select throws_ok($$update public.candidate_experiences set title='Edited'$$,'42501',null,'candidate cannot edit experiences directly');
select throws_ok($$select * from public.save_parsed_profile('91000000-0000-0000-0000-000000000001',3,'m',0,'[]','[]','[]')$$,'42501',null,'candidate cannot call the service RPC');

set local request.jwt.claims='{"sub":"91000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1')),0,'other candidate cannot read experiences');
set local request.jwt.claims='{"sub":"91000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1')),0,'recruiter cannot read experiences directly');
select throws_ok('select public.create_review_draft()','P0001','not_candidate','recruiter cannot start a review draft');
set local role anon;
set local request.jwt.claims='{}';
select throws_ok('select count(*) from public.candidate_experiences','42501',null,'anonymous cannot read experiences');

-- create_review_draft ----------------------------------------------------------
set local role authenticated;
set local request.jwt.claims='{"sub":"91000000-0000-0000-0000-000000000001","role":"authenticated"}';
insert into fixture values ('fallback',(public.create_review_draft()).id);
select ok((select version=3 and source='manual' and confirmed=false from public.profile_versions where id=(select v from fixture where k='fallback')),'without an active version it starts a manual draft');

select lives_ok($$select public.confirm_profile((select v from fixture where k='v1'),jsonb_build_array(
 jsonb_build_object('skill_id',(select v from fixture where k='flutter'),'raw_name','Flutter','years',4.5,'evidence','Built Flutter apps'),
 jsonb_build_object('skill_id',(select v from fixture where k='dart'),'raw_name','Dart','years',null,'evidence','Dart projects'),
 jsonb_build_object('skill_id',null,'raw_name','Codemagic','years',1,'evidence','Codemagic CI')))$$,'parsed draft confirms');
select is((select active_version_id from public.candidates where profile_id='91000000-0000-0000-0000-000000000001'),(select v from fixture where k='v1'),'confirmed parsed draft is active');
select is((select count(*)::int from public.candidate_experiences where profile_version_id=(select v from fixture where k='v1')),2,'confirming keeps experiences');

insert into fixture values ('copy',(public.create_review_draft()).id);
select ok((select version=4 and source='resume' and confirmed=false and total_years=6.5 and schema_version=3
  and education='[{"level":"BS","field":null}]'::jsonb
  from public.profile_versions where id=(select v from fixture where k='copy')),'review draft copies the active version');
select is((select count(*)::int from public.candidate_skills where profile_version_id=(select v from fixture where k='copy') and source='ai'),3,'review draft keeps skill provenance');
select is(array(select title from public.candidate_experiences where profile_version_id=(select v from fixture where k='copy') order by sort_order),
  array['Mobile Developer','Campus Map'],'review draft copies experiences');
select is((select active_version_id from public.candidates where profile_id='91000000-0000-0000-0000-000000000001'),(select v from fixture where k='v1'),'active version unchanged until the copy is confirmed');

reset role;
select * from finish();
rollback;
