-- A8 blind board. Internal formatting/redaction helpers have no client EXECUTE.
create function public.application_tile(p_row public.applications) returns jsonb
language sql stable set search_path=public as $$
 select jsonb_build_object(
  'application_id',p_row.id,'handle','◆ '||upper(substr(md5(p_row.id::text),1,4)),
  'match_score',p_row.match_score,'band',public.match_band(p_row.match_score),
  'total_years',(select total_years from public.profile_versions where id=p_row.profile_version_id),
  'top_skills',coalesce((select jsonb_agg(t.name) from (
    select b->>'name' as name from jsonb_array_elements(p_row.breakdown) b
    where b->>'matched_via' in ('exact','related')
    order by (b->>'required')::boolean desc,(b->>'score')::numeric desc,b->>'name' limit 3) t),'[]'::jsonb),
  'gaps',coalesce((select jsonb_agg(b->>'name' order by b->>'name')
    from jsonb_array_elements(p_row.breakdown) b where b->>'matched_via'='none'),'[]'::jsonb),
  'status',p_row.status,'committed_at',p_row.committed_at)
$$;
revoke all on function public.application_tile(public.applications) from public,anon,authenticated;

create function public.blind_evidence(p_text text,p_candidate uuid) returns text
language plpgsql stable security definer set search_path=public as $$
declare
 value text := p_text;
 identity text;
 remaining text;
 redacted text;
 position integer;
begin
 if value is null then return null; end if;
 -- Remove the known identity and its constituent names, regardless of case,
 -- without treating user-controlled names as regular expressions.
 for identity in
  select display_name from public.profiles where id=p_candidate
  union select unnest(regexp_split_to_array(display_name,'[[:space:]]+')) from public.profiles where id=p_candidate
  union select email from auth.users where id=p_candidate
 loop
  if identity is null or length(identity)<3 then continue; end if;
  remaining := value; redacted := '';
  loop
   position := strpos(lower(remaining),lower(identity));
   exit when position=0;
   redacted := redacted||substr(remaining,1,position-1)||'[redacted]';
   remaining := substr(remaining,position+length(identity));
  end loop;
  value := redacted||remaining;
 end loop;
 value := regexp_replace(value,'[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}','[email]','gi');
 value := regexp_replace(value,'(https?://|www\.)[^[:space:]]+','[link]','gi');
 value := regexp_replace(value,'\+?[0-9][0-9 ().-]{6,}[0-9]','[phone]','g');
 return value;
end;
$$;
revoke all on function public.blind_evidence(text,uuid) from public,anon,authenticated;

create function public.get_board(p_job_id uuid,p_filters jsonb default '{}',p_limit integer default 50,p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path=public as $$
declare
 result jsonb;
 minimum numeric := 0;
 item jsonb;
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 if not exists(select 1 from public.jobs where id=p_job_id and company_id=public.my_company_id()) then
  raise exception using errcode='P0001',message='not_owner';
 end if;
 if p_limit is null or p_limit not between 1 and 100 or p_offset is null or p_offset<0 then
  raise exception using errcode='P0001',message='invalid_pagination';
 end if;
 if p_filters is null or jsonb_typeof(p_filters)<>'object' then
  raise exception using errcode='P0001',message='invalid_filters';
 end if;
 if exists(select 1 from jsonb_object_keys(p_filters) k where k not in ('statuses','min_score')) then
  raise exception using errcode='P0001',message='invalid_filters';
 end if;
 if p_filters ? 'min_score' then
  if jsonb_typeof(p_filters->'min_score')<>'number' then
   raise exception using errcode='P0001',message='invalid_filters';
  end if;
  minimum := (p_filters->>'min_score')::numeric;
  if minimum<0 or minimum>100 or minimum<>trunc(minimum) then
   raise exception using errcode='P0001',message='invalid_filters';
  end if;
 end if;
 if p_filters ? 'statuses' then
  if jsonb_typeof(p_filters->'statuses')<>'array' then
   raise exception using errcode='P0001',message='invalid_filters';
  end if;
  if jsonb_array_length(p_filters->'statuses')>6 then
   raise exception using errcode='P0001',message='invalid_filters';
  end if;
  for item in select value from jsonb_array_elements(p_filters->'statuses') loop
   if jsonb_typeof(item)<>'string' or item#>>'{}' not in
    ('APPLIED','UNDER_REVIEW','INTERVIEW_REQUESTED','NOT_SELECTED','WITHDRAWN','JOB_CLOSED') then
    raise exception using errcode='P0001',message='invalid_filters';
   end if;
  end loop;
 end if;
 select coalesce(jsonb_agg(public.application_tile(a) order by a.match_score desc,a.committed_at,a.id),'[]'::jsonb)
  into result from (select * from public.applications a where a.job_id=p_job_id
   and a.committed_at<=clock_timestamp() and not a.anonymized and a.match_score>=minimum
   and ((not(p_filters ? 'statuses') and a.status not in ('NOT_SELECTED','WITHDRAWN','JOB_CLOSED'))
    or (p_filters ? 'statuses' and a.status::text in (select jsonb_array_elements_text(p_filters->'statuses'))))
   order by a.match_score desc,a.committed_at,a.id limit p_limit offset p_offset) a;
 return result;
end;
$$;

create function public.get_candidate_detail(p_application_id uuid) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
 application public.applications;
 result jsonb;
 skills jsonb;
 revealed boolean;
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 select a.* into application from public.applications a join public.jobs j on j.id=a.job_id
  where a.id=p_application_id and j.company_id=public.my_company_id() and not a.anonymized;
 if not found then raise exception using errcode='P0001',message='not_owner'; end if;
 if application.committed_at>clock_timestamp() then
  raise exception using errcode='P0001',message='application_not_committed';
 end if;
 revealed := application.status='INTERVIEW_REQUESTED';
 select coalesce(jsonb_agg(jsonb_build_object(
  'name',coalesce(s.name,case when revealed then cs.raw_name else public.blind_evidence(cs.raw_name,application.candidate_id) end),
  'years',cs.years,'evidence',case when revealed then cs.evidence else public.blind_evidence(cs.evidence,application.candidate_id) end)
  order by coalesce(s.name,cs.raw_name),cs.id),'[]'::jsonb) into skills
  from public.candidate_skills cs left join public.skills s on s.id=cs.skill_id
  where cs.profile_version_id=application.profile_version_id;
 result := public.application_tile(application)||jsonb_build_object('breakdown',application.breakdown,'skills',skills);
 if revealed then
  result := result||jsonb_build_object('identity',(select jsonb_build_object('display_name',p.display_name,'email',u.email)
   from public.profiles p join auth.users u on u.id=p.id where p.id=application.candidate_id));
 end if;
 return result;
end;
$$;

create function public.get_interview_list(p_job_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path=public as $$
declare
 company uuid := public.my_company_id();
 result jsonb;
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role then
  raise exception using errcode='P0001',message='not_recruiter';
 end if;
 if company is null or (p_job_id is not null and not exists(select 1 from public.jobs where id=p_job_id and company_id=company)) then
  raise exception using errcode='P0001',message='not_owner';
 end if;
 select coalesce(jsonb_agg(public.get_candidate_detail(a.id) order by a.match_score desc,a.committed_at,a.id),'[]'::jsonb)
  into result from public.applications a join public.jobs j on j.id=a.job_id
  where j.company_id=company and (p_job_id is null or a.job_id=p_job_id)
   and a.status='INTERVIEW_REQUESTED' and not a.anonymized and a.committed_at<=clock_timestamp();
 return result;
end;
$$;
revoke all on function public.get_board(uuid,jsonb,integer,integer),public.get_candidate_detail(uuid),
 public.get_interview_list(uuid) from public,anon;
grant execute on function public.get_board(uuid,jsonb,integer,integer),public.get_candidate_detail(uuid),
 public.get_interview_list(uuid) to authenticated;
