# Admin username sign-in

The login page has one Email or username field and one password field. Email addresses use member sign-in; usernames use admin sign-in. There is no account-type selector. Database profile roles are checked after authentication to determine dashboard access. Password recovery still asks for the email linked to the Auth account.

## Deployment

1. Apply `supabase/migrations/20261103000001_admin_username_login.sql`, then `supabase/migrations/20261104000000_admin_login_profile_read_access.sql` in the intended Supabase project's SQL Editor. The second migration grants the server role the profile-column access needed for username lookup; bypassing RLS alone does not grant table access.
2. Deploy the new function from the project root:

   ```powershell
   npx.cmd supabase functions deploy admin-username-login --project-ref YOUR_PROJECT_REF --no-verify-jwt
   ```

   `supabase/config.toml` also declares `verify_jwt = false` for this function because the caller is signing in and does not have a session yet. The function checks the password and administrator role itself. Existing functions retain their own settings. The function uses the server-provided `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY`; never put the service key in browser files.

3. Make sure each admin has a unique, nonblank username of at most 30 characters with no `@`. Matching ignores case. Do not assign usernames that differ only by case. In the SQL Editor, update the specific staff account:

   ```sql
   update public.profiles
   set username = 'staff_username'
   where id = 'THE-STAFF-AUTH-USER-UUID' and role = 'admin'
   returning id, full_name, username, role;
   ```

4. Serve the updated website and refresh the login page. Enter the admin username and existing account password in the same form members use. Verify that member email sign-in still works and that admin activity is attributed to the signed-in account.

Deploy the database migration and function before publishing the updated login page; Admin username sign-in cannot work until both are available.

## Behavior and limits

The endpoint resolves usernames privately, retrieves the account's current Auth email, verifies its password through Supabase Auth, and checks the admin role before returning access/refresh tokens. It does not return the lookup email. Unknown names and incorrect passwords receive a generic credential error. Duplicate case-insensitive matches fail closed until the usernames are corrected.

Attempts are limited to 10 per normalized username and 50 per reported source IP within a five-minute window. Shared-PC attempts count together for that IP. This complements Supabase Auth limits; IP headers depend on the hosting gateway and username limits apply independently. The database stores salted identity hashes, not passwords or raw usernames/IP addresses, for these counters. Old buckets are removed opportunistically when login attempts arrive.

The website directs admins to username login; their Supabase Auth accounts still use email internally. This is not a project-wide ban on direct Supabase email authentication. Existing active sessions continue to work. Auth account creation and password resets still need a reachable email.

## Local checks

Run the mocked endpoint tests with:

```powershell
deno test --allow-env --config supabase/functions/admin-username-login/deno.json supabase/functions/admin-username-login/handler_test.ts
```

`supabase/tests/admin_username_login.mjs` checks the SQL rate limiter in an isolated PGlite database; pass the absolute path to an installed `@electric-sql/pglite/dist/index.js`. These tests do not apply migrations to a hosted Supabase project.

Official references: [Edge Function configuration](https://supabase.com/docs/guides/functions/function-configuration), [restoring an Auth session](https://supabase.com/docs/reference/javascript/auth-setsession).
