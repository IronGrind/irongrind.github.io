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
