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
- Member profile sections stay in a fixed, responsive settings window

Speaker notes: Distinguish Auth account, application, profile and approved member record. A pending application does not mean active membership. Demonstrate the real counter payment step without implying online payment verification. New registration is handled by `member-registration`: it creates the Auth user, then stores the pending application; the signup call sends the confirmation email. If application storage fails after account creation, it attempts to delete the new Auth user; cleanup failures are reported for staff follow-up. Existing Auth accounts with no application can authenticate and submit one application; the flow checks for an existing membership/pending application before inserting. A duplicate-email response may come from an earlier or unfinished account/registration; use password recovery if needed or ask staff to check a pending record. The member settings dialog keeps a steady size as Personal Info, Emergency Contact, Health & Fitness, Login Email and Password sections change; its content scrolls inside the dialog, and the dashboard behind it remains modal/inert. These local UI changes have not been browser-accepted or deployed.

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
- Twelve public application tables and six private supporting tables
- Managed Auth users remain separate from public application tables
- Complete DFD SVG uses exact table names without schema prefixes; repeated stores refer to the same table
- Figures 5a-c show the main physical relationships; Figure 5d shows administrator security storage
- Data dictionary follows the Chapter 3 sample: field, type, length/precision, key, and validation details

Speaker notes: Chapter 3 now follows the supplied five-column dictionary format, separating declared lengths and precision from field types and retaining constraint details in the descriptions. The Entity Relationship Diagram heading matches the supplied chapter structure. All 201 fields, existing diagrams and prototype images are preserved; this documentation revision changes no deployed behavior. Final desktop Word pagination remains pending. The current Chapter 3 manuscript documents 18 application-owned tables, 201 fields and 27 declared foreign keys, reconciled from the supplied pgAdmin baseline and migrations through 20261110000004. This is not fresh live-schema introspection. The simplified public-schema overview ERD is omitted. The earlier physical ERD layout is restored: Figures 5a-c show the existing 15-table relationship model and 21 foreign keys; Figure 5d shows the three administrator-security tables and six references to managed Auth tables. The DFD follows the original multi-panel style in Figures 3a-e, with Figure 3f isolating administrator login-security stores D15-D17. A complete Level 1 SVG is available separately as `03-dfd-complete-gane-sarson.svg`. Its corrected stores display exact table names without schema prefixes (for example users, profiles and account_sessions), with schema-qualified mappings checked internally against the documented schema baseline, including managed auth.users; generic aliases, duplicate security stores and reserved placeholders are removed. The deployed member-device tables remain excluded from the existing Chapter 3 manuscript baseline; update the paper and figure set separately to match the live schema. The generator validates table mappings; SVG XML and store inventory checks pass. This local SVG correction does not update the Word manuscript or verify the live database. Repeated Auth reference cards denote the same managed tables, not additional application tables. The dictionary preserves five individually unique fields and the approval composite unique pair. Structural verification confirms all 23 Word tables and 201 dictionary fields remain unchanged. The figure/layout update is documentation-only; no application or database deployment resulted. Desktop Word pagination review remains pending. The member-device feature is deployed through migration 20261110000006 and its login/trust Edge Functions, and the three new tables are now included in Figure 5e and Tables 24–26. Controlled browser acceptance remains pending. Safe endpoint probes confirm availability, not successful browser acceptance.

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

Chapter 3 uses the original multi-panel DFD layout: Figures 3a-e continue the nine processes and Figure 3f isolates the administrator login-security stores. The separate complete Level 1 SVG is at `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. Final Word pagination in desktop Word remains pending.

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

Chapter 3 uses the original figure presentation: Figures 3a-e contain the nine-process DFD, Figure 3f is the administrator security-store supplement, Figures 5a-c show the main physical relationships, and Figure 5d shows the new administrator-security schema. A standalone Gane-Sarson Level 1 SVG with all nine processes is supplied at `Documentations/Chapter 3 Diagrams/03-dfd-complete-gane-sarson.svg`. Chapter 3's 23 tables and 201 dictionary fields remain unchanged. Final Word pagination in desktop Word remains pending.
