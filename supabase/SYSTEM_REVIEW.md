System review — 4 November 2026

Scope: available automated regression tests; JavaScript syntax and local HTML
references; live Supabase attendance structure and database function lint. No
customer accounts, attendance rows, passwords, or payment values were changed in
the live database during this review.

Confirmed findings and workspace corrections:

- Admin camera scans still used direct attendance writes. They now call the same
  atomic record_attendance_scan RPC as phone/staff scans, with a stable request ID
  retained after an uncertain response.
- Manual admin check-out did not populate checked_out_by. It now stores the
  authenticated operator ID along with the check-out time.
- Staff retries previously generated a new request ID every time. The pending
  request is now retained until confirmation or a database rejection.
- Repeated staff camera callbacks could reference a scanner already stopped by
  another callback. The callback now claims the scanner and gates concurrent work.
- The membership dashboard test lacked helper dependencies introduced since it
  was written. Its fixture has been updated; the regression test passes.
- Live database lint flags a static boolean assignment in the legacy compatibility
  branch of admin_record_membership_change on the numeric-paid production schema.
  Migration 20261104000029_membership_paid_type_compatibility.sql replaces only
  that statement with a parameterized dynamic statement. Both boolean and numeric
  schemas pass the compatibility test. The migration has NOT been applied to the
  live database by this review. Existing payment values are preserved.

Live read-only findings:

- Staff activity flag, atomic attendance RPC, operator check-out column, and the
  renamed attendance_scan_requests table are present.
- The old attendance_scan_receipts table is absent.
- No member currently has multiple open attendance visits.
- The password verifier no longer catches every database error as a wrong password.
- Database lint also reports unused parameters on the intentionally retired
  anonymous scan endpoint; these parameters remain for old-client compatibility.

Validation completed:

- Seven Node test entries passed (admin access, admin atomic attendance, phone
  identity/pairing/retries, and password-reset scenarios).
- Eleven Supabase regression scripts passed, including login, registration,
  membership synchronization/status, activity logs, pairing repair, attendance
  transaction permissions/retries, and payment-type compatibility.
- The registration SDK isolation test passed with the actual browser SDK and fake
  Auth responses; it did not create users.
- Edge Function username-login tests passed; staff-creation TypeScript check passed.
- All 13 browser JavaScript files passed syntax checking. Local HTML asset/link
  checks found no missing targets. Git whitespace checks passed.

Before proceeding:

1. Apply migration 29 and rerun live database lint to confirm the compatibility
   diagnostic is resolved there. This review did not deploy database changes.
2. Publish the reviewed frontend files, including admin-access.js. Workspace fixes
   are not evidence that the hosted app already serves the same versions.
3. Test on the actual installed phone: admin login and pairing password, remembered
   pairing after full close/reopen, staff operator login, scans with the admin tab
   closed, check-in/check-out by different operators, offline retry, and explicit
   unpairing. Camera permission, OS app lifecycle, and hosted cache behavior were
   not verified by an interactive browser/device in this review.

Passing automated tests does not establish that every UI workflow is error-free.
