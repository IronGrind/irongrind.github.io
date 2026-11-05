# Chapter 3 review

Reviewed against the checked-in system files on November 5, 2026 (Asia/Manila). The local migration baseline is the database reference; this review does not assert that a remote deployment has the same schema.

## Updated in Chapter 3.docx

- Replaced the context diagram with one whole-system process and separate member/applicant, administrator, and staff actors. Internal stores are excluded from the context view.
- Replaced the Level 1 data-flow figure and descriptions, distinguishing administrator review of online requests from staff counter operations.
- Replaced the use-case figure with separate role associations. Actors are outside the system boundary. Shared use cases repeat for readability.
- Replaced the ERD with three relationship panels derived from all 20 declared foreign keys. Panels show NULLability, parent/child cardinalities, and deletion actions. Full editable Mermaid ERD includes table attributes.
- Added phone-pairing, activity-log, and private attendance-request/account-protection tables to the dictionary. Rebuilt dictionary fields from the baseline, including numeric stock and payment fields, actual contact field types, operator references, account controls, and product units.
- Updated requirements, forms, permissions, transaction descriptions, and hardware requirements. Replaced the receipt illustration with a role workflow illustration.
- Preserved the stated operating rule: transactions are recorded without providing customer receipts. The existing database column receipt_number remains documented as an internal reference.

## Sources used

- supabase/migrations/20261105043517_remote_schema.sql
- supabase/migrations/20261105043518_staff_active_plan_change_search.sql
- assets/js/admin.js, staff.js, customer.js, attendance-phone.js, staff-accounts.js, activity-logs.js
- supabase/functions/admin-create-member/index.ts and the staff-provisioning workflow
- Current page structure and package.json

## Validation and remaining presentation work

- DOCX document XML and image relationships were checked. Replacement diagram images were visually inspected during preparation; updated figures use inline placement to reduce overlap.
- Final page layout has not been rendered in Microsoft Word. Check pagination, caption placement, and image text size before submission.
- Existing interface screenshots, other than the replaced receipt illustration, are historical prototype images and were not recaptured. Capture the current interfaces before presenting those figures as current screenshots.
- The Agile illustration was inspected and retained. The Gantt chart remains the original planned schedule, not evidence of actual completion dates.
- Some staff messages still use the word â€œreceiptâ€ for the internal reference. No application code was changed in this documentation task.
- Illustrations and editable ERD source are in Chapter 3 Diagrams. build-chapter3-diagrams.ps1 regenerates those source images; regenerating the images alone does not replace images already embedded in Word.

## Diagram conventions

The context and Level 1 DFD now use Gane-Sarson notation: numbered rounded process boxes with a separate number compartment, rectangular external entities, open-ended data stores with identifier compartments, and named directional flows. The Level 1 DFD uses five continuation panels (Figure 3a-e) for readability. The dedicated source is Chapter 3 Diagrams/gane-sarson.ps1, with its flow data in 03-gane-sarson-flows.json. Run that dedicated generator after the older general diagram generator to preserve the Gane-Sarson figures. It also updates their Word embeddings when Chapter 3 is closed.

The DFD uses repeated actor and data-store references in process lanes for readability. D0 is managed Auth storage; D10 is phone-pairing policy; D11 is pairing sessions; D13 is private attendance scan requests. D12 is reserved for the retained scan-event table and has no active frontend flow. D2-D8 in the reporting process groups the operational stores read for reports. Activity records are written through mutation triggers and logging functions. Grouped operations may be decomposed further if the professor requires a separate lower-level DFD for each workflow.

The availability audit checked current frontend calls and backend functions. It removed an unsupported scan-event review/clearing interface and the member lookup previously shown for product-sale recording. The current product-sale RPC receives the customer name and product, quantity, and unit rather than a member identifier. Online applicant account creation is shown with registration; approval does not assume a separate profile account-state update. Member self-profile updates and attendance-history reads are explicitly represented. Staff counter registration, direct renewal, active-member plan change, own-product-sales review, and attendance were confirmed in the staff portal. Administrator staff controls, pairing management, reports, and activity-log review were confirmed in their corresponding current code paths. This is a source-code audit, not a live deployment test.

ERD panels repeat table boxes rather than drawing every relationship across one crowded page. Each repeated name denotes the same physical table. activity_logs.actor_id has no declared foreign key, so it is not represented as an enforced relationship. Managed Supabase Auth internals are outside the application-owned dictionary.

## Staff-permission correction

The DFD now has nine processes. Process 3.0 contains counter registration, direct renewal, and active-member plan change. Member self-profile viewing/editing is isolated in process 9.0 with no staff association. Each DFD actor has separate labeled input/output arrows, including online-review, attendance, and catalog flows. Staff have no profile screen or existing personal-detail editing function. New Auth/profile rows created by the registration service describe server writes, not profile access granted to staff. Limited counter lookup details are distinguished from a member profile view. The context diagram, UML use-case associations, physical ERD, Agile illustration, and Gantt chart were rechecked for this issue. The use-case and staff-operation figures explicitly state the staff restriction. Physical ERD relationships remain unchanged because they do not grant application permissions.
