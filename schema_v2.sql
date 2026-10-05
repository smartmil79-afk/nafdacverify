-- ChecknVerify: allow anonymous reports (no login). Run AFTER schema.sql in the Supabase SQL Editor.
-- Reviewers read reports in the Supabase dashboard (Table Editor > reports). The app has no admin screen now.

alter table public.reports alter column reporter_id drop not null;
alter table public.reports
  add column if not exists contact_name text,
  add column if not exists contact_phone text,
  add column if not exists contact_email text;

-- keep anonymous input within sane limits
alter table public.reports
  add constraint reports_len_chk check (
    length(product_name) <= 150 and length(description) <= 2200 and length(purchase_location) <= 200
    and coalesce(length(batch),0) <= 80 and coalesce(length(seller),0) <= 150
    and coalesce(length(contact_name),0) <= 100 and coalesce(length(contact_phone),0) <= 20
    and coalesce(length(contact_email),0) <= 120);

-- anyone (not logged in) may create a report, but only as an unreviewed, unlinked, unowned row
grant insert on public.reports to anon;
create policy "reports: anyone can submit" on public.reports for insert to anon, authenticated
  with check (reporter_id is null and status = 'Submitted' and linked_alert_id is null);

-- photo uploads from the public form: images only, 5 MB max, into the anon/ folder only
update storage.buckets set file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'] where id = 'report-photos';
create policy "photos: anonymous upload" on storage.objects for insert to anon
  with check (bucket_id = 'report-photos' and (storage.foldername(name))[1] = 'anon');
