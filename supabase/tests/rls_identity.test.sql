begin;
set local search_path = public, extensions;
select no_plan();

insert into auth.users (id,email,raw_user_meta_data) values
 ('71000000-0000-0000-0000-000000000001','a3-candidate1@example.test','{"role":"candidate"}'),
 ('71000000-0000-0000-0000-000000000002','a3-candidate2@example.test','{"role":"candidate"}'),
 ('71000000-0000-0000-0000-000000000003','a3-recruiter1@example.test','{"role":"recruiter"}'),
 ('71000000-0000-0000-0000-000000000004','a3-recruiter2@example.test','{"role":"recruiter"}'),
 ('71000000-0000-0000-0000-000000000005','a3-google@example.test',null),
 ('71000000-0000-0000-0000-000000000006','a3-invalid@example.test','{"role":"admin"}'),
 ('71000000-0000-0000-0000-000000000007','a3-structured@example.test','{"role":{"admin":true}}'),
 ('71000000-0000-0000-0000-000000000008','a3-google-recruiter@example.test','{}');

select is((select count(*)::int from public.profiles where id::text like '71000000-%'),8,'every signup gets a profile, even without valid role metadata');
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000001'),'candidate','signup candidate role saved');
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000003'),'recruiter','signup recruiter role saved');
select is((select count(*)::int from public.candidates where profile_id::text like '71000000-%'),2,'only candidate signups get candidate rows');
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000005'),null,'missing Google role stays null');
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000006'),null,'admin metadata is ignored without breaking signup');
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000007'),null,'structured role metadata cannot break signup');
select ok(not has_function_privilege('anon','public.set_initial_role(public.app_role)','EXECUTE'),'anonymous role assignment denied');
select ok(not has_function_privilege('authenticated','public.handle_new_user()','EXECUTE'),'signup trigger is not a client RPC');

insert into public.companies(id,name) values
 ('72000000-0000-0000-0000-000000000001','A3 One'),('72000000-0000-0000-0000-000000000002','A3 Two');
insert into public.recruiters(profile_id,company_id,company_role) values
 ('71000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000001','owner'),
 ('71000000-0000-0000-0000-000000000004','72000000-0000-0000-0000-000000000002','owner');

set local role authenticated;
set local request.jwt.claims = '{"sub":"71000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is(public.current_app_role()::text,'candidate','role helper reads database');
select is((select count(*)::int from public.profiles where id::text like '71000000-%'),1,'candidate can only read own profile');
select lives_ok($$update public.profiles set display_name='A3 Updated' where id='71000000-0000-0000-0000-000000000001'$$,'candidate can update self');
select is((select display_name from public.profiles where id='71000000-0000-0000-0000-000000000001'),'A3 Updated','self update persisted');
select is_empty($$update public.profiles set display_name='Forbidden' where id='71000000-0000-0000-0000-000000000002' returning id$$,'candidate cannot update another profile');
select throws_ok($$update public.profiles set role='recruiter' where id='71000000-0000-0000-0000-000000000001'$$,'42501',null,'direct role change denied');
select throws_ok($$select public.set_initial_role('recruiter')$$,'P0001','role_already_set','chosen role cannot be changed through RPC');
select is_empty($$update public.companies set name='Forbidden' where id='72000000-0000-0000-0000-000000000001' returning id$$,'candidate cannot update companies');

set local request.jwt.claims = '{"sub":"71000000-0000-0000-0000-000000000005","role":"authenticated"}';
select throws_ok('select public.set_initial_role(null)','P0001','invalid_role','null role rejected');
select lives_ok($$select public.set_initial_role('candidate')$$,'Google user chooses candidate role');
select is(public.current_app_role()::text,'candidate','Google role stored in database');
select is((select count(*)::int from public.candidates where profile_id='71000000-0000-0000-0000-000000000005'),1,'Google choice also creates candidate row');
select throws_ok($$select public.set_initial_role('candidate')$$,'P0001','role_already_set','repeated selection is denied');

set local request.jwt.claims = '{"sub":"71000000-0000-0000-0000-000000000008","role":"authenticated"}';
select lives_ok($$select public.set_initial_role('recruiter')$$,'Google user chooses recruiter role');
select is(public.current_app_role()::text,'recruiter','Google recruiter role stored');
select is((select count(*)::int from public.candidates where profile_id='71000000-0000-0000-0000-000000000008'),0,'recruiter choice creates no candidate row');

set local request.jwt.claims = '{"sub":"71000000-0000-0000-0000-000000000003","role":"authenticated"}';
select is((select count(*)::int from public.profiles where id::text like '71000000-%'),1,'recruiter sees own profile only');
select is(public.my_company_id(),'72000000-0000-0000-0000-000000000001'::uuid,'company helper is self scoped');
select lives_ok($$update public.companies set name='A3 Owner Updated' where id='72000000-0000-0000-0000-000000000001'$$,'owner can update own company');
select is_empty($$update public.companies set name='Forbidden' where id='72000000-0000-0000-0000-000000000002' returning id$$,'owner cannot update another company');
select is_empty($$update public.profiles set display_name='Forbidden' where id='71000000-0000-0000-0000-000000000004' returning id$$,'recruiter cannot update another profile');
select throws_ok($$update public.companies set verified=true where id='72000000-0000-0000-0000-000000000001'$$,'42501',null,'owner cannot self-verify');

set local request.jwt.claims = '{}';
select throws_ok($$select public.set_initial_role('candidate')$$,'P0001','not_authenticated','missing subject denied even under authenticated role');
set local request.jwt.claims = '{"sub":"71000000-0000-0000-0000-000000000099"}';
select throws_ok($$select public.set_initial_role('candidate')$$,'P0001','not_authenticated','nonexistent user denied');
reset role;
update auth.users set raw_user_meta_data='{"role":"recruiter"}' where id='71000000-0000-0000-0000-000000000001';
select is((select role::text from public.profiles where id='71000000-0000-0000-0000-000000000001'),'candidate','editing user metadata cannot change established role');

set local role anon;
set local request.jwt.claims = '{}';
select throws_ok('select * from public.profiles','42501',null,'anonymous identity reads denied');
select throws_ok($$select public.set_initial_role('candidate')$$,'42501',null,'anonymous role RPC denied');
select is((select count(*)::int from public.companies where id::text like '72000000-%'),2,'public companies remain readable');
reset role;
select * from finish();
rollback;
