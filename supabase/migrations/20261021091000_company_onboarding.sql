-- A4 / PL-13. Profile locks serialize company creation/join for the same user;
-- invite locks serialize consumption so max_uses cannot be exceeded.
create function public.create_company(p_name text, p_website text default null)
returns public.companies
language plpgsql security definer set search_path = public as $$
declare
  caller_id uuid := (select auth.uid());
  caller_role public.app_role;
  company public.companies;
  company_name text := btrim(p_name);
  website text := nullif(btrim(p_website), '');
begin
  select role into caller_role from public.profiles where id = caller_id for update;
  if caller_role is distinct from 'recruiter'::public.app_role then
    raise exception using errcode = 'P0001', message = 'not_recruiter';
  end if;
  if exists (select 1 from public.recruiters where profile_id = caller_id) then
    raise exception using errcode = 'P0001', message = 'already_in_company';
  end if;
  if company_name is null or length(company_name) not between 1 and 120
    or (website is not null and (length(website) > 2048
      or website !~* '^https?://[a-z0-9]([a-z0-9.-]*[a-z0-9])?(:[0-9]{1,5})?([/?#][^[:space:]]*)?$')) then
    raise exception using errcode = 'P0001', message = 'invalid_company';
  end if;
  -- Conservative default until A10 implements email-domain verification.
  insert into public.companies (name, website, verified, created_by)
    values (company_name, website, false, caller_id) returning * into company;
  insert into public.recruiters (profile_id, company_id, company_role)
    values (caller_id, company.id, 'owner');
  return company;
end;
$$;

create function public.create_invite(p_expires_in_days integer default 7) returns text
language plpgsql security definer set search_path = public as $$
declare
  caller_id uuid := (select auth.uid());
  company_id uuid := public.my_owned_company_id();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  invite_code text;
  random_byte integer;
begin
  if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role
      or company_id is null then
    raise exception using errcode = 'P0001', message = 'not_owner';
  end if;
  if p_expires_in_days is null or p_expires_in_days not between 1 and 30 then
    raise exception using errcode = 'P0001', message = 'invalid_expiry';
  end if;
  for attempt in 1..8 loop
    invite_code := '';
    while length(invite_code) < 8 loop
      random_byte := get_byte(extensions.gen_random_bytes(1), 0);
      -- Rejection sampling avoids modulo bias in the 31-character alphabet.
      if random_byte < (256 / length(alphabet)) * length(alphabet) then
        invite_code := invite_code || substr(alphabet, random_byte % length(alphabet) + 1, 1);
      end if;
    end loop;
    insert into public.company_invites (code, company_id, created_by, expires_at)
      values (invite_code, company_id, caller_id, clock_timestamp() + make_interval(days => p_expires_in_days))
      on conflict (code) do nothing;
    if found then return invite_code; end if;
  end loop;
  raise exception using errcode = 'P0001', message = 'internal';
end;
$$;

create function public.join_company(p_code text) returns public.companies
language plpgsql security definer set search_path = public as $$
declare
  caller_id uuid := (select auth.uid());
  caller_role public.app_role;
  invite public.company_invites;
  company public.companies;
begin
  select role into caller_role from public.profiles where id = caller_id for update;
  if caller_role is distinct from 'recruiter'::public.app_role then
    raise exception using errcode = 'P0001', message = 'not_recruiter';
  end if;
  if exists (select 1 from public.recruiters where profile_id = caller_id) then
    raise exception using errcode = 'P0001', message = 'already_in_company';
  end if;
  select * into invite from public.company_invites
    where code = upper(btrim(p_code)) for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'invalid_invite';
  end if;
  if invite.revoked_at is not null or invite.expires_at <= clock_timestamp()
      or invite.uses >= invite.max_uses then
    raise exception using errcode = 'P0001', message = 'invalid_invite';
  end if;
  insert into public.recruiters (profile_id, company_id, company_role)
    values (caller_id, invite.company_id, 'member');
  update public.company_invites set uses = uses + 1 where code = invite.code;
  select * into company from public.companies where id = invite.company_id;
  return company;
end;
$$;

create function public.revoke_invite(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  owned_company uuid := public.my_owned_company_id();
begin
  if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role
      or owned_company is null then
    raise exception using errcode = 'P0001', message = 'not_owner';
  end if;
  update public.company_invites set revoked_at = coalesce(revoked_at, clock_timestamp())
    where code = upper(btrim(p_code)) and company_id = owned_company;
  if not found then
    -- A code in another company is indistinguishable from a missing code.
    raise exception using errcode = 'P0001', message = 'invalid_invite';
  end if;
end;
$$;

revoke all on function public.create_company(text, text), public.create_invite(integer),
  public.join_company(text), public.revoke_invite(text) from public, anon;
grant execute on function public.create_company(text, text), public.create_invite(integer),
  public.join_company(text), public.revoke_invite(text) to authenticated;
