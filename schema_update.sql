-- Migration: add usernames and email-code sign-up support.
-- Run this ONLY if you already ran the earlier schema.sql. New installs: just run schema.sql.
alter table public.profiles add column if not exists username text unique check (username ~ '^[a-z0-9_]{3,20}$');

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as
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

-- Username helpers used by the sign-up and login screens
create or replace function public.username_available(p_username text) returns boolean
language sql security definer stable set search_path = public as
$$ select not exists (select 1 from public.profiles where username = lower(p_username)) $$;
create or replace function public.email_for_username(p_username text) returns text
language sql security definer stable set search_path = public as
$$ select email from public.profiles where username = lower(p_username) $$;
grant execute on function public.username_available(text), public.email_for_username(text) to anon, authenticated;
