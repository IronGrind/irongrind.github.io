# Administrator MFA — Setup and Deployment Guide

Revision: November 10, 2026. Code is prepared locally. This guide does not mean any production change has already been applied. The original administrator MFA baseline is followed by a local current-device approval increment. In-website approval is implemented; user-supplied CLI output confirms its migration applied successfully. Matching client deployment and the two-device test remain unverified. SMS and background push notifications are not used.

## 1. Prepare access and backups

1. Confirm which Supabase project and Vercel project serve IronGrind. Check the project's database migration history; do not execute an old full schema export against production.
2. Keep the project owner's Supabase access available through a separate trusted administrative channel. Verify how the owner will establish identity during a lost-factor recovery.
3. Back up the database/configuration using the team's normal process. Retain the current deployed web revision and pending migration/function list.
4. Arrange a short maintenance period and have the genuine administrator ready with a trusted device and authenticator app. First enrollment must not be left for an unknown person who merely knows the password.

## 2. Confirm Auth settings

1. In the intended Supabase project's Authentication settings, enable authenticator/TOTP enrollment and verification.
2. `supabase/config.toml` now declares `[auth.mfa.totp]` with enrollment and verification enabled for local configuration. Editing this file does not automatically enable hosted settings.
3. Check email redirect settings and working account recovery separately. Password recovery does not remove an existing verified MFA factor.
4. If password-reset-request events should appear in custom activity logs, enable the corresponding database Auth audit storage. No raw Auth payload or secret is copied by the custom trigger.

## 3. Check locally before rollout

If PowerShell blocks `npx.ps1`, use `npx.cmd` in the commands below; no execution-policy change is needed. A November 10 read-only linked migration check confirmed versions 20261108000012, 20261110000001 and 20261110000002 were pending. This explains the incomplete security-setup sign-in error. The subsequent user-supplied push output confirms all three migrations applied successfully. Next, confirm hosted TOTP settings and test the matching deployed client/functions; do not repeat the migration just because the earlier diagnostic is retained here.

From the project directory, run:

```powershell
node --check assets/js/admin-mfa.js
node --check assets/js/auth.js
node --check assets/js/attendance-phone.js
node --test scripts/tests/admin-mfa-ui.test.mjs
node supabase/tests/admin_login_form.mjs
node scripts/check-ui-improvements.mjs
node scripts/check-form-validation.mjs
```

The SQL test requires an installed PGlite module path:

```powershell
node supabase/tests/admin_mfa.mjs "<absolute-path-to-PGlite-dist/index.js>"
```

The development server is `npm start`, normally at `http://localhost:4173`. Use test accounts/project for behavioral trials; do not manufacture production sales or attendance just to run tests.

## 4. Review migrations and deploy dependencies

1. Authenticate the Supabase CLI and link the intended project if not already linked. Inspect the project reference before approving any write.
2. Review migration status and the dry run:

```powershell
npx supabase migration list --linked
npx supabase db push --dry-run
```

3. Ensure earlier session-scope and security-event migrations are present. Relevant additions are `20261110000001_security_activity_events.sql` and `20261110000002_admin_mfa.sql`. The MFA migration extends the existing guard instead of replacing its session behavior.
4. During the maintenance window, apply the reviewed pending migrations:

```powershell
npx supabase db push
```

5. Deploy the authentication functions required by the current frontend if they are not already current:

```powershell
npx supabase functions deploy admin-username-login
npx supabase functions deploy member-password-login
```

The current member frontend depends on `member-password-login`. Do not release a frontend that references an undeployed function. Existing create-member/create-staff/store-password functions use caller profile access before privileged operations; that access passes through the new server gate. Re-deploy them if their source differs from the deployed version.

6. Release the matching web revision through the existing Vercel deployment workflow. MFA migration enforcement can temporarily block administrators on the old frontend, so coordinate these steps in the same maintenance window. Do not publish the web client alone and claim server MFA is enabled.

## 5. Enroll the genuine administrator

1. Open the deployed login page on the trusted device. Enter the administrator's assigned username and password.
2. The setup dialog appears if no verified authenticator is enrolled.
3. In the authenticator, add a time-based account and scan the setup QR, or enter the manual setup key privately.
4. Enter the current six-digit code and select Verify. Correct verification raises the session to AAL2; only then is the application session activated.
5. Keep the phone's date/time automatic. Test the next sign-in with a newly generated code.
6. Do not save the real setup QR/key in Git, slides, screenshots or shared documentation. Do not remove the authenticator entry after setup.

## 6. Verify allowed and blocked paths

| Check | Expected outcome |
|---|---|
| Admin password only, before code | No protected data access or session activation |
| Cancel verification | Return to sign-in; do not replace the active dashboard/scanner session |
| Incorrect/expired code | Stay in verification; allow a new current code |
| Correct code | Complete login and role/session checks |
| Staff sign-in | Existing flow, no administrator MFA prompt |
| Member email sign-in | Existing membership checks, no administrator MFA prompt |
| Admin signs into scanner | MFA before scanner activation |
| Staff signs into scanner | Operator checks and pairing still required |
| Direct AAL1 table/API/RPC access as admin | Server denies protected access |
| Administrator normal logout | Clean login page without false expiry warning |
| Existing verified factor after password reset | MFA remains required |

Record actual browser/device/date and outcomes in Review Evidence. Isolated tests already passed locally, but these physical/hosted checks remain to be performed. Update deployment status in both defense files and presentation speaker notes afterward.

## 7. Lost authenticator recovery

1. Stop repeated login attempts and contact the trusted project owner using the established real-world channel.
2. The owner verifies identity and checks whether credential compromise is suspected. Do not rely only on a message claiming to be the administrator.
3. Through Supabase's supported administrative MFA management, the owner identifies and resets/removes only the affected factor. Use the supported administrative interface/API available in the hosted project; never place a service-role key in browser code or slides.
4. If compromise is suspected, reset credentials and revoke affected sessions through supported Auth administration as appropriate.
5. Supervise the genuine administrator's fresh enrollment immediately. Confirm successful sign-in and record the recovery action through the team's controlled operational process.

This increment has no self-service recovery codes or old-device approval mechanism. Recovery is a project-owner procedure; don't describe it as an automatic feature. Never delete membership or transaction records to recover authentication access.

## 8. Maintain the notes and PPT

1. Update Capstone Study and Defense Notes.md with the behavior, modules, real-world scenario and limits.
2. Update Capstone Presentation.md slide bullets and speaker notes. Never expose MFA secrets in examples.
3. Run `node Documentations/Tools/build-defense-materials.mjs` to refresh Source Code Map.md and the editable PowerPoint.
4. Run `powershell -NoProfile -ExecutionPolicy Bypass -File Documentations/Tools/verify-chapters.ps1` when paper changes are made, and recheck figures/prototypes separately.
5. Record validation and distinguish local changes, deployed changes and planned features. AGENTS.md records this requirement for later work.

## Technical references

- https://supabase.com/docs/guides/auth/auth-mfa
- https://supabase.com/docs/guides/auth/auth-mfa/totp
- https://supabase.com/docs/guides/local-development/cli/config
- https://supabase.com/docs/guides/auth/audit-logs

## 9. Deploy and use in-website device approval

The earlier successful push applied migrations through 20261110000002. This new increment needs 20261110000003_admin_device_approval.sql; it does not require SMS or an upgrade to Pro within Free-plan usage limits.

1. Keep the genuine administrator signed in on Device A after its existing authenticator verification. Keep its website open and connected.
2. Review the new migration with `npx.cmd supabase db push --linked --dry-run`. Confirm that the new device-approval migration is the expected pending item; inspect any extra items before applying.
3. In a coordinated maintenance window apply the reviewed migration with `npx.cmd supabase db push --linked`, then deploy the matching web revision and refresh Device A so its new notification script is loaded. Existing authentication-function endpoints are unchanged by this increment.
4. On Device B, enter the same administrator credentials. It should display Waiting for approval rather than opening the dashboard.
5. Device A should show Is this you? with reported browser information, time and Approve/Deny. Approve only a request you initiated; browser descriptions are not proof of physical identity.
6. Approve on A. B completes session activation and receives access; A loses the replaced application scope when its existing monitor checks. Dashboard and scanner scopes remain separate.
7. Repeat with Deny, expiry, Cancel and Use authenticator instead. No failed/pending path should expose protected records or replace A's session. Requests expire in two minutes; approval grants last no more than eight hours and cannot outlive their Auth session.
8. If there is no active eligible session, sign-in uses the authenticator. If A is offline, B can select the authenticator fallback; it is never approved automatically due to timeout/offline status. Losing the authenticator as well requires the verified project-owner process above.
9. Verify the security log contains request and approval/denial events. No secret or code should appear. Check the private schema supplement and update diagram/dictionary evidence after deployment.
10. Record actual two-browser/two-device outcomes and update both notes and slide speaker notes. User-supplied output now confirms the approval migration applied successfully. Matching web deployment and physical testing remain unverified.
