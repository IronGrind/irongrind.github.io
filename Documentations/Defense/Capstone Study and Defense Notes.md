# IronGrind — Study and Defense Notes

Maintained baseline: November 10, 2026 (Asia/Manila). Read alongside the source and Chapters 1–3. This is a study companion, not a substitute for the approved paper. Subsequent changes must update this file and the separate presentation.

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
| Diagram/paper work | Nine aligned functions, context/DFD/use case, ERD and complete dictionary | Chapter 3, diagram sources and review evidence; some screenshots are historical |
| November 10 interface work | Split admin member names, inventory thresholds/unit displays, staff catalog form sections and name/Gmail attendance lookup | Current source and focused tests; not proof of production rollout |
| November 10 audit extension | Server-audited rejected login attempts, password changes/recovery requests, sessions and export requests | Security migration, authentication functions and audit tests; deployment/configuration required |
| Current admin MFA increment | Authenticator enrollment/challenge plus server-side administrator access enforcement | `admin-mfa.js`, MFA migration and tests; hosted setup and physical authenticator validation pending |

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
| User Login | Email/password | Assigned username/password | Assigned username/password plus TOTP MFA after deployment |
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
| auth.js | Parses email versus assigned username; obtains an Auth session through the applicable login function; now runs MFA before session activation; verifies profile/membership state and routes to a role-specific page |
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

The documented physical schema contains twelve public tables and three private supporting tables. `auth.users` is a managed reference, not another public application table. The current MFA increment adds functions/guards, not a new application table or a current-device approval table.

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

Primary keys identify rows, foreign keys enforce declared references, unique rules prevent duplicate identifiers, and nullability states whether a value may be absent. Do not draw a physical foreign key merely because a column name looks related. Chapter 3's full dictionary covers 174 application/supporting fields, 21 declared FK definitions and five unique fields in its reviewed export. These counts must be rechecked if the schema changes.

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

Authentication establishes identity; authorization determines allowed actions. AAL1 is password-level assurance; a verified second factor raises the session to AAL2. The own-account MFA bootstrap returns only whether an active administrator must verify. Administrators at AAL1 cannot activate dashboard/scanner sessions or use protected Data API operations. The session/RLS guard also rejects direct table reads before AAL2. Edge Functions that read the caller's protected profile pass through these checks before privileged operations.

First enrollment is a controlled rollout task: a valid password alone cannot distinguish the real owner from an attacker before any factor has been enrolled. The real administrator must enroll on a trusted device during deployment. Thereafter, knowing the password does not supply the authenticator code. A password reset does not automatically remove the existing factor.

The setup QR/manual secret is sensitive, shown only in a temporary enrollment dialog. Do not put it in screenshots, activity logs, the paper, slides or source control. Supabase manages factor secrets; no custom public secret table is added. Existing member password minimum is eight characters; staff creation minimum is twelve, with implemented character requirements. MFA does not silently change those rules.

Current-device approval notifications are a future enhancement, not part of this MFA increment. A new verified login still follows the existing replacement rules within its session scope. MFA does not ask the old device for approval. TOTP enrollment/challenge outcomes remain available through configured Supabase Auth audit facilities; the custom activity viewer does not currently mirror every MFA challenge outcome.

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
| Admin password is stolen | Enrolled TOTP is also required; no claim that MFA makes compromise impossible |
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

Context: one system boundary and external actors, no internal tables. DFD: nine functions and named flows to individual stores; simplified labels are expanded by the narrative. Use case: actor participation, not identical rights. ERD: stored entities/declared relationships, not a permissions chart. Data dictionary: exact column types/lengths/keys plus meaning. Gantt: planned schedule unless actual completion evidence is recorded. Agile: iterative planning, building, testing and revision; don't claim a framework or sprint schedule not documented.

## 13. Current revision checklist

- Admin MFA source and isolated tests are complete. The user supplied successful linked database push output on November 10 confirming application of migrations 20261108000012, 20261110000001 and 20261110000002. Auth settings, authentication-function/web deployment and physical enrollment/login remain separately unverified.
- Read-only linked migration check on November 10 confirmed 20261108000012, 20261110000001 and 20261110000002 were not applied remotely. A client calling the missing MFA bootstrap fails closed; its error now explains incomplete setup instead of suggesting refresh. The initial migration check did not alter the database. The later user-supplied push output reports all three migrations applied and Finished supabase db push. This establishes reported migration completion, not an end-to-end MFA test.
- New `admin_mfa_required`, private MFA checks and session/pre-request integrations; no new application table.
- Login and phone scanner call MFA before activation; CSS/dialog and service-worker shell updated.
- Security-event deployment prerequisites from the previous increment remain applicable.
- Existing project title and nine functions retained.
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
