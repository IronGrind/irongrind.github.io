-- The login Edge Function resolves usernames with its server-only service key.
-- BYPASSRLS does not itself grant permission to read table columns.
reset role;
begin;
grant usage on schema public to service_role;
grant select (id, username, role, full_name) on public.profiles to service_role;
commit;
notify pgrst, 'reload schema';
