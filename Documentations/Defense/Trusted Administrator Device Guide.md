# One trusted administrator browser

Local source revision: November 10, 2026. This supersedes the earlier session-only approval behavior. User-supplied CLI output confirms migration `20261110000004_admin_trusted_device.sql` applied and the `admin-device-trust` Edge Function deployed successfully. Matching website deployment and real sign-in behavior remain unverified. Keep the existing MFA factors; do not delete them to enable this feature.

## Intended daily behavior

| Situation | Required action / result |
|---|---|
| First trusted browser | Password and fresh authenticator code; browser generates a signing key and is registered for 30 days |
| Repeat login in the same browser and origin | Username/password, then automatic signed device proof; no code while trust is valid |
| Ordinary logout | Auth session ends; server device trust and browser key remain |
| New browser while current trusted device is active | Current device approves, new browser verifies a fresh authenticator code, then server transfers trust |
| New verification fails or is cancelled | Current device stays trusted; new browser cannot access protected records |
| Successful transfer | New browser becomes the single trusted device; previous browser's dashboard/scanner sessions lose access |
| Current device signed out or without a recent heartbeat | New browser uses fresh authenticator recovery; no automatic approval |
| Log out and forget this device | Revokes trust and application sessions; subsequent login requires verification |
| Trust expires, site data is cleared, different origin/browser, or private browsing loses its key | Device must verify/register again |

“Device” here means browser storage for the site's origin. A laptop's Chrome profile, Brave profile, localhost page and production URL can be different trusted-device identities. This is not hardware attestation. One browser can be used by multiple administrator accounts; trust remains separate per account. There is no SMS or persistent password storage.

## Deployment, in order

1. Back up the project and confirm trusted project-owner recovery access. Plan a maintenance window; existing AAL2 sessions must register a device under the new policy and can be blocked temporarily before the matching client is available.
2. Confirm earlier migrations through `20261110000003` are applied. The user previously supplied successful output for that migration; inspect current status rather than reapplying schema exports.
3. Preview the pending migration:

```powershell
npx.cmd supabase db push --linked --dry-run
```

4. Review its output. The expected new item is `20261110000004_admin_trusted_device.sql`; inspect any extra changes first. Apply the reviewed migration and deploy the new function in coordination with the website:

```powershell
npx.cmd supabase db push --linked
npx.cmd supabase functions deploy admin-device-trust
```

The function's gateway JWT check is disabled in config because it performs explicit server-side `auth.getUser()` verification and session binding itself. This does not make its privileged completion RPCs available anonymously. Service-role secrets remain in Edge Function environment settings.

5. Deploy the matching web revision through Vercel and hard-refresh. Keep TOTP **Enabled** (enrollment and verification); **Verify Enabled** alone prevents first enrollment. The local config file does not automatically change hosted Auth settings.
6. On the browser that should initially be trusted, sign in and complete authenticator verification. This first login registers the signing key. Keep the real enrollment QR/manual secret private if enrollment is required.
7. Log out normally, then sign in again in the same browser. It should verify the stored key automatically without another code.
8. Keep that dashboard visible and connected. On a second browser/device, sign in to the same account. The current browser receives Approve/Deny. After approval, the new browser must enter a fresh authenticator code; the old one remains trusted until the new one completes verification.
9. After successful transfer, confirm the old browser loses access and cannot regain it merely with its old key. Test a normal repeat login on the newly trusted browser.
10. Test denial, wrong code, cancellation, timeout, revoked trust and expiry in controlled accounts. Confirm no pending/failure state exposes operational data. Record actual test results and update the notes/PPT deployment status.

## Recovery and revocation

The trusted page updates a server heartbeat through the notification poll. Recent means within two minutes. Hidden/offline pages can stop updating it, so this is an activity window, not a claim that a physical device is powered off. If no valid active trusted session has a recent heartbeat, fresh TOTP may register a replacement without that device's approval. When the current page remains active, approval is mandatory even if a requester knows an authenticator code. An explicitly denied request cannot be reused for transfer; start a new sign-in if a legitimate recovery is needed.

Use **Log out and forget this device** in the administrator menu or administrator scanner controls to revoke current trust. Normal logout intentionally does not revoke trust. Device keys can remain in IndexedDB after revocation, but possession of that revoked key no longer authorizes sign-in. If the authenticator is also unavailable, use the existing verified project-owner recovery process; there is no password-only bypass.

If an otherwise correct authenticator code is failing, use the safe displayed error category to investigate. Device trust does not resolve an invalid code or broken Auth configuration; successful first registration still requires real verification.

## Security design

- Browser: non-extractable ECDSA P-256 private key in IndexedDB; public key may be exported. No bearer trust secret or “trusted=true” flag in localStorage.
- Proof: a random session-bound challenge expires after ten minutes and is consumed on successful completion. A copied signature cannot authorize another challenge/session.
- Server: Edge Function validates Auth identity, verifies ECDSA with the stored public challenge key and derives fresh TOTP from the validated JWT's `amr` method/timestamp. The service completion also checks the real Auth session and active account.
- New trust: approval when a recently active trusted session exists plus fresh TOTP. AAL2 alone is not enough to read protected application data under the new policy.
- Reuse: password plus a signature from the already trusted public key. Trust does not slide forward on every login; its original 30-day expiry remains.
- Transfer: one transaction under the account session lock swaps trust, retires old dashboard/scanner ownership and activates the new scope. A failed transaction preserves old trust.
- Permissions: direct client table and completion-RPC access are revoked; RLS/current-session guards require a server-authorized session mapped to the current trusted device.
- Audit: registration/transfer and explicit revocation events contain no private keys, codes, setup secrets or proof signatures. Existing approval request/decision events remain.
- Limit: non-extractable keys prevent ordinary key export; malicious same-origin scripts could still attempt signing. This feature does not replace XSS prevention, browser/OS security or account recovery controls.

## Schema supplement

The pending target adds two private tables and one approval snapshot field. From the prior 185-field approval baseline, the target is 201 fields across 12 public and 6 private tables. The public-only ERD is structurally unchanged; a full supporting-schema diagram/dictionary needs these additions. The migration is now reported applied in the supplied CLI output; these source-derived counts still need a refreshed deployed-schema export for manuscript synchronization.

### private.admin_trusted_devices

| Field | Type | Constraints / meaning |
|---|---|---|
| user_id | uuid | PK, FK auth.users(id), NOT NULL, ON DELETE CASCADE; one trusted row per administrator |
| device_id | uuid | NOT NULL; browser key identity, not globally unique across accounts |
| public_key | jsonb | NOT NULL; public EC P-256 JWK only |
| device_label | text | NOT NULL; reported browser description, not proof of hardware identity |
| registered_at | timestamptz | NOT NULL, default now(); latest registration/transfer time |
| expires_at | timestamptz | NOT NULL; 30-day trust deadline assigned by completion |
| last_seen_at | timestamptz | NOT NULL, default now(); notification heartbeat/completion activity |

### private.admin_device_sessions

| Field | Type | Constraints / meaning |
|---|---|---|
| session_id | uuid | PK, FK auth.sessions(id), NOT NULL, ON DELETE CASCADE |
| user_id | uuid | FK auth.users(id), NOT NULL, ON DELETE CASCADE |
| device_id | uuid | NOT NULL; compared to the current trusted row; deliberately not a foreign key because candidates are not yet trusted |
| session_scope | text | NOT NULL; CHECK dashboard/attendance |
| public_key | jsonb | NOT NULL; key bound to the challenged/authorized session |
| challenge | text | NOT NULL; random session-bound message, cleared when consumed |
| challenge_expires_at | timestamptz | NOT NULL; ten-minute signing/MFA window |
| authorized_until | timestamptz | Nullable until authorized; cannot exceed current device-trust expiry |

### private.admin_login_approvals addition

`trusted_device_id uuid NULL`: snapshot of the trusted device the requester seeks to replace. Deliberately no FK: the old trusted row/key can be replaced while retaining request history. It prevents an approval for an earlier trusted device from silently approving replacement of a different later device. Existing FK update rules remain NO ACTION; the three new FK update rules use the same default.

## Verification evidence

The local SQL fixture checks first registration, rejection without MFA, trusted-key reuse after logout, consumed challenges, AAL1 trusted approvers, approval without transfer, required MFA, atomic replacement, denied requests, inactivity recovery, explicit revocation and migration rerun. Crypto/Edge/browser tests verify non-extractable keys, valid/invalid signatures, old versus fresh TOTP claims, reuse without code, and failure without completion. These do not constitute an actual IndexedDB/physical authenticator/two-browser production test. Perform the deployment checklist above before claiming live success.

Relevant technical references: [Supabase JWT claims](https://supabase.com/docs/guides/auth/jwt-fields), [TOTP](https://supabase.com/docs/guides/auth/auth-mfa/totp). Implementation evidence is in the migration, Edge Function and focused tests.

## Attendance app separation - November 11, 2026

Administrator trusted-browser registration applies to the website. The attendance scanner app now uses the same staff/admin username and password without an authenticator or device-transfer approval. It has a separate server-bound attendance session and requires phone pairing to submit scans. The app cannot approve website sign-ins, revoke website device trust or access dashboard tables/APIs. Website device enrollment and forget-device actions preserve the independent scanner scope. This supersedes earlier instructions describing the phone scanner as an administrator trusted-device surface.

Migration 20261111000001_password_only_attendance_operator.sql was applied successfully to linked project nttsrdassmzvtaamyogi after terminal dry-run review. Deploy the matching phone UI, scanner JavaScript, shared session monitor and service worker v26, then reopen/reload the phone app. Do not reset authenticator factors or pairings. Local unit/SQL isolation checks passed; hosted frontend delivery and a physical website-plus-phone test remain unverified. Website administrator MFA and trusted-browser requirements remain enabled.
