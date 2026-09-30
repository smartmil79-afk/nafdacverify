-- NaijaVerify database schema (Supabase / Postgres)
-- Run once in Supabase: SQL Editor > New query > paste > Run.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text, username text unique check (username ~ '^[a-z0-9_]{3,20}$'), email text, phone text,
  role text not null default 'reporter' check (role in ('reporter','reviewer','admin')),
  created_at timestamptz not null default now()
);

create table public.alerts (
  id bigint generated always as identity primary key,
  product_name text not null,
  category text not null check (category in ('Food','Medicine','Beverage','Cosmetics','Other')),
  alert_type text not null,
  icon text default '⚠️',
  source_name text, source_url text, alert_date date,
  batch_numbers text[] not null default '{}',
  description text,
  published boolean not null default true,
  created_at timestamptz not null default now()
);
create index alerts_name_idx on public.alerts (lower(product_name));

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  ref text unique not null default 'RPT-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  product_name text not null,
  category text not null check (category in ('Food','Medicine','Beverage','Cosmetics','Other')),
  batch text, expiry date,
  purchase_location text not null, seller text,
  description text not null,
  photo_path text,
  status text not null default 'Submitted' check (status in
    ('Submitted','Under Review','Additional Information Required','Verified Alert','Confirmed Counterfeit','Closed')),
  linked_alert_id bigint references public.alerts(id),
  created_at timestamptz not null default now()
);
create index reports_reporter_idx on public.reports (reporter_id);

-- Role helpers (security definer avoids RLS recursion)
create function public.is_staff() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and role in ('reviewer','admin')) $$;
create function public.is_admin() returns boolean language sql security definer stable set search_path = public as
$$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

-- Auto-create a profile the first time anyone signs up (Google, Apple or email)
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as
$$ begin
  insert into public.profiles (id, full_name, username, email, phone)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
          lower(new.raw_user_meta_data->>'username'),
          new.email,
          new.raw_user_meta_data->>'phone')
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Username helpers used by the sign-up and login screens
create or replace function public.username_available(p_username text) returns boolean
language sql security definer stable set search_path = public as
$$ select not exists (select 1 from public.profiles where username = lower(p_username)) $$;
create or replace function public.email_for_username(p_username text) returns text
language sql security definer stable set search_path = public as
$$ select email from public.profiles where username = lower(p_username) $$;
grant execute on function public.username_available(text), public.email_for_username(text) to anon, authenticated;

-- Row-level security
alter table public.profiles enable row level security;
alter table public.alerts   enable row level security;
alter table public.reports  enable row level security;

create policy "profiles: own or staff read" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_staff());
create policy "profiles: edit own" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- users may change only name and phone, never their role
revoke update on public.profiles from authenticated, anon;
grant update (full_name, phone) on public.profiles to authenticated;

create policy "alerts: public read published" on public.alerts for select to anon, authenticated
  using (published or public.is_staff());
create policy "alerts: admin write" on public.alerts for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create policy "reports: create own" on public.reports for insert to authenticated
  with check (reporter_id = auth.uid());
create policy "reports: read own or staff" on public.reports for select to authenticated
  using (reporter_id = auth.uid() or public.is_staff());
create policy "reports: staff update" on public.reports for update to authenticated
  using (public.is_staff()) with check (public.is_staff());

-- Private bucket for evidence photos (files live under <user id>/...)
insert into storage.buckets (id, name, public) values ('report-photos','report-photos',false)
  on conflict (id) do nothing;
create policy "photos: upload to own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'report-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "photos: owner or staff read" on storage.objects for select to authenticated
  using (bucket_id = 'report-photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_staff()));

-- Starting alert list (from the prototype). Add source_name, source_url, alert_date and batch_numbers
-- from the official notice for each entry before public launch.
insert into public.alerts (product_name, category, alert_type, icon) values
  ('Cowbell Our Milk','Food','Counterfeit Alert','🥛'),
  ('Arla Dano Full Cream Milk Powder','Food','Counterfeit Alert','🥛'),
  ('Peak Milk','Food','Counterfeit Alert','🥛'),
  ('Big Bull Rice','Food','Counterfeit Alert','🍚'),
  ('Cap Rice','Food','Counterfeit Alert','🍚'),
  ('Stallion Rice','Food','Counterfeit Alert','🍚'),
  ('Royal Stallion Rice','Food','Counterfeit Alert','🍚'),
  ('Mama Pride Rice','Food','Counterfeit Alert','🍚'),
  ('BUA Rice','Food','Counterfeit Alert','🍚'),
  ('Whippy Real Mayonnaise','Food','Counterfeit Alert','🥫'),
  ('Sprite 50cl','Beverage','Counterfeit Alert','🥤'),
  ('Fanta','Beverage','Counterfeit Alert','🥤'),
  ('Coca-Cola','Beverage','Counterfeit Alert','🥤'),
  ('Schweppes','Beverage','Counterfeit Alert','🥤'),
  ('Lacasera','Beverage','Counterfeit Alert','🥤'),
  ('Hollandia Yoghurt','Food','Alert','🥛'),
  ('Super Commando Energy Drink','Beverage','Alert','🥤'),
  ('Amstel Malta','Beverage','Alert','🥤'),
  ('Cadbury Chocolate Drink','Food','Alert','🍫'),
  ('Ovaltine','Food','Alert','🥛'),
  ('Meronem 1g Injection','Medicine','Counterfeit Medicine','💉'),
  ('Ozempic','Medicine','Falsified Medicine Alert','💉'),
  ('Lantus SoloStar','Medicine','Falsified Medicine Alert','💉'),
  ('Daonil 5mg','Medicine','Counterfeit Medicine','💊'),
  ('Augmentin 625mg','Medicine','Counterfeit Medicine','💊'),
  ('Tandak Injection','Medicine','Counterfeit Medicine','💉'),
  ('Noristerat Injection','Medicine','Counterfeit Medicine','💉'),
  ('Aflotin 20/120','Medicine','Counterfeit Medicine','💊'),
  ('Cikatem','Medicine','Counterfeit Medicine','💊'),
  ('OHEAL Ampicillin/Cloxacillin','Medicine','Counterfeit Medicine','💊'),
  ('Giga-S Injection','Medicine','Counterfeit Medicine','💉'),
  ('ZACEF-TZ Injection','Medicine','Counterfeit Medicine','💉'),
  ('Herceptin','Medicine','Counterfeit Medicine','💉'),
  ('Accu-Chek Instant Test Strips','Medicine','Counterfeit Medical Product','🩺'),
  ('Oral-B Toothpaste','Cosmetics','Counterfeit Product','🪥'),
  ('Colgate Toothpaste','Cosmetics','Counterfeit Product','🪥'),
  ('Dove Beauty Cream Bar Soap','Cosmetics','Counterfeit Product','🧼'),
  ('Nivea Roll-On Deodorant','Cosmetics','Counterfeit Product','🧴'),
  ('Radox Care + Moisturise Liquid Hand Wash','Cosmetics','Counterfeit Product','🧴'),
  ('Brown Henna Hair Colour','Cosmetics','Counterfeit Product','🧴'),
  ('Benylin Paediatric Syrup','Medicine','Falsified Medicine Alert','💊'),
  ('Falsified paediatric cough syrups','Medicine','Safety Alert','💊'),
  ('Falsified COVID-19 Antigen Rapid Test Kits','Medicine','Falsified Product Alert','🧪');

-- After you sign in once, make yourself admin (replace the email):
-- update public.profiles set role = 'admin' where email = 'you@example.com';
