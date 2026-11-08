System error review — November 8, 2026

Corrections made

1. Staff Gmail validation: corrected an HTML pattern rejected by modern browser regular-expression syntax. Valid Gmail addresses with dots, plus signs, hyphens, or uppercase domain letters now pass the client check. Non-Gmail domains remain rejected for staff accounts.
2. Staff password guidance: updated the fixed hint to match the enforced uppercase/lowercase/number/symbol rule and twelve-character minimum.
3. Staff name inputs: checked separate first name, optional middle initial, and last name; tested compound names, optional initials, formatting, and invalid inputs.
4. Pairing-dialog refresh: added its own refresh timer so it updates even when this administrator browser did not create a scanner session. Polling stops after the dialog closes. Existing paired/pending counter and reserved-QR visibility regressions still pass.
5. Pairing error paths: removed unreachable branches that described an unsuccessful device registration as successful pairing. Updated code stops member scanning when registration fails.
6. Membership dates: staff counter registration, renewal, and plan-change dates now use Philippine calendar dates instead of the device timezone. Expiry arithmetic uses date-only UTC calculations. Age calculation uses the same Philippine business date.
7. Administrator authorization: both the browser authorization helper and private.is_admin now require an active administrator account. Browser role visibility alone does not authorize database operations.
8. Membership-change lint error: replaced the obsolete Boolean-paid compatibility branch with the numeric amount update required by the current database. No existing payment or membership records were changed by this migration.
9. Test infrastructure: corrected old migration-file paths after the migration archive move, corrected one historical migration filename, and supplied the current session-monitor dependencies in the real-SDK registration fixture. The suite runner records failures by process exit status so an earlier failing test cannot be hidden by a later successful command.

Validation

- 40 automated check groups passed, zero failed. Details and individual output: Review Evidence/System Regression Results.json.
- Checks cover all fifteen browser JavaScript files, local HTML script/style references, unique HTML IDs, modern form patterns, staff names, pricing, registration isolation, login, role restrictions, request approvals, sessions, attendance retries, phone identity, thirty-day pairing, combined capacity, reserved QR visibility, and staff-service permissions. Historical migrations are tested separately from current fixes.
- The new numeric membership test performs a renewal and plan change in isolated PostgreSQL, verifies saved payment amounts, and rejects inactive operators.
- Supabase db lint --linked --level error completed with an empty results list after deployment.
- Chapter verification passed for body/table bolding, stale approval statements, garbled punctuation, image links, SDG placement, fifteen dictionary tables, and 174 fields.

Delivery and limits

The administrator/payment migration is applied to the linked Supabase database. Website changes are local and require publication to affect the public site. No real member transactions, staff accounts, or phone pairings were created for this review; functional writes used isolated PostgreSQL fixtures.

The tests include simulated browser logic and the real Supabase browser SDK with mocked Auth responses. Complete visual browser testing, physical two-phone testing, and Word pagination were not performed. Passing these checks is evidence for the tested behavior, not a guarantee that every possible error has been eliminated.

To rerun the suite: node scripts/run-regression-checks.mjs <path-to-PGlite-dist/index.js> <path-to-cached-Supabase-browser-SDK.js>.

## Follow-up: compound first names in member settings

Saving a member's personal information previously rebuilt the name fields by splitting the combined `full_name`. That parser treated the second word in a compound first name as a middle name, so a first name such as “Anabelle Jean” appeared to move after saving. The save flow now updates the displayed account name without re-splitting the form fields; the entered first, middle, and last name values remain in their respective inputs after a successful save. The database continues to store the existing combined `full_name` value.

## Follow-up: member names and account identifiers

Member registration and staff walk-in registration now use email and password without collecting a separate member username. New members sign in with email; staff and administrators retain their assigned username workflow. Member-facing administrative reports no longer display member usernames. Existing username values are retained for compatibility with older records and are not cleared by this change.

Person-name inputs now reject numeric characters in the browser and account-provisioning services. The database migration adds a trigger check for standard digit characters on profile, member, and application names, including a supplied emergency-contact name. It preserves existing rows so historical data is not rewritten. The name rule allows Unicode letters and punctuation, including compound names. Website changes remain local; the new database migration has not been applied to the linked project.

The paper recheck confirmed Chapter 1 already describes staff and administrator approval correctly. Chapter 3 now documents email sign-in for members, retained username sign-in for staff and administrators, name validation, and the corrected request-review roles. The chapter verification passed after this update. Full Word pagination and current-interface screenshots still need their previously noted visual review.

## Follow-up: staff laptop camera

The staff attendance scanner previously requested a facing mode directly from the QR library, while the working admin scanner first opened a camera through `getUserMedia`, captured the browser-selected device ID, and passed that ID to the QR library. The staff scanner now follows the admin sequence, preferring the front-facing camera on computers and the rear camera on phones, then retrying browser-enumerated cameras if needed. It also opens a centered scan modal with a live preview, QR frame, status text, processing indicator, and Cancel control, matching the admin scanning flow. Camera errors appear inside that modal. The error handler recognizes string-form media errors and shows more specific guidance. The source changes are local and still need physical laptop-camera verification; HTTPS, browser permission, Windows camera privacy, and hardware availability remain necessary.

## Follow-up: remembered login identifier

The login checkbox now remembers only the applicable sign-in identifier: member email or staff/admin username. It fills that value into the login field on the next visit. It does not save a password or preserve an authenticated session. Authentication tokens and the dashboard marker use session storage, and logout clears the authenticated session while leaving the explicitly remembered identifier available. The checkbox says “Remember my login” so it does not imply that members still use usernames.

The paper recheck clarified Chapter 1's duplicate-identifier statement and updated Chapter 3's retained username-field descriptions so they do not imply that new members receive or use usernames. The login-page field itself is labeled Email; staff/admin authentication behavior remains unchanged.
