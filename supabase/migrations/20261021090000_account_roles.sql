-- A3 / PL-07, PL-08, PL-12. A2 already supplies role/company helpers and RLS.
-- Role metadata is an initial preference, never ongoing authorization.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  chosen_role public.app_role;
begin
  chosen_role := case new.raw_user_meta_data ->> 'role'
    when 'candidate' then 'candidate'::public.app_role
    when 'recruiter' then 'recruiter'::public.app_role
    else null
  end;
  insert into public.profiles (id, role) values (new.id, chosen_role);
  if chosen_role = 'candidate' then
    insert into public.candidates (profile_id) values (new.id);
  end if;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Also cover users registered before this trigger was deployed; never overwrite
-- an existing database role with subsequently editable user metadata.
insert into public.profiles (id, role)
select u.id, case u.raw_user_meta_data ->> 'role'
  when 'candidate' then 'candidate'::public.app_role
  when 'recruiter' then 'recruiter'::public.app_role else null end
from auth.users u
on conflict (id) do nothing;
insert into public.candidates (profile_id)
select id from public.profiles where role = 'candidate'
on conflict (profile_id) do nothing;

create function public.set_initial_role(p_role public.app_role) returns void
language plpgsql security definer set search_path = public as $$
declare
  caller_id uuid := (select auth.uid());
  existing_role public.app_role;
begin
  if caller_id is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;
  if p_role is null then
    raise exception using errcode = 'P0001', message = 'invalid_role';
  end if;
  -- Serialize concurrent choices. A second call sees the first committed role.
  select role into existing_role from public.profiles
    where id = caller_id for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;
  if existing_role is not null then
    raise exception using errcode = 'P0001', message = 'role_already_set';
  end if;
  update public.profiles set role = p_role where id = caller_id;
  if p_role = 'candidate' then
    insert into public.candidates (profile_id) values (caller_id);
  end if;
end;
$$;
revoke all on function public.set_initial_role(public.app_role) from public, anon;
grant execute on function public.set_initial_role(public.app_role) to authenticated;
-- Direct role writes remain denied by A2's column-level UPDATE grants.
