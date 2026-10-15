-- Mobile numbers are exactly 10 digits (e.g. 98XXXXXXXX). The app checks this
-- on sign-up and Edit profile; this makes the database refuse anything else,
-- even from a request that skips the app.
--
-- NOT VALID: applies to every new or edited row, but doesn't reject rows saved
-- before this rule. Once every profile has a 10-digit number, run:
--   alter table public.profiles validate constraint profiles_mobile_number_10_digits;
alter table public.profiles
  add constraint profiles_mobile_number_10_digits check (mobile_number ~ '^[0-9]{10}$') not valid;
