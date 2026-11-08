-- Staff administration validates the caller's active admin role before using
-- the server-only service client. The baseline revoked these required grants.
grant select, update on table public.profiles to service_role;
