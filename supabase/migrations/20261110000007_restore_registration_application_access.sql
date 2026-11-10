-- The registration Edge Function uses a server-only service client to save the
-- pending application and return its id. BYPASSRLS does not grant table access.
grant select, insert on table public.membership_applications to service_role;

-- Name-validation triggers run on profile, member and application writes.
-- Their helper remains private; callers must not need direct EXECUTE/USAGE
-- privileges just to have a permitted row validated. The function already uses
-- an empty search_path and schema-qualified helper calls.
alter function private.validate_person_name_record() security definer;

-- Keep helper functions inaccessible as direct client APIs.
revoke all on function private.is_valid_person_name(text) from public, anon, authenticated;
revoke all on function private.validate_person_name_record() from public, anon, authenticated;
