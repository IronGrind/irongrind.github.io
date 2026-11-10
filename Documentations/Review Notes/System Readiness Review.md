# System readiness review — November 10, 2026

The available checks passed for the behaviors below, but the system is not yet confirmed issue-free across complete hosted workflows. Do not describe automated or unauthenticated checks as successful real-account acceptance. This review changed verification tools and documentation; it did not deploy application code, change SQL, create accounts, send recovery emails, or record live sales/attendance.

## Verified results

| Area | Current evidence | Boundary |
|---|---|---|
| Automated regression | 49 check groups passed, zero failed; the browser-unit group contains 52 passing tests | Simulated UI, source checks and isolated SQL; not 49 complete hosted workflows |
| Backend handlers | All eight function entrypoints type-checked; the administrator login-handler test passed | Local type/test checks do not prove successful deployed account creation |
| Sales and stock | Eight additional isolated scenarios passed: gram/kilogram deduction, totals/header/line creation, insufficient-stock atomicity, unit validation, zero/negative rejection, pounds conversion, archived-product denial, role denial and admin item sale | Uses checked-in table definitions and sales function; role helpers are fixture stubs; no concurrency or hosted transaction test |
| Migration history | All 20 local migration versions match the linked remote project, through `20261110000006` | History match is not a full live schema diff |
| Database lint | Linked `extensions`, `private` and `public` schemas returned no errors at error level | Not a query-performance or security certification |
| Edge deployments | Eight expected functions are ACTIVE | Active status alone does not establish successful signed-in execution or secret configuration |
| Hosted files | All 30 checked HTML/JS/CSS/manifest/service-worker files match local content after BOM/line-ending/trailing-whitespace normalization | Eleven files differ in raw bytes only; no functional deployment drift found in this file set |
| Hosted browser | Seven routes at desktop (1440×1000) and mobile (390×844): 14 navigations, zero JS exceptions, no horizontal overflow | Fresh unauthenticated headless Edge profile; protected dashboards redirect instead of loading their signed-in views |
| Access redirects | Administrator, staff and member routes redirect anonymous browsers to login at both viewport sizes | Does not prove every cross-role or cross-member access rule |
| Public UI | Login recovery dialog and registration light theme opened; desktop/mobile screenshots saved; mobile captures visually inspected | No email sent, form submitted, signature saved or recovery link consumed |
| Public APIs | Registration availability responds; anonymous account-session activation is denied; empty registration input returns 400 | Registration success/email delivery not exercised |
| Anonymous records | Eleven public application-table requests returned 401 without exposing records | Only the checked requests; identifiers and personal data were not retained |

## Observed issues

1. A browser-requested `/favicon.ico` returned 404. The checked pages still rendered and no JavaScript exception resulted. This is a minor presentation/network issue.
2. Without any Authorization header, `admin-create-member` returns 500 and `verify-store-password` returns 503. Their checked-in code combines missing authentication with configuration errors. These responses are misleading: they do not prove that signed-in member creation fails or that the store secret is missing. Both endpoints reject a malformed bearer token with 401 at the gateway. Successful signed-in operation remains untested. No error-handling fix or deployment was performed in this review.

## Acceptance still required before claiming the whole system works

Use controlled accounts and disposable records with an agreed cleanup procedure. Do not use real member health information for demonstrations.

| Workflow | Remaining hosted acceptance |
|---|---|
| Registration | Submit valid application, receive/confirm email, verify pending record; check duplicate email, failure recovery and an existing account with no application |
| Authentication | Correct/incorrect admin, staff and member sign-in; disabled accounts; admin TOTP enrollment/recovery; explicit logout and replaced-session behavior |
| Browser trust | Initial enrollment, same-browser reuse, second-browser approve/deny/expiry, displaced session revocation; test administrator and member flows separately |
| Account recovery | Receive password-reset email, open the allowlisted reset route, change password, sign in with the new password |
| Member self-service | Save personal/emergency/health fields and verify persistence; confirm a member cannot access another member's records |
| Membership | Staff/admin review registration, reject requests, renew and change plan; confirm dates, payment, history and sales records reconcile |
| Attendance | Actual laptop/phone camera permissions, valid/expired QR, repeat scans, check-out, paired phone/PWA persistence, capacity and pairing removal |
| Products and sales | Actual admin product create/edit/image/restock/archive, staff product sale, unit conversion, insufficient stock, concurrent sale attempts and post-reload persistence |
| Reports and logs | Reconcile report totals against fixture transactions, export and open files, verify role restrictions and operational/security log entries |
| Usability and reliability | Signed-in desktop/mobile layouts, intermittent network behavior, supported browsers; separate controlled load testing before capacity claims |

## Saved evidence and rerun commands

- `Review Evidence/System Regression Results.json`
- `Review Evidence/Sales Inventory Results.json`
- `Review Evidence/Hosted Readiness Results.json` (includes the normalized-content follow-up and invalid-bearer checks)
- `Review Evidence/Anonymous Access Results.json`
- `Review Evidence/Hosted index desktop.png`, `Hosted index mobile.png`, `Hosted register desktop.png`, `Hosted register mobile.png`

The linked migration list, error-level lint, Edge Function list, local backend type checks and isolated administrator-handler test were checked in this session. Their outcomes are recorded here; this is not a claim that raw CLI transcripts were saved as separate evidence files.

```powershell
node scripts/run-regression-checks.mjs <PGlite-dist-index.js> <cached-Supabase-browser-SDK.js>
node supabase/tests/sales_inventory.mjs <PGlite-dist-index.js>
node scripts/check-hosted-readiness.mjs
node scripts/check-hosted-differences.mjs
node scripts/check-anonymous-data-access.mjs
npx.cmd supabase migration list --linked
npx.cmd supabase db lint --linked --level error
npx.cmd supabase functions list
deno test --config supabase/functions/admin-username-login/deno.json --allow-env supabase/functions/admin-username-login/handler_test.ts
```

The hosted readiness checker reports a nonzero exit status for observed HTTP/API issues; inspect the report rather than treating that exit as proof the entire application is down. The follow-up checker resolves raw-byte asset differences and records invalid-bearer responses. Neither tool signs in or completes business workflows.
