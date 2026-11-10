# Registration application-save permission fix — November 10, 2026

The reported registration reached Auth signup, but saving the pending membership application failed. The existing cleanup path removed the newly created Auth account and displayed the failure message. The availability/password messages in the screenshot describe client checks; they do not establish that the database insert succeeded.

## Verified causes

Read-only inspection of linked project `nttsrdassmzvtaamyogi` confirmed that `service_role` had neither INSERT nor SELECT permission on `public.membership_applications`. PostgreSQL BYPASSRLS does not replace table grants. The endpoint uses `.insert(...).select('id').single()`, so it needs both privileges.

The name-validation trigger was also an invoker function. It called `private.is_valid_person_name(text)`, which was deliberately revoked from browser roles. The registration service also lacked USAGE on the private schema. An isolated regression reproduced the application-table permission failure first, then the private-schema/helper failure after temporarily supplying only the table grants.

## Change and validation

Migration `supabase/migrations/20261110000007_restore_registration_application_access.sql` grants only SELECT and INSERT on the application table to the server-only service role. It changes `private.validate_person_name_record()` to SECURITY DEFINER, retaining its empty search path and schema-qualified helper calls. The helper and trigger functions remain unavailable for direct browser execution. No table, column, foreign key or browser permission was added. No UI text or manuscript formatting was changed.

The regression uses checked-in table definitions and name-validation migration. It verifies pending application insert/readback, rejection of invalid applicant and emergency names, authenticated own-account saves, denial of foreign-account reads/writes, profile/member name validation, direct helper isolation, absence of extra service UPDATE/DELETE grants, and migration rerun.

The linked dry run listed only migration 20261110000007. The normal linked terminal push applied it successfully; this installed CLI applied the migration without presenting an interactive confirmation prompt. No SQL Editor was used. A live service-role insert and return of an application id succeeded inside a transaction that was rolled back, including trigger-generated log effects. Subsequent metadata checks confirmed service INSERT/SELECT, SECURITY DEFINER validation, no anonymous INSERT, and absence of the temporary fixture. Linked error-level database lint returned an empty error list.

The screenshot's signup was not retried with the applicant's credentials. Email delivery, confirmation and full real-account signup remain to be checked by retrying the form. The existing Edge Function and website use the repaired database permissions immediately; no function or website redeployment was needed. No real member data, accounts or emails were created for verification.

## Affected files and rerun

- Migration 20261110000007.
- `supabase/tests/registration_application_access.mjs` and the regression-suite entry.
- `supabase/tests/registration_application_access_live.sql` (rollback-only terminal verification).
- Defense notes, presentation source and setup documentation.

```powershell
node supabase/tests/registration_application_access.mjs <PGlite-dist-index.js>
npx.cmd supabase db query --linked --file supabase/tests/registration_application_access_live.sql
```

The post-fix full regression run passed 50 check groups with zero failures. The full regression result is saved in `Documentations/Review Evidence/System Regression Results.json`. Earlier unauthenticated readiness probes did not exercise this successful application-write path; their passing results must not be described as complete registration acceptance.
