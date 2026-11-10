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

Speaker notes: Show the scanner install button and distinguish member QR from pairing QR. If browser storage is cleared or a pairing expires, recovery/new pairing may be necessary. Cached shell does not provide offline attendance writes. Administrator scanner operators also complete MFA after deployment.

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
- Twelve public application tables and three private supporting tables
- Managed Auth users remain separate from public application tables
- Keys, constraints and relationships support consistency
- Data dictionary supplies full definitions behind the readable ERD

Speaker notes: Use the reviewed ERD and dictionary. The reviewed export has 174 fields, 21 FK definitions and five unique fields. The earlier MFA baseline adds functions/guards only. The subsequent local approval increment adds one private supporting table with eleven fields and three managed-Auth references; the twelve public application tables are unchanged. The latest trust increment extends the local target supporting schema to 201 fields across twelve public and six private tables. Use the supplements and refresh full supporting dictionary/DFD evidence after deployment. Do not claim unrelated tables are linked by a declared FK without checking the schema.

## Slide 14 — One trusted administrator browser
- First registration verifies the authenticator and browser signing key
- Repeat login on that trusted browser: password plus automatic key proof
- New browser: current-device approval, then fresh authenticator verification
- Successful transfer revokes old device trust; normal logout retains trust

Speaker notes: This latest local increment supersedes the earlier approval-only model. One browser key is trusted per admin account for 30 days. Its private key remains non-extractable in IndexedDB; the server stores only the public key. New browser access is blocked until approval and fresh TOTP have both completed. The server transaction preserves old trust if verification fails and atomically replaces it only on success. Old dashboard/scanner scopes are revoked when trust moves. No live eligible approver means fresh authenticator recovery; a two-minute heartbeat window defines recent activity. Forget-device explicitly revokes trust, while normal logout retains it. This is origin/browser trust, not a hardware identity or protection against every XSS attack. User-supplied CLI output confirms migration 20261110000004 and admin-device-trust deployed successfully. Matching frontend deployment, first registration, repeat-login reuse and physical transfer tests still require verification. No SMS is used and no private key or TOTP secret belongs in slides.

## Slide 15 — Accountability and session behavior
- Readable actions, category badges and expandable log details
- Filter by account, category, action and Philippine date range
- Operational/security events exclude passwords and tokens
- Explicit logout differs from expiry or session replacement

Speaker notes: Failed attempts are unverified events, not proof that the named account owner acted. Export requests do not prove files were saved. Custom logging does not mirror every MFA Auth audit event. Routine page views/searches are not comprehensive activity events. Main dashboard and scanner session ownership remain separate.

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

Speaker notes: Follow Admin MFA Setup and Deployment Guide.md. Local config.toml edits do not automatically change hosted Auth settings. A November 10 read-only check confirmed the name-validation, security-event and MFA migrations were pending remotely; the new login therefore fails closed until setup is completed. The later user-supplied CLI output confirms all three migrations were applied successfully. This does not independently verify Auth settings, deployed functions/client or actual authenticator login. Do not disable MFA enforcement casually to recover an account. Project owner verifies identity, uses supported administrative factor reset and supervises re-enrollment. The application does not provide backup codes. The local trusted-browser increment adds two further private tables and a snapshot field on approval requests, with a new server function for signature validation; the earlier three-migration push was followed by user-supplied output confirming this fourth migration applied successfully. A real approval/denial test is still pending.

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
