-- A7: atomic swipe, matching snapshot, daily cap and bounded undo.
create function public.swipe(p_job_id uuid,p_direction public.swipe_direction,p_reason public.pass_reason default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 version_id uuid;
 config public.app_config;
 decision_at timestamptz;
 day_start timestamptz;
 result jsonb;
 swipe_id uuid;
 application_id uuid;
 commit_at timestamptz;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001',message='not_candidate';
 end if;
 -- Serialize every apply/undo by this candidate to protect the cap and duplicates.
 select active_version_id into version_id from public.candidates where profile_id=caller for update;
 if version_id is null or not exists(select 1 from public.profile_versions
   where id=version_id and candidate_id=caller and confirmed) then
  raise exception using errcode='P0001',message='profile_not_confirmed';
 end if;
 -- Job lifecycle/requirement writers take UPDATE locks, so a score and the job's
 -- OPEN state stay consistent through insertion of the application snapshot.
 perform 1 from public.jobs where id=p_job_id and status='OPEN'
  and (expires_at is null or expires_at>clock_timestamp()) for share;
 if not found then raise exception using errcode='P0001',message='job_not_open'; end if;
 if p_direction is null then raise exception using errcode='P0001',message='invalid_direction'; end if;
 if p_direction='right' and p_reason is not null then
  raise exception using errcode='P0001',message='invalid_reason';
 end if;
 if exists(select 1 from public.swipes where candidate_id=caller and job_id=p_job_id) then
  raise exception using errcode='P0001',message='already_swiped';
 end if;
 select * into strict config from public.app_config;
 decision_at := clock_timestamp();
 day_start := date_trunc('day',decision_at at time zone 'UTC') at time zone 'UTC';
 if p_direction='right' then
  if (select count(*) from public.swipes where candidate_id=caller and direction='right'
    and created_at>=day_start and created_at<day_start+interval '1 day')>=config.daily_apply_cap then
   raise exception using errcode='P0001',message='daily_cap_reached';
  end if;
  result := public.compute_match(version_id,p_job_id);
 end if;
 insert into public.swipes(candidate_id,job_id,direction,pass_reason,created_at)
  values(caller,p_job_id,p_direction,p_reason,decision_at) returning id into swipe_id;
 if p_direction='right' then
  commit_at := clock_timestamp()+make_interval(secs=>config.undo_seconds);
  insert into public.applications(swipe_id,candidate_id,job_id,profile_version_id,
    match_score,breakdown,scoring_version,committed_at,created_at)
   values(swipe_id,caller,p_job_id,version_id,(result->>'score')::integer,result->'breakdown',
    config.scoring_version,commit_at,decision_at) returning id into application_id;
  insert into public.status_events(application_id,from_status,to_status,actor_id,created_at)
   values(application_id,null,'APPLIED',caller,clock_timestamp());
 end if;
 return jsonb_build_object('swipe_id',swipe_id,'application_id',application_id,'committed_at',commit_at);
end;
$$;

create function public.undo_swipe(p_swipe_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 swipe_row public.swipes;
 application public.applications;
 job uuid;
 deadline timestamptz;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001',message='not_candidate';
 end if;
 perform 1 from public.candidates where profile_id=caller for update;
 select job_id into job from public.swipes where id=p_swipe_id and candidate_id=caller;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 perform 1 from public.jobs where id=job for share;
 select * into swipe_row from public.swipes where id=p_swipe_id and candidate_id=caller for update;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if swipe_row.direction='right' then
  select * into application from public.applications where swipe_id=p_swipe_id for update;
  if not found then raise exception using errcode='P0001',message='undo_window_expired'; end if;
  deadline := application.committed_at;
 else
  deadline := swipe_row.created_at+make_interval(secs=>(select undo_seconds from public.app_config));
 end if;
 -- Wall clock is intentional: transaction start time must not extend the window.
 if clock_timestamp()>=deadline then
  raise exception using errcode='P0001',message='undo_window_expired';
 end if;
 delete from public.swipes where id=p_swipe_id;
 -- The application, reject reason and status events cascade in the same transaction.
end;
$$;

create function public.set_pass_reason(p_swipe_id uuid,p_reason public.pass_reason) returns void
language plpgsql security definer set search_path=public as $$
declare
 decision public.swipes;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001',message='not_candidate';
 end if;
 select * into decision from public.swipes where id=p_swipe_id and candidate_id=(select auth.uid()) for update;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if decision.direction<>'left' then raise exception using errcode='P0001',message='not_left_swipe'; end if;
 update public.swipes set pass_reason=p_reason where id=p_swipe_id;
end;
$$;
revoke all on function public.swipe(uuid,public.swipe_direction,public.pass_reason),
 public.undo_swipe(uuid),public.set_pass_reason(uuid,public.pass_reason) from public,anon;
grant execute on function public.swipe(uuid,public.swipe_direction,public.pass_reason),
 public.undo_swipe(uuid),public.set_pass_reason(uuid,public.pass_reason) to authenticated;
