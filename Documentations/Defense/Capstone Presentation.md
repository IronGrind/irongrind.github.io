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

Speaker notes: A browser role marker is not a security boundary. The publishable key is used with protected APIs; service-role credentials remain server-side. Do not describe this implementation as React or Next.js. pgAdmin inspects the connected database; it is not automatically a separate source of truth.

## Slide 7 — Development and evidence
- Iterative planning, implementation, testing and revision
- Source history and migrations show recorded changes
- Automated fixtures verify selected browser and database behavior
- Stakeholder evaluation and production validation require separate evidence

Speaker notes: Explain Agile using the documented project process, not an invented sprint schedule. The historical November 8 report records forty check groups; it is not a fresh count for every later change. Screenshots show interface states, not measured performance or user satisfaction.

## Slide 8 — Application to active membership
- Applicant submits account and membership information
- Authorized operator reviews the pending request and gym payment
- Approval creates or updates applicable membership records
- Member signs in to access only permitted own information

Speaker notes: Distinguish Auth account, application, profile and approved member record. A pending application does not mean active membership. Demonstrate the real counter payment step without implying online payment verification.

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

Speaker notes: Show the scanner install button and distinguish member QR from pairing QR. The scanner page has a local visual refresh aligned with the app's dark navy and red styling; it does not change its workflow. If browser storage is cleared or a pairing expires, recovery/new pairing may be necessary. Cached shell does not provide offline attendance writes. Administrator scanner operators also complete MFA after deployment. The updated page has not been device/browser reviewed or deployed, so capture replacement slides only after that review.

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
- Keys, constraints and relationships support consistency
- Data dictionary supplies full definitions behind the readable ERD

Speaker notes: The current Chapter 3 manuscript documents 18 application-owned tables, 201 fields and 27 declared foreign keys, reconciled from the supplied pgAdmin baseline and migrations through 20261110000004. This is not fresh live-schema introspection. Figure 5 retains the readable twelve-public-table ERD; Figure 5a shows the three private admin security tables and six Auth references. Repeated Auth reference cards denote the same managed tables, not additional application tables. The dictionary preserves five individually unique fields and the approval composite unique pair. Figure 3b supplements the detailed nine-function DFD with three individually named administrator security stores. A separate member-device feature is implemented locally but is not yet part of the Word chapter or diagram; it adds three private tables and remains undeployed. Do not combine its source-defined counts with the manuscript counts. User-supplied CLI output confirms admin trust migration/function deployment, not member-feature deployment or live browser acceptance.

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

Chapter 3 Figure 3 now opens with a simplified DFD overview: three roles, nine functions grouped into four areas, and logical record categories. Figure 3a follows with the detailed individual-store diagram; Figure 3b isolates the administrator login-security stores. The overview was inserted and its embedded image matches the generated source; final Word pagination review remains pending.

## Slide 16 — Testing and limitations
- Unit and simulated UI tests cover selected workflows
- Isolated SQL tests check permissions, transactions and MFA denial paths
- Real devices, hosted settings and complete visual flows still need verification
- Historical screenshots and planned schedules are labeled honestly

Speaker notes: Present the actual saved test output, not an invented overall pass rate. MFA tests prove AAL1 denial/AAL2 access in fixtures; they do not prove the deployed project's Auth configuration. Formal usability results must be added only after real evaluation. Keep production data out of demonstrations where possible.

## Slide 17 — Deployment and recovery
- Enable hosted TOTP and coordinate client, functions and SQL migration
- Genuine administrator enrolls and verifies the authenticator
- Test admin, staff, member and scanner paths after deployment
- Lost authenticator requires verified project-owner recovery
- Deploy the separate member-device approval flow; members do not receive an authenticator-code step
- Password recovery targets the allowlisted reset page from local and preview origins

Speaker notes: Follow Admin MFA Setup and Deployment Guide.md for administrator TOTP. Local config.toml edits do not automatically change hosted Auth settings. A November 10 read-only check confirmed the name-validation, security-event and MFA migrations were pending remotely; the later user-supplied CLI output reports those three migrations applied. It does not independently verify hosted Auth settings, deployed functions/client or actual authenticator login. Do not disable administrator MFA enforcement to recover an account. Project owner verifies identity, uses supported administrative factor reset and supervises re-enrollment. The application does not provide backup codes. User-supplied CLI output confirms the administrator trusted-device migration and function deployment; matching browser acceptance remains unverified. A separate local member-device increment adds three private tables and `member-device-trust`. Members enroll a signing key on first eligible sign-in; a new browser asks the currently trusted member dashboard to approve it. The member flow has no authenticator factor or code, and password-based recovery remains possible when no trusted member session is available to approve. The migration, function and web client have not been deployed or tested on the hosted project. Follow Member Device Approval Guide.md and record actual results before claiming success.

Password recovery note: The linked Supabase config diff showed the hosted Site URL is `https://irongrind.github.io` and the allowlisted recovery destination is `https://irongrind.github.io/reset-password.html`. The client now targets that exact destination instead of constructing one from the current origin. The code change is local, has not been deployed, and still needs a fresh-email browser check. If the hosted email template was customized to link directly to the Site URL rather than Supabase's confirmation URL, review it so recovery token verification and redirect are preserved.

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

Staff member creation now checks membership plans, prices and exact durations on the server and requires the current Philippine business date, preventing client-submitted terms from being trusted. Date-only inputs are validated before account creation. Focused Node tests passed for the validation rules and Activity Logs UI fixture (6/6); syntax and whitespace checks passed. A member-device SQL regression fixture now covers enrollment, approval/transfer, session revocation, denial, expiry and access boundaries, but it could not be executed because the local PGlite runtime is absent. The changes remain local and undeployed; hosted function/database verification is pending.
