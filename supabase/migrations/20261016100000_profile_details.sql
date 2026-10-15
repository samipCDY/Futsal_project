-- Richer profile: separate first/last name, date of birth, gender, address.
-- full_name stays (Django keeps it as "first last") so existing readers work.

alter table public.profiles
  add column if not exists first_name    text not null default '',
  add column if not exists last_name     text not null default '',
  add column if not exists date_of_birth date,
  add column if not exists gender        text check (gender in ('male', 'female', 'other')),
  add column if not exists address       text not null default '',
  add column if not exists city          text not null default '';

-- Split existing names: first word -> first_name, the rest -> last_name.
update public.profiles
set first_name = split_part(trim(full_name), ' ', 1),
    last_name  = trim(substr(trim(full_name), length(split_part(trim(full_name), ' ', 1)) + 1))
where first_name = '' and trim(full_name) <> '';

-- Sign-up still sends one "full name"; split it the same way.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  name text := trim(coalesce(new.raw_user_meta_data ->> 'full_name', ''));
begin
  insert into public.profiles (id, email, full_name, first_name, last_name, mobile_number, role)
  values (
    new.id,
    new.email,
    name,
    split_part(name, ' ', 1),
    trim(substr(name, length(split_part(name, ' ', 1)) + 1)),
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

revoke execute on function public.handle_new_user() from public, anon, authenticated;
