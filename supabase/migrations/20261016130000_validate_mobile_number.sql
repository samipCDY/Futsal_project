-- Every existing profile now has a 10-digit number, so check old rows too.
alter table public.profiles validate constraint profiles_mobile_number_10_digits;
