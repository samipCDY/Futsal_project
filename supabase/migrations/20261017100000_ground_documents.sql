-- Ownership documents (lalpurja) for ground approval. PRIVATE bucket: owners
-- upload to and see only ground-documents/<owner user id>/<file>; admins open
-- them from the Django admin panel through short-lived signed links.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ground-documents', 'ground-documents', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "ground-documents: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'ground-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "ground-documents: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ground-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "ground-documents: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'ground-documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
