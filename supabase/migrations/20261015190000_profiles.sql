-- Profiles: the single source of truth for each user's role.
--
-- Why: Supabase `user_metadata` (what signUp(data: ...) writes) is editable by
-- the user themselves via updateUser(), so the app must never trust a role
-- read from there. Roles live here instead, where users can read their own
-- row but can never change `role`.
--
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text not null default '',
  mobile_number text not null default '',
  role          text not null default 'customer'
                check (role in ('customer', 'ground_owner', 'admin')),
  created_at    timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Users can read only their own profile.
drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

-- Users can update only their own profile...
drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ...and only these columns. `role` is deliberately left out, so it can only
-- be changed from the dashboard / SQL editor (or a future admin function).
-- No insert/delete grants either: rows are created by the trigger below.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name, mobile_number) on public.profiles to authenticated;

-- Create the profile automatically when someone signs up. The requested role
-- comes from sign-up metadata, so only the self-service roles are honoured;
-- anything else (e.g. someone sending role=admin) becomes 'customer'.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, mobile_number, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'mobile_number', ''),
    case
      when new.raw_user_meta_data ->> 'role' in ('customer', 'ground_owner')
        then new.raw_user_meta_data ->> 'role'
      else 'customer'
    end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill profiles for anyone who signed up before this migration
-- (same rule: never admin from metadata).
insert into public.profiles (id, full_name, mobile_number, role)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', ''),
  coalesce(u.raw_user_meta_data ->> 'mobile_number', ''),
  case
    when u.raw_user_meta_data ->> 'role' in ('customer', 'ground_owner')
      then u.raw_user_meta_data ->> 'role'
    else 'customer'
  end
from auth.users u
on conflict (id) do nothing;

-- To make someone an admin, run (in the SQL editor, never from the app):
--   update public.profiles set role = 'admin'
--   where id = (select id from auth.users where email = 'you@example.com');
