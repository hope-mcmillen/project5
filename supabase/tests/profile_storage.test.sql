begin;
set local search_path=public,extensions;
select no_plan();
select is((select public from storage.buckets where id='resumes'),false,'resume bucket private');
select is((select file_size_limit from storage.buckets where id='resumes'),5242880::bigint,'resume size limit five MiB');
select is((select cardinality(allowed_mime_types) from storage.buckets where id='resumes'),2,'resume bucket allows only PDF/DOCX');
select is((select public from storage.buckets where id='company-logos'),true,'logos publicly readable');

insert into auth.users(id,email,raw_user_meta_data) values
 ('81000000-0000-0000-0000-000000000001','a5-one@example.test','{"role":"candidate"}'),
 ('81000000-0000-0000-0000-000000000002','a5-two@example.test','{"role":"candidate"}'),
 ('81000000-0000-0000-0000-000000000003','a5-owner@example.test','{"role":"recruiter"}'),
 ('81000000-0000-0000-0000-000000000004','a5-member@example.test','{"role":"recruiter"}');
insert into public.companies(id,name) values ('82000000-0000-0000-0000-000000000001','Storage Test');
insert into public.recruiters(profile_id,company_id,company_role) values
 ('81000000-0000-0000-0000-000000000003','82000000-0000-0000-0000-000000000001','owner'),
 ('81000000-0000-0000-0000-000000000004','82000000-0000-0000-0000-000000000001','member');
create temp table fixture(k text primary key,v uuid);
grant all on fixture to authenticated;
insert into fixture values ('flutter',(select id from public.skills where name='Flutter')),('dart',(select id from public.skills where name='Dart'));

set local role authenticated;
set local request.jwt.claims='{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$insert into storage.objects(bucket_id,name) values('resumes','81000000-0000-0000-0000-000000000001/83000000-0000-0000-0000-000000000001.pdf')$$,'candidate inserts own resume metadata');
select throws_ok($$insert into storage.objects(bucket_id,name) values('resumes','81000000-0000-0000-0000-000000000002/83000000-0000-0000-0000-000000000001.pdf')$$,'42501',null,'cannot upload into another folder');
select throws_ok($$insert into storage.objects(bucket_id,name) values('resumes','81000000-0000-0000-0000-000000000001/83000000-0000-0000-0000-000000000001.exe')$$,'42501',null,'invalid filename extension denied');
select throws_ok($$insert into storage.objects(bucket_id,name) values('resumes','81000000-0000-0000-0000-000000000001/nested/83000000-0000-0000-0000-000000000001.pdf')$$,'42501',null,'nested/path traversal uploads denied');
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name like '81000000-%'),1,'owner can list own resume');
select is_empty($$update storage.objects set name='81000000-0000-0000-0000-000000000001/replacement.pdf' where bucket_id='resumes' and name like '81000000-%' returning id$$,'resumes cannot be overwritten');
insert into fixture values ('manual',(public.create_manual_profile()).id),('draft',(public.create_manual_profile()).id);
select is((select version from public.profile_versions where id=(select v from fixture where k='manual')),1,'first manual version numbered one');
select is((select version from public.profile_versions where id=(select v from fixture where k='draft')),2,'second version numbered two');
select is((select source::text from public.profile_versions where id=(select v from fixture where k='manual')),'manual','manual profile source saved');
select is((select confirmed from public.profile_versions where id=(select v from fixture where k='manual')),false,'manual profiles begin unconfirmed');

select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),null)$$,'P0001','invalid_skills','null skill array denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'{}')$$,'P0001','invalid_skills','object instead of array denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[null]')$$,'P0001','invalid_skills','null skill object denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","source":"ai"}]')$$,'P0001','invalid_skills','client cannot forge AI provenance');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"years":1}]')$$,'P0001','invalid_skills','missing raw name denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":" "}]')$$,'P0001','invalid_skills','empty raw name denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","years":"2"}]')$$,'P0001','invalid_skills','string years denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","years":-1}]')$$,'P0001','invalid_skills','negative years denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","years":1.23}]')$$,'P0001','invalid_skills','excess precision denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","years":100}]')$$,'P0001','invalid_skills','out of range years denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","skill_id":"bad"}]')$$,'P0001','invalid_skills','malformed skill UUID denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill","skill_id":"99999999-9999-9999-9999-999999999999"}]')$$,'P0001','invalid_skills','unknown canonical skill denied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[{"raw_name":"Skill"},{"raw_name":" skill "}]')$$,'P0001','invalid_skills','duplicate unmapped skill names denied');
select is((select confirmed from public.profile_versions where id=(select v from fixture where k='draft')),false,'failed validation leaves version unconfirmed');
select is((select active_version_id from public.candidates where profile_id='81000000-0000-0000-0000-000000000001'),null,'failed validation leaves active version unchanged');
select lives_ok($$select public.confirm_profile((select v from fixture where k='manual'),jsonb_build_array(
 jsonb_build_object('skill_id',(select v from fixture where k='flutter'),'raw_name','Flutter','years',3,'evidence','Built apps'),
 jsonb_build_object('skill_id',(select v from fixture where k='dart'),'raw_name','Dart','years',2,'evidence',null)))$$,'manual profile confirms atomically');
select is((select active_version_id from public.candidates where profile_id='81000000-0000-0000-0000-000000000001'),(select v from fixture where k='manual'),'confirmed version activated');
select is((select total_years from public.profile_versions where id=(select v from fixture where k='manual')),3::numeric,'overlapping skill years are not summed');
select ok((select confirmed and confirmed_at is not null and embedding is not null and embedding_model='gemini-embedding-001@1536' from public.profile_versions where id=(select v from fixture where k='manual')),'confirmation stamps time and taxonomy vector');
select is((select count(*)::int from public.candidate_skills where profile_version_id=(select v from fixture where k='manual') and source='user'),2,'new skills marked user supplied');
select throws_ok($$select public.confirm_profile((select v from fixture where k='manual'),'[]')$$,'P0001','profile_already_confirmed','confirmed snapshot is immutable');

select lives_ok($$select public.save_preferences('{"locations":["Baton Rouge, LA"],"remote":["hybrid","remote"],"job_types":["full_time"],"salary_min":70000,"needs_sponsorship":false,"include_stretch":true}')$$,'valid preferences saved');
select throws_ok($$select public.save_preferences('{"unknown":true}')$$,'P0001','invalid_preferences','unknown keys denied');
select throws_ok($$select public.save_preferences('{"salary_min":1.5}')$$,'P0001','invalid_preferences','fractional salary denied');
select throws_ok($$select public.save_preferences('{"salary_min":-1}')$$,'P0001','invalid_preferences','negative salary denied');
select throws_ok($$select public.save_preferences('{"salary_min":2147483648}')$$,'P0001','invalid_preferences','salary overflow denied');
select throws_ok($$select public.save_preferences('{"remote":["anywhere"]}')$$,'P0001','invalid_preferences','unknown remote enum denied');
select throws_ok($$select public.save_preferences('{"job_types":["volunteer"]}')$$,'P0001','invalid_preferences','unknown job type denied');
select throws_ok($$select public.save_preferences('{"locations":[2]}')$$,'P0001','invalid_preferences','nonstring location denied');
select throws_ok($$select public.save_preferences('{"include_stretch":"true"}')$$,'P0001','invalid_preferences','string boolean denied');
select throws_ok($$select public.save_preferences('{"needs_sponsorship":null}')$$,'P0001','invalid_preferences','null boolean denied');
select throws_ok($$select public.save_preferences('[]')$$,'P0001','invalid_preferences','nonobject preferences denied');
select throws_ok('select public.save_preferences(null)','P0001','invalid_preferences','null preferences denied');
select is((select preferences->>'salary_min' from public.candidates where profile_id='81000000-0000-0000-0000-000000000001'),'70000','invalid preference update rolls back entirely');
select lives_ok($$select public.save_preferences('{}')$$,'empty object resets preferences');
select is((select preferences from public.candidates where profile_id='81000000-0000-0000-0000-000000000001'),'{}'::jsonb,'preference replacement clears old keys');

set local request.jwt.claims='{"sub":"81000000-0000-0000-0000-000000000002","role":"authenticated"}';
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name like '81000000-%'),0,'other candidate cannot list private files');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[]')$$,'P0001','not_owner','other candidate cannot confirm version');
set local request.jwt.claims='{"sub":"81000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name like '81000000-%'),0,'recruiter cannot read resumes directly');
select throws_ok('select public.create_manual_profile()','P0001','not_candidate','recruiter cannot create profile');
select throws_ok($$select public.save_preferences('{}')$$,'P0001','not_candidate','recruiter cannot save candidate preferences');
select throws_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[]')$$,'P0001','not_candidate','recruiter cannot confirm candidate profile');
select lives_ok($$insert into storage.objects(bucket_id,name) values('company-logos','82000000-0000-0000-0000-000000000001/logo.png')$$,'owner can upload company logo');
select throws_ok($$insert into storage.objects(bucket_id,name) values('company-logos','82000000-0000-0000-0000-000000000099/logo.png')$$,'42501',null,'owner cannot upload another company logo');
set local request.jwt.claims='{"sub":"81000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$insert into storage.objects(bucket_id,name) values('company-logos','82000000-0000-0000-0000-000000000001/member.png')$$,'42501',null,'member cannot upload logo');

-- A parsed draft retains unchanged AI provenance, marks edits as user, removes
-- omitted skills, and preserves non-overlapping career duration from parsing.
reset role;
insert into public.profile_versions(id,candidate_id,version,source,total_years) values
 ('84000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000001',3,'resume',7.5);
insert into public.candidate_skills(profile_version_id,skill_id,raw_name,years,evidence,source) values
 ('84000000-0000-0000-0000-000000000001',(select v from fixture where k='flutter'),'Flutter',4,'Built Flutter apps','ai'),
 ('84000000-0000-0000-0000-000000000001',(select v from fixture where k='dart'),'Dart',1,'Dart projects','ai'),
 ('84000000-0000-0000-0000-000000000001',null,'Omitted Skill',1,'Old evidence','ai');
set local role authenticated;
set local request.jwt.claims='{"sub":"81000000-0000-0000-0000-000000000001","role":"authenticated"}';
select lives_ok($$select public.confirm_profile('84000000-0000-0000-0000-000000000001',jsonb_build_array(
 jsonb_build_object('skill_id',(select v from fixture where k='flutter'),'raw_name','Flutter','years',4,'evidence','Built Flutter apps'),
 jsonb_build_object('skill_id',(select v from fixture where k='dart'),'raw_name','Dart','years',2,'evidence','Dart projects')))$$,'resume review confirms edited skills');
select is((select source::text from public.candidate_skills where profile_version_id='84000000-0000-0000-0000-000000000001' and raw_name='Flutter'),'ai','unchanged AI row retains provenance');
select is((select source::text from public.candidate_skills where profile_version_id='84000000-0000-0000-0000-000000000001' and raw_name='Dart'),'user','edited row marked user');
select is((select count(*)::int from public.candidate_skills where profile_version_id='84000000-0000-0000-0000-000000000001'),2,'omitted skill removed in same transaction');
select is((select total_years from public.profile_versions where id='84000000-0000-0000-0000-000000000001'),7.5::numeric,'parsed non-overlapping career duration preserved');
select lives_ok($$select public.confirm_profile((select v from fixture where k='draft'),'[]')$$,'empty manual fallback profile may confirm');
select is((select embedding from public.profile_versions where id=(select v from fixture where k='draft')),null::extensions.vector,'empty profile has no invented vector');
set local role anon;
set local request.jwt.claims='{}';
select is((select count(*)::int from storage.objects where bucket_id='resumes' and name like '81000000-%'),0,'anonymous cannot list private files');
select is((select count(*)::int from storage.objects where bucket_id='company-logos' and name like '82000000-%'),1,'logos publicly readable');
select ok(not has_function_privilege('anon','public.confirm_profile(uuid,jsonb)','EXECUTE'),'anonymous confirmation denied');
reset role;
select * from finish();
rollback;
