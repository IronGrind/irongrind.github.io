Single account sessions — November 8, 2026

A successful sign-in makes its server-issued Auth session the active session for that account. Member, administrator, staff, and phone-operator sign-ins use the same rule. Signing in to phone attendance with an account already open on a computer therefore replaces that account's computer session. Different accounts remain independent. Tabs sharing one browser session share its identity and are not treated as separate devices.

The older dashboard checks its session every five seconds while visible and online, and checks again on focus, visibility changes, or reconnection. It signs out locally and returns to login with an explanation. Network failures alone do not prove replacement and do not force sign-out. An offline or suspended device shows the change when it reconnects or resumes.

Server enforcement

- private.account_sessions keeps one row per account: user_id (UUID primary key and foreign key to auth.users), session_id (UUID), and session_created_at (timestamp with time zone). All fields are required. The account row is removed when its Auth user is deleted. Direct browser table access is revoked and RLS is enabled.
- activate_account_session verifies the caller's signed session ID against auth.sessions and serializes updates for the account. An older session cannot claim ownership after a newer session. Reloading a page checks ownership and never activates an old session again.
- Table policies and a Data API pre-request guard reject the previous session, including SECURITY DEFINER RPC access. An existing pre-request hook is preserved. The heartbeat RPC can return false for a replaced session without exposing another device's session details.
- The old device signs out with local scope. It cannot revoke the newer device as a side effect of being logged out. The active-session marker remains after sign-out, preventing older Auth sessions from becoming eligible again.
- This is application access enforcement. It does not erase information already displayed or stored on an offline device. Public catalog images remain public. Supabase Auth access tokens may remain cryptographically valid until expiration, but the application's database/API checks deny the replaced session.

Database documentation impact

The single-session migration adds one private supporting table. The system now has 12 public application tables and 3 private supporting tables, totaling 15 application-owned tables. Auth-managed tables remain separate. Earlier Chapter 3 schema counts and ERD describe the baseline before this security addition; incorporate private.account_sessions and the Auth-user relationship into the next schema revision rather than counting it as a public table.

Deployment and checks

The session migrations and matching username-login cleanup were applied to the linked Supabase project. A live read-only API check verified that public registration availability checks remain accessible and anonymous callers cannot activate sessions. Website changes are local and need publication through the project's normal workflow before the public website uses the new login and logout behavior. Existing website pages must be refreshed to load the versioned scripts.

PostgreSQL tests cover replacement, inability to reclaim an older session, RLS denial, RPC denial, preservation of a previous API hook, isolation between accounts, and inability to restore old sessions by signing out the newest device. Browser-script tests cover active sessions, local-only sign-out, login redirection, offline handling, network failures, and exclusion of registration and recovery pages. Login-form tests cover activation during both username and email login. Physical multi-device browser testing was not performed.

Reference: Supabase documents that JWTs can outlive sign-out and that additional server checks are needed for immediate application access denial: https://supabase.com/docs/guides/auth/sessions and https://supabase.com/docs/guides/api/securing-your-api.
