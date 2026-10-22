-- A8: status changes take job SHARE then application UPDATE locks, matching the
-- job lifecycle writer's lock order. The internal dispatcher is not a client RPC.
create function public.change_application(p_id uuid,p_action text,p_text text default null) returns void
language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 application public.applications;
 job public.jobs;
 target public.application_status;
begin
 if p_action='withdraw' then
  if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
   raise exception using errcode='P0001',message='not_candidate';
  end if;
 else
  if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
   raise exception using errcode='P0001',message='not_recruiter';
  end if;
 end if;
 select j.* into job from public.jobs j join public.applications a on a.job_id=j.id
  where a.id=p_id and ((p_action='withdraw' and a.candidate_id=caller)
    or (p_action<>'withdraw' and j.company_id=public.my_company_id())) for share of j;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 select * into application from public.applications where id=p_id for update;
 if not found or application.anonymized or (p_action='withdraw' and application.candidate_id is distinct from caller) then
  raise exception using errcode='P0001',message='not_owner';
 end if;
 if p_action<>'withdraw' and application.committed_at>clock_timestamp() then
  raise exception using errcode='P0001',message='application_not_committed';
 end if;
 if length(p_text)>2000 then
  raise exception using errcode='P0001',message=case when p_action='reject' then 'invalid_reason' else 'invalid_note' end;
 end if;
 case p_action
 when 'open' then
  if application.status='UNDER_REVIEW' then return; end if;
  if application.status<>'APPLIED' then raise exception using errcode='P0001',message='invalid_transition'; end if;
  target := 'UNDER_REVIEW';
 when 'advance' then
  if application.status not in ('APPLIED','UNDER_REVIEW') then
   raise exception using errcode='P0001',message='invalid_transition';
  end if;
  target := 'INTERVIEW_REQUESTED';
 when 'reject' then
  if application.status not in ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED') then
   raise exception using errcode='P0001',message='invalid_transition';
  end if;
  target := 'NOT_SELECTED';
 when 'undo_reject' then
  if application.status<>'NOT_SELECTED' or application.previous_status is null
    or application.previous_status not in ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED')
    or job.status='CLOSED' or (job.expires_at is not null and job.expires_at<=clock_timestamp()) then
   raise exception using errcode='P0001',message='invalid_transition';
  end if;
  if application.rejected_at is null or clock_timestamp()>=application.rejected_at+
    make_interval(secs=>(select reject_undo_seconds from public.app_config)) then
   raise exception using errcode='P0001',message='undo_window_expired';
  end if;
  target := application.previous_status;
 when 'withdraw' then
  if application.status not in ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED') then
   raise exception using errcode='P0001',message='invalid_transition';
  end if;
  target := 'WITHDRAWN';
 else raise exception using errcode='P0001',message='invalid_transition';
 end case;
 update public.applications set status=target,
  previous_status=case when p_action='reject' then application.status else null end,
  rejected_at=case when p_action='reject' then clock_timestamp() else null end,
  advanced_by=case when p_action='advance' then caller else advanced_by end,
  interview_note=case when p_action='advance' then p_text else interview_note end
  where id=p_id;
 if p_action='reject' then
  insert into public.application_reject_reasons(application_id,reason,created_by,created_at)
   values(p_id,p_text,caller,clock_timestamp()) on conflict(application_id) do update
    set reason=excluded.reason,created_by=excluded.created_by,created_at=excluded.created_at;
 elsif p_action='undo_reject' then
  delete from public.application_reject_reasons where application_id=p_id;
 end if;
 insert into public.status_events(application_id,from_status,to_status,actor_id,created_at)
  values(p_id,application.status,target,caller,clock_timestamp());
end;
$$;
revoke all on function public.change_application(uuid,text,text) from public,anon,authenticated;

create function public.open_application(p_application_id uuid) returns void
language sql security definer set search_path=public as $$ select public.change_application(p_application_id,'open') $$;
create function public.advance(p_application_id uuid,p_note text default null) returns void
language sql security definer set search_path=public as $$ select public.change_application(p_application_id,'advance',p_note) $$;
create function public.reject(p_application_id uuid,p_reason text default null) returns void
language sql security definer set search_path=public as $$ select public.change_application(p_application_id,'reject',p_reason) $$;
create function public.undo_reject(p_application_id uuid) returns void
language sql security definer set search_path=public as $$ select public.change_application(p_application_id,'undo_reject') $$;
create function public.withdraw(p_application_id uuid) returns void
language sql security definer set search_path=public as $$ select public.change_application(p_application_id,'withdraw') $$;
revoke all on function public.open_application(uuid),public.advance(uuid,text),public.reject(uuid,text),
 public.undo_reject(uuid),public.withdraw(uuid) from public,anon;
grant execute on function public.open_application(uuid),public.advance(uuid,text),public.reject(uuid,text),
 public.undo_reject(uuid),public.withdraw(uuid) to authenticated;

create function public.get_application_contact(p_application_id uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
 application public.applications;
 recruiter uuid;
 result jsonb;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001',message='not_candidate';
 end if;
 select * into application from public.applications
  where id=p_application_id and candidate_id=(select auth.uid()) and not anonymized;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if application.status<>'INTERVIEW_REQUESTED' or application.committed_at>clock_timestamp() then
  raise exception using errcode='P0001',message='contact_not_available';
 end if;
 select coalesce(application.advanced_by,j.created_by,
   (select profile_id from public.recruiters where company_id=j.company_id order by company_role,created_at,profile_id limit 1))
  into recruiter from public.jobs j where j.id=application.job_id;
 select jsonb_build_object('name',p.display_name,'email',u.email,'note',application.interview_note)
  into result from public.profiles p join auth.users u on u.id=p.id where p.id=recruiter;
 if result is null then raise exception using errcode='P0001',message='contact_not_available'; end if;
 return result;
end;
$$;
revoke all on function public.get_application_contact(uuid) from public,anon;
grant execute on function public.get_application_contact(uuid) to authenticated;
