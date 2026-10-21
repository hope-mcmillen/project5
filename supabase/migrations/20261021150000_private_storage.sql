-- A5 / PL-14. Resume uploads are immutable and private; new files use new UUIDs.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('resumes','resumes',false,5242880,array['application/pdf','application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
 ('company-logos','company-logos',true,5242880,array['image/png','image/jpeg','image/webp'])
on conflict(id) do update set public=excluded.public, file_size_limit=excluded.file_size_limit,
 allowed_mime_types=excluded.allowed_mime_types;

create policy resumes_select_owner on storage.objects for select to authenticated
 using (bucket_id='resumes' and (select public.current_app_role())='candidate'
   and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy resumes_insert_owner on storage.objects for insert to authenticated
 with check (bucket_id='resumes' and (select public.current_app_role())='candidate'
   and (storage.foldername(name))[1]=(select auth.uid())::text
   and cardinality(storage.foldername(name))=1
   and storage.filename(name) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|docx)$');
create policy resumes_delete_owner on storage.objects for delete to authenticated
 using (bucket_id='resumes' and (select public.current_app_role())='candidate'
   and (storage.foldername(name))[1]=(select auth.uid())::text);

create policy logos_public_read on storage.objects for select to anon, authenticated
 using (bucket_id='company-logos');
create policy logos_insert_owner on storage.objects for insert to authenticated
 with check (bucket_id='company-logos' and (select public.current_app_role())='recruiter'
   and (storage.foldername(name))[1]=(select public.my_owned_company_id())::text
   and cardinality(storage.foldername(name))=1);
create policy logos_update_owner on storage.objects for update to authenticated
 using (bucket_id='company-logos' and (storage.foldername(name))[1]=(select public.my_owned_company_id())::text)
 with check (bucket_id='company-logos' and (storage.foldername(name))[1]=(select public.my_owned_company_id())::text
   and cardinality(storage.foldername(name))=1);
create policy logos_delete_owner on storage.objects for delete to authenticated
 using (bucket_id='company-logos' and (storage.foldername(name))[1]=(select public.my_owned_company_id())::text);
