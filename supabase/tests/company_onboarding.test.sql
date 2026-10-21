begin;
set local search_path = public, extensions;
select no_plan();
insert into auth.users (id,email,raw_user_meta_data) values
 ('73000000-0000-0000-0000-000000000001','a4-owner@example.test','{"role":"recruiter"}'),
 ('73000000-0000-0000-0000-000000000002','a4-member@example.test','{"role":"recruiter"}'),
 ('73000000-0000-0000-0000-000000000003','a4-other@example.test','{"role":"recruiter"}'),
 ('73000000-0000-0000-0000-000000000004','a4-unused@example.test','{"role":"recruiter"}'),
 ('73000000-0000-0000-0000-000000000005','a4-candidate@example.test','{"role":"candidate"}');
create temp table fixture (k text primary key, v text);
grant all on fixture to authenticated;

set local role authenticated;
set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000005","role":"authenticated"}';
select throws_ok($$select public.create_company('Candidate Co')$$,'P0001','not_recruiter','candidate cannot create company');
select throws_ok($$select public.join_company('ABCD2345')$$,'P0001','not_recruiter','candidate cannot join company');
select throws_ok('select public.create_invite()','P0001','not_owner','candidate cannot create invite');
select throws_ok($$select public.revoke_invite('ABCD2345')$$,'P0001','not_owner','candidate cannot revoke invite');

set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000001","role":"authenticated"}';
select throws_ok($$select public.create_company('  ')$$,'P0001','invalid_company','blank name rejected');
select throws_ok($$select public.create_company(null)$$,'P0001','invalid_company','null name rejected');
select throws_ok($$select public.create_company(repeat('X',121))$$,'P0001','invalid_company','long name rejected');
select throws_ok($$select public.create_company('Valid','javascript:alert(1)')$$,'P0001','invalid_company','non-HTTP website rejected');
select throws_ok($$select public.create_company('Valid','https://example.test bad')$$,'P0001','invalid_company','malformed website rejected');
select is(public.my_company_id(),null,'failed creation leaves no company membership');
insert into fixture values ('company1',(public.create_company('  A4 One  ',' https://example.test ')).id::text);
select is((select name from public.companies where id=(select v::uuid from fixture where k='company1')),'A4 One','valid company name trimmed');
select is((select website from public.companies where id=(select v::uuid from fixture where k='company1')),'https://example.test','website trimmed');
select is((select company_role::text from public.recruiters where profile_id='73000000-0000-0000-0000-000000000001'),'owner','company creator becomes owner');
select is((select verified from public.companies where id=(select v::uuid from fixture where k='company1')),false,'verification remains conservative until A10');
select throws_ok($$select public.create_company('Duplicate')$$,'P0001','already_in_company','one company per recruiter');
select throws_ok('select public.create_invite(0)','P0001','invalid_expiry','zero-day expiry rejected');
select throws_ok('select public.create_invite(31)','P0001','invalid_expiry','expiry over 30 days rejected');
select throws_ok('select public.create_invite(null)','P0001','invalid_expiry','null expiry rejected');
insert into fixture values ('invite',public.create_invite());
select matches((select v from fixture where k='invite'),'^[A-HJKMNP-Z2-9]{8}$','invite is eight unambiguous characters');
select is((select uses from public.company_invites where code=(select v from fixture where k='invite')),0,'new invite has no uses');
select is((select max_uses from public.company_invites where code=(select v from fixture where k='invite')),10,'default maximum ten uses');
select ok((select expires_at > now()+interval '6 days' and expires_at < now()+interval '8 days' from public.company_invites where code=(select v from fixture where k='invite')),'default expiry is seven days');
select throws_ok($$select public.join_company('BADCODE2')$$,'P0001','already_in_company','existing membership checked before invite');

set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000002","role":"authenticated"}';
select throws_ok($$select public.join_company('BADCODE2')$$,'P0001','invalid_invite','unknown code rejected');
select throws_ok('select public.join_company(null)','P0001','invalid_invite','null code rejected');
select throws_ok($$select public.join_company('   ')$$,'P0001','invalid_invite','blank code rejected');
select is((public.join_company('  '||lower((select v from fixture where k='invite'))||'  ')).id,(select v::uuid from fixture where k='company1'),'lowercase padded code joins correct company');
select is((select company_role::text from public.recruiters where profile_id='73000000-0000-0000-0000-000000000002'),'member','joining creates member, not owner');
select is((select count(*)::int from public.recruiters where company_id=(select v::uuid from fixture where k='company1')),2,'teammates share membership visibility');
select is((select count(*)::int from public.company_invites),0,'members cannot list invite codes');
select throws_ok('select public.create_invite()','P0001','not_owner','member cannot create invite');
select throws_ok($$select public.revoke_invite((select v from fixture where k='invite'))$$,'P0001','not_owner','member cannot revoke invite');
select is_empty($$update public.companies set name='Unauthorized' where id=(select v::uuid from fixture where k='company1') returning id$$,'member cannot edit company');
select throws_ok($$select public.join_company((select v from fixture where k='invite'))$$,'P0001','already_in_company','joining twice does not consume another use');

set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000003","role":"authenticated"}';
insert into fixture values ('company2',(public.create_company('A4 Two')).id::text);
select throws_ok($$select public.revoke_invite((select v from fixture where k='invite'))$$,'P0001','invalid_invite','other company owner cannot revoke code');
select is((select count(*)::int from public.company_invites),0,'other owner cannot list code');

set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000001","role":"authenticated"}';
select is((select uses from public.company_invites where code=(select v from fixture where k='invite')),1,'one successful join consumes exactly one use');
select lives_ok($$select public.revoke_invite((select v from fixture where k='invite'))$$,'owner revokes own invite');
select lives_ok($$select public.revoke_invite((select v from fixture where k='invite'))$$,'revocation is idempotent');
select ok((select revoked_at is not null from public.company_invites where code=(select v from fixture where k='invite')),'revocation recorded');
reset role;
insert into public.company_invites(code,company_id,expires_at,max_uses,uses) values
 ('EXPR2345',(select v::uuid from fixture where k='company1'),now()-interval '1 second',10,0),
 ('USED2345',(select v::uuid from fixture where k='company1'),now()+interval '1 day',1,1),
 ('NEXT2345',(select v::uuid from fixture where k='company1'),now()+interval '1 day',1,0);
set local role authenticated;
set local request.jwt.claims = '{"sub":"73000000-0000-0000-0000-000000000004","role":"authenticated"}';
select throws_ok($$select public.join_company((select v from fixture where k='invite'))$$,'P0001','invalid_invite','revoked invite rejected');
select throws_ok($$select public.join_company('EXPR2345')$$,'P0001','invalid_invite','expired invite rejected');
select throws_ok($$select public.join_company('USED2345')$$,'P0001','invalid_invite','exhausted invite rejected');
select is(public.my_company_id(),null,'invalid invites leave membership unchanged');
select is((public.join_company('NEXT2345')).id,(select v::uuid from fixture where k='company1'),'last available slot can join');
reset role;
select is((select uses from public.company_invites where code='NEXT2345'),1,'last slot exhausted exactly once');
select is((select count(*)::int from public.companies where name='Duplicate'),0,'failed duplicate creation leaves no orphan company');
select is((select uses from public.company_invites where code='EXPR2345'),0,'failed expired join does not consume usage');
select ok(not has_function_privilege('anon','public.create_company(text,text)','EXECUTE'),'anonymous create RPC denied');
select ok(not has_function_privilege('anon','public.create_invite(integer)','EXECUTE'),'anonymous invite RPC denied');
select ok(not has_function_privilege('anon','public.join_company(text)','EXECUTE'),'anonymous join RPC denied');
select ok(not has_function_privilege('anon','public.revoke_invite(text)','EXECUTE'),'anonymous revoke RPC denied');
select * from finish();
rollback;
