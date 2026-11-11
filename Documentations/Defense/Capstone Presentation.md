# IronGrind — Capstone Presentation

Editable slide text and speaker notes. Baseline: November 10, 2026. Generated PowerPoint is a text-first defense draft; replace historical prototype screenshots with current verified captures before presenting. No fabricated evaluation results are included.

## Slide 1 — IronGrind
- A Fitness Gym Membership and Operations Management System
- Iron Grind Fitness Gym
- Web application with an installable attendance scanner

Speaker notes: Introduce the actual proponents, adviser and institution verbally or add approved names. Keep the existing approved project title. Explain that web application describes implementation; the scanner is a PWA, not a separately developed native mobile app.

## Slide 2 — The operational problem
- Membership, attendance and product records need consistent organization
- Counter payments must be recorded against the correct operation
- Operators need clear responsibilities and traceable changes

Speaker notes: Link these points to Chapter 1 and the team's real data-gathering evidence. Do not invent interview quotes, measured errors or time savings. Describe the actual gym process before demonstrating its digital equivalent.

## Slide 3 — Objectives and boundaries
- Organize applications, membership periods and attendance
- Support inventory, in-person sales and operational review
- Preserve role-specific access and member self-service
- Record gym payments; no online payment gateway or issued customer receipts

Speaker notes: An internal transaction reference is not a customer receipt. The system supports administration, not medical advice, coaching or workout prescription. Present benefits as intended unless measured evaluation exists.

## Slide 4 — Users and responsibilities
- Members: own profile, membership, QR, visits and renewal requests
- Staff: attendance, counter services, request review and product sales
- Administrator: supervision, inventory, staff access, reports and logs

Speaker notes: Administrator views member personal profiles without editing their personal details. Staff do not get a general member-profile viewer/editor. Broad use-case associations do not grant identical permissions to every actor.

## Slide 5 — Nine main functions
- Login · Membership Application · User Management
- Renewals · QR Attendance · Products & Inventory
- Sales · Generate Reports · Activity Logs

Speaker notes: Keep these nine functions aligned with the functional requirements, use-case diagram and DFD. Security refinements sit within login/access and auditing rather than automatically becoming new main functions.

## Slide 6 — Architecture and tools
- HTML, CSS and browser JavaScript provide the interface
- Supabase Auth, PostgreSQL, RPCs and Edge Functions provide backend services
- Vercel hosts the web client; Node serves local development files
- RLS and server checks enforce access
- 21 application tables: 12 public and 9 private; 224 fields and 33 foreign keys

Speaker notes: A browser role marker is not a security boundary. The publishable key is used with protected APIs; service-role credentials remain server-side. Do not describe this implementation as React or Next.js. pgAdmin inspects the connected database; it is not automatically a separate source of truth. Figure 5e and Tables 24–26 now include member_trusted_devices, member_device_sessions and member_device_approvals from migration 20261110000006. The supplied context export lists only the twelve public tables; managed auth.users and auth.sessions are excluded from application-table counts. Member browser trust is separate from administrator trust and phone-camera pairing. Deployment is recorded in the member-device guide; controlled browser acceptance remains pending.

## Slide 7 — Development and evidence
- Iterative planning, implementation, testing and revision
- Source history and migrations show recorded changes
- Automated fixtures verify selected browser and database behavior
- Stakeholder evaluation and production validation require separate evidence

Speaker notes: Explain Agile using the documented project process, not an invented sprint schedule. The historical November 8 report records forty check groups; it is not a fresh count for every later change. Screenshots show interface states, not measured performance or user satisfaction.

## Slide 8 — Application to active membership
- Applicant submits account and membership information
- New signup creates its Auth account and pending application in one server workflow; failed application saves trigger account cleanup
- Authorized operator reviews the pending request and gym payment
- Approval creates or updates applicable membership records
- Member signs in to access only permitted own information
- Existing Auth accounts can resume an application missing after signup confirmation
- Registration save permissions repaired by deployed migration 20261110000007
- Registration confirmation summary follows Light and Dark Mode (local UI fix)
- Member profile sections stay in a fixed, responsive settings window

Speaker notes: Distinguish Auth account, application, profile and approved member record. A pending application does not mean active membership. Demonstrate the real counter payment step without implying online payment verification. New registration is handled by `member-registration`: it creates the Auth user, then stores the pending application; the signup call sends the confirmation email. If application storage fails after account creation, it attempts to delete the new Auth user; cleanup failures are reported for staff follow-up. The registration save failure was traced to missing service-role application INSERT/SELECT grants and an invoker name-validation trigger unable to call its private helper. Migration 20261110000007 restores those narrow grants and makes the fixed-search-path trigger SECURITY DEFINER while keeping its helpers inaccessible directly. The linked dry run listed only migration 07, then the terminal push applied it. A rollback-only live service insert/readback, clean database lint and 50 passing regression groups verified the repaired write path; real signup/email confirmation still needs retry. No website/function redeployment or table/column addition was needed. A separate registration-dialog theme fix replaces the hardcoded dark summary background with theme-aware CSS, improves the light-theme status badge and ID contrast, and wraps long values on phones. Local Edge previews at desktop and mobile sizes passed in both themes with no page/panel horizontal overflow. Registration CSS/JS cache versions were refreshed. This UI change still needs website deployment; it does not change application status or approval rules. Existing Auth accounts with no application can authenticate and submit one application; the flow checks for an existing membership/pending application before inserting. A duplicate-email response may come from an earlier or unfinished account/registration; use password recovery if needed or ask staff to check a pending record. The member settings dialog keeps a steady size as Personal Info, Emergency Contact, Health & Fitness, Login Email and Password sections change; its content scrolls inside the dialog, and the dashboard behind it remains modal/inert. These local UI changes have not been browser-accepted or deployed.

## Slide 9 — Attendance in practice
- Scan a member QR or search by name/Gmail in the staff portal
- Select a matching record before manual attendance submission
- Service checks member and visit state, then records check-in/out
- Older open visits are Incomplete; missing exit times are not invented

Speaker notes: Use a prepared test member. Explain that unique identifiers prevent shared names from selecting the wrong record. Request IDs protect uncertain retries. Scanner feedback time is the local display time; database event timestamps remain authoritative. Do not create fake live member transactions just for the defense.

## Slide 10 — Phone scanner and installation
- Administrator pairing, operator login and app installation are separate
- Setup QR: ten minutes; successful pairing: thirty days unless ended
- Paired phones and pending QRs share the configured capacity
- Direct scanner link supports reinstalling without a new QR when saved pairing survives
- Admin pairing-password prompt keeps its input full-width and aligned with the reveal control

Speaker notes: Show the scanner install button and distinguish member QR from pairing QR. The scanner page has a local visual refresh aligned with the app's dark navy and red styling; it does not change its workflow. The admin phone-pairing password modal also styles the password wrapper created by the shared visibility control so the field spans the form and has one focus indicator. If browser storage is cleared or a pairing expires, recovery/new pairing may be necessary. Cached shell does not provide offline attendance writes. Administrator scanner operators also complete MFA after deployment. The updated page has not been device/browser reviewed or deployed, so capture replacement slides only after that review.

The administrator account menu also has a local update showing the registered browser label and explaining the difference between ordinary logout (trust retained) and forgetting the browser (trust revoked). User-supplied terminal output confirms migration 20261110000005 was applied to the linked database after a dry run listed only that migration. The matching website revision remains local and has not been visually validated or deployed.

Store unlock UI follow-up: fixed flex sizing for the password-visibility wrapper so the password field no longer intrudes into the Open Store button. Source inspection passed; browser visual validation and website deployment remain pending.

Scanner follow-up: screenshots showed a pairing recognized before sign-in but missing afterward. Pairing credentials are browser-profile and origin storage, not physical-device identity. The exact cause is unconfirmed. The local scanner now holds a pairing snapshot through password/MFA requests, server-validates it after sign-in, and saves it again after validation. Expired/revoked pairings still require pairing again. Real phone/PWA validation and website deployment remain pending.

## Slide 11 — Inventory and sales
- Stock quantity, stock unit and selling price are displayed separately
- Pounds/ounces convert to base units before comparison or deduction
- Staff catalog groups supplements by form and separates merchandise
- Sale validation saves transaction lines and deducts available stock

Speaker notes: Explain a powder received in pounds but sold in grams. Capsules/tablets can be tracked by piece or box according to configuration; no unspecified box-to-piece conversion is assumed. Staff cannot restock or edit products. Show a low-stock item and an unavailable item as different states.

## Slide 12 — Low-stock policy
- Protein powder: 1,000 g; selected other powder types: 250 g
- Other powder: 500 g; liquids: 1,000 ml
- Pieces: 30; boxes: 4; other supplement items: 10
- Merchandise: 4 items per product/size

Speaker notes: The 250 g group covers creatine, pre-workout, amino-acid and vitamin powders. Form and selling unit take priority over type. Triggers are inclusive and are starting code-defined policies, not optimized forecasts. Actual reorder planning depends on sales demand, replenishment lead time and safety stock.

## Slide 13 — Data model
- Figure 5 shows twelve public tables and eighteen declared foreign-key relationships
- Managed auth.users is a reference card, outside the public application-table count
- Full dictionary: twenty-one application tables, 224 fields, and thirty-three foreign keys
- Nine private supporting tables remain defined in the dictionary and security references
- PK, FK, UQ and crow-foot endpoints explain keys and relationship multiplicity

Speaker notes: The November 11 diagram revision adds an explicit Figure 5 caption, public-schema scope, a notation legend and an interpretation of the business relationships. In particular, members.application_id identifies an optional unique source application, while membership_applications.member_id allows requests to refer to a member; these are separate relationships. Dashed blue-gray lines distinguish managed Auth references visually and retain database foreign-key enforcement. Selected attributes appear in the overview, with full definitions in the five-column dictionary. The model is based on the supplied schema export and repository migrations, not a new live-database inspection. Current Chapter 3 contains the public overview rather than the historical Figures 5a-e layout. Context, ERD and original-plan Gantt figures use dedicated landscape sections; the use-case caption and function-level explanation are restored. Agile and DFD content are intentionally unchanged. All requirements/dictionary tables and unrelated package parts were compared with the backup. Rendered diagram images were inspected; desktop Word pagination is checked separately. This documentation change introduces no application, schema, workflow or deployment behavior.

## Slide 14 — One trusted administrator browser
- First registration verifies the authenticator and browser signing key
- Repeat login on that trusted browser: password plus automatic key proof
- New browser: current-device approval, then fresh authenticator verification
- Successful transfer revokes old device trust; normal logout retains trust

Speaker notes: This latest local increment supersedes the earlier approval-only model. One browser key is trusted per admin account for 30 days. Its private key remains non-extractable in IndexedDB; the server stores only the public key. New browser access is blocked until approval and fresh TOTP have both completed. The server transaction preserves old trust if verification fails and atomically replaces it only on success. Old dashboard/scanner scopes are revoked when trust moves. No live eligible approver means fresh authenticator recovery; a two-minute heartbeat window defines recent activity. Forget-device explicitly revokes trust, while normal logout retains it. This is origin/browser trust, not a hardware identity or protection against every XSS attack. User-supplied CLI output confirms migration 20261110000004 and admin-device-trust deployed successfully. Matching frontend deployment, first registration, repeat-login reuse and physical transfer tests still require verification. No SMS is used and no private key or TOTP secret belongs in slides.

## Slide 15 — Accountability and session behavior
- Readable actions, category badges and expandable log details
- Filter by account name, account type (all users, members, staff or administrators), category, action and Philippine date range
- Operational/security events exclude passwords and tokens
- Explicit logout differs from expiry or session replacement

Speaker notes: Failed attempts are unverified events, not proof that the named account owner acted. Export requests do not prove files were saved. Custom logging does not mirror every MFA Auth audit event. Routine page views/searches are not comprehensive activity events. Main dashboard and scanner session ownership remain separate.

The local Activity Logs UI now adds an actor-role filter for members, staff and administrators; “All users” remains the default and includes other recorded/system actors. Dropdown and date changes apply immediately, while account-name typing is debounced. The Apply filters button was removed and Reset filters remains. This is a client-only filter over the existing actor_role field, with no schema migration. Browser validation and website deployment remain pending.

Chapter 3 uses the original multi-panel DFD layout: Figures 3a-e continue the nine processes, and data-store symbols show public application tables only. Authentication records and private security stores are omitted from the DFD; login remains Process 1.0. The separate complete Level 1 SVG is at `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. The Word images were refreshed and the private-store DFD supplement was removed. Final desktop Word pagination remains pending.

## Slide 16 — Testing and limitations
- Unit and simulated UI tests cover selected workflows
- Isolated SQL tests check permissions, transactions and MFA denial paths
- Real devices, hosted settings and complete visual flows still need verification
- Historical screenshots and planned schedules are labeled honestly
- November 10 readiness review: 49 regression groups and eight added sales scenarios passed; full hosted acceptance remains pending

Speaker notes: Present the actual saved test output, not an invented overall pass rate. MFA tests prove AAL1 denial/AAL2 access in fixtures; they do not prove the deployed project's Auth configuration. Formal usability results must be added only after real evaluation. Keep production data out of demonstrations where possible. The current review also confirmed 20 matching migration versions, clean error-level linked DB lint, eight active Edge Functions, 30 hosted files matching normalized local content, and 14 unauthenticated browser navigations without JS exceptions or horizontal overflow. Eleven anonymous table reads were denied. A favicon 404 and misleading missing-Authorization responses (500/503) remain observed minor issues; invalid bearer tokens are rejected with 401. These checks do not prove successful signed-in transactions, email delivery, camera scanning or two-browser transfers. See Review Notes/System Readiness Review.md before claiming whole-system acceptance. This review deployed no fixes; the editable PowerPoint was not regenerated.

## Slide 17 — Deployment and recovery
- Enable hosted TOTP and coordinate client, functions and SQL migration
- Genuine administrator enrolls and verifies the authenticator
- Test admin, staff, member and scanner paths after deployment
- Lost authenticator requires verified project-owner recovery
- Deploy the separate member-device approval flow; members do not receive an authenticator-code step
- Password recovery targets the allowlisted reset page from local and preview origins

Speaker notes: Follow Admin MFA Setup and Deployment Guide.md for administrator TOTP. Local config.toml edits do not automatically change hosted Auth settings. A November 10 read-only check confirmed the name-validation, security-event and MFA migrations were pending remotely; the later user-supplied CLI output reports those three migrations applied. It does not independently verify hosted Auth settings, deployed functions/client or actual authenticator login. Do not disable administrator MFA enforcement to recover an account. Project owner verifies identity, uses supported administrative factor reset and supervises re-enrollment. The application does not provide backup codes. User-supplied CLI output confirms the administrator trusted-device migration and function deployment; matching browser acceptance remains unverified. The deployed member-device increment adds three private tables and `member-device-trust`. Members enroll a signing key on first eligible sign-in; a new browser asks the currently trusted member dashboard to approve it. The member flow has no authenticator factor or code, and password-based recovery remains possible when no trusted member session is available to approve. Migration 20261110000006 and the member-device-trust and member-password-login functions are deployed; Vercel serves the matching client. Safe endpoint probes passed, but real member sign-in/device approval and physical authenticator acceptance remain unverified. Follow Member Device Approval Guide.md and record actual results before claiming success.

Password recovery note: The user clarified that production is now hosted at `https://irongrind-github-io.vercel.app`; the prior linked Supabase config diff showed the old GitHub Pages destination and is stale for current hosting. The local login client now targets `https://irongrind-github-io.vercel.app/reset-password.html`. Update Supabase Authentication URL Configuration to that Vercel Site URL and exact redirect allowlist entry. The recovery email template must link to `{{ .ConfirmationURL }}` so token verification and the requested redirect are preserved. Live Vercel checks confirm the login and reset pages return HTTP 200 and the deployed login script targets the Vercel reset page. Supabase URL allowlist and recovery email template remain unverified; no fresh email or password update was tested.

Authentication review update: the source review found and corrected a wrong-schema permission revoke in the member-device migration. The member-device SQL test now reapplies the migration under its owner role. Two login/SDK test fixtures were updated for the member-device gate and sessionStorage-backed Auth client. The complete local regression suite passed 49 checks, including administrator TOTP, device approval/trust, and member-device SQL scenarios. Migration 06 and member-device-trust/member-password-login are deployed. Live Vercel routes and safe function probes were confirmed. Hosted Supabase URL/email-template settings, real account login, fresh password-reset email, and physical authenticator acceptance remain unverified.

## Slide 18 — Demonstration and closing
- Follow one complete, role-appropriate gym scenario
- Show safeguards, not just successful screens
- Explain implementation evidence and remaining validation
- Invite questions about scope, flow, data and permissions

Speaker notes: Suggested sequence: member request, authorized review, attendance lookup/scan, product sale, administrator inventory/report/log review, and a test administrator MFA sign-in. Use controlled fixtures and avoid exposing credentials or live enrollment secrets. Add adviser-approved recommendations and actual evaluation results when available.

## Technical source notes

- Repository modules, SQL migrations, tests and Chapters 1–3 support the implementation descriptions.
- Supabase MFA: https://supabase.com/docs/guides/auth/auth-mfa
- TOTP integration: https://supabase.com/docs/guides/auth/auth-mfa/totp
- Auth audit storage: https://supabase.com/docs/guides/auth/audit-logs
- Local configuration: https://supabase.com/docs/guides/local-development/cli/config

Keep the final thesis reference list in its approved format. These are presentation source notes, not fabricated related literature.

Dashboard light mode received a source-level completion pass for nested cards, dialogs, filters, form controls, tables, scanner/phone pairing panels, inventory and sales surfaces. Staff-specific light rules account for its later-loaded stylesheet. This revision is local and still needs visual review across admin, member, staff and mobile views before deployment; do not present it as browser-validated.

A screenshot identified one missed Light Mode surface: the login page's Forgot your password dialog used the shared dark modal styling outside the dashboard theme scope. Login-specific overrides now theme the dialog, email field, copy, Cancel button and backdrop. The change is local and needs browser review in both themes, including mobile, before deployment.

The follow-up Light Mode audit found registration was missing the shared theme bootstrap and used dark inline surfaces. Registration now follows the saved preference, offers a theme toggle, and styles its sections, plan choices, fields and modal for Light Mode. Password reset also loads the saved theme and offers a toggle. The login recovery dialog was corrected in the prior local pass. These authentication-page changes have not received browser acceptance or deployment; review the full login → registration/password-reset paths and their success/error dialogs before release.

A final registration screenshot review caught the dark `+63` country-code blocks. They now use a muted gray fill with a matching border and dark text in Light Mode; dark mode is unchanged. The CSS revision is local and awaits browser review/deployment.

Staff member creation now checks membership plans, prices and exact durations on the server and requires the current Philippine business date, preventing client-submitted terms from being trusted. Date-only inputs are validated before account creation. Focused Node tests passed for the validation rules and Activity Logs UI fixture (6/6); syntax and whitespace checks passed. A member-device SQL regression fixture now covers enrollment, approval/transfer, session revocation, denial, expiry and access boundaries, and passed with the cached PGlite runtime. Migration 06 and required login/trust functions are deployed; controlled real-account acceptance remains pending.

PowerPoint reported a content problem opening the editable deck. Although basic XML checks passed, PowerPoint rejected the previous hand-built package. The 18-slide deck was rebuilt from this Markdown using native PowerPoint automation and reopened successfully with all 18 speaker-note sections present. The repository package checker also passes. Slide appearance still needs a human visual review; the rebuilt deck and generator changes are local.

Chapter 3 uses the original figure presentation: Figures 3a-e contain the nine-process DFD with public application tables as data stores; Figures 5a-c show the main physical relationships and Figure 5d shows the administrator-security schema. A standalone Gane-Sarson Level 1 DFD with all nine processes is supplied at `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. The public-only choice applies to DFD store symbols; database dictionary and ERD content retain private schema documentation where needed. Final desktop Word pagination remains pending.

## Complete DFD connector presentation

- Nine processes use specific action labels.
- One connector per process/entity or process/store pair.
- Two arrowheads indicate two-way data exchange; destination-prefixed labels identify each direction.
- Exact table names and individual stores remain visible.

Speaker notes: Use the standalone 03-dfd-complete-gane-sarson.svg. For example, login verifies identity and authorizes access; sales records transactions and sale items; activity records are filtered and viewed. Read each connector label by its stated destination. Two-way exchanges retain distinct input and output meanings on one line. Generation and XML checks passed: nine panels and 68 pair connectors. Adviser notation review and desktop visual review remain pending. This local SVG revision does not replace the Word figures or change deployed application/database behavior.

## Gane?Sarson DFD: single-headed presentation

- Rectangular entities; rounded numbered processes; open-ended identified stores.
- Specific process actions and one single-headed arrow per pair.
- Simplified view shows input/write flows for two-way pairs and reads for read-only stores.

Speaker notes: This supersedes the prior double-headed presentation in the standalone SVG. One arrow represents only the named flow in its indicated direction. Reverse flows are omitted for two-way pairs and remain in the source model; do not describe this view as complete directional coverage. A full DFD would draw separate arrows for both directions. Generation, syntax and SVG XML checks passed with nine panels and 68 single-headed connectors. Visual/adviser review remains pending. Word figures and deployed application/database behavior are unchanged.

## DFD line clarity and reference styling

- Pale-blue entities and numbered headers with white process bodies follow the supplied Gane?Sarson example.
- Darker, thicker single-headed arrows and larger separated flow labels improve tracing.
- Horizontal lanes keep connections distinct.

Speaker notes: Use the updated standalone SVG. All nine specific process actions and individual table names remain. This remains the simplified one-arrow-per-pair view; reverse flows are omitted as stated on the diagram. Generation, syntax and XML checks passed, and the visible first-panel styling was inspected in an Edge screenshot. Full page and adviser review remain pending. Word diagrams and deployed behavior are unchanged.

## DFD reference layout and connector routing

- Shared entities left, nine compact processes center, individual shared stores right.
- Bent routes use distinct ports and lanes with gaps at crossings.
- One single-headed named flow per pair remains.

Speaker notes: This replaces the standalone SVG panel layout to match how connections travel in the supplied reference. Generate it with build-dfd-reference-routing.mjs. Generation produced three entities, nine processes, seventeen stores and 68 connectors; syntax, XML parsing and a full-layout browser preview were checked. Zoom the SVG to read dense routes. Reverse flows remain omitted from this simplified view; the source model retains them. Adviser review and Word replacement remain pending. No application/database deployment occurred.

## DFD shared same-name flows

- Identically named flows to the same receiver share one labeled trunk.
- Branch dots show real joins; crossing gaps keep unrelated flows separate.
- 68 represented source connections now use 60 connector groups.

Speaker notes: Five compatible same-name groups were merged while retaining every connection represented by the prior simplified view. Different names and destinations remain separate. A shared arrow describes only its stated receiving direction; omitted reverse flows remain in the source model. Generation, syntax and XML checks passed; full visual/adviser review remains pending. Word figures and deployed application/database behavior are unchanged.

## Complete DFD on one sheet

- All nine processes, three shared entities and seventeen source-model stores remain together.
- All 108 documented directional flows are represented in 98 connector groups.
- Wider routing lanes and spaced ports reduce congestion; compatible same-name flows share trunks.

Speaker notes: This supersedes the simplified one-arrow-per-pair view and restores return directions required for complete source-model coverage. Individual arrows remain single-headed. Dots mark branch joins and gaps distinguish unrelated crossings. The SVG uses a 6600-by-5300 canvas for zoom or large-sheet printing. Generation checks all nonempty input/output entries; syntax and XML parsing passed, and a complete browser preview was visually inspected. Complete means the documented DFD baseline; newer member-device stores are not added by this layout change. Word replacement, adviser review and final print sizing remain pending. No application/database deployment occurred.

## DFD line jumps and spacing

- Connection-span routing reduces crossing events by about 18 percent.
- Curved bridge jumps mark all 1,172 detected crossings.
- Geometry checks find zero unrelated collinear overlaps.
- The single-sheet diagram retains all 108 documented directional flows.

Speaker notes: Curved jumps mean lines cross without joining; filled dots identify actual shared-flow branches. The SVG includes real curve geometry, so these jumps do not depend on an editor setting. All nine processes, three entities, seventeen source-model stores and 98 connector groups remain. Generation, syntax, XML parsing and a dense browser-rendered detail were checked; a final small continuity adjustment extends bridge tails. The routing audit is saved as dfd-routing-audit.json. This does not establish final label-collision, print-size or panel acceptance; review the vector at the intended display/print size. No Word replacement, application/schema change or deployment occurred.

## DFD fewer shared data lines

- Equivalent categories share a trunk with source or destination branches.
- All 108 documented connections remain in 86 connector groups, reduced from 98.
- Crossings fall to 1,006; every detected crossing retains a jump.
- Zero unrelated collinear overlaps in the geometry audit.

Speaker notes: Consolidated categories include activity events, sales transactions, sale-item records, membership changes, role/active-status reads and role-specific access results. Each original endpoint and original label is recorded beside its displayed category in the routing audit. Branches retain the original receiving arrows; role-specific results are routed to the appropriate role and do not imply shared user sessions or identical permissions. Source-model flow coverage, generator syntax and SVG XML/group counts passed; a browser-rendered detail was inspected. Full print/adviser review remains pending. This is a standalone diagram/documentation update; Word figures and deployed application/database behavior are unchanged.

## Simpler complete Level 1 DFD

- Broad data categories reduce connector groups from 86 to 52.
- All 108 source connections remain represented through branches.
- Reads and writes retain separate directions and individual stores.
- Curved jumps distinguish all 763 detected crossings.

Speaker notes: Labels such as Permitted member data and Member and membership updates summarize detailed payloads at Level 1. Each process uses role-scoped request/result categories. A parent category does not mean every role can perform every included action; original actor permissions and endpoint relationships remain. The routing audit maps every detailed original label to its displayed category. All nine processes, seventeen baseline stores and three actors remain together. Generation, syntax, XML/group coverage and the 108-entry audit passed; the complete browser preview was visually inspected. Zero unrelated collinear overlaps were detected. Final print/adviser review remains pending. This changes the standalone diagram and defense source materials, not Word figures or deployed application/database behavior.

## Complete DFD with local repeated references

- One sheet contains all nine processes in three rows.
- Nearby store/entity references shorten routes; matching IDs/names identify the same objects.
- All 108 detailed flows remain; crossings fall from 763 to 74.
- Every detected crossing has a curved jump; no unrelated collinear overlaps were found.

Speaker notes: This is the user-authorized repeated-reference layout trial. The complete standalone SVG explains that repeated D-numbers/table names and actor names represent the same logical stores/entities. Read processes left to right, then top to bottom. The nine processes, seventeen unique baseline stores and three unique entities remain. Exact original source/destination/payload triples were independently compared against the preceding audit and all 108 match. The generator, syntax and XML checks passed; a browser-rendered first-process detail was visually inspected. The previous shared-routing version is preserved as 03-dfd-shared-routing-comparison.svg under _Sources. Current generator is build-dfd-local-references.mjs. Print sizing was checked: at natural SVG scale (96 CSS px/in), the canvas is about 95.8 × 32.3 inches, with 16 px flow labels equivalent to 12 pt. A normal page would shrink text too far; use large-format vector printing or inspect the supplied preview and process details. No physical print was produced. Adviser review of repeated-reference notation remains pending. Word figures and deployed application/database behavior are unchanged.
## End-to-end test plan

- A 239-case manual checklist covers 18 sections from login and registration through admin, staff, member and full-system scenarios.
- Each case includes actual-result, status and evidence fields; all begin as Not tested.

Speaker notes: The checklist was exported to `Documentations/Testing/Iron Grind End-to-End Manual Testing Checklist - Final.docx` on 2026-11-10 from the checklist supplied in the conversation handoff. It provides a start-to-end test plan, not test results. No application or database behavior changed, and execution and outcomes remain pending.

## Public-schema ERD

- The editable overview focuses on the 12 public tables and their 18 declared foreign-key relationships.
- Its original simple business layout is restored.
- Private application tables remain defined in the Chapter 3 dictionary and separate security references.

Speaker notes: The user asked to keep the main ERD focused on the public schema. The standalone 05-gym-erd-editable.svg and its Draw.io source therefore show the 12 public tables only. The nine private application tables remain documented in the Chapter 3 relationship panels and administrator/member security supplements; across the full schema materials, 21 application-owned tables, 224 fields and 33 foreign keys are covered. The all-in-one 21-table draft is preserved under `_Archive/Previous ERD Versions/05-gym-erd-complete-with-private.svg` and `.drawio`. Use the public diagram as a focused reference, not as the only schema figure. No Word figures, application/schema code, or deployment state changed.

## Slide - Updated system context

- Members and applicants submit credentials, registration and renewal requests, and permitted profile changes.
- Administrators and authorized staff can review online applications and renewal requests.
- Role-specific membership, attendance, counter-operation, and administrative results return to the appropriate user.
- Gym payments are recorded in person; no online payment gateway or customer receipt is represented.

Speaker notes: The context diagram uses the supplied horizontal layout and pale-blue actor/process-header colors. Member / Applicant appears on the left, process 0 is centered, and Administrator and Authorized Staff appear at the right. The administrator and staff inputs now both state online request-review decisions, matching the implemented role permissions. Separate arrows indicate each role's input and returned information. Walk-in customers transact through an operator. The context diagram shows information exchange, not internal MFA, trusted-device, database, or hosting details. The 2200-by-760 PNG was rendered and visually inspected; the Chapter 3 Word image byte-matches it, and the Word package XML parses. Word pagination and adviser review remain pending. This was a documentation-only update; application, schema, and deployment behavior did not change.

## Diagram revision — November 11, 2026

- Clean context inputs and output arrows; Figure 4 use-case caption restored.
- Figure 5 explicitly covers the public schema, with a relationship explanation and notation legend.
- Figure 33 retains the original date ranges and activities; larger labels identify an original plan rather than completed work.

Speaker notes: Supersedes earlier manuscript-layout descriptions in these historical maintenance entries. The current Word manuscript includes one public-schema ERD overview and the full 21-table dictionary; earlier claims that it contains separate Figures 5a-e no longer describe the current layout. No Agile or DFD change was made. Diagram source/PNG inspection and preservation checks are recorded in the review evidence; no deployment occurred.

Diagram validation status: all 26 requirements/dictionary tables and unrelated Word image parts are preserved; the embedded replacement PNGs match their sources. Desktop Word automation did not complete, including the local-copy retry, so pagination remains pending. No generated PDF is presented as a completed preview.

## Chapter 1–3 manuscript format

- Times New Roman, 12 pt, with 1.5-line spacing, including tables and captions.
- Margins: 1.5 inches left; 1 inch right, top and bottom in every section.
- Existing wording, diagram image bytes and page orientations are preserved.

Speaker notes: The November 11 formatting pass follows the user's supplied manuscript specification. Twenty-three Chapter 3 table grids were fitted to the available text width. Staged documents passed font, spacing, margin and content-preservation checks before replacement; the report and backups are retained in Review Evidence and Review Backups. Existing paragraph before/after spacing and emphasis are retained. Font requirements apply to editable Word text, not lettering already contained in supplied image assets. Final visual pagination review remains separate. This is a manuscript-only change, with no application, schema or deployment action and no change to the eighteen-slide PowerPoint.

## Combined manuscript and contents

- Chapters 1–3 are available together in a separate Word manuscript.
- A linked table of contents includes 39 chapter and section headings.
- Chapter text, 26 tables and 46 imported media files are preserved.

Speaker notes: The separate chapter sources remain unchanged. The merge isolates imported styles, numbering and relationship targets while retaining the saved chapter formatting and section layouts. Package/content checks passed; this does not establish final printed pagination. The table of contents is a real Word field and requests updating on open. Update the entire table in Word to populate its page numbers; no calculated page numbers are claimed from the stalled Word automation. The combined manuscript is a documentation-only deliverable and changes no application or deployment behavior.

## Gantt planning activities — corrected

- Identify a potential client.
- Conduct the first client interview and identify problems and needs.
- Conceptualize the project.
- Draft the proposal.

Speaker notes: These four activities follow the proponents' November 11 clarification and replace the previous planning labels in the Gantt chart. Chapter 3 and the combined manuscript now use the corrected image and matching explanation. Existing week/date assignments are retained as schedule information; no new actual-completion dates are asserted. Design and development activities are unchanged. Package checks confirm that all unrelated manuscript content, tables, formatting and TOC parts are preserved. This is a documentation-only correction with no application or deployment change.

## Member menu visibility correction

- Closed member settings remain hidden on the dashboard.
- The existing menu action opens the settings as a modal.
- Local CSS fix; browser visual verification and deployment pending.

Speaker notes: The November 11 source correction adds an explicit closed-dialog display rule because the custom flex layout overrode the browser's default hiding. This explains the settings panel appearing near the bottom without a modal backdrop. The customer stylesheet cache version was updated. Affected modules are customer.html and assets/css/style.css. The diff whitespace check and existing UI improvement checks passed; showModal()/close() handlers were inspected. No database or setup change was required, and no hosted deployment or browser visual acceptance is claimed.

## Combined manuscript pagination

- Preliminary pages count toward the continuous page sequence while their numbers stay hidden.
- Centered page numbers appear from Chapter 1 onward, including landscape sections.
- The contents must be refreshed in Word after pagination.

Speaker notes: The November 11 update modifies only the combined Chapters 1-3 Word manuscript, using blank footers for five preliminary sections and live PAGE fields for the following ten sections. Page 1 belongs to the beginning of the document; Chapter 1 continues that count. No chapter restart is configured. The package preservation check passed for original content, tables, TOC fields, styles, media and section layouts. Backups and a verification report are retained. Final rendered pagination, footer placement and contents page references require desktop Word review; no exact first chapter page number or page total is asserted. No application, schema, setup or deployment changes occurred.

## Contents page references refreshed

- All 39 contents entries now use page references calculated by Microsoft Word.
- Chapter 1: page 7; Chapter 2: page 22; Chapter 3: page 29.
- Preliminary pages remain counted with their footer numbers hidden.

Speaker notes: Word successfully repaginated the combined manuscript and reported 150 pages. The earlier all-page-1 contents cache was replaced with the actual refreshed reference values. Preservation checks verified heading order, bookmark destinations and unchanged body content, tables, styles, media, footer numbering and section layouts. Only 39 cached reference values changed in the final manuscript package. This resolves the earlier pending contents refresh; final visual print-layout review remains separate. Backups and a verification report are retained. No application, schema, setup or deployment change occurred.

## Updated paper prototype figures

- All 57 FEATURES.zip screenshots appear in Figures 6–62.
- Access, administrator, staff, and member flows have matching explanations.
- The Gantt chart is retained as Figure 63.

Speaker notes: The November 11 documentation revision replaces the earlier prototype captures in Chapter 3 and the combined manuscript. It covers recovery, browser approval, session conflicts, trusted-browser logout, attendance lookup, sales and report filters, and member self-service. Images are reproduced in full as supplied, including supplied details. Source matching, captions, relationships and preserved tables are checked separately from the older chapter validator, which still expects an obsolete schema-count sentence. Pagination and contents page references require Word refresh after replacement. No application or schema deployment results from this update; screenshots show interface states and do not establish formal evaluation results.

## Phone scanner approval timing repair

- Recheck device approval after authenticator verification when initial approval was unavailable.
- Show a reload instruction if the approval script fails to load.
- Local regression checks: 14 passed; deployment and physical two-device verification pending.

Speaker notes: A phone scanner screenshot showed an approval-required rejection without a notification. Code inspection reproduced a timing gap in which a trusted browser resumes during MFA after the first approval check returned mfa_required. The shared trust helper now asks again before completing device registration. This explains a possible failure path; the original device's server state has not been inspected. Login, administrator and scanner references use a new script version and the phone shell cache advances to v25. Server security requirements are retained; no database migration or setup change is involved. Automated trust and scanner tests passed all 14 cases. These are local changes, not evidence of hosted deployment or a completed physical two-device test.

## Independent attendance scanner login

- Website: administrator authenticator and trusted-browser verification remain.
- Attendance app: same staff/admin username and password; no authenticator or website approval.
- Website and scanner sessions coexist; phone pairing is still required to record attendance.
- Scanner access is restricted to attendance endpoints and cannot read website tables.

Speaker notes: This user-requested design supersedes the earlier attempt to repair scanner device approval. The app now uses a private, server-bound scanner session marker and narrow identity/status/scan/audit RPCs. It replaces only another scanner session and does not transfer website device trust. Website trust registration and forget-device actions preserve scanner access. Migration 20261111000001 was reviewed by linked terminal dry run and successfully applied to nttsrdassmzvtaamyogi; the installed CLI applied without an interactive confirmation prompt. Fifteen browser/Edge unit tests, the new PostgreSQL-compatible scanner isolation suite, and existing administrator-trust and reliable-scanning SQL suites passed locally. The phone shell is v26. Hosted frontend delivery, installed-app refresh and physical two-device testing remain unverified; these local test results do not establish a production or usability outcome. No accounts, passwords, authenticator factors or phone pairings were reset.

Speaker notes — completed verification: Verification completion: Desktop Word successfully repaginated the updated combined manuscript and reported 172 pages. The rebuilt contents includes the replacement subsection headings and its links resolve to existing bookmarks. The final refreshed copy preserves all non-contents body paragraph/table text and all 15 sections' page-size, margin and page-number settings. All 57 embedded prototypes passed source matching; four Word-recompressed images passed aspect and appearance checks. The refreshed copy is saved as Chapters 1-3 with Table of Contents.docx. This completes the contents refresh mentioned above; final visual print-layout review remains separate. See Review Evidence/FEATURES Manuscript Verification.txt. Earlier 150-page contents status describes the prior manuscript.

## Approve a scanner handoff before logout

- First phone receives Approve / Deny for another scanner using the same account.
- Pending, rejected, cancelled or expired requests leave the first scanner signed in.
- Approval alone keeps the first phone active; the approved phone must complete activation.
- Scanner stays password-only; website authenticator and device trust remain separate.

Speaker notes: The user identified the first scanner as the device that unexpectedly logged out and selected first-phone approval as the desired behavior. The original password-only scanner implementation immediately replaced its attendance session. The new scanner-specific approval table/RPCs bind the decision to the requesting and approving Auth sessions, with a two-minute request expiry. The first phone polls every three seconds while open and online; failed decisions remain retryable. Timeout does not grant access. Change operator explicitly releases the caller's scanner session. Legacy administrator-trust attendance login paths are blocked so old clients cannot bypass the handoff. Scanner UI/worker versions advance to handoff and shell v27. Twenty browser/Edge tests and the expanded scanner SQL integration suite passed locally. Linked terminal dry runs reviewed only migration 20261111000002; push successfully applied it to nttsrdassmzvtaamyogi without an interactive prompt. Matching frontend delivery and physical two-phone notification/handoff testing remain unverified. The earlier hosted HTML check confirmed the password-scanner revision, not this new handoff revision. No authenticator factors, credentials or phone pairings were reset.

## Clear recovery for expired pairing references

- Expired or ended pairing references stop polling and are removed from the admin browser list.
- Other pairings remain intact; connection errors retain saved references.
- The admin no longer incorrectly instructs users to apply an archived migration.

Speaker notes: The reported screenshot came from the admin phone status check. Its RPC uses an inactive/expired error for a missing, expired or differently owned pairing reference, while the UI previously appended migration advice to every error. The new frontend handler cleans up only the stale local reference and directs the operator to Phone Camera to inspect paired phones or create a QR. It does not delete database pairings or reset phone storage, credentials or authenticators. JavaScript syntax and four admin attendance tests passed. Affected modules are the admin JavaScript, HTML version reference and tests. No schema/setup change or database push is needed. Matching frontend deployment and physical reproduction remain unverified; the screenshot alone does not establish the exact server record state.

## Make scanner approval visible and diagnosable

- Approve/Deny opens as a modal above the camera.
- The signed-in scanner shows request-check status and an immediate retry button.
- Check failures remain visible; they do not approve or replace a session.

Speaker notes: The user reported a waiting incoming phone and an open, signed-in first phone without a visible approval. Earlier notification polling silently discarded RPC errors and used a page panel. The revised scanner uses a modal dialog plus listening/failure status, sanitized error codes, and Check sign-in requests. Local tests cover dialog opening, approval and retry after polling failure; all 14 scanner/notification tests passed. Versions advance to visible-approval and shell v28. This is a frontend change, with no database migration or website MFA change. Matching frontend deployment, physical-device confirmation and the exact cause on the originally reporting first phone remain unverified. This update does not prove that the original issue was only camera stacking or caching.

## Refresh without requesting approval again

- Refresh restores the same tab-scoped scanner session after server validation.
- Replaced sessions remain blocked; passwords are not stored.
- Recover inactive session is explicit and requires two minutes without scanner activity.
- Active scanners still require Approve/Deny; request expiry alone grants no access.

Speaker notes: The reported lockout followed a refresh. The old scanner kept Auth only in memory while its server attendance session survived, leaving a ghost approver. The new sessionStorage client restores the same scanner without new activation or approval, restarts its monitor/listener, and retains the session on transient network failures. Closing the tab/app or clearing storage is separate from refresh. Migration 20261111000003 adds last-seen heartbeat timestamps and atomic, audited recovery for an explicitly requested replacement after two minutes of inactivity; a backgrounded phone may become inactive under this rule. Denied/cancelled/consumed requests cannot use recovery in the same requester session. This extends the earlier no-offline-recovery design while keeping website MFA and phone pairing separate. Twenty-four browser/Edge tests and the expanded scanner SQL suite passed locally. The linked terminal dry run listed only migration 03 and push reported successful application to nttsrdassmzvtaamyogi without an interactive prompt. Frontend versions are session-recovery and shell v29. Hosted delivery and physical-device refresh/recovery testing remain unverified.

## Clarify a missing scanner connection

- An admin pairing label does not prove this app/browser still has its saved connection token.
- The scanner directs users to reopen the app in the browser used for pairing.
- Ask the admin to inspect the pairing before ending it or issuing another QR.

Speaker notes: The user reported that the admin listed the Reno phone as paired while the phone scanner said it was not paired. The pairing ID/token is saved in browser storage and validated separately against the server; the exact cause on the reported device is unconfirmed. The scanner's missing-local-connection status now explains this distinction and avoids claiming that the server pairing is absent. A truly expired or revoked saved connection still uses the existing re-pair flow. The scanner script URL and service-worker shell advance to v30. No schema or server state changed. Source inspection and whitespace validation only; automated and physical-device checks, frontend deployment, and reproduction remain pending.

## Activity Logs in split view

- At narrow viewport widths, each event uses a readable card layout.
- Expanded event details span the full card width.

Speaker notes: A user screenshot showed Activity Logs details squeezed into a narrow table column in an IDE split view. The container-based responsive breakpoint did not reliably follow the visible pane, leaving the desktop table active. A viewport breakpoint now switches to two-column event cards through 1024px and one-column cards through 560px; details span the card. The stylesheet cache version was refreshed. No data or schema changed. Source inspection only; browser review, deployment, and production behavior remain unverified.

## Recover when no scanner is in use

- A recorded scanner session does not prove a phone is currently in use.
- Try Recover inactive session immediately when nobody is using another scanner.
- The server blocks recovery if the previous scanner recently reported activity.

Speaker notes: A staff sign-in remained waiting although the user reported no other scanner in use. The status reflects a recorded server session, not proof of a person currently signed in. The dialog now offers immediate recovery; the server still requires two minutes without heartbeat and rejects a recent heartbeat. Approval and recovery policy/database behavior are unchanged. Frontend script and service-worker shell advance to recovery guidance/shell v31. No schema change. Source inspection only; physical-device reproduction and deployment remain pending.

## Improve admin toast contrast

- Admin success and error toast messages use readable light text on the dark toast surface.
- Registration approval and payment behavior are unchanged.

Speaker notes: The user screenshot showed the registration approval success toast with dark text on a dark background. The shared toast rule now sets an explicit light text color so it remains readable when the page uses the light theme. The admin stylesheet cache version was refreshed. No workflow or data changes. Source inspection only; browser verification and deployment remain pending.

## Keep Store password controls aligned

- The visibility control stays inside the Store password field.
- The Open Store button keeps its own space; narrow phone layouts stack the controls.

Speaker notes: A screenshot showed the password visibility control overlapping the Store password field and submit button. CSS now reserves input space for the eye control, positions it within the field, prevents submit-button shrinking, and stacks the form at phone widths. Store authentication is unchanged. The admin stylesheet cache version was refreshed. Source inspection only; browser validation and deployment remain pending.

## Inventory section naming

- Admin navigation and lock screen call the section Inventory.
- The unlock action is labeled Open Inventory.
- Existing access control and inventory behavior remain unchanged.

Speaker notes: Updated the admin-facing Store & Inventory wording to Inventory for consistency with the section's function. The internal section key and password check remain unchanged. This label-only UI change affects admin.html and does not change data or permissions. Source inspection only; browser review and deployment remain pending.

## Theme-aware admin notifications

- Toasts use dark surfaces in dark mode and light surfaces in light mode.
- Success and error messages have matching readable text and accent colors.
- Shared modal and approval surfaces have existing light-theme styles.

Speaker notes: The registration success toast remained dark in light mode because only its text contrast had been corrected. The admin stylesheet now gives neutral, success and error toasts theme-appropriate surfaces and text/accent colors. Existing dark-mode appearance and application workflow are unchanged. Source review only; visual checks across popups/pages and deployment remain pending.

Theme follow-up: Member notifications use the same shared toast stylesheet; the member page cache version was refreshed too. The source review checked common shared popup surfaces, but does not establish visual acceptance across every page.

Inventory toggle follow-up: The earlier adjustment did not remove the visible overlap; the global focus-visible halo extended beyond the eye button. The eye control now sits farther inside the field with a compact focus outline and wider separation from Open Inventory. Admin stylesheet cache version refreshed. Source inspection only; visual browser confirmation and deployment remain pending.

Inventory password toggle correction: The reveal button is disabled only for the Inventory unlock field to eliminate the persistent overlap; other password fields keep their reveal controls. The input and submit button use a direct responsive layout. Store password behavior is unchanged. JavaScript syntax and whitespace checks passed; visual confirmation and deployment remain pending.

## Staff attendance from member search

- Search by name or Gmail and choose Record attendance on the matching member.
- The existing server flow decides check-in or check-out from the member's latest visit.
- Attendance retains staff attribution and existing duplicate, expiry and retry protections.

Speaker notes: Staff could already search and record attendance after a selection, but the result row lacked a clear action. Each result now has a visible Record attendance control that calls the existing server attendance RPC using the member UUID. No schema change. JavaScript syntax and whitespace checks passed; automated and hosted/physical acceptance remain pending.

Staff fallback guidance: If a member has no QR or the camera cannot scan it, staff can search by name or Gmail and record attendance from the matching member result. Existing server authorization, membership checks and attendance logic apply. Copy-only follow-up; no schema change. Browser acceptance and deployment remain pending.

Staff attendance UI polish: The attendance area distinguishes QR scanning from name/Gmail fallback with a clear heading and supporting instruction; each matching member retains a Record attendance action. Dark and light theme styles were added for the section headings and divider. No workflow/schema change. Source inspection only; browser review and deployment remain pending.

## Keep prior incomplete visits intact

- A missing checkout from a previous Manila calendar day stays Incomplete.
- A returning member gets a new check-in; the old record is not closed by that scan.
- Same-day checkout and existing duplicate, expiry and authorization checks remain.

Speaker notes: The old attendance function checked out any latest open row, even when it was from an earlier day. Migration 20261111000004 limits checkout to an open visit whose check-in is today in Manila; otherwise an eligible return creates a new visit. Migration has been applied to linked project nttsrdassmzvtaamyogi as recorded below; physical attendance acceptance remains pending.

Deployment status update - November 11, 2026: The linked dry-run for nttsrdassmzvtaamyogi listed only migration 20261111000004_preserve_incomplete_attendance.sql, and the linked push reported it applied successfully without an interactive prompt. The database rule is deployed; physical attendance acceptance remains pending.

Staff stock visibility: Product choices show available stock quantity and unit; unavailable products stay disabled. Staff can search the live catalog by product/size and filter to available stock. No sale workflow or schema change. JavaScript syntax and whitespace checks passed; browser review and deployment remain pending.

Merchandise catalog organization: Staff and members can browse merchandise in separate size sections, each showing an item count. Staff keeps the product/size search and available-only filter. Inventory records and checkout behavior are unchanged. JavaScript syntax and whitespace checks passed; browser review and deployment remain pending.

Staff catalog readability: The live inventory uses a maximum of four cards per row with responsive narrower layouts, stronger type/size headings, clearer stock text, and a note distinguishing stock browsing from sale entry. No inventory or checkout behavior changed. Whitespace check passed; browser review and deployment remain pending.

Staff inventory view: The live catalog now uses compact responsive rows with product identity, stock quantity/status and price, while keeping search, availability filtering and merchandise size sections. No inventory or checkout behavior changed. JavaScript syntax and whitespace checks passed; browser review and deployment remain pending.

Staff inventory controls: A compact overview shows product-variant availability counts, and category filters let staff focus on all products, supplements or merchandise. These combine with search and the Available only filter. Counts refer to variants, not summed stock units. No inventory or checkout behavior changed; JavaScript syntax and whitespace checks passed. Browser review and deployment remain pending.

Staff inventory filter simplification: Replaced multiple summary tiles/category buttons with a search, one category dropdown, Available only checkbox and inline matching/in-stock count. Filters combine; no stock or checkout behavior changed. JavaScript syntax and whitespace checks passed; browser review and deployment remain pending.

Staff member selection spacing: Hidden member-summary panels now stay hidden until a member is selected, removing an empty bar from renewal and plan-change forms. No membership behavior changed. Whitespace check passed; browser review and deployment remain pending.

Staff membership form refinement: Complete Renewal and Save plan change buttons now use compact content-sized widths and consistent touch sizing. No membership behavior changed. Whitespace check passed; browser review and deployment remain pending.

Member mobile attendance: Narrow layouts show attendance entries as labeled cards for date, check-in/out, duration and status; desktop retains the table. Attendance data and calculation behavior are unchanged. JavaScript syntax and whitespace checks passed; mobile browser review and deployment remain pending.

Member attendance table adjustment: On narrow screens, the member history retains its table and scrolls horizontally like staff attendance, with a swipe hint and non-wrapping date/time cells. No attendance data change. JavaScript syntax and whitespace checks passed; mobile review and deployment remain pending.

Admin approvals navigation: Opening Membership > Approvals resets the view to the membership panel header after rendering, avoiding a stale deep scroll position. Approval behavior/data unchanged. JavaScript syntax and whitespace checks passed; browser review and deployment remain pending.

## Scanner layout and manuscript consistency review

- Pairing setup and camera actions take priority; operator and optional controls are compact.
- The supplied complete DFD replaces the five old panels in Chapter 3 and the combined manuscript.
- Preserved tables and 57 prototypes; verified and refreshed 38 contents references.
- Main scope is consistent; security wording, full dictionary and selected DFD flows still need correction.

Speaker notes: The scanner UI cleanup keeps automatic approval dialogs, errors and authorization behavior while reducing repeated status and oversized optional controls. The layout uses scanner-layout script references and shell v32; seventeen scanner/notification tests passed, with physical visual review and hosted delivery unverified. The subsequent user-authorized paper review used the exact supplied SVG, embedded as vector with fallback, and retained backups and an editable source. Chapter 1 and Chapter 2 were not edited. DFD replacement preservation checks and the 57-prototype verifier passed. Desktop Word reported 168 pages and the existing 38 TOC entries retained their heading/bookmark identity; only page-reference cache values were applied. Chapter starts remain 7, 22 and 29. The helper's obsolete 39-entry/150-page assumptions were removed. This is not a claim that every diagram is correct: the review report identifies legacy D12 and log-viewer routing, outdated scanner trust statements, and missing current private scanner tables. Repository-derived totals are 23 tables/235 fields/38 FKs, compared with the paper's old 21/224/33 baseline; no live schema introspection was performed for the review. Final print-layout approval and those content corrections remain pending. No evaluation results, dates of client activities, deployment results or production outcomes were invented.

## Full-page landscape DFD

- Complete supplied SVG enlarged to ten inches wide on a dedicated landscape page.
- Heading and caption stay with the diagram; explanation begins on the next portrait page.
- Manuscript wording, tables, source SVG and footer files are preserved.

Speaker notes: This is the user's requested presentation/layout change in Chapter 3 and the combined manuscript. Desktop Word verified diagram/caption placement on physical pages 20 and 47, and the following portrait explanation on pages 21 and 48. The checked layout reported 142 standalone Chapter 3 pages and 167 combined pages. The aspect ratio is preserved; the original arrows are not redrawn and earlier semantic review findings still apply. No page-number restart was added. Backups and layout/pagination reports are retained. The optional PDF preview export was omitted after stalling; the source manuscripts are the delivered artifacts. The combined contents was staged for a separately verified refresh. These checks do not substitute for final paper-size readability review, and no application/schema/deployment change occurred.

Speaker-note completion update: All 38 Word-derived contents entries were refreshed and verified. Because the original combined file was locked, the complete deliverable is Chapters 1-3 with Updated Table of Contents.docx, containing both the landscape DFD layout and refreshed contents. Chapter 3.docx was updated directly. The TOC helper uses shared read hashing with unchanged-source verification and saves a separate output instead of forcing a locked-file replacement. The final combined pagination reported 167 pages. No application/schema/deployment changes occurred.

## Diagram-description clarity revision

- Updated Chapter 3 and the combined manuscript with reader-oriented descriptions for Agile, Context, DFD, Use Case, ERD, and Gantt diagrams.
- Each explanation now states the diagram's purpose, notation, reading method, relevant actors/processes/relationships, and limits.
- Website administrator device trust is explicitly separate from password-based attendance-scanner sessions and their scanner-to-scanner approval handoff.
- ERD text identifies the checked-in migration baseline as 23 application tables, 235 fields, and 38 declared foreign keys; this is not represented as a live-database inspection.

Speaker notes: Describe the figures as complementary views: Context identifies external exchanges; DFD follows logical inputs, processes, and stores; Use Case identifies role participation but does not grant every sub-action; ERD identifies declared storage relationships, not access rights; Agile shows a repeatable development cycle; Gantt is an original planned schedule rather than proof of completion. The revised text preserves verified-versus-pending distinctions. Document package checks found the five key explanatory anchors in both delivered documents. No implementation, schema, deployment, physical-device, or evaluation outcome changed.
## Slide 19 - Password recovery email
- IronGrind dark and red branded recovery email draft
- Secure reset link and copyable fallback link
- Hosted Auth template and fresh email verification pending

Speaker notes: The local template at `supabase/templates/reset-password.html` uses Supabase's `{{ .ConfirmationURL }}` for both links so Supabase token verification and the requested redirect are preserved. It includes a branded reset button and explains that an unrequested message can be ignored. This is a local HTML artifact intended for Supabase Auth email-template settings; it has not been applied to the hosted dashboard. No schema or runtime code changed. A fresh email and completed password recovery remain unverified. The existing reset page and redirect target are already in the local/deployed client as described in the recovery notes; do not describe the email design as deployed.
## Chapter 3 consistency correction

- Revised opening deployment and verification wording to separate recorded evidence from later pending acceptance checks.
- Separated website administrator trusted-browser/TOTP from attendance-scanner password sessions, scanner handoff approval, and recovery.
- Added the two scanner private tables to the dictionary, reconciling it with the 23-table migration model.

Speaker notes: Explain that a website browser-trust transfer and an attendance-scanner handoff are different security workflows. The first protects website administrator access; the second requires the active scanner to approve or deny a different scanner for the same authorized operator. `session_scope` belongs in the shared account-session model, not `attendance_operator_sessions`. The revision improves traceability between requirements, workflows, the data dictionary, and migrations. It does not claim a new release, physical-device test, or evaluation result.