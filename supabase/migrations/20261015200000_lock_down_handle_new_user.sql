-- handle_new_user only needs to run as the sign-up trigger; nobody should be
-- able to call it through the API (/rest/v1/rpc/handle_new_user).
alter function public.handle_new_user() set search_path = '';
revoke execute on function public.handle_new_user() from public, anon, authenticated;
