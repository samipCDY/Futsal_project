-- Accounts made by hand in the Supabase dashboard (Authentication -> Add user),
-- like the admin login, have no phone number, and the 10-digit check made
-- creating them fail. Allow an empty number for those; the app's sign-up and
-- Edit profile still require 10 digits.

alter table public.profiles drop constraint profiles_mobile_number_10_digits;
alter table public.profiles add constraint profiles_mobile_number_10_digits
  check (mobile_number = '' or mobile_number ~ '^[0-9]{10}$');
