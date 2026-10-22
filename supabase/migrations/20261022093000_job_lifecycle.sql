-- A-owned job RPCs required by the apply/recruiter loop (API_CONTRACT 7.4).
create function public.save_requirements(p_job_id uuid,p_requirements jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare
 job public.jobs;
 item jsonb;
 skill uuid;
 required boolean;
 years numeric;
 weight numeric;
 required_count integer := 0;
 seen uuid[] := '{}';
 application public.applications;
 scored jsonb;
 vector extensions.vector(1536);
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 select * into job from public.jobs where id=p_job_id and company_id=public.my_company_id() for update;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if job.status='CLOSED' then raise exception using errcode='P0001',message='invalid_transition'; end if;
 if p_requirements is null or jsonb_typeof(p_requirements)<>'array' then
  raise exception using errcode='P0001',message='invalid_requirements';
 end if;
 if jsonb_array_length(p_requirements)>15 or (job.status<>'DRAFT' and jsonb_array_length(p_requirements)=0) then
  raise exception using errcode='P0001',message='invalid_requirements';
 end if;
 for item in select value from jsonb_array_elements(p_requirements) loop
  if jsonb_typeof(item)<>'object' then raise exception using errcode='P0001',message='invalid_requirements'; end if;
  if exists(select 1 from jsonb_object_keys(item) k where k not in ('skill_id','required','min_years','weight','evidence'))
   or jsonb_typeof(item->'skill_id') is distinct from 'string'
   or jsonb_typeof(item->'required') is distinct from 'boolean'
   or jsonb_typeof(item->'min_years') is distinct from 'number'
   or jsonb_typeof(item->'weight') is distinct from 'number'
   or (item ? 'evidence' and jsonb_typeof(item->'evidence') not in ('string','null'))
   or length(item->>'evidence')>2000 then
   raise exception using errcode='P0001',message='invalid_requirements';
  end if;
  begin skill := (item->>'skill_id')::uuid;
  exception when invalid_text_representation then raise exception using errcode='P0001',message='invalid_requirements'; end;
  required := (item->>'required')::boolean;
  years := (item->>'min_years')::numeric;
  weight := (item->>'weight')::numeric;
  if years<0 or years>99.9 or years<>round(years,1) or weight not between 1 and 3 or weight<>trunc(weight)
   or skill=any(seen) or not exists(select 1 from public.skills where id=skill) then
   raise exception using errcode='P0001',message='invalid_requirements';
  end if;
  seen := array_append(seen,skill);
  if required then required_count := required_count+1; end if;
 end loop;
 if required_count>8 then raise exception using errcode='P0001',message='invalid_requirements'; end if;
 delete from public.job_requirements where job_id=p_job_id;
 insert into public.job_requirements(job_id,skill_id,required,min_years,weight,evidence)
 select p_job_id,(j->>'skill_id')::uuid,(j->>'required')::boolean,(j->>'min_years')::numeric,
  ((j->>'weight')::numeric)::smallint,j->>'evidence' from jsonb_array_elements(p_requirements) j;
 vector := public.skills_centroid(seen);
 update public.jobs set embedding=vector,embedding_model=case when vector is null then null else 'gemini-embedding-001@1536' end,
  parse_status='READY',rescored_at=case when status in ('OPEN','PAUSED') then clock_timestamp() else rescored_at end where id=p_job_id;
 -- B owns the formula; call it without modifying it or introducing a stub.
 if job.status in ('OPEN','PAUSED') then
  for application in select * from public.applications where job_id=p_job_id
    and profile_version_id is not null and not anonymized
    and status in ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED') order by id for update loop
   scored := public.compute_match(application.profile_version_id,p_job_id);
   update public.applications set match_score=(scored->>'score')::integer,breakdown=scored->'breakdown',
    scoring_version=(select scoring_version from public.app_config) where id=application.id;
  end loop;
 end if;
end;
$$;

create function public.set_job_status(p_job_id uuid,p_status public.job_status) returns void
language plpgsql security definer set search_path=public as $$
declare
 job public.jobs;
 application public.applications;
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 select * into job from public.jobs where id=p_job_id and company_id=public.my_company_id() for update;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if p_status is null or not ((job.status='DRAFT' and p_status='OPEN') or
   (job.status='OPEN' and p_status in ('PAUSED','CLOSED')) or (job.status='PAUSED' and p_status in ('OPEN','CLOSED'))) then
  raise exception using errcode='P0001',message='invalid_transition';
 end if;
 if p_status='OPEN' and (job.parse_status<>'READY' or nullif(btrim(job.title),'') is null or
   not exists(select 1 from public.job_requirements where job_id=p_job_id)) then
  raise exception using errcode='P0001',message='requirements_not_ready';
 end if;
 if p_status='OPEN' and job.expires_at is not null and job.expires_at<=clock_timestamp() then
  raise exception using errcode='P0001',message='invalid_transition';
 end if;
 update public.jobs set status=p_status,
  published_at=case when p_status='OPEN' then coalesce(published_at,clock_timestamp()) else published_at end,
  expires_at=case when p_status='OPEN' then coalesce(expires_at,clock_timestamp()+interval '60 days') else expires_at end
  where id=p_job_id;
 if p_status='CLOSED' then
  for application in select * from public.applications where job_id=p_job_id
    and status in ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED') order by id for update loop
   update public.applications set status='JOB_CLOSED',previous_status=null,rejected_at=null where id=application.id;
   insert into public.status_events(application_id,from_status,to_status,actor_id,created_at)
    values(application.id,application.status,'JOB_CLOSED',(select auth.uid()),clock_timestamp());
  end loop;
 end if;
end;
$$;
revoke all on function public.save_requirements(uuid,jsonb),public.set_job_status(uuid,public.job_status) from public,anon;
grant execute on function public.save_requirements(uuid,jsonb),public.set_job_status(uuid,public.job_status) to authenticated;
