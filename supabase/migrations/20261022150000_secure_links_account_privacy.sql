-- A9/A10: exact-host soft verification; no email or website network requests.
create function public.company_domain_verified(p_owner uuid,p_website text) returns boolean
language sql stable security definer set search_path=public as $$
 select coalesce(email_confirmed_at is not null
  and lower(split_part(email,'@',2)) = regexp_replace(substring(lower(p_website) from '^https?://([^/:?#]+)'), '^www\.', '')
  and lower(split_part(email,'@',2)) <> all(array['gmail.com','googlemail.com','outlook.com','hotmail.com','live.com','msn.com','yahoo.com','ymail.com','aol.com','icloud.com','me.com','proton.me','protonmail.com','mail.com','gmx.com','gmx.net','fastmail.com']),false)
 from auth.users where id=p_owner
$$;
revoke all on function public.company_domain_verified(uuid,text) from public,anon,authenticated;
-- A4 / PL-13. Profile locks serialize company creation/join for the same user;
-- invite locks serialize consumption so max_uses cannot be exceeded.
create or replace function public.create_company(p_name text, p_website text default null)
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
  -- Soft verification requires a confirmed email and an exact non-free-mail host.
  insert into public.companies (name, website, verified, created_by)
    values (company_name, website, public.company_domain_verified(caller_id, website), caller_id) returning * into company;
  insert into public.recruiters (profile_id, company_id, company_role)
    values (caller_id, company.id, 'owner');
  return company;
end;
$$;


create function public.refresh_company_verification() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 -- Trusted local seed explicitly includes a synthetic verified company.
 if new.is_seed and auth.uid() is null then return new; end if;
 new.verified := coalesce(public.company_domain_verified(new.created_by,new.website),false);
 return new;
end;
$$;
revoke all on function public.refresh_company_verification() from public,anon,authenticated;
create trigger companies_verify_website before update of website,verified on public.companies
 for each row execute function public.refresh_company_verification();

-- Only this narrow authenticated lookup crosses the recruiter/candidate boundary.
create function public.get_resume_access(p_application_id uuid) returns text
language plpgsql security definer set search_path=public as $$
declare a public.applications; path text;
begin
 if public.current_app_role() is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 select x.* into a from public.applications x join public.jobs j on j.id=x.job_id
  where x.id=p_application_id and j.company_id=public.my_company_id() for share of x;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if a.status<>'INTERVIEW_REQUESTED' or a.anonymized or a.committed_at>clock_timestamp() then
  raise exception using errcode='P0001',message='resume_not_available';
 end if;
 select r.storage_path into path from public.profile_versions v join public.resumes r on r.id=v.resume_id
  where v.id=a.profile_version_id and v.candidate_id=a.candidate_id and r.candidate_id=a.candidate_id;
 if path is null or split_part(path,'/',1)<>a.candidate_id::text then
  raise exception using errcode='P0001',message='resume_not_available';
 end if;
 return path;
end;
$$;
revoke all on function public.get_resume_access(uuid) from public,anon;
grant execute on function public.get_resume_access(uuid) to authenticated;

-- First phase of retryable deletion. Lock the candidate like swipe/confirmation;
-- remove the swipe FK BEFORE cascading candidate deletion to retain audit totals.
-- The Auth identity remains until Storage removal succeeds, allowing retries.
create function public.prepare_account_deletion() returns void
language plpgsql security definer set search_path=public as $$
declare caller uuid := auth.uid();
begin
 if public.current_app_role() is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001',message='not_candidate';
 end if;
 perform 1 from public.candidates where profile_id=caller for update;
 -- Consistent job/application lock order with status changes and job closure.
 perform 1 from public.jobs j where exists(select 1 from public.applications a
  where a.job_id=j.id and a.candidate_id=caller) order by j.id for share;
 perform 1 from public.applications where candidate_id=caller order by id for update;
 delete from public.application_reject_reasons where application_id in
  (select id from public.applications where candidate_id=caller);
 update public.applications set swipe_id=null,candidate_id=null,profile_version_id=null,
  anonymized=true,breakdown='[]'::jsonb,interview_note=null,previous_status=null,rejected_at=null
  where candidate_id=caller;
 update public.status_events set actor_id=null where actor_id=caller;
 delete from public.llm_usage where user_id=caller;
 delete from public.device_tokens where user_id=caller;
 delete from public.candidates where profile_id=caller;
 update public.profiles set display_name=null,terms_accepted_at=null where id=caller;
end;
$$;
revoke all on function public.prepare_account_deletion() from public,anon;
grant execute on function public.prepare_account_deletion() to authenticated;

-- Serialize an in-flight Storage insert with candidate deletion. A plain EXISTS
-- could use an older MVCC snapshot and allow an upload after cleanup finished.
create function public.candidate_upload_allowed() returns boolean
language plpgsql security definer set search_path=public as $$
begin
 if public.current_app_role() is distinct from 'candidate'::public.app_role then return false; end if;
 perform 1 from public.candidates where profile_id=auth.uid() for key share;
 return found;
end;
$$;
revoke all on function public.candidate_upload_allowed() from public,anon;
grant execute on function public.candidate_upload_allowed() to authenticated;
-- Prevent new uploads between deletion preparation and final Auth removal.
drop policy resumes_insert_owner on storage.objects;
create policy resumes_insert_owner on storage.objects for insert to authenticated
 with check (bucket_id='resumes' and (select public.current_app_role())='candidate'
   and (select public.candidate_upload_allowed())
   and (storage.foldername(name))[1]=(select auth.uid())::text
   and cardinality(storage.foldername(name))=1
   and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|docx)$');
