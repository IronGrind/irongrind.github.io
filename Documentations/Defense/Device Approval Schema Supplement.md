# Current-device approval — schema and flow supplement

This describes the earlier session-only approval baseline. The subsequent trusted-browser target supersedes its access policy and adds a device snapshot field; see [Trusted Administrator Device Guide](Trusted%20Administrator%20Device%20Guide.md) for the latest flow and schema additions.

Source: `supabase/migrations/20261110000003_admin_device_approval.sql`. User-supplied CLI output confirms this migration applied successfully after the earlier deployment through 20261110000002. Matching web deployment and live two-device behavior are not yet verified. Public tables are unchanged. This extends the supporting schema from three to four private tables in the deployed migration reported by the user; the prior 174-field dictionary baseline gains eleven fields. `auth.sessions` is managed Auth storage, not a new public application table.

## private.admin_login_approvals

| Name | Type | Constraints | Description |
|---|---|---|---|
| id | uuid | PK; NOT NULL; default gen_random_uuid() | Unique approval request identifier |
| user_id | uuid | FK → auth.users(id); NOT NULL; ON DELETE CASCADE | Administrator account owning the request; derived from verified Auth identity |
| requesting_session_id | uuid | FK → auth.sessions(id); NOT NULL; ON DELETE CASCADE; part of composite UQ | Exact password-authenticated session seeking access; never supplied as a client-selected identity |
| approver_session_id | uuid | FK → auth.sessions(id); nullable; ON DELETE SET NULL | Active verified session selected by the server to decide the request. A completed grant survives sign-out of its displaced approver |
| session_scope | text | NOT NULL; CHECK dashboard/attendance; part of composite UQ | Activation scope being requested; dashboard and scanner ownership remain separate |
| device_label | text | NOT NULL | Reported browser label, limited to 180 characters by the request RPC; untrusted descriptive information |
| status | text | NOT NULL; default pending; CHECK pending/approved/denied/cancelled | Recorded decision state. Expired is a derived response, not an additional stored enum value |
| requested_at | timestamptz | NOT NULL; default now() | Server request time |
| expires_at | timestamptz | NOT NULL; default now() + 2 minutes | Deadline for approval of a pending request |
| decided_at | timestamptz | Nullable | Time approval, denial or cancellation was recorded |
| approval_expires_at | timestamptz | Nullable | Approved access deadline, set to decision time + 8 hours; Auth expiry/session ownership may end access sooner |

Unique constraint: `(requesting_session_id, session_scope)`. It prevents the same Auth session from creating duplicate/replayed requests for a scope. All three FK updates use PostgreSQL's default NO ACTION behavior. Direct PUBLIC, anon and authenticated table access is revoked; RLS is enabled with no client-access policy. Security-definer RPCs supply narrowly scoped access.

## Server functions

| Function | Caller and purpose |
|---|---|
| request_admin_login_approval(scope, label) | Password-authenticated active admin creates or polls only its own session request. Selects an active eligible same-account approver, preferring dashboard; returns MFA fallback when none exists |
| list_admin_login_approvals() | Current verified admin reads only unexpired pending requests specifically assigned to its session |
| decide_admin_login_approval(id, approve) | The assigned current verified session approves/denies under the same per-account transaction lock used for session activation |
| cancel_admin_login_approval(scope) | Requesting session cancels its pending or approved-but-not-activated grant; cannot cancel somebody else's request |
| private.admin_mfa_satisfied() | Allows existing AAL2 or an exact-session unexpired approval, while leaving non-admin behavior unchanged |
| private.is_admin() | Requires active admin identity plus MFA or valid approval |
| private.require_admin_login_scope(scope) | Prevents using a dashboard grant to activate the scanner scope, or vice versa |

API pre-request exceptions extend only the own-account MFA Boolean, own request/poll and own cancellation endpoints. List/decision RPCs remain protected. Table RLS, role checks and current-session ownership continue to apply. Frontend state alone cannot grant access.

## Security and actual use

1. Device A remains signed in with an eligible verified application session.
2. Device B verifies the same admin's password but cannot read operational records or activate its scope.
3. B requests approval and polls its request every three seconds. A polls assigned requests every five seconds while open/connected and shows reported browser details plus Approve/Deny.
4. Approval is bound to B's Auth session; B activates the approved scope. A's displaced scope is detected by its monitor. Removal of A's Auth session does not delete B's grant, because the approver FK uses SET NULL.
5. Denied, expired, cancelled, foreign-account or stale-approver decisions cannot activate B. Requests are terminal within that Auth session/scope; a new attempt must authenticate again.
6. With no eligible approver, or by explicit choice while waiting, B uses the authenticator fallback. No automatic approval happens on timeout or loss of connectivity. AAL2 remains the recovery route if A is unavailable.

No SMS, browser push subscription, service-role key in the client, or permanent remembered-device token is introduced. The grant is application-specific; B's AAL1 JWT is not relabeled as AAL2. Custom logs capture the request and approval/denial; expiry is derived, and cancellation is stored on the request rather than claimed as an additional custom log event. Session deletion cascades remove requester-owned approval records; historical activity entries retain their textual event references.

## Diagram/dictionary implications

The twelve-public-table ERD remains structurally unchanged. A full supporting-schema diagram needs this private entity linked to managed auth.users and auth.sessions references. Process 1.0 in the DFD gains request, approval/denial and fallback flows to the private approval store; the nine main functions remain the same. This supplement supplies exact field definitions for the pending migration rather than silently treating the prior deployed-schema dictionary as already updated. Refresh full supporting dictionary counts/figures with the next deployed-schema review.

## Validation and deployment boundary

Isolated SQL tests exercise pending isolation, own-session polling, self/cross-account approval denial, stale-session denial, exact approval transfer, scope mismatch, cancellation after approval, expiry, approval survival when the old session signs out, MFA fallback and migration rerun. Simulated UI tests exercise wait/approve/deny/fallback and safe notification text. Hosted application and two-device behavior still need a recorded end-to-end test after the new migration and web client are deployed.
