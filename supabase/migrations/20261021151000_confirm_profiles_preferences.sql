-- A5 / PL-17. Reviewed snapshots cannot be changed after confirmation.
create function public.create_manual_profile() returns public.profile_versions
language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 next_version integer;
 result public.profile_versions;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001', message='not_candidate';
 end if;
 -- Same per-candidate lock used by B's save_resume_draft for version numbering.
 perform 1 from public.candidates where profile_id=caller for update;
 if not found then raise exception using errcode='P0001', message='not_candidate'; end if;
 select coalesce(max(version),0)+1 into next_version from public.profile_versions where candidate_id=caller;
 insert into public.profile_versions(candidate_id,version,source)
  values(caller,next_version,'manual') returning * into result;
 return result;
end;
$$;

create function public.confirm_profile(p_version_id uuid,p_skills jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 draft public.profile_versions;
 item jsonb;
 skill uuid;
 skill_years numeric;
 new_skills jsonb := '[]';
 provenance public.skill_source;
 seen text[] := '{}';
 identity_key text;
 max_years numeric;
 centroid extensions.vector(1536);
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001', message='not_candidate';
 end if;
 perform 1 from public.candidates where profile_id=caller for update;
 if not found then raise exception using errcode='P0001', message='not_candidate'; end if;
 select * into draft from public.profile_versions
  where id=p_version_id and candidate_id=caller for update;
 if not found then raise exception using errcode='P0001', message='not_owner'; end if;
 if draft.confirmed then raise exception using errcode='P0001', message='profile_already_confirmed'; end if;
 if p_skills is null or jsonb_typeof(p_skills)<>'array' then
  raise exception using errcode='P0001', message='invalid_skills';
 end if;
 if jsonb_array_length(p_skills)>100 then
  raise exception using errcode='P0001', message='invalid_skills';
 end if;
 for item in select value from jsonb_array_elements(p_skills) loop
  if jsonb_typeof(item)<>'object' then
   raise exception using errcode='P0001', message='invalid_skills';
  end if;
  if exists(select 1 from jsonb_object_keys(item) k where k not in ('skill_id','raw_name','years','evidence'))
    or jsonb_typeof(item->'raw_name') is distinct from 'string'
    or length(btrim(item->>'raw_name')) not between 1 and 120
    or (item ? 'skill_id' and jsonb_typeof(item->'skill_id') not in ('string','null'))
    or (item ? 'years' and jsonb_typeof(item->'years') not in ('number','null'))
    or (item ? 'evidence' and jsonb_typeof(item->'evidence') not in ('string','null'))
    or length(item->>'evidence')>2000 then
   raise exception using errcode='P0001', message='invalid_skills';
  end if;
  begin
   skill := (item->>'skill_id')::uuid;
   skill_years := (item->>'years')::numeric;
  exception when invalid_text_representation or numeric_value_out_of_range then
   raise exception using errcode='P0001', message='invalid_skills';
  end;
  if skill_years<0 or skill_years>99.9 or skill_years<>round(skill_years,1)
    or (skill is not null and not exists(select 1 from public.skills where id=skill)) then
   raise exception using errcode='P0001', message='invalid_skills';
  end if;
  identity_key := coalesce(skill::text,lower(btrim(item->>'raw_name')));
  if identity_key=any(seen) then raise exception using errcode='P0001', message='invalid_skills'; end if;
  seen := array_append(seen,identity_key);
  -- Preserve provenance only when all reviewed fields are unchanged. The client
  -- cannot label edited/additional evidence as AI-generated.
  select source into provenance from public.candidate_skills old
   where old.profile_version_id=p_version_id and old.skill_id is not distinct from skill
    and old.raw_name=btrim(item->>'raw_name') and old.years is not distinct from skill_years
    and old.evidence is not distinct from (item->>'evidence') limit 1;
  new_skills := new_skills || jsonb_build_array(jsonb_build_object(
   'skill_id',skill,'raw_name',btrim(item->>'raw_name'),'years',skill_years,
   'evidence',item->>'evidence','source',coalesce(provenance,'user'::public.skill_source)));
  max_years := greatest(max_years,skill_years);
 end loop;
 delete from public.candidate_skills where profile_version_id=p_version_id;
 insert into public.candidate_skills(profile_version_id,skill_id,raw_name,years,evidence,source)
 select p_version_id,(j->>'skill_id')::uuid,j->>'raw_name',(j->>'years')::numeric,
  j->>'evidence',(j->>'source')::public.skill_source from jsonb_array_elements(new_skills) j;
 centroid := public.skills_centroid(array(select skill_id from public.candidate_skills
   where profile_version_id=p_version_id and skill_id is not null));
 update public.profile_versions set confirmed=true,confirmed_at=clock_timestamp(),
  -- Resume totals describe non-overlapping employment, not a sum of skill years.
  -- For manual profiles use the greatest evidenced skill duration, not their sum.
  total_years=case when source='resume' then coalesce(draft.total_years,max_years) else max_years end,
  embedding=centroid,embedding_model=case when centroid is null then null else 'gemini-embedding-001@1536' end
  where id=p_version_id;
 update public.candidates set active_version_id=p_version_id where profile_id=caller;
end;
$$;

create function public.save_preferences(p_prefs jsonb) returns void
language plpgsql security definer set search_path=public as $$
declare
 caller uuid := (select auth.uid());
 entry record;
 item jsonb;
 amount numeric;
begin
 if (select public.current_app_role()) is distinct from 'candidate'::public.app_role then
  raise exception using errcode='P0001', message='not_candidate';
 end if;
 if p_prefs is null or jsonb_typeof(p_prefs)<>'object' then
  raise exception using errcode='P0001', message='invalid_preferences';
 end if;
 for entry in select * from jsonb_each(p_prefs) loop
  if entry.key in ('locations','remote','job_types') then
   if jsonb_typeof(entry.value)<>'array' then
    raise exception using errcode='P0001', message='invalid_preferences';
   end if;
   if jsonb_array_length(entry.value)>50 then
    raise exception using errcode='P0001', message='invalid_preferences';
   end if;
   for item in select value from jsonb_array_elements(entry.value) loop
    if jsonb_typeof(item)<>'string' or length(btrim(item#>>'{}')) not between 1 and 120
      or (entry.key='remote' and item#>>'{}' not in ('onsite','hybrid','remote'))
      or (entry.key='job_types' and item#>>'{}' not in ('full_time','part_time','contract','internship')) then
     raise exception using errcode='P0001', message='invalid_preferences';
    end if;
   end loop;
  elsif entry.key in ('needs_sponsorship','include_stretch') then
   if jsonb_typeof(entry.value)<>'boolean' then
    raise exception using errcode='P0001', message='invalid_preferences';
   end if;
  elsif entry.key='salary_min' then
   if jsonb_typeof(entry.value)<>'number' then
    raise exception using errcode='P0001', message='invalid_preferences';
   end if;
   amount := (entry.value#>>'{}')::numeric;
   if amount<0 or amount>2147483647 or amount<>trunc(amount) then
    raise exception using errcode='P0001', message='invalid_preferences';
   end if;
  else
   raise exception using errcode='P0001', message='invalid_preferences';
  end if;
 end loop;
 update public.candidates set preferences=p_prefs where profile_id=caller;
 if not found then raise exception using errcode='P0001', message='not_candidate'; end if;
end;
$$;
revoke all on function public.create_manual_profile(),public.confirm_profile(uuid,jsonb),
 public.save_preferences(jsonb) from public,anon;
grant execute on function public.create_manual_profile(),public.confirm_profile(uuid,jsonb),
 public.save_preferences(jsonb) to authenticated;
