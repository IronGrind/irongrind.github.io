# Member browser registration and approval

Status: migration `20261110000006_member_device_approval.sql` and the `member-device-trust` and `member-password-login` Edge Functions were deployed to linked project `v1-IronGrind` on November 10, 2026. The live Vercel login and reset pages return HTTP 200. Safe unauthenticated probes confirmed member/admin login functions return 400 for empty credentials and device-trust functions return 401 without a session. Actual member login, first-browser enrollment, cross-device approval, and physical-device acceptance remain untested. No authenticator enrollment or code is added to member sign-in.

## Intended behavior

| Situation | Result |
|---|---|
| First eligible member sign-in after this change | The browser creates a non-extractable signing key and registers its public key after password authentication. |
| Same browser signs in again | A session-bound signature proves possession of the registered key; no approval or authenticator code is requested. |
| Different browser signs in while the registered member session is active and checking in | The new browser waits. The current member dashboard displays an “Is this you?” card with the reported browser label and Approve/Deny actions. |
| Member denies, or the two-minute request expires | The new browser cannot activate its member session. |
| Approval succeeds | The new browser registers; its session replaces the previous member dashboard session. |
| No current trusted session is available | Password sign-in can enroll/replace the browser without a second factor. This is the recovery path because members do not use TOTP in this feature. |
| Browser storage is cleared, browser/origin changes, or private browsing is used | The browser may need registration again. If a current trusted dashboard is active, it must approve the replacement. |

Only one trusted member browser is stored per member account, matching the existing single active member dashboard session. The browser label is user-agent information and is not verified hardware identity. The private signing key stays in IndexedDB; the server stores a public key. A recent heartbeat means the member dashboard has checked in within two minutes. A hidden or offline page may stop checking in.

## Deployment steps

1. Review the local migration and confirm the linked project and recovery path.
2. Preview pending SQL:

```powershell
npx.cmd supabase db push --linked --dry-run
```

3. Confirm the expected member device approval migration is the only intended addition, then apply it and deploy its Edge Function:

```powershell
npx.cmd supabase db push --linked
npx.cmd supabase functions deploy member-device-trust
```

4. Deploy the matching website revision. Migration, function and website must be coordinated; the login flow calls the Edge Function before activating a member session.
5. On a controlled member account, sign in once to enroll the first browser. Sign out and sign in again on the same browser. Then keep it open and connected while signing in from another browser; confirm Approve and Deny behavior, expiry, and loss of the displaced session.
6. Confirm administrator and staff login, membership application recovery, and member logout still work. Record actual hosted results before describing the feature as deployed or verified.

This feature does not require enabling or changing hosted TOTP settings. It does not add an authenticator code to members. The migration and Edge Functions are deployed and Vercel serves the matching client; complete the controlled member browser-acceptance steps above before claiming full workflow verification.

## Affected modules

- `supabase/migrations/20261110000006_member_device_approval.sql`: private key/session/approval stores, service-only challenge/finish/status RPCs, trusted-session Approve/Deny RPCs, audit entries, and a guard on member session activation.
- `supabase/functions/member-device-trust/index.ts`: validates the Auth session and verifies ECDSA proofs before invoking service-only database functions.
- `assets/js/member-device-approval.js`: browser key handling, waiting dialog, and member dashboard notification polling.
- `assets/js/auth.js`, `assets/js/supabase-client.js`, `assets/js/customer.js`, `index.html`, `customer.html`, `supabase/config.toml`: login gate, notification lifecycle and function configuration.

## Validation and limits

The migration and Edge Functions are deployed, Vercel serves the matching client, and the local SQL/browser fixtures passed. No real member credentials or physical browsers have been used for acceptance. The first sign-in after rollout is initial enrollment: sessions predating this feature do not have a registered browser key, so an existing member must enroll once before subsequent browser transfers can be approved by that device. The member account continues to rely on its password when no current trusted browser can approve; this change does not add a second factor or claim phishing-resistant authentication.
