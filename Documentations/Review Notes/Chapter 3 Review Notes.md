## Prototype whole-screenshot presentation - November 10, 2026

Updated Chapter 3 at the user's request: all 27 supplied original screenshots now appear whole as the main Figures 6-32. Eight supplementary enlarged views are retained only for the online registration form, administrator walk-in form, and staff add-member form (Figures 7a-c, 12a-c, and 26a-b). Other formerly split screens now use their complete captures. Captions and explanations distinguish the complete layout from supplementary details. The Gantt remains Figure 33.

Verification confirms 27 complete original main-image files with no Word crop settings, 8 selected detail images, unique captions, matching embedded images, and all 15 dictionary tables/174 descriptions preserved. The current individual-store DFD, ERD and use-case images are unchanged. Earlier split-image presentation notes below are historical. Superseded crop files were archived under Prototype Screenshots/_Sources/Previous cropped presentation.

---

## DFD individual-store correction - November 10, 2026

Per the adviser's requirement, Figure 3 now shows fourteen individual data-store symbols: D0-D11, D13, and D14. Each has its own name and identifier; no comma-separated or range-based store groups remain. Report generation reads seven separately drawn stores, D2 through D8. All nine processes remain. Chapter 3 embeds the revised SVG and PNG and explains the individual-store model. Earlier grouped-store diagram files are archived under Chapter 3 Diagrams/_Archive/Previous DFD Versions. Prototype screenshots and their formatting were not changed by this correction.

## Simplified DFD overview

At the user's request, Chapter 3 Figure 3 now starts with an at-a-glance overview: the three actor groups, all nine system functions grouped into four areas, and five logical record categories. A visible note explains that these categories are for readability and do not combine physical tables. The detailed DFD remains as a companion and retains individually identified data stores and specific actor/process/store flows. The overview PNG was visually inspected and its copy inside Chapter 3.docx byte-matches the generated source. Full Word pagination and final thesis review are pending.

---

## Prototype update - November 10, 2026

Chapter 3 now uses all 27 screenshots supplied in UI AND FEATURRES.zip, arranged as Figures 6-32 by access, administrator, staff, member, and session workflows. Long captures are presented in 38 total readable parts. Complete originals are retained in Prototype Screenshots/Originals; the figure index identifies every source. The existing Gantt image and date narrative are unchanged; its caption is now Figure 33.

Each figure has a caption and an operational explanation. Explanations distinguish member self-service from staff counter services and administrator controls; remembered identifiers from passwords; pairing setup QRs from member attendance QRs; pending reservations from completed pairings; internal transactions from customer receipts; and captured screen values from evaluated results. Older report-preview, print-preview, profile-edit, QR-display, and staff-workflow illustrations were replaced by the actual supplied captures rather than presented as screenshots that were not provided.

The following capture wording remains in the supplied screenshots and in the current UI source; application code was not changed during this paper update:

- admin.html describes staff access as attendance-only, while the implemented staff workspace also supports counter membership, sales, and request-review operations. The prototype explanation states the broader actual scope.
- register.html's short introductory sentence mentions gym-admin review, while authorized staff can also review requests. The detailed explanation retains both reviewer roles.
- The administrator registration approval button says Approve & Create Account. The documented workflow retains the distinction between the applicant Auth account and the approved member record; it does not infer account creation timing from the label.

The supplied administrator Add New Member screenshot uses one full-name input; staff registration uses separate name fields. The generic end-to-end counter sentence was adjusted to avoid claiming both interfaces have the same separated-name inputs.

Optional captures for a later completeness pass: opened member profile-edit form, opened member QR, report preview/print output, staff direct-renewal and plan-change states, and a working camera/scanning result. The current section does not claim those states were pictured.

Verification: 27 originals covered; 38 captions and descriptions each present once; every embedded PNG matches its source full capture or lossless part; drawing IDs unique; original DFD, ERD, use case, Gantt and other existing media unchanged; all 20 requirements/dictionary tables preserved. Chapter 3 verification passed for the 15-table, 174-field dictionary and its 21 foreign keys. No Gantt schedule changes or new evaluation claims were made.

---

Historical review entries below describe earlier versions; the latest manuscript and current verification report take precedence.

# Chapter 3 review

Dictionary correction: restored the Description column inside every dictionary table. The current layout is Name / Type / Constraints / Description. All 174 field-purpose descriptions were recovered from the retained field notes, with declared types, PK/FK/UQ roles, nullability, referenced columns, update/delete actions and CHECK information retained. The three-column presentation described below is superseded.

Current dictionary presentation: all fifteen dictionary tables now use the requested Name / Type / Constraints layout. Declared varchar lengths and numeric precision/scale are retained directly in Type. Constraints retains PK/FK/UQ roles, identity generation, nullability, all twenty-one foreign-key targets and update/delete actions, composite-key membership and verified CHECK details. All 174 fields remain. Former field-purpose text is retained in Chapter 3 Diagrams/data-dictionary-field-notes.md; the paper's entity-purpose paragraphs remain. Legacy member username behavior is explained beside the dictionary. Table headers repeat across pages; data rows use regular Times New Roman and cannot split across pages. The five requirements tables and ERD image links were preserved.

Latest ERD scope: Figure 5 now includes all twelve public tables and all eighteen foreign keys declared on those tables. The managed auth.users id is an additional reference card and does not count as a public table. The figure is a single landscape overview with all PK/FK columns and selected descriptive fields; the 162 public fields and three private tables remain fully documented in the unchanged fifteen-table, 174-field dictionary. Lines use separate tracks and marked crossing gaps. Chapter 3's caption, scope, relationships and twelve entity descriptions were aligned to this figure, and a landscape section isolates the figure from the surrounding portrait pages. This replaces the earlier seven-table core view without changing the data dictionary format.

ERD page layout correction: removed an older schema panel that remained after Word renumbered image relationships. The ERD section now contains one complete figure, sized at 6 x 7 inches, with single-spaced image/caption paragraphs. Its heading starts a new page; heading, image and caption stay together, and the explanation starts on the next page. Verification locates the figure by its section boundaries rather than fixed relationship identifiers.

Current ERD presentation: Figure 5 is now a black-and-white Core Business Entity Relationship Diagram following the professor's simple presentation style. Seven public business entities and their seven mutual foreign-key relationships are shown with selected attributes and crow's-foot optionality/cardinality. Links A and B distinguish the optional unique source-application link from the member-to-many-requests link. The figure has no crossing relationship lines. Supporting identity, phone, audit and security tables are explicitly outside its scope. The full fifteen-table, 174-field dictionary remains and now records PK/FK/UQ keys, nullable/required state, all 21 reference targets with delete/update rules, all five unique-value fields, both parts of the scoped-session composite PK, and verified CHECK descriptions. Full schema figures and sources remain available separately. This supersedes the four-panel presentation described below.

Agile source attribution: added a note immediately below Figure 1, a cited discussion of the article's Agile-adoption perspective, and a full reference for Misa Pavlovic's LinkedIn article (the document preserves the author's accented surname). The original article page displays October 23, 2018; the author-supplied paste displays October 24. The reference uses the original page's date. The wording credits the article as an influence on the approach and makes no unverified claim that its author created the figure template. The reference has a hanging indent and an italic article title.

Latest ERD presentation: Figure 5a-d now uses schema-visualizer table cards, generated from the author-supplied pgAdmin export and checked against the migration baseline. The four PNG/SVG panels display all 15 application tables and 174 columns once in full, with 21 declared FK connections. Repeated reference cards show only existing id columns. PK, FK, UQ and NOT NULL markers explain storage constraints; standalone unique indexes omitted by pgAdmin's ERD script were retained from the baseline. The caption and detailed interpretation were updated, and all four embedded PNGs were checked against the generated figures. This supersedes the earlier relationship-row ERD presentation.

Latest identifier review: members sign in with email and new member records do not receive usernames. The three retained username dictionary fields now distinguish staff/admin sign-in from legacy member/application values kept for compatibility. These nullable schema fields do not imply that member usernames are collected or used for member sign-in.

Formatting pass: removed 252 empty layout-spacer paragraphs, converted the remaining 17 floating figures to inline placement, standardized body text to justified 1.5-line spacing with a true first-line indent, centered figure captions, left-aligned table captions, and used compact single-spaced table paragraphs. Bold formatting is restricted to section headings and table headers. Captions and body/data text use regular weight. Image dimensions were capped to the available page area. Word XML and image links were validated; final pagination has not been rendered in Word.

Latest presentation correction: diagram explanations, rather than dictionary entries, are the expanded prose. Context, Level 1 DFD, UML use-case, physical ERD, and Gantt explanations now discuss interpretation, roles, flow boundaries, relationships, and relevant limitations in fuller paragraphs. The 174 dictionary entries have been shortened to a brief field-purpose sentence plus required/nullable status; their declared length, precision/scale, and key columns remain intact. The earlier notes about detailed dictionary descriptions below describe the prior revision and are superseded by this presentation correction.

The data dictionary has been expanded with substantive field purposes, declared character limits, numeric precision and scale, NULLability, foreign-key targets, and relevant validation details. All 174 entries have a populated Length / Precision / Scale cell: an actual declared size, Not declared, N/A, or the explicit QR-payload check range. No new database limits were invented or applied.

Verified validation distinctions: register.html permits up to 300 characters in the online email input, while the corresponding varchar column allows 254; the staff email form allows 254. The online additional-medical-details textarea allows 500 characters, but the database column remains unbounded text. The paired-device registration function truncates its label to 100 characters while its column remains text. The retained QR-payload column is text with an explicit database CHECK requiring 1-500 characters. These workflow/check limits are distinct from the column type declaration. Application and database code were not changed by this documentation revision.

Reviewed against the checked-in system files on November 9, 2026 (Asia/Manila). The local migration baseline and subsequent migrations are the database reference; this review does not assert that a remote deployment has the same schema.

## Updated in Chapter 3.docx

- Replaced the context diagram with one whole-system process and separate member/applicant, administrator, and staff actors. Internal stores are excluded from the context view.
- Arranged the Gane–Sarson context diagram in the requested vertical composition: Member / Applicant above process 0, Administrator and Authorized Staff below, with distinct labeled, directional input and output arrows.
- Replaced the Level 1 data-flow figure and descriptions, distinguishing administrator review of online requests from staff counter operations.
- Replaced the use-case figure with separate role associations. Actors are outside the system boundary. Shared use cases repeat for readability.
- Replaced the ERD with four schema-style panels derived from the supplied pgAdmin export: membership, account/history/audit, attendance/pairing, and products/sales. Full columns, data types, PK/FK/UQ markers, and required status are shown, with reference-key connections. Editable SVGs and the normalized schema JSON accompany the PNGs; the Mermaid relationship source is also retained.
- Added phone-pairing, activity-log, and private attendance-request/account-protection tables to the dictionary. Rebuilt dictionary fields from the baseline, including numeric stock and payment fields, actual contact field types, operator references, account controls, and product units.
- Updated requirements, forms, permissions, transaction descriptions, and hardware requirements. Replaced the receipt illustration with a role workflow illustration.
- Preserved the stated operating rule: transactions are recorded without providing customer receipts. The existing database column receipt_number remains documented as an internal reference.
- Rechecked the Chapter 3 workflow narrative against current authentication, application-review, walk-in registration, attendance, inventory, sales, reporting, and activity-log code paths. Expanded the end-to-end flow and corrected applicant-versus-member terminology, the timing of Auth account creation, the initial-registration/member relationship, optional sale links, and attendance records with no recorded checkout.
- Corrected functional input/output requirement rows to reflect authorized staff as well as administrators for online request review, and matched product-sale inputs to the actual customer/product/quantity/unit transaction fields.
- Reworked the staff workflow figure as a distinct four-path staff process diagram, checked its labels against staff permissions, and corrected the context/DFD distinction between account registration and request approval. The DFD no longer implies the applicant Auth account is created on approval.
- Replaced unsupported hardware minimum claims with indicative examples and stated that performance and bandwidth thresholds have not been measured. The OS row now advises using operating systems and browsers that receive vendor security updates.
- Added Vercel to the software requirements and deployment description. The dashboard screenshot supplied for this review shows a Ready Production Deployment at `irongrind-github-io.vercel.app`, sourced from `main`; this status is described as deployment evidence, not as proof that all production workflows or evaluations have passed.
- Corrected the profile-table caption and updated entity relationship explanations to distinguish optional links and the registration application's source relationship.

## Sources used

- supabase/migrations/20261105043517_remote_schema.sql and subsequent migrations through 20261108
- supabase/migrations/20261105043518_staff_active_plan_change_search.sql
- assets/js/admin.js, staff.js, customer.js, attendance-phone.js, staff-accounts.js, activity-logs.js, register.js, auth.js
- supabase/functions/admin-create-member/index.ts and the staff-provisioning workflow
- Current page structure and package.json

## Validation and remaining presentation work

- DOCX document XML and image relationships were checked. Replacement diagram images were visually inspected during preparation; updated figures use inline placement to reduce overlap. The structural chapter verifier checks table counts, documented field counts, figures, and key implementation statements.
- Final page layout has not been rendered in Microsoft Word. Check pagination, caption placement, and image text size before submission.
- Existing interface screenshots, other than the replaced receipt illustration, are historical prototype images and were not recaptured. Capture the current interfaces before presenting those figures as current screenshots.
- The Agile illustration was inspected and retained. The Gantt chart remains the original planned schedule, not evidence of actual completion dates.
- Some staff messages still use the word ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œreceiptÃƒÂ¢Ã¢â€šÂ¬Ã‚Â for the internal reference. No application code was changed in this documentation task.
- Illustrations and editable ERD source are in Chapter 3 Diagrams. build-chapter3-diagrams.ps1 regenerates those source images; regenerating the images alone does not replace images already embedded in Word.

## Diagram conventions

The context and Level 1 DFD now use Gane-Sarson notation: numbered rounded process boxes with a separate number compartment, rectangular external entities, open-ended data stores with identifier compartments, and named directional flows. The Level 1 DFD uses five continuation panels (Figure 3a-e) for readability. The dedicated source is Chapter 3 Diagrams/gane-sarson.ps1, with its flow data in 03-gane-sarson-flows.json. Run that dedicated generator after the older general diagram generator to preserve the Gane-Sarson figures. It also updates their Word embeddings when Chapter 3 is closed.

The DFD uses repeated actor and data-store references in process lanes for readability. D0 is managed Auth storage; D10 is phone-pairing policy; D11 is pairing sessions; D13 is private attendance scan requests. D12 is reserved for the retained scan-event table and has no active frontend flow. D2-D8 in the reporting process groups the operational stores read for reports. Activity records are written through mutation triggers and logging functions. Grouped operations may be decomposed further if the professor requires a separate lower-level DFD for each workflow.

The availability audit checked current frontend calls and backend functions. It removed an unsupported scan-event review/clearing interface and the member lookup previously shown for product-sale recording. The current product-sale RPC receives the customer name and product, quantity, and unit rather than a member identifier. Online applicant account creation is shown with registration; approval does not assume a separate profile account-state update. Member self-profile updates and attendance-history reads are explicitly represented. Staff counter registration, direct renewal, active-member plan change, own-product-sales review, and attendance were confirmed in the staff portal. Administrator staff controls, pairing management, reports, and activity-log review were confirmed in their corresponding current code paths. This is a source-code audit, not a live deployment test.

ERD panels repeat table boxes rather than drawing every relationship across one crowded page. Each repeated name denotes the same physical table. activity_logs.actor_id has no declared foreign key, so it is not represented as an enforced relationship. Managed Supabase Auth internals are outside the application-owned dictionary.

## Final function alignment

The functional, input, and output requirements now share nine functions: User Login; Membership Applications; User Management; Renewals; QR Attendance; Products & Inventory; Sales; Generate Reports; Activity Logs. The DFD uses the same numbered responsibilities. Process 9.0 is read-only Activity Logs, while process 8.0 generates reports. Administrator staff-account changes belong to User Management, and phone-pairing controls belong to QR Attendance. Their recorded events are visible in Activity Logs; the viewer does not perform those changes.

User Management has distinct actor arrows: administrator read-only member-profile queries, separate membership operations, and staff-account controls; staff counter registration, renewal and active-plan changes with limited lookup; and member own-profile queries/edits. Staff have no member-profile viewing or personal-detail editing function. New Auth/profile records created by registration services are backend writes, not staff profile-editing rights. The use-case illustration shows report generation and activity-log review separately. The physical ERD describes stored relationships rather than granting user permissions.

## Personal-profile permissions

| Role | View member personal profile | Edit member personal profile |
| --- | --- | --- |
| Administrator | Yes | No |
| Member | Own profile only | Own profile only |
| Staff | No | No |

Membership registration, renewal, plan changes, staff-account provisioning, and attendance are separate operational functions; their database writes must not be described as permission to edit an existing member's personal profile. Staff counter lookup supplies limited operation-specific details, not a profile page. The requirement descriptions, prototype narrative, User Management use case, member self-profile use case, context flows, and DFD actor arrows were checked and corrected to use this distinction.

## November 10, 2026 source-alignment review

Chapters 1 and 3 were compared with the recent source revisions and updated. This entry supersedes older implementation statements where they conflict with the following changes.

- Retained the existing project title and nine main functions. Clarified the web application and installable attendance-scanner PWA without describing it as a separate native application or an offline attendance service.
- Added staff attendance lookup by name/Gmail with explicit member selection and submission of the unique identifier. Lookup alone does not record attendance or expose a general member-profile page.
- Documented separate scanner installation, pairing and operator authentication; active saved pairings can be reused in the same browser, while lost/expired/removed connections need recovery or new pairing.
- Aligned administrator and staff walk-in registration with split first name, optional middle initial and last name, composed into the existing full-name field. Retained the actual eight-character member and twelve-character staff-creation minimums.
- Documented unit-aware initial low-stock thresholds, pound/ounce conversion, stock-versus-sale-unit presentation and staff supplement-form catalog groups. These are starting policy alerts, not optimized demand forecasts or new database columns.
- Expanded the activity-log scope and described action/category/date/account filters and expandable details. Failed credential attempts are not attributed to an assumed account owner. Passwords/hashes/tokens and report contents are excluded from log entries. Export requests do not prove download completion; browser closure does not prove explicit logout.
- Distinguished local security logging from verified production deployment. Migration 20261110000001_security_activity_events.sql, member-password-login, updated admin-username-login and the dependent web client require coordinated deployment. Auth database audit storage must be enabled for recovery-request capture.
- Kept the historical November 8 regression statement dated. The new review does not claim a fresh full production or physical-device test.
- Marked prototype captures as earlier interface evidence; revised administrator registration, staff directory, activity-log and catalog descriptions distinguish later source changes. Refreshed captures and final Word pagination review remain necessary.

Validation: chapter XML and figure relationships passed verification; 20 Chapter 3 tables, all 174 dictionary descriptions/types/constraints, 21 FK definitions and five unique fields were verified. Dictionary XML and figure counts were preserved by the update. Prototype verification confirmed 27 complete main screenshots and eight supplementary details, with all 35 media placements resolving correctly. No schema table/column changes were introduced by the reviewed UI and logging revisions; the existing ERD/dictionary structure remains applicable. DFD and use-case artwork was retained; the explanations extend attendance lookup and security audit behavior within the same nine functions, rather than claiming every added audit event is individually drawn.

Backup: Review Backups/system-alignment-20261110-105401. Original Chapter 1 and Chapter 3 files are retained there alongside staged updated copies.

## Administrator MFA and defense materials — November 10, 2026

Implemented administrator TOTP enrollment/challenge before main-dashboard and administrator scanner activation. The MFA migration enforces AAL2 through the active-admin role helper, current-session/RLS guard, both activation functions and the preserved API pre-request guard. The own-account bootstrap returns only a Boolean requirement and is the narrow pre-request exception. Staff/member flows retain their existing authentication/authorization. No application table/column was added; managed Supabase factors supply the second factor.

Verified locally: MFA UI fixtures (four), direct PostgreSQL access/enforcement fixtures including migration rerun, login cancellation without application-session replacement, session-monitor behavior, scanner tests, UI/form checks, chapter integrity and prototype/media consistency. A focused run of 17 browser tests passed; later focused runs reconfirmed the modified code. These are scoped checks, not a fresh production acceptance or complete regression claim. Real Auth enrollment and PowerPoint/Word visual review remain pending.

Prepared Defense/Capstone Study and Defense Notes.md, generated Source Code Map.md, separate Capstone Presentation.md and editable PowerPoint with eighteen slides and eighteen populated speaker-note sections, plus Admin MFA Setup and Deployment Guide.md. AGENTS.md now requires the notes and presentation to be updated with future material changes. Presentation generation/verification can be rerun after editing the slide source. Sources and implementation/deployment limitations are identified in the materials.

Chapters 1 and 3 received scoped MFA addenda; no ERD/dictionary restructuring was needed. Backups: Review Backups/admin-mfa-20261110-112638. All 174 dictionary fields, 21 FK definitions, five unique fields and the existing figures remain verified. No actual setup secret or QR was inserted into documentation. Current-device approval/push notifications remain outside this increment. Deployment, supervised genuine-admin first enrollment and verified project-owner lost-factor recovery are documented prerequisites.


## One trusted administrator browser ? November 10 local revision

Implemented browser-held non-extractable ECDSA P-256 keys in IndexedDB, public-key server challenges, and one 30-day trusted row per administrator. Repeat password logins prove the same key without MFA. A new browser receives current-device approval and must then freshly verify TOTP; signature verification and a single server transaction transfer trust, revoke both old device application scopes and activate the new scope. Failed/denied/cancelled verification leaves old trust intact. Normal logout preserves trust; explicit forget controls revoke it. Recovery permits fresh MFA when no valid current approver with a two-minute heartbeat is available. Hidden/offline pages may stop heartbeats. A denied request cannot be reused. Revoked/transferred trust has a distinct login notice instead of a false ordinary logout/expiry error.

New migration: 20261110000004_admin_trusted_device.sql. New authenticated Edge Function: admin-device-trust (explicit getUser validation and ECDSA proof verification before service-only completion). Two private tables plus a snapshot field extend the local target to 201 fields across 12 public and 6 private tables; the Trusted Administrator Device Guide supplies exact definitions and deployment steps. No deployment is claimed. Existing public-only ERD remains structurally unchanged; full supporting dictionary/DFD updates belong with the next deployed-schema review.

Validation: 27 focused browser/crypto/Edge simulation/MFA/scanner/logout tests passed, including invalid signatures, stale MFA, reuse without a code and failure without transfer. Isolated SQL checks passed initial MFA enrollment, post-logout reuse, service API isolation, consumed challenge rejection, AAL1 trusted approvers, required approval plus MFA, atomic revocation, denial, inactivity recovery, forget revocation and migration rerun. UI/form/session checks and login fixtures passed. Notes, PPT speaker notes, source map and the deployment guide were updated. Physical IndexedDB/authenticator/two-device hosted testing remains pending.
