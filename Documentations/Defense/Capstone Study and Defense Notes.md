# IronGrind — Study and Defense Notes

Maintained baseline: November 10, 2026 (Asia/Manila). Read alongside the source and Chapters 1–3. This is a study companion, not a substitute for the approved paper. Subsequent changes must update this file and the separate presentation.

## Current security revision ? one trusted administrator browser

The latest local increment supersedes the earlier session-only MFA/approval descriptions below. One browser-held, non-extractable ECDSA signing key is trusted per administrator account for 30 days. Repeat password logins from that browser prove possession of the key without another code. A new browser requires current-device approval plus a fresh authenticator verification before an atomic trust transfer; the previous device stays trusted if verification fails or is cancelled. Ordinary logout preserves trust; Log out and forget this device revokes it. When no eligible live approver exists, fresh MFA is the recovery route. A trusted page heartbeat is considered recent for two minutes; hidden/offline pages may stop heartbeat updates. This is browser/origin trust, not hardware attestation or a permanent login token. User-supplied CLI output confirms migration 20261110000004 and the admin-device-trust Edge Function deployed successfully. Matching website revision and physical/browser validation remain unverified.

## Local member-device approval increment

The November 10 local revision adds browser-key registration for approved members without adding an authenticator factor or code to member sign-in. The first eligible sign-in enrolls that browser. A later sign-in from another browser waits for approval from the currently trusted member dashboard; the dashboard displays “Is this you?” with the reported browser and Approve/Deny. Approval transfers the single member dashboard session. Denial or the two-minute request expiry keeps the new browser out. If there is no active trusted member session to approve, password sign-in can enroll a replacement; this is not a second factor. Migration 20261110000006 and the member-device-trust and member-password-login Edge Functions are deployed to the linked project, and the Vercel client is live. Safe probes confirm all four member/admin login and trust endpoints respond; no real account credentials or physical authenticator were used, so successful user-flow acceptance remains unverified. See `Member Device Approval Guide.md` for the exact rollout and limitations.

## Password recovery redirect correction

The user clarified that production is now hosted at `https://irongrind-github-io.vercel.app`; the earlier linked Supabase config diff showing a GitHub Pages Site URL is stale for the current hosting setup. `assets/js/auth.js` now requests `https://irongrind-github-io.vercel.app/reset-password.html`, and `index.html` cache-busts the changed script. Supabase Authentication URL Configuration must use the Vercel origin as Site URL and allowlist the exact reset page. The recovery email template must link through `{{ .ConfirmationURL }}` so Supabase verifies the token and honors the requested redirect. Live Vercel checks confirm the login and reset pages return HTTP 200 and the deployed login script targets the Vercel reset page. Supabase Authentication URL Configuration must use the Vercel origin as Site URL and allowlist the exact reset page. The recovery email template must link through {{ .ConfirmationURL }}. The public Auth settings endpoint does not expose the active Site URL, redirect allowlist or email template. Those dashboard values, a fresh recovery email, and a completed password update remain unverified.

## Authentication and device security recheck

On November 10, the local end-to-end source and regression review covered reset-link target, recovery-page script syntax, member and staff login, administrator username login, TOTP enrollment and challenge handling, trusted-browser approval, account-session activation, and member-device approval. The review found that migration `20261110000006_member_device_approval.sql` revoked a private helper using the wrong `public` schema name. It now references `private.member_device_session_is_trusted` and `private.require_member_device_session`. Two stale test fixtures were updated to model member-device approval during login and the sessionStorage-backed Auth client. The member migration rerun fixture now restores the owner role before replay. The complete local regression suite then passed all 49 checks, including the SQL fixtures for administrator MFA, approval, trusted-device transfer and member-device approval. The local source and simulated database checks were supplemented by live read-only Vercel and Supabase endpoint probes. They do not verify the private hosted Auth URL/email-template settings, real account login, real email delivery, password update, or a physical authenticator. Migration 20261110000006 is applied on linked project v1-IronGrind; member-device-trust and member-password-login are deployed. Live unauthenticated probes returned expected 401/400 responses. Real logins, fresh password-reset email, hosted redirect/template values, and physical authenticator acceptance remain unverified.

## 1. Explain the project in one minute

IronGrind: A Fitness Gym Membership and Operations Management System is a web application for Iron Grind Fitness Gym. It brings membership applications, membership periods, attendance, inventory, sales, reports and operational accountability into one system. Applicants submit requests; authorized staff or administrators verify the transaction at the gym before approval. Members access their own information. Operators record attendance and in-person transactions. The administrator supervises inventory, staff accounts, reports and logs. Supabase supplies authentication and PostgreSQL services, while the web client is hosted through Vercel. A phone attendance scanner can be installed as a Progressive Web App (PWA).

The installable scanner remains a web application. Installation is not authentication, phone pairing is not operator authentication, and cached pages do not make attendance saving available offline.

## 2. Evidence and history: what can actually be claimed

The available conversation, repository history, migration files, review evidence and supplied screenshots show an incremental development process. They do not establish the exact first day the team started, stakeholder approval dates, measured efficiency gains or completed production acceptance. Avoid inventing these for the defense.

| Development stage | What changed / why | Evidence / present interpretation |
|---|---|---|
| Problem and scope definition | Organize gym records previously handled through separate/manual processes | Chapter 1 describes the problem and objectives; interview claims require the team's original records |
| Core application | Separate applicant/member, staff and administrator workflows | HTML pages, role guards, SQL policies and Edge Functions |
| Authentication refinements | Member email sign-in; assigned operator usernames; name validation; remembered identifier instead of persistent credentials | Auth, registration and form code; never say the checkbox saves a plaintext password |
| Operational correctness | Payment recording, stock deductions, attendance duplicate protection, restricted staff services | RPCs, migrations and isolated database tests |
| Device/session work | Dashboard/scanner separation, pairing lifetime/capacity, laptop camera handling and explicit logout cleanup | Session and pairing migrations, scanner code and regression fixtures |
| Diagram/paper work | Nine aligned functions, context/DFD/use case, schema relationship descriptions and complete dictionary | Chapter 3, diagram sources and review evidence; some screenshots are historical |
| November 10 interface work | Split admin member names, inventory thresholds/unit displays, staff catalog form sections and name/Gmail attendance lookup | Current source and focused tests; not proof of production rollout |
| November 10 audit extension | Server-audited rejected login attempts, password changes/recovery requests, sessions and export requests | Security migration, authentication functions and audit tests; deployment/configuration required |
| Current admin MFA increment | Authenticator enrollment/challenge plus server-side administrator access enforcement | `admin-mfa.js`, MFA migration and tests; hosted setup and physical authenticator validation pending |
| November 10 member-device increment | Member browser signing-key enrollment and “Is this you?” transfer approval from the current member device; no member TOTP | Migration 20261110000006 and member login/trust functions deployed; real member browser approval validation pending |

Use `git log --date=short` for actual repository commit dates. A commit date is evidence of a recorded revision, not automatically the date of an interview, implementation start or production launch.

## 3. What, why, who, when, where and how

| Scenario | Who / where / when in reality | Digital process | Important boundary |
|---|---|---|---|
| Online application | Applicant uses a supported browser before visiting/approval | Email/password account and pending membership application | An Auth account is not yet an approved member |
| Counter registration | Operator and applicant are at the gym; applicant chooses credentials and signs | Split name inputs combine into full_name; authorized service creates records and records payment | This creates a new record; it is not permission to edit existing member profiles |
| Request approval | Authorized staff/admin verifies the applicable gym payment | Pending request is approved/rejected by an authorized RPC | No online payment processing or automated payment verification is claimed |
| Member self-service | Member opens the portal on their own device | Own membership, QR, visits, renewal request and permitted profile updates | Members do not gain other people's records or operator checkout tools |
| Attendance | Operator checks arriving/leaving member | Camera QR or staff name/Gmail lookup → explicit selection → attendance RPC | Name search alone never records a visit; unique ID disambiguates shared names |
| Missing checkout | Member did not have a recorded departure on an earlier Philippine day | Old open visit is shown as Incomplete | System does not fabricate a departure time |
| Product sale | Customer pays the operator at the gym | Product/unit/quantity validation, sale/lines and stock deduction | An internal receipt_number is a transaction reference, not an issued customer receipt |
| Restocking | Administrator receives product stock | Add quantity in a compatible unit, convert and save | Staff can sell but cannot maintain stock |
| Phone setup | Administrator creates setup QR; operator opens scanner on a phone | Pair phone, sign in as operator, grant camera access | Setup QR, member QR and authenticator QR have different purposes |
| Scanner reinstall | Operator accidentally deletes home-screen app | Open scanner link directly and install again | Reuse requires the same browser's active saved pairing; cleared storage can require re-pairing |
| Admin sign-in | Administrator uses password plus authenticator | AAL1 password session → TOTP challenge → AAL2 → session activation | A popup is not the security boundary; server checks enforce MFA |
| Report export | Administrator selects reporting period and requests file | Generate PDF or ZIP and log export request | Browser file-save completion is not verified |
| Incident review | Administrator investigates a change or rejected login | Filter logs by actor, category, action and Philippine date range | Unverified attempts are not attributed as actions performed by an account owner |

## 4. The nine main functions and permissions

| Function | Member / applicant | Staff | Administrator |
|---|---|---|---|
| User Login | Email/password plus member-browser proof; current member device approves a new browser when available | Assigned username/password | Password plus trusted-browser proof, or approval and fresh TOTP for administrator browser transfer |
| Membership Application | Submit own request / view own state | Review authorized pending requests | Review authorized pending requests |
| User Management | Update own permitted information | Counter creation and limited operational lookup | Read member profiles; administer staff access; no member-personal-detail edit |
| Renewals | Request renewal | Direct renewal and active-plan changes | Membership operations and request review |
| QR Attendance | Display own QR / read own visits | Camera or member lookup; permitted visits | Record and review; pairing administration |
| Products & Inventory | Browse active catalog | Browse sales catalog | Add/edit/restock/archive products |
| Sales | No self-checkout | Record product sales / own-sale history | Authorized transaction recording/review |
| Generate Reports | No | No | Preview/export supported reports |
| Activity Logs | No | No | Read and filter recorded events |

Different associations with the same function do not imply identical permissions. This distinction explains why members and staff can appear under broad User Management or Products & Inventory in a use-case diagram.

## 5. Technology choices and their actual roles

| Component | What / where / why |
|---|---|
| HTML | Semantic page structure and forms in the seven root pages |
| CSS | Shared theme, layouts, responsive controls, badges and dialogs; staff-specific rules in staff.css |
| Browser JavaScript | Renders data, handles user actions and calls Auth/Edge Functions/RPCs; not a trusted authorization boundary |
| Supabase Auth | Password verification, sessions, account email flows and TOTP factor verification |
| PostgreSQL | Persistent application tables, constraints, transactions, policies, stored procedures and audit triggers |
| RLS | Limits table operations according to authenticated identity, role/session and applicable ownership |
| SQL functions / RPCs | Server-side business operations such as attendance, membership transactions and session checks |
| Supabase Edge Functions | Privileged workflows with server-only credentials; username/email login throttling, account creation, store-password verification |
| Supabase browser SDK | Auth and API client loaded by the pages; service-role credentials must never be placed here |
| Vercel | Existing hosted web client; a Ready deployment does not prove every backend migration is applied |
| Node.js | Development static server and automated JavaScript checks; server.js is not the production business backend |
| Html5Qrcode | Camera-based QR decoding; secure context and camera permission remain required |
| Signature handling | Captures the applicant's drawn signature; this does not independently verify legal identity |
| PWA manifest/service worker | Scanner installation metadata and cached shell; database writes still require network access |
| PDF/ZIP libraries | Browser report generation, as loaded by the reporting interface |
| jsPDF 2.5.2 / AutoTable 3.8.4 / JSZip 3.10.1 | The administrator page's declared CDN versions for PDF creation, tabular reports and ZIP packaging |
| QRCode.js 1.0.0 / Html5Qrcode 2.3.8 | The administrator page's declared QR generation and camera-decoding libraries; generation and reading have separate purposes |
| Font Awesome | Interface icons, loaded from a CDN; icons do not supply authorization or business processing |
| pgAdmin | PostgreSQL inspection/export tool; compare the connected instance to Supabase, not assume it is a second independent source of truth |
| draw.io / SVG | Editable diagram sources and scalable illustrations; diagrams must agree with actual declared relationships |
| Word | Chapters and data dictionary; updated text does not recapture old UI screenshots |
| Git / VS Code | Version history and development workspace; commit history is not a measured evaluation |
| PGlite / Node tests | Isolated PostgreSQL and simulated browser logic verification without writing fake operational transactions to production |

Package declarations, CDN script URLs and test imports describe different dependency roles. Do not describe the application as React, Next.js or a native Android app; those are not its current architecture.

## 6. Code walkthrough by module

`Source Code Map.md` is a generated companion listing source-defined functions and SQL routines with locations. It is a navigation inventory, not a claim that every source line has been independently explained or reviewed.

| Module | What it does / key reasoning |
|---|---|
| auth.js | Parses email versus assigned username; obtains an Auth session through the applicable login function; now runs administrator device approval or the MFA fallback before session activation; verifies profile/membership state and routes to a role-specific page |
| member-device-approval.js | Stores the member browser's non-extractable signing key, waits for current-device approval on a new browser, and polls the member dashboard for approval requests; no authenticator UI |
| member-device-trust Edge Function | Validates the member Auth session and ECDSA proof before service-only registration/approval completion calls |
| admin-device-trust.js | Stores a non-extractable browser signing key in IndexedDB; gets and signs session-bound challenges; coordinates trusted reuse, approval, fresh MFA and server registration; forget control revokes server trust |
| admin-device-approval.js | Requests session-bound approval, polls the waiting state, displays Approve/Deny on an active administrator device and cancels pending requests before the authenticator fallback |
| admin-mfa.js | Queries own MFA requirement, checks assurance level, lists factors, enrolls TOTP if needed and presents QR/manual key; challengeAndVerify must succeed before resolving the login gate; cancelling rejects login |
| supabase-client.js | Creates the browser client using session storage, checks server session ownership, and provides monitor cleanup so intentional logout is not reported as expiry |
| admin.js | Administrator membership, attendance, pairing, product, sale and reporting views; composes split member names; converts product units; calculates alert thresholds; generates report files and logs export requests |
| admin-access.js | Checks current operator/admin permission in protected flows; a saved browser role hint is not sufficient |
| staff.js | Staff navigation, counter services, request review, product sales and own history; uses server-limited member lookup, UUID submission, request IDs and restricted catalog reads |
| customer.js | Member-only dashboard, personal settings, own attendance/QR and renewal requests; password updates call Auth rather than writing password columns |
| register.js | Applicant inputs, validation, account/application submission and recovery of supported saved registration state |
| reset-password.js | Handles the password recovery session and password update; it is not permission to bypass MFA |
| attendance-phone.js | Separate operator Auth client, phone identity/model, pairing credentials, camera transitions and attendance request retry; admin operators also complete MFA |
| staff-accounts.js | Administrator creates staff and controls active status; directory search is local filtering of the returned directory; labeled details show missing values explicitly |
| activity-logs.js | Server-filtered/paginated read-only logs; readable action labels stay separate from expandable details; untrusted strings are escaped before HTML output |
| ui-improvements.js | Shared password rules and visibility buttons, product pricing/photo utilities and accessible image viewer; MutationObserver handles dynamic forms |
| signature.js | Initializes and handles signature canvas interactions |
| theme.js | Theme selection and presentation state |
| button-feedback.js | Loading/disabled feedback prevents accidental repeated user actions; business duplicate prevention also exists on the server |
| server.js | Development GET/HEAD static serving with path/content handling; no gym transaction processing |

Important code patterns: `async/await` orders dependent work; `try/catch/finally` reports failures and restores controls; `textContent` or escaping avoids interpreting user data as markup; `required`, patterns and JavaScript improve form feedback; server checks remain necessary because a client can be modified. Never use `localStorage` as evidence of authorization.

## 7. Database explanation

The documented deployed schema baseline has twelve public and six private application tables. `auth.users` is a managed reference, not another public application table. Migration 20261110000006 has been applied and adds three private tables, bringing the documented migration target to 21 application-owned tables (12 public, 9 private), 224 fields and 33 declared foreign keys. This is a source/migration count, not live catalog introspection; the current Chapter 3 Word tables and diagrams still cover the earlier 18-table baseline and need a separate paper update.

| Table | Purpose / scenario |
|---|---|
| profiles | Application account identity, role, active state and supported contact attributes |
| members | Approved member and current membership information |
| membership_applications | Pending/reviewed online registration and renewal submissions |
| attendance | Visits, check-in/out timestamps and responsible operators |
| membership_history | Historical membership changes and prior/new plan/date/payment context |
| products | Active catalog, product form/type, stock and unit configuration |
| sales | Transaction header, total, customer context, operator and internal reference |
| sale_items | Itemized product, quantity, unit, price and line-total snapshots |
| activity_logs | Event metadata and changed-field names; no full password/token payloads |
| mobile_attendance_pairing_policy | Pairing capacity and supported pairing/password-removal policy |
| mobile_attendance_scan_sessions | Setup/pairing connection records and expiry/device binding |
| mobile_attendance_scan_events | Retained scan-event storage; do not claim an active event-review screen absent from current code |
| private.attendance_scan_requests | Attendance request retry/deduplication support |
| private.admin_login_attempts | Hashed login throttling buckets and attempt windows |
| private.account_sessions | Active session ownership, distinguished by dashboard versus scanner scope |

Primary keys identify rows, foreign keys enforce declared references, unique rules prevent duplicate identifiers, and nullability states whether a value may be absent. Do not draw a physical foreign key merely because a column name looks related. The current Chapter 3 manuscript dictionary covers 201 application/supporting fields and 27 declared foreign keys across twelve public and six private tables. Five fields have individual uniqueness rules; the approval pair is unique as a composite constraint. These manuscript counts reconcile the supplied export with migrations through 20261110000004, rather than a fresh live-schema introspection. The additional 23 fields and six foreign keys from the now-deployed member-device migration are tracked separately and have not yet been inserted into the Word chapter; update the paper and diagrams to match the deployed schema.

## 8. Inventory units and alerts

Stock entry unit and selling unit may differ: pounds of powder can be stored while sales are calculated in grams. One pound is 453.59237 g. Conversion occurs before availability/deduction/threshold comparison. An item, piece and box are discrete units; do not infer how many tablets a box contains without a defined packaging conversion.

| Policy class | Initial low-stock trigger, inclusive |
|---|---|
| Protein powder | 1,000 g |
| Creatine/pre-workout/amino-acid/vitamin powders | 250 g |
| Other powder | 500 g |
| Liquids/drinks | 1,000 ml |
| Capsules/tablets sold as pieces | 30 pieces |
| Boxed supplements | 4 boxes |
| Other individually sold supplements | 10 items |
| Merchandise | 4 items per product/size |

These application-code defaults are alerts, not predicted reorder quantities or a new threshold database column. Appropriate business reorder points depend on demand, replenishment lead time and safety stock. Zero stock receives a separate unavailable/out-of-stock presentation.

## 9. Security: how to explain it accurately

Authentication establishes identity; authorization determines allowed actions. AAL1 is password-level assurance; a verified second factor raises the session to AAL2. The own-account MFA bootstrap returns only whether an active administrator must verify. Under the subsequent approval migration, an AAL1 administrator needs an explicit, unexpired grant bound to that exact Auth session and intended activation scope; otherwise activation and protected Data API access remain blocked. An AAL2 administrator continues to use the authenticator route. The session/RLS guard also rejects direct table reads before AAL2. Edge Functions that read the caller's protected profile pass through these checks before privileged operations.

First enrollment is a controlled rollout task: a valid password alone cannot distinguish the real owner from an attacker before any factor has been enrolled. The real administrator must enroll on a trusted device during deployment. Thereafter, knowing the password does not supply the authenticator code. A password reset does not automatically remove the existing factor.

The setup QR/manual secret is sensitive, shown only in a temporary enrollment dialog. Do not put it in screenshots, activity logs, the paper, slides or source control. Supabase manages factor secrets; no custom public secret table is added. Existing member password minimum is eight characters; staff creation minimum is twelve, with implemented character requirements. MFA does not silently change those rules.

Current-device approval is implemented in a separate migration and module. Subsequent user-supplied CLI output confirms 20261110000003 applied successfully to the linked database; matching web deployment and the physical two-device flow remain unverified. A new password-authenticated administrator session can request approval from an active verified administrator session of the same account. The dashboard is preferred as approver; a verified active scanner session is eligible when no dashboard is available. No SMS is used. The old website polls every five seconds and the requesting website polls every three seconds. Requests expire after two minutes. A successful approval permits that requesting session for up to eight hours, subject to Auth expiry, active account and application session ownership; this is not a remembered-device token. Approval does not rewrite the Auth JWT to claim AAL2. The new session must still activate its approved dashboard/scanner scope before replacing that scope. Denial, cancellation, expiry and network uncertainty never grant access. If no approver is available, or the user chooses the explicit fallback, the authenticator flow remains required. TOTP enrollment/challenge outcomes remain available through configured Supabase Auth audit facilities; the custom activity viewer does not currently mirror every MFA challenge outcome.

Recovery requires the trusted project owner to verify identity outside the application, investigate possible compromise, use Supabase's supported administrative MFA-factor reset process and arrange supervised re-enrollment. There is no in-app password-only bypass, no automatic approval because an old device is offline, and no custom recovery-code feature in this increment.

## 10. Failure scenarios and defense answers

| Question / failure | Accurate answer |
|---|---|
| Internet is unavailable | Display/service operations can fail; cached scanner shell does not prove offline attendance persistence |
| Camera fails | Check HTTPS/permissions/hardware contention; staff can use limited name/Gmail attendance lookup |
| Two people share a name | Staff select the matched record with email/status context; the submitted identifier is unique |
| Scan is retried after uncertain response | Reuse request ID; server deduplication protects against a second state change |
| Member forgets to check out | Old visit becomes Incomplete without a fictional exit timestamp |
| Another device signs in | Existing scope ownership is replaced only after the login gates; monitor detects displaced sessions |
| Admin password is stolen | New access requires an existing verified session to approve or the enrolled TOTP; approving an unfamiliar request would defeat this protection |
| Authenticator phone is lost | Trusted project-owner recovery, factor reset and supervised enrollment; see the setup guide |
| App icon is deleted | Reopen direct scanner URL and install; pairing reuse depends on saved browser data and expiry |
| Pairing exists but saved token is lost | Administrator ends the stale pairing and issues a fresh QR; don't silently bypass device binding |
| Product measured in pounds | Convert to base units; do not use the numerical pound quantity as if it were grams |
| Staff need to fix personal member details | Member self-service handles permitted personal changes; staff counter lookup does not grant profile editing |
| Why not online payment? | Existing scope records payments made at the gym; no payment-gateway integration is claimed |
| Are all clicks logged? | Operational/security events are logged as implemented; routine searches/page views are not comprehensive audit events |
| Did the PDF reach the user? | Export request is logged, but browser save completion cannot be confirmed by the current code |
| Have users evaluated usability? | Report only actual collected evaluation; source tests and screenshots are not stakeholder satisfaction results |
| Does Ready on Vercel prove everything works? | It proves deployment status only; database migrations, functions, settings and end-to-end flows need separate verification |

## 11. Testing and presentation evidence

Use the saved November 8 regression report only with its date and stated scope. Recent focused checks cover inventory conversions, workflow confirmations/search, action-log rendering/filtering/escaping, login rejection/throttling, database audit permissions, logout races and admin MFA. The MFA database fixture verifies AAL1 denial of table reads and activation, protected-request rejection, narrow bootstrap, AAL2 access, staff continuity and migration rerun. Browser MFA tests simulate enrollment, cancellation and verification; they do not certify a physical authenticator or hosted Auth configuration.

Before defense: deploy in the documented order; test an actual administrator TOTP setup/login and scanner login; verify staff/member login; capture current screenshots with sensitive setup data concealed; check Word pagination; update presentation images; record what was actually tested. Do not call planned trials completed results.

## 12. How the diagrams relate

Context: one system boundary and external actors, no internal tables. DFD: nine functions and named flows to individual stores; simplified labels are expanded by the narrative. Use case: actor participation, not identical rights. Schema relationship descriptions and data dictionary: stored entities, declared relationships, exact column types/lengths/keys and field meaning; these are not a permissions chart. Gantt: planned schedule unless actual completion evidence is recorded. Agile: iterative planning, building, testing and revision; don't claim a framework or sprint schedule not documented.

## 13. Current revision checklist

- Admin MFA source and isolated tests are complete. The user supplied successful linked database push output on November 10 confirming application of migrations 20261108000012, 20261110000001 and 20261110000002. Auth settings, authentication-function/web deployment and physical enrollment/login remain separately unverified.
- Read-only linked migration check on November 10 confirmed 20261108000012, 20261110000001 and 20261110000002 were not applied remotely. A client calling the missing MFA bootstrap fails closed; its error now explains incomplete setup instead of suggesting refresh. The initial migration check did not alter the database. The later user-supplied push output reports all three migrations applied and Finished supabase db push. This establishes reported migration completion, not an end-to-end MFA test.
- New `admin_mfa_required`, private MFA checks and session/pre-request integrations; no new application table.
- Login and phone scanner call MFA before activation; CSS/dialog and service-worker shell updated.
- Security-event deployment prerequisites from the previous increment remain applicable.
- Latest local trust increment: migration 20261110000004_admin_trusted_device.sql adds two private supporting tables and a trusted-device snapshot column on approval requests. It adds the admin-device-trust Edge Function; this function must deploy with the migration and matching website. See Trusted Administrator Device Guide.md.
- Member-device approval deployment: migration 20261110000006_member_device_approval.sql adds three private tables (23 fields and six declared foreign keys), server-side member session activation enforcement, and approval RPCs. The `member-device-trust` and `member-password-login` Edge Functions and Vercel client are deployed. Safe unauthenticated endpoint probes pass; real member login and browser approval remain to be tested. Follow `Member Device Approval Guide.md` for acceptance steps.
- Existing project title and nine functions retained.
- Latest local increment: private.admin_login_approvals and request/list/decision/cancel RPCs implement in-website approval. The user supplied successful linked push output for 20261110000003_admin_device_approval.sql. Matching client deployment and two-device approval/denial tests still require confirmation. See Device Approval Schema Supplement.md and the approval deployment section of the guide.
- Old Word prototype captures remain historical until refreshed. Chapter MFA addendum records the revision; no revised screenshot is fabricated.
- Repository AGENTS.md requires both this file and presentation/speaker notes to be maintained for future material changes.

## Sources and supporting files

- Local source, migrations and isolated tests are the primary evidence for implementation.
- Chapter 1, Chapter 3 and their Review Notes/Evidence establish the reviewed paper baseline.
- [Supabase TOTP MFA](https://supabase.com/docs/guides/auth/auth-mfa/totp): enrollment/challenge integration.
- [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa): assurance and enforcement.
- [Supabase CLI configuration](https://supabase.com/docs/guides/local-development/cli/config): local TOTP settings; hosted settings are separate.
- [Supabase Auth audit logs](https://supabase.com/docs/guides/auth/audit-logs): Auth-event storage/configuration.

These technical links support implementation explanations; they do not replace the verified scholarly related literature in Chapter 2.

### MFA troubleshooting follow-up

A user reported rejection after entering a current authenticator code. The prior browser catch used the same incorrect-code message for all Auth and post-verification session errors, so the screenshot did not establish the cause. Local UI now distinguishes documented Auth error codes from post-verification session confirmation failures, keeps access blocked, and displays only a safe error identifier. No token, code or setup key is logged/displayed as diagnostic data. Focused tests cover incorrect-code and session-error paths. The actual user failure remains unresolved until the new error category is observed; no factor was reset and no bypass was introduced. Use the IronGrind account entry, not the separate Supabase dashboard account authenticator.

## Trusted-browser implementation details

The server stores only a public EC P-256 key. A random, expiring challenge is bound to an Auth session and its requested scope. The Edge Function validates the JWT with Auth, verifies the ECDSA signature using Web Crypto, and checks a recent TOTP authentication-method timestamp for new registration. Direct client access to service-only completion RPCs is revoked. First registration, renewal and transfer require fresh MFA; current trust reuse only needs password authentication and valid key proof. The completion transaction takes the per-account session lock, verifies the current approval when a recently active trusted session exists, swaps the trusted row, revokes both old device scopes and activates the new scope atomically. A stale or failed completion rolls back rather than removing the old device. No private key, code or signature is written into activity logs. IndexedDB CryptoKeys are non-extractable, but this is not protection against all same-origin script compromise; normal XSS defenses and device access controls remain necessary. Private browsing, clearing site data, changing browser/origin or trust expiry can require verification again.

Chapters 1 and 3 describe the trusted-administrator-browser policy. The Chapter 3 manuscript includes the 201-field dictionary, User Login security-store view (Figure 3f), and administrator-security schema supplement (Figure 5d). The simplified public-schema overview ERD remains omitted; physical relationships appear in Figures 5a-c, with the new administrator-security relationships in Figure 5d. The DFD uses five continuation panels (Figures 3a-e) for nine functions, with Figure 3f isolating the new administrator stores. A standalone complete Level 1 SVG is provided separately. The deployed member-device approval schema remains outside the current Word chapter baseline; update that paper separately to include the three new tables and current login/approval flows. Context and UML explanations retain the three roles and nine main functions. Source-based counts are separate from actual browser acceptance results. Linked CLI output confirms the member migration and Edge Function deployments; safe endpoint probes do not establish successful login or approval.

### Trusted-device deployment checkpoint

The user supplied successful linked migration output for 20261110000004 and successful hosted deployment of admin-device-trust to project nttsrdassmzvtaamyogi. The Docker warning did not prevent the reported hosted function deployment. This records user-provided deployment evidence, not an independent live sign-in result. First registration, post-logout trusted reuse and two-device approval/transfer remain to be tested against the matching website revision.

### Paper synchronization and defense explanation

The current paper replaces the earlier MFA-only statement that approval was unimplemented and needed no new tables. Explain the scenario in order: password, browser proof, approval if an eligible trusted session is active, fresh TOTP for registration/replacement, then atomic authorization and revocation of old scopes. Returning to the current trusted browser reuses its key without requesting TOTP on every login. Normal logout retains trust; explicit forget-device logout revokes it. A two-minute heartbeat is an application eligibility rule, not physical online detection. Browser trust is distinct from phone-camera pairing.

Figure 3f keeps D15 approval requests, D16 trusted keys and D17 challenged/authorized sessions separate. It supplements Process 1.0, not a tenth main function. Figure 5d uses repeated managed Auth reference cards to avoid crossing lines; the repetition does not create extra tables. Candidate/snapshot UUIDs have no invented foreign keys. The four-column dictionary describes all 201 fields, nullability, defaults where declared, 27 FK targets/actions and the approval composite unique pair. The simplified public-schema overview is excluded from the submitted paper.

Validation: manuscript package/relationship checks, exact field/type/key/nullability comparison, 27 FK definitions and approval composite uniqueness; prototype consistency remains checked separately. The two new figure PNGs were visually inspected. Full Word pagination and actual-device authentication are separate pending reviews. Original manuscripts are retained under Review Backups/security-paper-20261110-124307.

### Scanner interface refresh

The phone attendance scanner page now follows the app's dark navy and Iron Grind red visual language, with a branded header, clearer scan heading, updated status panel and controls, and visible keyboard focus. This presentation-only change is in `attendance-phone.html`; authentication, pairing, camera, scan submission and offline behavior are unchanged. Review was limited to source inspection; no device/browser validation was performed. The revision is local and has not been deployed. Refresh scanner screenshots after browser review.

### Trusted browser display and logout wording

The administrator account menu now displays the registered browser's browser/platform name and clarifies that ordinary logout preserves trust while “Forget this trusted browser” revokes trust and signs out. The label is derived from the user-agent string already stored at device registration. A new authenticated, admin/session-scoped read function exposes only the label and registration/expiry metadata; the private key is never exposed. User-supplied terminal output confirms migration `20261110000005_admin_trusted_device_label.sql` was applied successfully to the linked database after dry-run showed it was the only pending migration. The matching dashboard UI is local and has not been deployed or browser-validated. A missing/expired registration is displayed as no trusted browser.

### Store unlock layout correction

A screenshot showed the Store password field overlapping its submit button. The shared password-visibility helper wraps password inputs, while the store form's flex styling expected a direct input child; the wrapper's intrinsic width caused overflow. The admin stylesheet now constrains that wrapper and preserves the submit button width. Source/CSS inspection and `git diff --check` passed; no browser/device visual check was performed. The stylesheet cache version was bumped. This frontend fix is local and deployment remains pending.

### Activity Logs role filter

The Activity Logs panel now includes an Account type selector for all users, members, staff and administrators. It filters the existing `activity_logs.actor_role` column alongside the account-name, category, action and date filters, preserving server-side pagination and the existing RLS-protected query. Dropdown/date changes apply immediately; account-name typing is debounced. The redundant Apply filters button was removed; Reset filters remains. No schema change is needed. Source inspection and `git diff --check` passed; browser validation and website deployment remain pending.

### Superseded: interim Chapter 3 DFD restoration

The interim restoration used a backup made immediately before the simplified DFD overview was removed. The user clarified that the requested baseline was the earlier Chapter 3 layout from before the simplified ERD was introduced. That interim restoration was superseded by the correction documented below. The simplified public-schema overview remains omitted; the complete Level 1 SVG is retained separately. No application, schema, database or deployment change resulted from the interim paper edit.

### Superseded: interim Chapter 3 DFD readability revision

The detailed Level 1 DFD contains all nine numbered processes in separate horizontal lanes, with actors at left, processes in the middle and named stores at right. Repeated entity/store boxes denote the same roles and tables; flows remain within their process lane. Figure 3a is this complete DFD, following the simplified overview in Figure 3; Figure 3b isolates administrator security stores D15-D17. A separate vector copy is `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. Structural checks confirm Chapter 3's 23 tables, 18 dictionary tables, 201 fields, 27 declared foreign keys and five individually unique fields remain unchanged. No schema/table content changed. Final desktop Word pagination review and thesis review remain pending; no deployment or database behavior changed.


### Omit the simplified public-schema ERD from the paper

At the user's request, the selected-field public-schema overview ERD and its figure-specific explanation were removed from Chapter 3 because the simplified ERD should not appear in the paper. At that stage the administrator security-schema supplement was Figure 5. The later layout correction renumbered it Figure 5d and restored the original Figure 5a-c physical relationship panels. The underlying schema and the 23 Word tables/201 dictionary fields were not changed by either figure edit.

### Chapter 3 original figure layout restored with current system content

The user clarified that the intended layout was the earlier Chapter 3 format from before the simplified ERD was introduced, and approved restoring that layout while retaining the current tables. The interim overview/full-page arrangement was replaced with the original five-panel Gane-Sarson DFD sequence (Figures 3a-e) and three-panel physical relationship sequence (Figures 5a-c). Current administrator login-security details remain as Figure 3f and the administrator-security schema supplement is Figure 5d. The simplified public-schema overview ERD remains omitted. The complete nine-process DFD remains available as the separate SVG `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`.

The regenerated DFD panels include current D15-D17 login-approval stores, individually named report sources D2-D8, current mobile-scanner store names, and the documented reserved status of D12. Figures 5a-c cover the existing 15-table, 21-foreign-key relationship model; Figure 5d shows the three administrator-security tables and six additional references to managed Auth tables. Chapter 3 retains all 23 Word tables and all 201 dictionary fields covering 18 application-owned tables and 27 foreign keys. The diagram panels were visually inspected for line/text overlap, and the Chapter 3 structural verifier confirms the current table/field counts and figure references. Defense materials were synchronized. This is a documentation-only change; application/schema code and deployment state did not change. Final desktop Word pagination review remains pending.

### Scanner pairing across operator sign-in

User-supplied phone screenshots showed “Saved pairing found” before operator sign-in and “Phone not paired” afterward. The pairing token is held in browser storage scoped to the browser profile and site origin; it is not bound to the physical phone alone. The cause of the reported transition is not confirmed. The scanner now snapshots any locally saved pairing before password/MFA requests, uses that snapshot after sign-in, validates it with Supabase, and persists it again only after validation succeeds. Invalid/expired pairings still clear and require a new pairing. The scanner script URL and service-worker shell cache version were bumped. Source inspection and `git diff --check` are local checks; actual phone/PWA validation and website deployment remain pending.

### Dashboard light-theme coverage

The shared dashboard stylesheet now applies a final light palette to nested cards, dialogs, filters, form controls, tables, scanner/phone-pairing panels, inventory and sales surfaces that had retained dark backgrounds or dark color-scheme controls. Staff-specific overrides are placed at the end of `assets/css/staff.css`, which loads after the shared stylesheet and previously overrode some shared light-mode values. The dashboard theme rules affect the admin, member and staff workspaces; shared stylesheet cache versions were bumped on pages that load these assets. Existing success/error/status colors are retained with light-mode-readable variants. Source review and whitespace validation are local checks only; no browser/device visual review or deployment has been completed. Follow-up validation should inspect each workspace, dialogs, filters, and narrow/mobile layouts in both themes.

### Login password-recovery dialog in Light Mode

A user screenshot showed that the login page correctly switched to Light Mode while its Forgot your password dialog remained dark. The dialog is rendered under `body.login-body`, outside the dashboard-only theme scope. `assets/css/style.css` now provides a login-specific light palette for the dialog, email field, labels, supporting copy, Cancel button and backdrop. The shared stylesheet cache version was bumped on pages that load it. This is a local presentation fix; source inspection and whitespace validation do not establish browser visual acceptance or deployment. Verify the dialog in both themes and test its mobile layout before release.

### Light Mode coverage for linked authentication pages

A follow-up screenshot showed membership registration remained dark after the user selected Light Mode. `register.html` had no theme bootstrap and hard-coded dark inline surfaces; it now reads the saved preference, offers a theme toggle, and uses light overrides for registration sections, plan choices, inputs, contact/footer text and the application modal. `reset-password.html` now bootstraps the same saved preference and has a theme toggle; it uses the existing light login palette for its form and recovery states. The login forgot-password dialog and backdrop were also included in the preceding pass. The shared stylesheet cache version was refreshed across pages. This remains local presentation work; source inspection and `git diff --check` do not confirm visual behavior. Browser review of login, registration, reset-link success/error states, form controls and modal layouts at desktop/mobile widths remains pending; no deployment is claimed.

### Registration phone country prefix in Light Mode

The registration form's fixed `+63` spans retained the dark default field background after the surrounding form switched to Light Mode. A registration-scoped rule now gives the prefix a light gray fill, matching border and readable dark text; the dark theme remains unchanged. Stylesheet cache versions were refreshed. Validation was limited to source review and `git diff --check`; no browser review or deployment has occurred.

### Staff membership-term validation and regression coverage

The staff member-creation Edge Function now validates membership terms on the server: the submitted plan must be one of Monthly, Half Month or Walk-in, the price must match the configured amount, the start date must be the current Philippine business date, and the expiry date must match the configured term. It also rejects malformed or impossible date-only values before creating the account. This closes the client-trust gap where an authenticated staff caller could submit a standard plan with a forged price or term. The validation is isolated in `supabase/functions/admin-create-member/validation.js` and covered by focused Node tests. The Activity Logs UI test fixture now supplies the `querySelectorAll` method used by the page script. A member-device approval SQL regression fixture covers initial enrollment, approval and transfer, session revocation, denial/expiry preservation, non-member handling and service-only access. Focused Node tests passed (6/6), JavaScript syntax checks passed, and `git diff --check` passed. The full regression suite was rerun with the cached PGlite runtime and passed 49 checks, including the member-device SQL fixture. Migration 06 and the required Edge Functions are deployed. Live endpoint probes succeeded at the expected unauthenticated response level; account-level browser acceptance remains pending.

### PowerPoint open error and native rebuild

A user screenshot showed PowerPoint reporting a problem with `Capstone Presentation.pptx`. The package's XML and relationship targets passed the repository checker, but PowerPoint's own open operation rejected the hand-built Open XML package. The deck was rebuilt from the current Markdown slide source through native PowerPoint automation, then reopened and checked for all 18 slides and 18 speaker-note sections before replacing the failing file. `build-defense-materials.mjs` now delegates editable deck creation to `build-defense-presentation.ps1`, preventing the former package writer from being used again. The repository verifier passes with 109 parseable XML/relationship parts and no missing targets. This confirms package structure and PowerPoint reopen, not visual slide review. The rebuilt deck and generator change are local; no presentation content has been deployed or externally published.


### Complete DFD SVG: exact database table names

Corrected the standalone `03-dfd-complete-gane-sarson.svg` and its `build-readable-dfd.mjs` generator to use exact schema-qualified table names from `schema-visualizer.json`, plus managed `auth.users`. Removed generic store aliases, duplicate administrator security stores and the reserved-store note. Retained real private supporting tables supported by the documented pgAdmin baseline and migrations through 20261110000004; member-device tables are excluded from this paper-baseline SVG. Repeated identifiers denote the same physical table. The generator rejects unmapped tables. Also separated the header from the first panel and corrected actor result arrow direction. Validation: regenerated SVG, XML parse and store inventory checks. This is a local documentation correction, not fresh live-schema verification; no database, application, Word manuscript or deployment change.

## Chapter 3 format alignment — November 10, 2026

Updated Chapter 3.docx to follow the user-supplied chapter structure and five-column data-dictionary format: Field Name, Field Type, Length / Precision / Scale, Key, and Description and Validation Details. Restored the Entity Relationship Diagram heading. Separated declared varchar lengths and numeric precision/scale from base types; moved nullability, referential actions, composite constraints and other validation details into the descriptions without discarding them. Existing methodology, requirements, diagrams, forms, prototype figures, Gantt schedule, current security supplements and verified-versus-pending distinctions are retained. The duplicate Gantt ending in the pasted sample was not introduced.

Affected materials: Chapter 3 manuscript, chapter verifier, presentation slide content and speaker notes, and these study notes. Validation checks all 23 tables, 201 fields, 27 foreign keys, five individually unique fields, composite constraints and figure relationships against the repository schema model. This is a documentation-only change; no application, database or deployment action is involved. Final visual pagination review in desktop Word remains pending. Backup: Documentations/Review Backups/sample-format-20261110-203446/Chapter 3.docx.


### Complete DFD label clarification

The user clarified that the visible store labels must be table names alone, for example `users`, `profiles` and `account_sessions`, without schema prefixes. Updated the standalone complete DFD generator and SVG accordingly. Schema-qualified names remain internal to validation against the documented baseline. All nine processes and existing table mappings are retained. Validation: regeneration and SVG XML/store-label checks. Documentation-only local correction; no database or deployment change.

### Member settings dialog stability and responsive layout — November 10, 2026

The member profile/settings window changed its apparent position when sections with different content heights were selected, and its width could exceed a narrow viewport. The dialog now keeps a steady responsive height and width; section content scrolls within the dialog, and section changes reset only that internal scroll position. The native modal continues to keep the dashboard behind it inactive. Tablet and phone layouts stack the section navigation and reduce form columns to prevent horizontal clipping. A stylesheet cache version was refreshed on `customer.html`.

Affected modules: `customer.html`, `assets/css/style.css`, and `assets/js/customer.js`. Validation: source-level review and `git diff --check`; no browser/device interaction review was performed. This is a local UI change; no Vercel deployment is claimed. Database schema and Chapter 3 tables are unchanged.

### Registration duplicate-email guidance — November 10, 2026

The availability RPC intentionally rejects an address already present in `auth.users` or `public.profiles`; `handle_new_auth_user` creates a profile row when an Auth user is created. Thus, an address that is new to its owner can still match an unfinished earlier signup in this project. Updated field and submit feedback to suggest sign-in/password recovery or staff review of a pending record. The underlying availability checks and account data were not changed. Validation: source review and `git diff --check`; the linked Supabase records were not inspected, and no database deletion, schema change or Vercel deployment was performed.
