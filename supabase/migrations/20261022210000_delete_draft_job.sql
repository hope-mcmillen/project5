-- Recruiters can delete their company's DRAFT jobs (API_CONTRACT 7.4).
-- A draft never reached the deck: swipe() only accepts OPEN jobs and no
-- status leads back to DRAFT, so it has no swipes, applications or status
-- events. The check below keeps that true instead of silently cascading.
-- job_requirements cascades with the job; llm_usage has no job_id and the job
-- description lives in jobs.raw_description, so nothing in Storage to remove.
create function public.delete_draft_job(p_job_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare
 company uuid := public.my_company_id();
 job public.jobs;
begin
 if (select public.current_app_role()) is distinct from 'recruiter'::public.app_role or company is null then
  raise exception using errcode='P0001',message='not_company_recruiter';
 end if;
 select * into job from public.jobs where id=p_job_id for update;
 if not found then raise exception using errcode='P0001',message='job_not_found'; end if;
 if job.company_id<>company then
  raise exception using errcode='P0001',message='not_company_recruiter';
 end if;
 if job.status<>'DRAFT' or exists(select 1 from public.swipes where job_id=p_job_id)
   or exists(select 1 from public.applications where job_id=p_job_id) then
  raise exception using errcode='P0001',message='job_not_draft';
 end if;
 delete from public.job_requirements where job_id=p_job_id;
 delete from public.jobs where id=p_job_id;
end;
$$;
revoke all on function public.delete_draft_job(uuid) from public,anon;
grant execute on function public.delete_draft_job(uuid) to authenticated;

-- Close the direct path: jobs_delete_company let any company recruiter delete
-- an OPEN job and cascade away its applications. Deletion is RPC-only now.
drop policy jobs_delete_company on public.jobs;
revoke delete on public.jobs from authenticated;
