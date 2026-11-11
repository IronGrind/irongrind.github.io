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

### Atomic member signup and recovery for accounts without an application — November 10, 2026

The previous client-first signup created the Supabase Auth user before the client inserted the membership application. If the insert failed or the confirmation callback lacked its local browser draft, Auth could retain a user/profile while staff/admin had no application to review. New signups now call `supabase/functions/member-registration`: it validates the supplied form and rate-limits by hashed email/IP, creates the Auth user through Supabase signup, then inserts one pending application. If that insert fails, it deletes the newly created Auth user so its profile is cascaded; cleanup failure is surfaced for staff action. The Auth signup sends the confirmation email, while the confirmation callback now reads the already-saved application rather than needing a new signup draft. The endpoint does not log password or application PII.

Existing Auth accounts with no application can still resume through password verification. That flow checks for an existing member or pending/approved application, activates the account session before the RLS-protected insert, and does not create duplicate applications. For an unconfirmed existing account, the form retains a password-free local draft and resends confirmation. A rejected application may be resubmitted. Script cache versions and duplicate-email guidance were updated.

Affected modules: `supabase/functions/member-registration/index.ts`, `supabase/config.toml`, `register.html`, `assets/js/register.js`, `assets/js/ui-improvements.js`, `Documentations/README.md`, and presentation/study-note sources. Validation: manual code-path/source review and `git diff --check`; no automated tests, live Auth/email execution, database-state inspection or browser acceptance were performed. No database schema migration was required. The Edge Function and Vercel client are local and must both be deployed before production use; Supabase must allow `https://irongrind-github-io.vercel.app/register.html?completeApplication=1`. This cannot retroactively remove the already-existing account in the screenshot; its application should be completed with the existing-account path, or staff should verify and clean it manually. No live account/application was altered.

### Admin phone-pairing password prompt layout — November 10, 2026

A screenshot showed the admin phone-pairing password input rendered at half width with a separate browser focus outline after the shared password-visibility enhancement wrapped the input in a new element. The QR-camera modal styles now size that wrapper and its input to the full form width, reserve room for the reveal control, use a single focus ring, and align the action buttons. Light Mode selectors cover the wrapped input, and `admin.html` uses a refreshed stylesheet cache key. Validation: source review and `git diff --check`; no browser screenshot or device review was performed. Local-only UI change; no Vercel deployment is claimed.

## Member-security schema and manuscript alignment — November 10, 2026

Migration `20261110000006_member_device_approval.sql` adds `private.member_trusted_devices` (6 fields), `private.member_device_sessions` (7), and `private.member_device_approvals` (10), with six Auth foreign keys. The documented model now comprises 21 application-owned tables, 224 fields and 33 foreign keys: 12 public tables (162 fields, 18 FKs) and 9 private tables (62 fields, 15 FKs). Managed Auth tables are references, not application-owned tables. The user-supplied context export contains only the 12 public tables; it is not evidence that private tables were removed.

Chapter 1 adds the member browser-approval scope and its acceptance boundary. Chapter 2 adds a design connection in the existing synthesis without changing the literature or references. Chapter 3 adds Figure 5e and Tables 24–26 using existing paragraph, figure and five-column dictionary templates, and updates affected count explanations. Existing Figures 5a–d and dictionary tables are retained. The editable member ERD is `Chapter 3 Diagrams/05b-member-security-schema.drawio`, with matching SVG and PNG. Affected modules are manuscript, ERD model, dictionary, and defense slide text/notes; no application or SQL migration was changed by this documentation revision.

Validation: chapter package, image links, dictionary types/nullability, 33 FK targets/actions, six individual unique fields and original formatting checks passed. Existing source references remain unchanged. The repository Member Device Approval Guide records migration/function/client deployment; controlled member browser acceptance remains pending. This revision performs no deployment or fresh live database introspection. Desktop Word pagination remains pending.

## Current system readiness review — November 10, 2026

The current rerun passed 49 regression check groups (including 52 browser unit tests), and eight additional isolated sales/inventory scenarios passed. All eight backend function entrypoints type-checked; the administrator login-handler test passed. The linked project has all 20 local migration versions through 20261110000006, error-level database lint returned no errors, and eight expected Edge Functions are ACTIVE. All 30 checked hosted files match normalized local content. Fourteen unauthenticated desktop/mobile browser navigations produced no JS exceptions or horizontal overflow; protected pages redirected to login. Eleven anonymous application-table reads returned 401. Registration availability and anonymous session-denial smoke checks passed.

This supports tested behaviors, not an issue-free whole-system claim. Observed minor issues: a favicon 404, and missing-Authorization requests returning 500 for admin-create-member or 503 for verify-store-password because their code combines missing authentication with configuration checks. Invalid bearer tokens return 401. No signed-in failure or missing store secret was established by those responses. Registration/email confirmation, password recovery delivery, administrator/member browser transfers, physical camera/PWA use, full role-specific transactions, report exports, cross-member isolation and load evaluation still require controlled hosted acceptance.

Affected modules are verification scripts, isolated sales coverage, readiness evidence and defense notes/slide text. No application/schema fix or deployment was performed; the Word chapters and editable PowerPoint were not modified by this review. See `Documentations/Review Notes/System Readiness Review.md` for the evidence and remaining acceptance matrix. Preserve the distinction between deployed components, tested behavior and unverified end-to-end outcomes when finalizing the paper.

## Registration application-save permissions repaired — November 10, 2026

A reported signup created its Auth user but failed to save the application, then followed the existing account-cleanup error path. Live metadata confirmed service_role lacked both INSERT and SELECT on membership_applications. Its BYPASSRLS attribute did not supply those table grants. The invoker name-validation trigger also needed a private helper inaccessible to the inserting roles. The new regression reproduced both errors independently.

Migration 20261110000007_restore_registration_application_access grants service-only SELECT/INSERT and makes the existing fixed-search-path, schema-qualified validation trigger SECURITY DEFINER. Name checks remain enforced; direct helper calls remain revoked. No browser grant, table, field or FK was added. This also repairs permitted profile/member writes that otherwise could fail when the name trigger tried its private helper.

Deployment: the linked dry run listed only migration 07 for nttsrdassmzvtaamyogi, and the normal terminal push applied it successfully without an interactive prompt from this CLI. A live synthetic service-role insert/readback succeeded and was rolled back with its log effects; post-checks confirmed no fixture remained, service INSERT/SELECT were present and anonymous INSERT stayed denied. Error-level linked DB lint returned no errors. The isolated regression verifies pending save, invalid-name rejection, own-account RLS, foreign-account denial, profile/member triggers, direct-helper isolation, narrow grants and migration rerun. The post-fix full suite passed 50 groups with zero failures; results are saved in Review Evidence/System Regression Results.json.

Affected modules: registration application grants, name-validation trigger execution, regression runner/tests, setup instructions and defense source notes. Existing client and function deployments use this repair immediately; no function/site redeployment was required. No real account or email was used for testing. Real signup and confirmation acceptance remains a form retry, separate from the verified database write. See Review Notes/Registration Application Save Fix.md. Earlier read-only readiness checks did not cover this successful write path and do not establish complete registration acceptance.

## Registration confirmation summary theme — November 10, 2026

The submitted-application dialog used a hardcoded #0d1219 summary background even when its surrounding modal was in Light Mode, leaving dark text on a dark panel. The summary now uses a dedicated registration-summary class with the existing Dark Mode colors and explicit Light Mode background, border, text, application-ID and pending-status colors. Rows wrap long identifiers and email values within narrow displays. This is presentation-only; registration persistence and approval states are unchanged.

Affected modules: assets/js/register.js, assets/css/style.css and register.html (CSS/JS cache-version refresh). Validation: JavaScript syntax passed; local headless Edge rendered the actual showSuccessModal with synthetic data in light/dark at desktop 1440x1000 and mobile 390x844, with no page or panel horizontal overflow. Screenshots and computed colors are saved under Review Evidence/Registration summary *.png and Registration Summary Theme Verification.json. The mobile Light Mode capture was visually reviewed. No form was submitted for these previews. Website deployment remains pending; no backend or database change is needed. Manuscript formatting and the editable PowerPoint were not changed.

## Complete DFD: specific actions and one connector per pair

The standalone complete Level 1 SVG now gives all nine processes specific action labels, such as Verify login and authorize access, Record sales and sale items, and Filter and view activity records. Each process/entity or process/store pair uses one connector. Two-way exchanges have arrowheads at both ends and separate destination-prefixed labels (To entity, To process, To store); one-way flows retain only their receiving arrowhead. This compact presentation preserves the separate input/output meanings and individual exact table names. Explain the two labels when presenting the diagram; a lower-level DFD may separate directional arrows if required by the adviser.

Affected files: build-readable-dfd.mjs and 03-dfd-complete-gane-sarson.svg. Validation: regenerated successfully; SVG XML parses with nine process panels and 68 pair connectors. This is a local documentation revision; Word figures and application/schema/deployment behavior are unchanged. Desktop visual/pagination and adviser notation review remain pending.

## DFD revision: Gane?Sarson with single-headed flows

Supersedes the double-headed connector presentation above. The standalone SVG now uses rectangular external entities, rounded numbered process compartments, open-ended identified stores, and a single-headed named data-flow arrow per pair. Specific action labels remain. Where the source has two-way exchange, this simplified view shows the initiating entity input or process-to-store write; read-only stores point toward the process. Reverse responses/reads for those two-way pairs are omitted explicitly, not represented by the single arrow. The SVG is therefore titled Simplified Level 1 DFD and carries this limitation; the source flow model retains both directions. A complete directional DFD would require separate arrows for both directions.

Affected modules: standalone SVG generator and output, defense text/notes. Validation: generator syntax and regeneration passed; XML verification found 68 connectors across nine panels, each with exactly one receiving arrowhead and no starting marker. No Word, application, schema or deployment change. Visual/adviser review remains pending.

## DFD reference styling and line clarity

The standalone simplified Gane?Sarson SVG now follows the supplied visual reference with pale-blue rectangular entities, pale-blue numbered process headers, white rounded process bodies and identified open-ended stores. Flow strokes are darker and thicker, arrowheads have an explicit size, and larger labels sit farther above the connector on white backgrounds. The existing separate horizontal lanes avoid crossings. The nine specific actions, exact table names, single-headed connector policy and explicit omission of reverse flows are retained. Affected modules: build-readable-dfd.mjs and standalone SVG; a first-panel style preview is under _Sources/dfd-style-preview. Validation: regeneration, JavaScript syntax and SVG XML parsing passed; a headless Edge screenshot was inspected for header, entity and connector appearance (viewport crop, not a complete page review). No Word, application, schema or deployment change.

## DFD shared layout and bent connector routing

The user clarified that the supplied example concerned line movement and shared-node arrangement. The standalone SVG now uses three shared entities on the left, nine compact numbered Gane?Sarson processes in the middle, and seventeen individually named shared stores on the right. Separate orthogonal routes connect ports; white crossing gaps distinguish crossings from junctions. Specific process actions, exact store names and one single-headed flow per pair remain. Reverse flows for two-way pairs remain omitted explicitly in this simplified view. This supersedes the previous repeated-node horizontal-panel presentation for this SVG.

Current generator: Documentations/Tools/build-dfd-reference-routing.mjs. Validation: regenerated nine processes, seventeen stores, three entities and 68 routed connectors; syntax and XML parsing passed. A full-layout headless Edge preview was visually inspected, then store ordering was aligned with operational areas. Dense shared routing benefits from zoom in the vector file; adviser review and Word figure replacement remain pending. No application, schema or deployment changes.

## DFD shared same-name flow lines

The reference-routing generator now groups flows only when their normalized names and receiving entity/process/store match. These flows use separate source branches joining one trunk and one receiving arrow, with a single common label. Filled dots mark genuine branch joins; white gaps still mark unrelated crossings. Different labels or destinations remain separate. This avoids implying that different records or recipients are interchangeable. Five shared groups reduce the 68 source-model connections shown in this simplified view to 60 connector groups; all 68 shown source connections remain represented. The existing omission of reverse flows is unchanged.

Affected modules: build-dfd-reference-routing.mjs, standalone complete-named SVG and defense text/notes. Validation: generation, JavaScript syntax and SVG XML parsing passed; five shared groups have branch counts 3, 2, 3, 3 and 2. No Word, application, schema or deployment change; full visual and adviser review remain pending.

## Complete single-sheet DFD with expanded routing

The adviser/panel requirement is a complete diagram on one sheet. The current standalone SVG retains all nine processes, three shared external entities and seventeen individually named stores from the documented DFD baseline. Both directions of each source-model exchange are restored: 108 source flows are represented in 98 connector groups, superseding the prior simplified 68-flow view. Same-name flows merge only when their receiving node matches; all arrowheads are single-headed and branch joins use dots. The 6600-by-5300 vector canvas provides wider distinct routing lanes, larger process rows, and spaced entity/store ports. Crossings remain unavoidable with shared nodes; white gaps distinguish them from branch joins.

Affected modules: build-dfd-reference-routing.mjs, standalone SVG, routing preview and defense source text/notes. Validation: generation checks directional coverage against every nonempty actor/store input/output in the source model; JavaScript syntax and SVG XML parsing passed. The entire layout was rendered in headless Edge and visually inspected. Use vector zoom or a large print sheet; fitting the entire drawing on a small page reduces label legibility. This is complete coverage of the documented DFD model, not a fresh live-schema review or a claim that the newer member-device stores are included. Word figure replacement, adviser review and final print-size review remain pending. No application, schema or deployment change.

## DFD crossing jumps and route congestion audit

The single-sheet Gane?Sarson generator now orders routing lanes by connection span, placing shorter connections near the processes. This reduces detected crossing events from 1,422 in the prior assignment to 1,172 (about 18 percent). Every remaining detected perpendicular crossing receives a geometric curved bridge jump. These are explicit SVG curves with a final overlay pass, rather than relying only on a white gap or a viewer setting. Filled branch dots continue to indicate real same-name shared-flow joins.

Validation: the geometric audit rejects unrelated collinear overlapping segments; the current result has zero such overlaps, 1,172 crossing events and 1,172 bridge jumps. Nine processes, three entities, seventeen documented stores, and all 108 source-model directional flows in 98 connector groups remain. Generation, syntax and XML parsing passed; a dense crossing detail was rendered in headless Edge and visually inspected, followed by a small bridge-tail continuity adjustment. Machine-readable results are saved in Chapter 3 Diagrams/_Sources/dfd-routing-audit.json. This audit covers connector geometry, not final label collision or panel acceptance. Large-format/zoom review and adviser approval remain pending. Affected modules: reference-routing generator, standalone SVG, preview/evidence and defense source text/notes. Word figures, application, schema and deployment behavior are unchanged.

## DFD equivalent-data consolidation with endpoint traceability

Reviewed equivalent data categories now share trunks for either a common receiver or a common source. Explicit contextual aliases consolidate activity event writes, sales transaction writes, sale-item writes, membership change events, role/active-status reads and role-specific login results. Other labels remain distinct. The source data and all original source/receiver pairs remain unchanged; the audit records each original name beside its displayed category. Shared role-result branches indicate the appropriate result for each role, not broadcasting one user session or expanding permissions. Source fan-out retains a receiving arrow on every destination branch; receiver fan-in retains one arrow at the common receiver.

All 108 documented directional source connections are represented in 86 connector groups, down from 98. Detected crossings/jumps fall from 1,172 to 1,006; unrelated collinear overlaps remain zero. All nine processes, seventeen baseline stores and three external entities remain on one sheet. Validation: successful regeneration, syntax, XML/group coverage checks, 108 endpoint/name audit entries and a browser-rendered detail inspected visually. The source/destination/original-name/display-name mapping is in _Sources/dfd-routing-audit.json. Full print/adviser review remains pending; no claim of panel acceptance. Affected files: reference-routing generator, standalone SVG, audit/preview and defense source materials. Word figures, application/schema and deployment state remain unchanged.

## DFD logical-category simplification

At the user?s request for a simpler complete drawing, displayed flows now use broader Level 1 data categories. Per-store reads and writes have distinct labels (for example Permitted member data versus Member and membership updates); each process has a role-scoped request/result category for external actors. Reads and writes remain separate directions, source and receiving nodes are retained, and individual stores are not combined. Branches show the original connections; the logical category is a parent description of the detailed payloads rather than a claim that all payloads are identical. Role-scoped actor branches retain the original permission boundaries; they do not imply every role may perform every operation in the category.

The standalone model now uses 52 connector groups instead of 86 (about 40 percent fewer), representing all 108 documented source connections. Crossings/jumps reduce from 1,006 to 763; the geometry audit still finds zero unrelated collinear overlaps. Nine processes, seventeen baseline stores and three entities remain on one sheet. Detailed original labels, source/destination IDs and displayed parent categories are preserved in _Sources/dfd-routing-audit.json. Validation: generation, JavaScript syntax, XML/group totals and 108-entry mapping checks passed; the full updated browser preview was visually inspected. Final label legibility at print size and adviser acceptance remain pending. Affected modules: reference-routing generator, standalone SVG, audit/preview and defense source notes. No Word figure replacement, application/schema change or deployment resulted.

## DFD trial: repeated references and local routing

The user authorized trying repeated store references beside the processes that use them. The current standalone SVG is now a single-sheet three-by-three arrangement of all nine processes, with nearby repeated actor/store references and short local routes. The same D-number and exact table name identify one logical store; actor names likewise identify the same entity across occurrences. The drawing explicitly explains repeated references and process reading order. Detailed original flow labels are restored rather than relying on broad composite categories. Single-headed arrows preserve each direction, and curved jumps distinguish local crossings.

Current generator: build-dfd-local-references.mjs. The preceding 52-group shared-routing SVG is preserved as _Sources/03-dfd-shared-routing-comparison.svg. Validation: nine processes, seventeen unique stores, three unique entities and 108 flows; independent comparison with the prior routing audit confirms the exact multiset of all original source/destination/payload triples. Local geometry reports 74 crossings and 74 jumps, versus 763 in the previous layout, with zero unrelated collinear overlaps. Generation, syntax, XML parsing and a browser-rendered first-process detail were checked. Print review: at SVG natural scale (96 CSS px/in), the 9200 × 3100 canvas is approximately 95.8 × 32.3 inches and 16 px flow labels render at 12 pt; fitting the complete sheet to ordinary paper would make labels too small. Use the SVG as a large-format vector print at or near natural scale, or review its supplied whole-sheet preview with process-detail views. No physical print was produced. Adviser review of repeated-reference notation remains pending.

Affected modules: local-reference generator, standalone SVG, comparison copy, local audit/preview and defense text/notes. This is a documentation layout trial using the existing documented baseline; it does not add newer live-schema stores or change Word figures, application/schema behavior or deployment.
## End-to-end manual test checklist export

On 2026-11-10, the complete start-to-end manual test checklist provided in the conversation handoff was exported as `Documentations/Testing/Iron Grind End-to-End Manual Testing Checklist - Final.docx`. The Word document contains 239 cases in 18 sections, from login, theme switching, password recovery and registration through admin/staff/member workflows, cross-system checks and end-to-end scenarios. Each case has fields for actual result, status and evidence. All cases are marked Not tested; this export records planned checks and does not claim execution or passing results.

Affected modules: testing documentation only; no application, schema, security implementation or deployment behavior changed. Validation: the export generator read all 18 supplied sections and emitted 239 checklist cases. Deployment status: not applicable. The checklist is ready for manual execution; test results remain pending.

## Public-only main ERD

At the user's request, the main editable ERD is now focused on the 12 public tables and their 18 declared foreign-key relationships. The original public layout and line spacing were restored; the compact private-table panel was removed from the main view. The nine private application tables remain documented in the Chapter 3 physical relationship panels and administrator/member security supplements. The full schema materials cover 21 application-owned tables, 224 fields and 33 foreign keys. The all-in-one 21-table draft is preserved under `_Archive/Previous ERD Versions/05-gym-erd-complete-with-private.svg` and `.drawio`; the former public-only source is retained as the regeneration base.

Source: user-supplied Supabase public-schema context and full pgAdmin schema export, reconciled with checked-in migrations through `20261110000006`; this is not direct live database introspection. Affected files: public ERD SVG/Draw.io source, preview, generator, CURRENT ERD guide and defense materials. Validation: public source restores 12 tables and 18 declared relationships; private schema figures remain available separately. SVG/Draw.io XML parsing and git whitespace checks pass. Deployment status: documentation only; no application behavior, schema or deployment changed. Chapter 3 Word figures were not replaced.
### Public-table-only DFD revision � November 11, 2026

The DFD store symbols now show only public application tables. Auth account storage, private attendance request records, private account sessions, and administrator trusted-device/approval/session tables were removed from the DFD store set; the nine processes and their documented operations remain, including login as Process 1.0. This makes the data-store layer match the requested public-table scope without implying that omitted security data is absent from the implementation. The Word Chapter 3 panels were refreshed, the Figure 3f private-store DFD supplement was removed, and its editable/vector/source assets were archived. The physical security ERD remains separate and continues to document private schema structures. Updated the standalone SVG, panel sources, renderer and source flow model. Validation: both DFD generators completed successfully; the source and panel index contain nine processes and 39 public-table store references; Chapter 3 Word XML parses, Figure 3f is absent, and all five embedded DFD panels byte-match their generated PNG sources. Documentation-only change; no application, schema, or deployment state changed. Final desktop Word pagination review remains pending.

## Context diagram layout and shared request review

The Chapter 3 context diagram now follows the supplied horizontal reference: Member / Applicant at left, process 0 in the center, and Administrator and Authorized Staff at right, using pale-blue actor boxes and a pale-blue process header. The actor flows identify online application and renewal review decisions as shared administrator/staff work. The labels retain separate role-specific inputs and returned results. A note states that walk-in transactions are entered by an operator and payment is recorded at the gym; the context view does not represent an online gateway or a customer receipt.

Affected files: `02-context.png`, editable `02-context.svg`, `build-context-diagram.ps1`, `sync-context-diagram.ps1`, the embedded Chapter 3 context figure, and these defense notes. Validation: the 2200-by-760 PNG was rendered by the PowerShell generator and visually inspected; the Chapter 3 Word package XML parses, its context image byte-matches the generated PNG, and its wide-page extent is set to the image ratio. The Word package was backed up under `Documentations/Review Backups`. Full Word pagination and adviser review remain pending. This is a diagram/documentation update only; application behavior, database schema, and deployment status did not change.

## Chapter 3 non-DFD diagram revision — November 11, 2026

At the user’s request, corrected the context diagram, restored the Figure 4 use-case caption, documented Figure 5 as the 12-public-table ERD with 18 foreign keys, and redrew Figure 33 with larger labels and an explicit original-plan title. Added explanations of role-scoped information exchange, the two application/member links, transaction and attendance relationships, key/cardinality notation, managed Auth references, private-schema exclusions, and planned versus actual work. The 21-table, 224-field, 33-foreign-key full model remains in the dictionary/schema reference. This entry supersedes earlier claims that the current manuscript retains Figures 5a-e. Agile and DFD are excluded from the change.

Affected modules: Chapter 3 manuscript; context, ERD and Gantt diagram assets; local generation/application scripts; this study guide and presentation slide 13 plus speaker notes. A backup of the user-modified manuscript is retained under Review Backups/non-dfd-diagrams-20261111. The application script compares all table XML, the opening/Agile paragraphs, the entire DFD section, and every unrelated DOCX package part against that backup. Generated context/ERD/Gantt PNGs were visually inspected. Desktop Word pagination is a separate check and is not implied by package validation. No application/schema change, database command, website release or deployment occurred; setup steps are unchanged.

Validation outcome: the final preservation check passed for all 26 tables and all unrelated Word package parts; the three replacement images match the generated PNGs. Defense verification passed for 18 slides and 18 speaker-note parts. Word automation also stalled on a temporary local copy and was closed without saving; final desktop Word pagination remains pending. No PDF preview is claimed.

## Chapter 1–3 manuscript formatting — November 11, 2026

Applied the user-supplied format to Chapters 1, 2 and 3: Times New Roman, 12-point editable text, 1.5-line paragraph spacing, 1.5-inch left margin, and 1-inch right, top and bottom margins. The settings include table cells, captions, headers/footers where present, paragraph styles and defaults. Existing page orientations, bold/italic emphasis, paragraph alignment and before/after spacing are retained. Twenty-three Chapter 3 table grids were reduced to fit the available text width. Figure content and embedded image bytes are unchanged; text inside diagram/screenshot images is not editable manuscript text.

Validation: staged all three documents before replacement; checked all paragraph/run settings and section margins, compared wording, field instructions and table text with the backups, and verified every unrelated package part/media file unchanged. The saved report is Review Evidence/Chapter 1-3 Spacing Verification.txt; backups are under Review Backups/chapter-spacing-20261111-030959. This is manuscript formatting only, with no application/schema/deployment change or setup change. Final desktop Word pagination remains a separate visual check.

## Combined Chapters 1–3 with table of contents — November 11, 2026

Created Documentations/Chapters 1-3 with Table of Contents.docx from snapshots of the saved chapter files, leaving the three originals untouched. The combined file preserves chapter order, original wording (2,011 text runs), all 26 tables, 46 imported media files, chapter section layouts, and existing formatting. A front section contains 39 linked chapter/section entries inside a genuine three-level Word TOC field. Imported style IDs, numbering IDs, relationships and bookmarks are separated to prevent chapter collisions. Package XML, relationship targets, numbering references, TOC anchors and media preservation checks passed. Sources are retained under Review Backups/combined-chapters-20261111-032526; the report is Review Evidence/Combined Chapters Verification.txt.

Word automation did not complete saving/pagination. The package-generated document requests field refresh on opening; right-click the contents and choose Update Field / Update entire table in Word to generate final page numbers. No page numbers or print-layout acceptance are fabricated. This is a documentation-only artifact, with no application/schema/deployment or setup change.

## Gantt planning correction — November 11, 2026

The proponents clarified their four planning activities: identifying a potential client; the first client interview and identification of problems and needs; project conceptualization; and drafting the proposal. Updated the four planning labels in the Gantt source/PNG and the Gantt explanation in Chapter 3 and the combined Chapters 1–3 manuscript. Earlier wording about proposal presentation/feedback and requirement confirmation is superseded for these planning rows. The existing week/date assignments and all design/development activities are retained; the clarification does not independently verify actual completion dates.

Validation: the rendered PNG was visually inspected; both manuscripts were compared with backups, confirming only the Gantt image part and its explanatory paragraph changed. Tables, other body nodes, style/formatting parts, TOC fields, image relationships and unrelated media are unchanged. Evidence: Review Evidence/Gantt Planning Correction Verification.txt. Backups: Review Backups/gantt-planning-20261111-035557. Documentation only; no application/schema/deployment or setup changes. Final Word pagination remains a separate visual check.

## Member menu dialog visibility - November 11, 2026

Corrected the member settings dialog appearing at the bottom of the dashboard while closed. The custom flex display overrode the browser's default closed-dialog hiding; an explicit `.member-settings-dialog:not([open])` rule now hides it until the existing `showModal()` action opens it. Closing returns it to the hidden state. Updated the customer page stylesheet version to refresh cached CSS. Affected modules: assets/css/style.css and customer.html. No schema or setup changes.

Validation: git diff --check and the existing scripts/check-ui-improvements.mjs checks passed. The existing showModal()/close() handlers were inspected. Browser visual verification and deployment remain pending; this entry describes a local source fix, not a verified hosted release.

## Combined manuscript page numbering - November 11, 2026

Added centered Times New Roman, 12-point PAGE footer fields to the combined Chapters 1-3 manuscript. The five preliminary sections (including cover, certification/approval material and contents) use blank footers but count from page 1. Visible numbering begins with Chapter 1 and continues across the remaining ten sections, including landscape pages; no later section restarts the count. Default, first and even footer variants are explicitly assigned. The separate chapter documents are unchanged.

Validation: Documentations/Tools/add-manuscript-page-numbers.ps1 staged and backed up the current document, compared its body with only footer/numbering metadata excluded, verified all unrelated package parts unchanged and parsed all XML parts. Original wording, tables, TOC fields, styles, media, margins and section layouts are preserved. Evidence: Review Evidence/Manuscript Page Numbering Verification.txt. Desktop Word pagination, visual footer placement and TOC refresh remain pending; no exact page count is claimed. Open the combined file in Word and update the entire table of contents to refresh its page references. Documentation only; no application, schema, setup or deployment change.

## Combined manuscript contents refresh - November 11, 2026

Corrected all 39 cached table-of-contents page references in Chapters 1-3 with Table of Contents.docx, which previously displayed page 1 for every entry. Desktop Microsoft Word successfully repaginated a temporary local copy, rebuilt the TOC and refreshed its page numbers. Word reported 150 pages, with Chapter 1 on page 7, Chapter 2 on page 22 and Chapter 3 on page 29. This supersedes the earlier pending Word pagination status for those TOC references; final visual print-layout review remains separate.

Only the 39 verified page-reference result values were transferred back to the original package, retaining its heading text, live fields, hyperlinks, dot leaders, styles and section layout. Compared document XML with those values restored and verified all unrelated package parts byte-identical. Bookmark destinations and entry order passed validation. Counted-but-hidden preliminary page numbering is preserved. The verified output replaced the combined manuscript after transient file locks cleared; its saved hash matches the staged output. Scripts: Tools/refresh-manuscript-toc.ps1 and Tools/apply-refreshed-manuscript-toc.ps1. Evidence: Review Evidence/Manuscript TOC Refresh Verification.txt; backups: Review Backups/toc-refresh-20261111-115112. Documentation only; no application/schema/setup/deployment changes.

## Updated prototype captures — November 11, 2026

The paper prototype section now uses all 57 PNG captures supplied in FEATURES.zip, organized as access/registration, administrator, staff, and member interfaces. Figures 6–62 replace the earlier capture set; the retained Gantt chart is Figure 63. Captions and explanations describe visible states, including password recovery, browser approval and session conflicts, trusted-browser logout, attendance lookup, catalog/report filters, and member self-service. Each image is embedded in full as supplied; some supplied images are interface details rather than complete pages.

Affected documents: Chapter 3.docx, Chapters 1-3 with Table of Contents.docx, prototype figure index and asset manifest. Source images and pre-edit manuscript backups are retained. Verification checks source-image identity, unique captions/descriptions, image relationships, crop settings, drawing IDs, and unchanged requirements/dictionary tables. The older chapter-wide validator expects an obsolete schema-count sentence and cannot certify the current chapter. Word pagination and contents references must be refreshed after this larger section replacement. This is a documentation revision; no application, database, setup, or deployment change is made, and screenshots are not usability or end-to-end test results.

## Phone administrator approval timing repair - November 11, 2026

A reported phone scanner sign-in displayed the trusted-device approval requirement without a visible approval notification. Repository inspection identified a reproducible timing gap: request_admin_login_approval may return mfa_required while the trusted browser is inactive; if that browser resumes during authenticator verification, finish_admin_device_login requires approval although no request was created. This is a code-supported failure path, not confirmation of the reporting device's server state.

The shared browser trust helper now rechecks approval after authenticator verification when the first check did not grant approval. It also stops with a reload instruction when the approval helper is missing instead of silently skipping that step. Affected modules: shared administrator trust script, login/admin/phone script versions, and phone service-worker cache v25. Existing server approval and authenticator requirements remain enforced. No schema or setup changes. Validation: node --test scripts/tests/admin-device-trust.test.mjs scripts/tests/attendance-phone.test.mjs passed all 14 tests, including a simulated trusted browser waking during MFA and a missing approval script. Local changes only; hosted deployment and a physical two-device retest remain pending.

## Separate password-only attendance app login - November 11, 2026

The user clarified that the attendance app must use existing website staff/admin credentials without an authenticator, while website administrator sign-in retains its authenticator and trusted-browser protection. This supersedes the earlier scanner approval-timing approach: scanner sessions no longer participate in administrator browser enrollment or approval. The same credential endpoint remains in use; accounts and passwords are not duplicated.

Migration 20261111000001_password_only_attendance_operator.sql adds a private Auth-session marker and narrow scanner identity, status, attendance and audit RPCs. Activation replaces only the attendance scope, rejects website session downgrade, and preserves the dashboard session. Scanner sessions cannot pass website RLS, including staff scanner sessions, and the pre-request hook rejects their access outside the scanner RPC allowlist. Scan submission requires a pairing id/token and delegates to existing paired-device expiry checks, attribution and retry handling. Website trust enrollment and forget-device actions preserve the independent scanner scope. The phone no longer loads authenticator/device-approval scripts or offers website trust revocation; its shell cache is v26. Shared monitoring accepts a scanner-specific status RPC with the original website default retained.

Validation: 15 browser/Edge unit tests passed. The new PGlite integration suite passed password-only admin/staff activation, simultaneous trusted website access, retained website MFA, table/RPC isolation, required/invalid pairing, restricted audit events, replacement rejection, inactive-account rejection and website forget isolation. Existing administrator-trust and reliable-attendance SQL suites also passed. PGlite is a temporary local test dependency installed without manifest/lockfile changes. No physical two-device result is claimed.

Deployment: linked project reference verified as nttsrdassmzvtaamyogi. The terminal dry run listed only the new migration; npx.cmd supabase db push --linked completed successfully and reported that migration applied. This CLI run applied without an interactive confirmation prompt. Matching frontend hosting and installed-app refresh remain unverified. Deploy the matching web files and reopen/reload the scanner to obtain the new shell; retain website MFA settings and existing pairing records. Setup guidance is updated in Admin MFA Setup and Deployment Guide.md and Trusted Administrator Device Guide.md.

Verification completion: Desktop Word successfully repaginated the updated combined manuscript and reported 172 pages. The rebuilt contents includes the replacement subsection headings and its links resolve to existing bookmarks. The final refreshed copy preserves all non-contents body paragraph/table text and all 15 sections' page-size, margin and page-number settings. All 57 embedded prototypes passed source matching; four Word-recompressed images passed aspect and appearance checks. The refreshed copy is saved as Chapters 1-3 with Table of Contents.docx. This completes the contents refresh mentioned above; final visual print-layout review remains separate. See Review Evidence/FEATURES Manuscript Verification.txt. Earlier 150-page contents status describes the prior manuscript.

## Scanner-to-scanner Approve/Deny handoff - November 11, 2026

The user clarified that the unexpected logout affected the first attendance scanner, and explicitly selected Approve/Deny on that first phone before another scanner may take over. The password-only separation initially activated a newer attendance session immediately. That could end the first scanner before the second finished its UI steps. The supplied screenshot also contained the retired website approval error, indicating a legacy scanner flow; the currently hosted scanner HTML was separately checked and referenced 20261111-password-scanner at that check. This establishes a frontend version mismatch, not the exact original devices' server state.

Migration 20261111000002_scanner_login_approval.sql adds private scanner approval requests bound to requester, current approver, account and a two-minute expiry. Pending, denied, cancelled, expired or wrong-session requests cannot replace the current scanner. Approving does not end the first session; replacement happens only when the requesting session subsequently activates with that approval. Activation is idempotent for an already current scanner. Another requester or a changed approver cannot reuse the grant. Scanner notification/list, decision, request and cancel RPCs stay separate from website administrator MFA and device trust. The retired administrator-trust attendance challenge/completion path is rejected server-side so cached old clients cannot bypass the new handoff. Explicit Change operator releases only the caller's current scanner session; an already replaced phone cannot end the newer one.

Frontend: scanner-login-approval.js polls the first phone every three seconds while visible/online, renders reported browser labels as text, offers Approve/Deny with retry on failed decisions, and refreshes on focus, online and visibility changes. The incoming phone waits or cancels; no authenticator is requested. Phone sign-in fails closed if this helper is missing and rechecks the handoff if another scanner wins the activation race. Phone HTML/script/worker versions advance to scanner-handoff and shell v27. Keep the first phone open to receive the request. No timeout or offline state automatically approves a pending request; if the first scanner is being retired, use Change operator there to release it before signing in elsewhere.

Validation: 20 browser/Edge tests passed, including waiting/approval cleanup, denial, safe label rendering, explicit decisions, failed-decision retry, and password-only sign-in ordering. The expanded PGlite integration suite passed pending protection, approval before activation, idempotent activation, denied/cancelled/expired attempts, stale-scanner logout isolation, and legacy administrator attendance route rejection, while retaining website MFA, RLS/RPC isolation and mandatory phone pairing checks. Terminal dry runs listed only migration 20261111000002, then npx.cmd supabase db push --linked reported it applied successfully to nttsrdassmzvtaamyogi. This CLI applied without an interactive confirmation prompt. Matching frontend deployment, notification appearance on physical phones and a full two-phone handoff remain unverified. This increment supersedes immediate scanner replacement described in the previous section; website MFA and independent website/scanner scopes remain intact.

## Expired admin pairing status recovery - November 11, 2026

The supplied admin screenshot showed an inactive/expired pairing error followed by an instruction to apply archived migration 20261104000011. Repository evidence shows that get_admin_mobile_attendance_device raises this error when the referenced record is missing, expired or not owned by the current administrator; it does not establish a missing migration. The admin JavaScript incorrectly appended the migration instruction to every error.

The admin status handler now removes only the invalid local session reference and its persistence/polling entries, selects another tracked pairing if available and stops polling when none remain. It explains that the pairing QR expired or was ended and directs the operator to Phone Camera. Other errors retain saved references and show a connection/retry message without claiming a migration is missing. This does not delete server pairing records or reset phone storage, credentials or authenticators. Affected files: assets/js/admin.js, admin.html script version, and scripts/tests/admin-attendance.test.mjs. Validation: JavaScript syntax check and all four admin attendance tests passed, covering isolated stale-reference removal, final-reference cleanup, transient-error retention and atomic scan retry behavior. No schema/setup change or database push is required. Frontend deployment and reproduction on the reporting admin browser remain unverified.

## Visible scanner approval and polling diagnostics - November 11, 2026

The user reported that the incoming phone was waiting while the first scanner stayed open and signed in, but no Approve/Deny appeared. This confirms a waiting requester state as reported by the user; it does not establish whether the first phone had current JavaScript, a working polling request, or the current server session. The prior notification code silently ignored list-RPC errors and displayed a fixed page panel instead of a modal dialog.

The scanner now uses a native modal dialog for the first phone's Approve/Deny request, above the camera/page. Its signed-in operator area displays whether sign-in request checks are listening or failing, with a sanitized error code where available, and provides Check sign-in requests for an immediate retry. Inactive-session errors are distinguished from other check failures. Decision errors retain the dialog and enabled retry controls; failed polling does not grant access or end either session. Polling, approval bindings, expiry, password-only scanner login and website MFA are unchanged. Frontend versions: visible-approval script and shell v28. Affected modules: scanner-login-approval.js, attendance-phone.html, attendance-phone-sw.js and notification tests. Fourteen notification/scanner unit tests passed, including modal opening, explicit approval, visible polling failure and manual retry recovery. Matching frontend deployment and physical confirmation on the reporting phones remain pending; the original no-popup cause is not yet confirmed. No schema migration or setup change is required.

## Scanner refresh restoration and inactive-session recovery - November 11, 2026

The user reported refreshing an approved scanner, losing its login, and then being asked to obtain approval although no phone remained signed in. Repository inspection confirms that the scanner used nonpersistent in-memory Auth storage and cleared its operator on pagehide, while its server-side attendance session could remain registered. This left an unreachable approver and made ordinary refresh behave like a new device sign-in.

The scanner Auth client now uses a separate sessionStorage key (ig_phone_operator_session), preserving its Auth session across refresh within the same tab/app browsing session, without storing passwords. On load and back/forward-cache restore it validates current scanner status and retrieves its narrow operator identity, then restarts monitoring/approval notifications without requesting a new login or approval. It does not reactivate a replaced session. Transient restore failures retain stored credentials and show a retry message. Pagehide stops monitors and camera activity; explicit Change operator still releases the server session and signs out locally. This does not promise login persistence after closing the tab/app or clearing storage.

Migration 20261111000003_scanner_session_recovery.sql adds scanner last-seen timestamps, refreshed by the existing current-status RPC. A new explicit Recover inactive session action checks the account, valid Auth session, current approver and inactivity under the same account advisory lock, and activates recovery atomically only after at least two minutes without scanner heartbeat. A recently active first scanner remains protected by Approve/Deny. Denied/cancelled/consumed requests cannot be recovered using that same requester session. Request expiry itself never grants access; the UI keeps recovery available after expiry, and successful recovery is audited as scanner_session_recovered. This explicit user-triggered inactivity recovery supersedes earlier notes saying no offline recovery path existed. A backgrounded phone may stop heartbeats; the two-minute rule measures application activity, not physical possession or proof of logout. Website sessions/MFA, pairing records and scan attribution remain separate and unchanged.

Affected modules: scanner JavaScript and approval dialog, phone HTML and service-worker versions (session-recovery, shell v29), migration and tests. Validation: all 24 scanner/approval/admin-trust browser/Edge tests passed, including same-session restore without approval, transient-failure retention and explicit recovery UI handling. The expanded PGlite integration suite passed heartbeat-protected active-scanner rejection and explicit inactive recovery alongside earlier scope, pairing and approval checks. Linked project nttsrdassmzvtaamyogi was verified; terminal dry run listed only migration 20261111000003 and push reported successful application. This CLI applied without an interactive confirmation prompt. Matching frontend delivery and refresh/recovery on the reporting physical phones remain unverified. Setup guides were updated; no password, authenticator factor or phone pairing reset is required.

## Explain admin pairing versus the phone's saved connection

The user reported that the admin listed the Reno phone as paired while that same phone's scanner said it was not paired. Repository code stores the pairing ID/token in browser storage and separately verifies the pairing against the server. The admin's device label and active server record do not prove that the current app/browser still has the matching saved token; the exact cause on the phone has not been confirmed.

The signed-in scanner's missing-local-connection status now explains that the admin may still list an active pairing, asks the operator to reopen the app in the same browser used to pair it, and tells them to have the admin inspect the pairing before ending it or issuing another QR. This prevents the status from asserting that the server pairing is absent or immediately recommending re-pairing. A genuinely invalid or expired saved token still follows the existing re-pair flow. Affected modules: assets/js/attendance-phone.js, attendance-phone.html script version, and attendance-phone-sw.js shell cache v30. No schema, account, credential, authenticator, or pairing records were changed. Validation: source inspection and git diff --check; no automated or physical-device test was run. The revised frontend has not been deployed, and reproduction on the Reno phone remains pending.

## Activity Logs in split-screen layouts - November 11, 2026

A user screenshot showed expanded Activity Logs details squeezed into a very narrow column in an IDE split view. The activity panel used container queries for its compact layout; the visible pane did not reliably trigger those queries, so the table remained in desktop columns.

Added a viewport breakpoint at 1024px that renders each event as a two-column card and makes the Details cell span the full card width. At 560px and below, cards use one column. The admin stylesheet URL now has a fresh cache version. Affected modules: assets/css/style.css and admin.html. No data/schema/workflow changes. Validation: source inspection and git diff --check only; browser/split-view review and deployment remain pending.

## Explain immediate scanner recovery - November 11, 2026

The user tested a staff sign-in and saw it waiting for another scanner even though nobody was using one. This state means an attendance session remains on record; it does not prove another phone is currently being used. The existing server recovery RPC permits takeover only when the previous scanner has reported no activity for at least two minutes, and refuses recovery if its heartbeat is recent.

The sign-in dialog now tells the operator to try Recover inactive session immediately when no other scanner is in use. The server remains the authority: a recent heartbeat keeps the old scanner protected and the UI explains that condition. This is a guidance-only frontend change; approval, recovery, timeout and database behavior are unchanged. Affected modules: scanner-login-approval.js, attendance-phone.html script version, attendance-phone-sw.js shell v31. No schema change. Source inspection and git diff --check only; device repro and frontend deployment remain pending.

## Make admin toast text readable in light theme - November 11, 2026

A user screenshot after approving a registration showed a success toast with a dark background and nearly black text. The toast style set its background but left text color inherited from the light-theme page, reducing contrast.

The shared toast rule now sets an explicit light text color, preserving the dark toast surface and colored success/error border. The admin stylesheet URL receives a new cache version. Affected modules: assets/css/style.css and admin.html. Approval/payment behavior is unchanged; the screenshot indicates the success path completed. Validation: source inspection and git diff --check only; visual browser verification and deployment remain pending.

## Prevent Store password control overlap - November 11, 2026

A user screenshot of Store & Inventory in light theme showed the password visibility control overlapping the password field and Open Store button. The shared password enhancer wraps the field and appends an absolutely positioned eye button; the Store form did not explicitly constrain that control inside its flex item.

The Store password field now reserves room for the eye control, positions it within the field with fixed dimensions and transparent background, and keeps the submit button from shrinking into it. At phone-width viewports, the form stacks the field and submit button. The admin stylesheet cache version was refreshed. Affected modules: assets/css/style.css and admin.html. Store authentication behavior is unchanged. Validation: source inspection and git diff --check only; browser layout review and deployment remain pending.

## Rename the admin Store & Inventory labels - November 11, 2026

The admin navigation, locked-state heading and instructions, submit button, and inventory section heading now use Inventory / Open Inventory consistently. The icon changed from a store to stacked boxes. This is a visible-label-only change: the internal section key, existing password check, access scope, and inventory behavior are unchanged. Affected module: admin.html. No schema, setup, or deployment change has been applied. Validation: source inspection and git diff --check only; browser review and deployment remain pending.

## Match admin notifications to the selected theme - November 11, 2026

The user noted that light mode still showed dark popups/pages. Review of shared admin surfaces found that the reusable modal, account menu, approval dialogs, inventory lock and page loader already have light-theme overrides, while the screenshot's success toast had no light-theme surface rule. It therefore kept its charcoal background even after its text contrast was fixed.

Added light-theme toast surfaces: neutral messages use white, success uses a pale green surface, and errors use a pale red surface with matching text and borders. Dark theme retains the existing dark toast palette. Refreshed the admin stylesheet cache version. Affected modules: assets/css/style.css and admin.html. No workflow or data changes. Validation: source review and git diff --check only; browser checks across each popup/page remain pending, and frontend deployment is unverified.

Theme follow-up: Shared toast rules also serve member-dashboard notifications. The admin and member pages now both use the refreshed stylesheet version. Source inspection confirms existing light-theme overrides for the shared modal, account menu, approval dialogs, inventory lock, and page loader; this was not a full browser audit of every screen or popup.

Inventory password toggle follow-up: The user supplied a screenshot showing the visibility control still appearing as a red circle and touching Open Inventory after the earlier layout change. Inspection found the shared dashboard focus-visible rule adds a 3px outline with a 3px offset; the earlier sizing/background rules did not constrain that focus halo. The Inventory toggle is now smaller and inset farther from the input edge, the form gap is wider, and its focus outline is compact with no offset. The admin stylesheet cache version was refreshed. Affected modules remain assets/css/style.css and admin.html. Source inspection and git diff --check only; screenshot-based browser confirmation and deployment remain pending.

Inventory password toggle correction: A new screenshot showed the overlapping eye control remained visible after two CSS layout attempts. To remove the source of the overlap on this screen, the Inventory password field now opts out of the shared password-visibility enhancer; all other password fields retain their existing reveal control. The field is a direct flex child and stays aligned with Open Inventory, stacking on narrow phones. Admin cache versions for the shared helper and stylesheet were refreshed. Affected modules: admin.html, assets/js/ui-improvements.js, and assets/css/style.css. Store password validation is unchanged. Validation: JavaScript syntax check and git diff --check; visual confirmation and deployment remain pending.

## Record attendance directly from staff member search - November 11, 2026

The staff attendance view already searched members by name/Gmail and could record attendance after selecting a result, but the search result did not show an attendance action. The user asked to make search-to-attendance direct and clear.

Each matching member result now includes a visible Record attendance action. Clicking it submits that member's UUID to the existing record_attendance_scan RPC, preserving server-side staff authorization, membership expiry checks, duplicate-scan protection, check-in/out determination, operator attribution, and attendance history. Failed network requests keep a retry action for the same member/request ID; successful writes clear the result and refresh history. The instructions clarify that the server determines check-in versus check-out from the latest visit. Affected modules: staff.js, staff.html, and staff.css; asset cache versions refreshed. No schema or migration change. Validation: JavaScript syntax check and git diff --check; no automated test or hosted/physical staff acceptance performed.

Staff attendance guidance follow-up: The help text now explicitly describes name/Gmail lookup as the fallback when a member has no QR or the camera cannot scan it. Staff can then use the member-specific Record attendance action; the existing server RPC still determines check-in/out and enforces staff access and membership rules. UI copy only; no schema change. Source inspection and git diff --check only; browser acceptance/deployment remain pending.

Staff attendance layout polish - November 11, 2026: The attendance panel now separates its two paths with clear headings: Scan a member QR, or Search member when there is no QR/camera scan is unavailable. Search results retain the prominent per-member Record attendance action. Added matching dark/light heading and divider styles and refreshed the staff stylesheet version. Affected modules: staff.html and assets/css/staff.css. Workflow and database behavior unchanged. Validation: source inspection and git diff --check only; visual/browser review and deployment remain pending.

## Preserve incomplete attendance when members return - November 11, 2026

The user noted that records shown as Incomplete (a missing checkout from a prior Manila calendar day) must not be checked out when the member returns. The existing scan RPC closed any latest open record, regardless of its date, so a later visit could falsely fill the old checkout time.

Migration 20261111000004_preserve_incomplete_attendance.sql updates the existing record_attendance_scan function: an open visit can be checked out only when its check-in date is today in Asia/Manila. A prior-day open record remains incomplete; a valid returning member receives a new check-in row, retaining the old record and its original operator attribution. Same-day checkout, eight-second duplicate protection, expiry validation, phone-pairing validation, scan request idempotency and staff/admin authorization are retained. Affected module: public.record_attendance_scan. Validation: source review and git diff --check. Linked dry-run and push status is recorded below; physical attendance acceptance remains pending.

Deployment status update - November 11, 2026: Linked dry-run for project nttsrdassmzvtaamyogi listed only migration 20261111000004_preserve_incomplete_attendance.sql. The linked push reported successful application of that migration; the CLI did not request an interactive confirmation. The SQL change is applied to the linked database. No physical attendance device or live member flow was tested, so operational acceptance remains pending.
