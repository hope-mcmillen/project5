-- A6: local-dev accounts only. Source taxonomy/vectors/demo world load first
-- via config.toml db.seed.sql_paths; preserve B's generated files verbatim.
-- Synthetic credentials are documented only in README's local-dev section.
-- Never apply local seeds to a production/linked remote project.
begin;
-- Auth signup creates candidate rows before B's seed reaches its upserts.
update public.candidates c set is_seed=true from public.profiles p
 where c.profile_id=p.id and p.is_seed;
update public.companies set verified=(id='00d8c474-f4e6-4ed4-95d8-21ea1b2fb38e')
 where is_seed;
with demo(id,email) as (values
 ('9bb3713e-8bb4-4579-9ece-2b31a4fbc3df'::uuid,'candidate@demo.resurhombus.test'),
 ('53221234-2d14-4a06-a2e7-72d951abec46'::uuid,'recruiter@demo.resurhombus.test')
)
update auth.users u set email=d.email,
 encrypted_password=extensions.crypt('LocalDemo-4330!',extensions.gen_salt('bf')),
 email_confirmed_at=now(),confirmation_token='',recovery_token='',
 email_change_token_new='',email_change='',updated_at=now()
from demo d where u.id=d.id;
insert into auth.identities(id,user_id,provider_id,identity_data,provider,created_at,updated_at)
select gen_random_uuid(),u.id,u.id::text,
 jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true,'phone_verified',false),
 'email',now(),now()
from auth.users u where u.id in ('9bb3713e-8bb4-4579-9ece-2b31a4fbc3df','53221234-2d14-4a06-a2e7-72d951abec46')
on conflict(provider_id,provider) do update
 set identity_data=excluded.identity_data,updated_at=excluded.updated_at;
commit;
