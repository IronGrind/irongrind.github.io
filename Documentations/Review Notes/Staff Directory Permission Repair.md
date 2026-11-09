Staff directory repair — November 8, 2026

Live database checks confirmed service_role lacked SELECT and UPDATE on public.profiles. The staff administration Edge Function validates the caller as an active administrator, then uses this server-only role to list staff and change activation state. Missing table grants caused its generic Could not load staff accounts response.

The repair grants SELECT and UPDATE on profiles to service_role only. It grants no additional access to anonymous or authenticated browser roles. Existing administrator validation, session checks, and staff-only filters in the Edge Function remain in place.

PostgreSQL tests reproduce the missing-permission error, verify listing and activation updates after the repair, and confirm that browser roles receive no new table access. The migration is deployed separately to the linked database. This repair changes no schema columns, table counts, or documentation field counts.
