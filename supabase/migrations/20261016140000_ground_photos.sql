-- Ground photos. Owners upload to ground-photos/<owner user id>/<file>; the
-- photo's public URL is saved on the ground through the Django API.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ground-photos', 'ground-photos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "ground-photos: read own" on storage.objects
  for select to authenticated
  using (bucket_id = 'ground-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "ground-photos: upload own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'ground-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "ground-photos: update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'ground-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "ground-photos: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'ground-photos' and (storage.foldername(name))[1] = (select auth.uid())::text);
