Attendance review — 4 November 2026

The review covered the installed phone scanner, phone pairing lifecycle, desktop
QR scans, staff attendance, and operator attribution. It was not a full audit of
membership, inventory, or sales.

Issues corrected:

- Admin logout ended phone pairings. Logout now stops dashboard polling and leaves
  trusted pairings intact; explicit pairing removal still uses the admin PIN.
- Transient pairing validation errors erased saved credentials. Network errors now
  preserve them and allow retry; a confirmed invalid/expired pairing still clears them.
- Phone scans entered an anonymous queue and depended on an open admin dashboard.
  The new record_attendance_scan transaction saves directly as the verified operator.
- Rapid callbacks, competing scanners, and uncertain responses could toggle visits
  or duplicate writes. The transaction locks each member, suppresses repeats within
  eight seconds, and accepts an idempotency key for safe phone retries.
- The installed app could keep old JavaScript from its cache. The service worker
  now fetches current app files first and retains a cached fallback.

Operator identity:

Use the staff/admin account username as the operator ID, with its password. No
separate numeric employee-ID field has been introduced. Phone operator sessions
stay in memory; reopening the app asks for identity again without deleting pairing.
Check-in stores recorded_by, check-out stores checked_out_by, and existing activity
log triggers capture the authenticated operator. Entering somebody's name alone
does not establish identity.

Rollout:

1. Apply 20261104000025_restore_separate_staff.sql if it has not already been applied.
2. Apply 20261104000026_reliable_attendance_scanning.sql.
3. Publish the updated admin/staff pages, phone page, JavaScript, and service worker
   together. The previously deployed admin-username-login function supports both roles.
4. Close and reopen the installed app online to get the updated shell; sign in with
   a staff/admin account. Remembered pairings last 30 days. Temporary pairings still
   expire after ten minutes. Explicitly revoked or expired phones must pair again.

The old anonymous submit endpoint now asks old clients to update and sign in. The
updated dashboard does not replay old anonymous queue entries under an admin's
identity. Historical attendance has not been rewritten or deleted.

Automated verification:

- node --test scripts/tests/attendance-phone.test.mjs
- node supabase/tests/reliable_attendance_scanning.mjs <path-to-pglite/dist/index.js>
- JavaScript syntax and git whitespace checks.

Physical-device checks still needed: pair a remembered phone, install/open the app,
close it completely, reopen it, verify operator sign-in appears and the pairing
returns without another admin QR, then scan with the admin tab closed. Confirm both
check-in and check-out in Activity Logs using different operator accounts. Test
temporary loss of internet and explicit pairing removal. Installing from a browser
with isolated storage (for example some iOS contexts), clearing site data, or using
a different origin can require a first pairing in that app context.
