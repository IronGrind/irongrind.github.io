# CHAPTER 3

# RESEARCH METHODOLOGY

This chapter discusses the methodology used to develop **IronGrind: A Web-Based Fitness Gym Membership and Operations Management System for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte**. It describes the development process, system requirements, design, data organization, and evaluation procedures. The system is intended to organize membership applications and records, membership periods and renewals, staff-recorded attendance, products, sales, and reports. Its development is organized using Agile, with work planned and delivered incrementally. Proposed evaluation activities are distinguished from results that have not yet been collected.

### System Development Methodology

![Figure 1. Agile Methodology](iron-grind-agile-methodology.svg)

**Figure 1.** Agile Methodology.


Agile is an iterative system-development approach in which stakeholder needs are gathered and prioritized, selected work is developed and tested in increments, and review results inform the next iteration. Figure 1 has two connected parts. The circular cycle places Develop, Test, and Review around the IronGrind project name: the team builds a selected increment, checks it against its requirements, and uses review feedback to refine the next increment. The lower project flow shows Data Gathering, Plan, and Design before Launch. This lower row represents the project's overall progression; Launch follows verification of the required increments rather than occurring at the end of every cycle. The work is organized around the gym's applicant/member and administrator workflows. The figure describes the Agile activities used to organize the project and does not prescribe a particular framework or iteration length.


### Requirements Planning

Requirements planning organizes the workflows and scope described in Chapters 1 and 2 into a prioritized task list. Work begins with account access and membership applications, followed by staff review, member access, attendance, inventory, sales, and reporting. Each selected requirement is assigned acceptance criteria so the increment can be checked during construction. Privacy and authorization requirements apply throughout development because the system handles personal and health-related information.

### User Design

For each iteration, the relevant user workflows, page layouts, forms, reports, data relationships, and role permissions are designed or refined. The design distinguishes pending applications from approved member records, keeps attendance as a separate operational record, and stores sales with their itemized lines. The architecture, use-case, and data-flow figures in this chapter summarize the system design.

### Prototypes

The system prototype is an interactive, browser-based version of the gym workflows. Applicants use the sign-in and registration pages to enter the application workflow. Members use the member portal to review membership information, display their QR code, view attendance history, and submit an eligible renewal request. Administrators use the dashboard to review applications and manage membership, staff-scanned attendance, products, sales, receipts, and reports. The prototype uses Supabase Auth and configured database services for supported operations. Its key pages are listed in the Forms section. Deployment and operational readiness are separate implementation activities.

### Construction

Selected requirements are implemented in the HTML, CSS, and JavaScript client and the Supabase authentication and PostgreSQL services. Database policies and functions support authorization and operational transactions. Each increment is checked against its acceptance criteria. Issues identified during verification are corrected or returned to the prioritized task list for a later increment.

### Implementation

The implementation phase follows verification of the required increments. It includes configuring the website and Supabase project for the intended environment, applying the approved access policies, preparing administrator accounts, and orienting staff to the supported workflows. Deployment and user-orientation outcomes are reported after those activities are completed.

## Requirement Specifications

This section presents the operating context and the functional, input, output, software, hardware, and nonfunctional requirements for IronGrind. These specifications describe the system represented by the current project files.

### Study Setting and Intended Users

The system is intended for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte. Its intended users are applicants, members, authorized administrators, and walk-in customers served by staff. The database defines `admin` and `member` profile roles; it does not define a separate staff role.

### Functionality Requirements

The functional requirements describe the operations available to applicants, members, and authorized administrators. They cover sign-in, application review, membership, attendance, inventory, sales, and reports.

#### Table 1. Functional Requirements

| ID | Requirement | Description |
| --- | --- | --- |
| FR-01 | Authentication and access | Users authenticate through Supabase Auth. Administrator and member access is governed by profile roles and database authorization policies. |
| FR-02 | Online application | An applicant submits registration details through the website. The application is stored for administrator review and is not automatically an active membership. If the applicant attempts to log in while the application is pending, the website displays the pending status. |
| FR-03 | Application review | Authorized staff view, approve, or reject registration and renewal applications. The decision and application status are retained. |
| FR-04 | Membership management | Authorized staff manage member records, plan and membership dates, status, payment information, and membership lifecycle records. |
| FR-05 | Member portal | An approved member views membership status and progress, personal attendance history, and a QR code; updates are limited to supported account and personal-information fields. |
| FR-06 | Renewal request | An eligible member can submit a renewal request for staff review. A request is not an automatic renewal. Chapter 2 specifies the five-calendar-day renewal window before and including the current expiry date. |
| FR-07 | Attendance | Staff scan a member's QR code to record check-in and check-out. Members can view their own attendance history; the member does not record their own attendance. |
| FR-08 | Product and inventory management | Authorized staff maintain products and inventory. Supplements use gram-based quantities; merchandise uses item quantities and stock tracking. |
| FR-09 | Sales and receipts | Staff record in-person product and membership sales for members or walk-in customers. The system stores a sale record and its line items and supports receipt/report views. |
| FR-10 | Operational reports | Authorized staff view and print or save the available membership, member-status, archive, payment, attendance, renewal, inventory, and sales reports. Report contents depend on the records entered into the system. |

### Input Requirements

#### Table 2. Input Requirements

Input requirements identify the information supplied to the system by applicants, members, and authorized administrators or recorded through staff actions. Required fields depend on the selected workflow.

| Input requirement | Description |
| --- | --- |
| Account credentials | Email and password are submitted to Supabase Auth. |
| Registration or renewal application | Applicant and plan details, contact and emergency-contact information, goals, health declarations, and signature where collected by the form. |
| Attendance action | Staff scans a member QR code and records check-in or check-out. |
| Product and inventory update | Administrator enters product details, price, unit, and merchandise stock quantity where applicable. |
| Sale transaction | Staff enters customer type and name, products or membership, quantities, and transaction details. |
| Report request | Administrator selects a report type and available filters or date range. |

### Output Requirements

#### Table 3. Output Requirements

Outputs are the responses and records produced after the system validates a request and processes the stored data. Email notifications remain planned and are not currently sent.

| Output requirement | Description |
| --- | --- |
| Authentication and login result | Role-appropriate routing or an authentication error; pending applicants see their application status during login. |
| Application and membership result | The recorded application status and, after staff review, the decision and updated membership information. |
| Member portal information | Membership details, QR code, personal attendance history, and active product catalog permitted for the member. |
| Attendance confirmation | Confirmation of staff-recorded check-in/check-out and permitted attendance history. |
| Receipt | Sale details, line items, quantities, prices, customer information, and total. |
| Administrative reports | Membership, member status, archives, payments, attendance, renewals, inventory, and sales data based on stored records. |
| Planned: email notifications | Application or renewal decisions and expiry reminders are planned; email delivery is not currently available. |

### Software Requirements

#### Table 4. Software Requirements

| Software | Requirement or purpose |
| --- | --- |
| Web browser | Current browser with JavaScript enabled for applicant, member, and administrator workflows. |
| Frontend | HTML, CSS, and JavaScript files served by a compatible web host. |
| Backend services | Supabase Auth and PostgreSQL, with the project schema, Row Level Security policies, and required database functions configured. |
| Edge Function | Supabase Edge Function runtime for administrator-authorized member account creation. |
| Development environment | Node.js 20 or later to run the repository's local static-file server. This local server is for development, not the production database backend. |
| QR scanning | Browser camera permission and a secure HTTPS origin for production QR scanning. |

### Hardware Requirements

#### Table 5. Hardware Requirements

| User or component | Requirement |
| --- | --- |
| Administrator or staff | Desktop computer, laptop, or compatible mobile device with a current browser and internet access. A camera-enabled device is needed when staff scan member QR codes. |
| Applicant or member | Smartphone, tablet, laptop, or desktop computer with a current browser and internet access. |
| Web hosting | Hosting capable of serving the static HTML, CSS, JavaScript, and image assets over HTTPS. Supabase provides the separate authentication and database services. |

### Nonfunctional Requirements

#### Table 6. Nonfunctional Requirements

| Area | Requirement |
| --- | --- |
| Platform | The application is accessed through a modern browser with JavaScript enabled. The user interface is implemented as web pages and client-side scripts. |
| Connectivity | Authenticated database-backed functions require an internet connection to reach Supabase. |
| QR scanning | The staff device requires a camera and browser permission to scan QR codes. Production camera access should be served from a secure HTTPS origin. |
| Access control | Database access is restricted through authenticated roles and PostgreSQL Row Level Security policies. Privileged account creation is routed through the administrator-verified Edge Function. The deployed configuration must be tested before use. |
| Data handling | The application stores contact, emergency-contact, and health-related information. Access and retention practices should follow the gym's approved privacy procedures and applicable law. This description is not a certification of legal compliance. |
| Availability | Users depend on the availability of the website host, internet connection, and Supabase services. Operational backup and recovery procedures must be defined for the deployed environment. |

## System Design

### System Architecture Diagram

![Figure 2. IronGrind system architecture](iron-grind-system-architecture.svg)

**Figure 2.** System architecture of IronGrind.


Figure 2 is a component view of the system and shows where each kind of work takes place. On the user side, applicants and members use the login, registration, and member pages; administrators use the dashboard. Supabase Auth verifies credentials and establishes a session, while the application uses the profile role to route a signed-in person to the appropriate interface. Inside the browser application, the labeled modules group related functions: Applications and Membership handle submissions and staff decisions; Attendance and QR supports staff scans; Inventory and Products maintains the catalog; Walk-in POS and Receipts records transactions; Member Portal presents a member's permitted information; and Reports and Exports prepares administrative summaries. Requests go to Supabase through its Data API or database RPC functions. The PostgreSQL database contains the application records, and Row Level Security (RLS) policies plus function-level checks restrict access to them. Realtime sends changes from `membership_applications` and `attendance` to subscribed website views. The email component is marked as in development because no external provider is selected. The Node.js server in the repository serves static files for local development and is not the production database backend.


### Data Process Modeling

Data process modeling describes how information enters IronGrind, which processes handle it, where records are stored, and what results are returned to applicants, members, and administrators. The model is based on the current Supabase schema and implemented workflows. Email notification is shown only as a planned feature.

#### Diagrams

The diagrams that follow present the system at different levels. The context diagram defines the system boundary and external exchanges. The Level 1 data-flow diagram expands the system into processes and stores. The use-case diagram groups functions by actor, and the ERD describes the database relationships that support those functions.

##### Context Diagram

![Figure 3. IronGrind system context diagram](iron-grind-context-diagram.svg)

**Figure 3.** System context diagram of IronGrind.


Figure 3 sets the boundary around IronGrind as a single system, without showing its internal modules or database tables. Applicants and members send credentials, registration or renewal details, and supported profile requests into that boundary. IronGrind returns authentication results and the membership, attendance, or active catalog information their role permits. Administrators send review decisions, member and product updates, sale entries, and report filters; the system returns updated records, receipts, and reports. A walk-in customer is represented through the staff-entered purchase rather than a direct system account. Supabase Auth and Supabase data services appear outside the application boundary because they provide authentication and database services to the website. The email exchange is planned and should be read as a future integration, not a current system output.


##### Data Flow Diagram

![Figure 4. Level 1 data-process model for IronGrind](iron-grind-data-flow.svg)

**Figure 4.** Level 1 data-process model for IronGrind.

Figure 4 decomposes the single IronGrind system from Figure 3 into numbered processes and named data stores. External actors provide inputs to the process that handles them: credentials go to authentication; application details and staff decisions go to application processing; member requests go to the portal; QR scans go to attendance; product changes go to inventory; and customer and item details go to walk-in sales. The report process reads the operational stores to prepare summaries. The data stores D1–D8 correspond to profiles, membership applications, members, attendance, products, sales, sale items, and membership history, as listed in the Data Stores table. Arrows between processes and stores distinguish information read from information written; arrows between a process and an actor represent the corresponding request or response. The figure's email process is explicitly planned only: the current system has no configured email provider and does not send these messages. Together, this diagram explains the record flow in more detail than the context diagram, while the tables below define each process and store in text.


### Data Process Explanations

The Level 1 diagram can be read as a sequence of related responsibilities. Each process validates its input, uses only the records needed for its task, and returns the corresponding result.

**1.0 Authenticate User.** Supabase Auth verifies submitted credentials and provides the authenticated session. The application reads the associated profile role to route the account to the member or administrator interface. Pending applicants receive an application-status response; they are not treated as approved members.

**2.0 Process Membership Applications.** The system records registration or renewal details in the applications store. An authorized administrator reviews the request. Approval creates or updates the member record and records the associated transaction where configured; rejection updates the application status.

**3.0 Manage Member Portal.** A signed-in member requests permitted membership, attendance, catalog, or profile information. The system returns records allowed for that member and stores a renewal request for staff review.

**4.0 Record Attendance.** Staff scan a member QR code. The system resolves the member and either records a check-in or closes the member's open visit. The QR code identifies a member for staff use; it does not grant entry by itself.

**5.0 Manage Inventory.** An authorized administrator creates, edits, or archives product records. Supplement prices and quantities use gram units; merchandise uses item units and tracked stock. The active catalog is returned to permitted views.

**6.0 Process Walk-in Sale.** Staff enter the customer and selected product. The system validates product availability, records a sale header and itemized line, updates merchandise stock according to the configured transaction, and provides receipt details.

**7.0 Query Reports and History.** An administrator selects a report and available filters. The system reads the relevant membership, attendance, inventory, sales, or history records and returns the corresponding view or export.

**8.0 Email Notifications (planned).** Approval and expiry events may be used by a future notification integration. No external provider is configured, so this process currently produces no email output.

##### Use-Case Diagram

![Figure 5. IronGrind use-case diagram](iron-grind-use-case.svg)

**Figure 5.** Use-case diagram of IronGrind.


Figure 5 describes the system from each actor's point of view. The actor lines connect a role to the use cases that role may initiate; the system boundary encloses the functions provided by IronGrind. Applicants can register and access the application/login workflow. Members can use the member portal, view their membership and attendance information, and submit renewal requests when eligible. Administrators review applications and manage members, attendance, products, sales, and reports. Walk-in customers are not shown as authenticated users because staff enter their sale details at the counter. The diagram expresses available role interactions; it does not imply that a member can approve an application or record their own attendance.


### Use-Case Explanations

The use cases in Figure 5 are grouped by the actor's role. The associations show which actor can initiate each function; database policies and server-side checks still control access to the underlying records.

**Applicant.** An applicant creates an account and submits a membership application. The application remains pending until an administrator reviews it.

**Member.** A member signs in to view permitted membership details, the issued QR code, personal attendance history, and the active catalog. An eligible member may submit a renewal request, which remains subject to staff review.

**Administrator.** An administrator reviews applications and manages member records, staff-scanned attendance, products, sales, receipts, and operational reports.

**Walk-in customer.** A walk-in customer does not need a system account. Staff enter the customer's purchase in the point-of-sale workflow and provide a receipt.

##### Entity Relationship Diagram

![Figure 6. IronGrind entity relationship diagram](iron-grind-erd-simplified.svg)

**Figure 6.** Entity relationship diagram of IronGrind.


Figure 6 is a relational view of the core tables, rather than a flow of screens or activities. Each box names a table and shows selected fields; PK marks a primary key, FK marks a foreign key, and UK marks a unique field or link. The line ends indicate relationship cardinality: for example, one member may have many attendance events and membership-history records, while each such record points back to one member. A sale may belong to a member or to a walk-in customer, and its itemized lines are stored separately in `sale_items`; a line can retain its item description even when it has no linked product. `auth.users` is managed by Supabase and is shown to explain identity links, while `profiles` stores application role information. The `members.auth_user_id` link is nullable and unique, so a member can exist without a linked Auth identity and a single Auth user cannot be linked to multiple member rows. Application and member links also allow pending submissions to exist before they are connected to an approved member. The simplified ERD omits secondary fields to keep the relationships readable; consult the data dictionary and current schema for the full field list.


### Entity and Relationship Explanations

The ERD is a database structure diagram. Primary keys identify rows; foreign keys connect records; unique keys prevent duplicate identity or receipt links. Optional links are nullable, so a record can exist before an associated account or member has been linked.

**Authentication and profiles.** Supabase manages authentication identities in `auth.users`. The `profiles` row stores the application role and account information. A profile's identifier corresponds to its Auth user.

**Applications and members.** `membership_applications` stores registration and renewal requests and their review state. An application may refer to a member after the account is approved or when it represents an existing member's renewal. `members` stores approved membership information. The nullable unique `members.auth_user_id` link permits no more than one member row per Auth user.

**Attendance and membership history.** Each attendance row refers to the member whose visit it records; a member can have multiple visits. Membership history stores lifecycle events such as expiration, renewal, and plan change, with prior and new values where available.

**Sales, sale items, and products.** A sale stores the receipt-level customer, date, status, and total. Its itemized details are stored in `sale_items`. A line may refer to a product, while the item name and price are retained on the line for the transaction record. A member sale may link to a member; a walk-in sale may have no member link.

These links support the reports and workflows described in the process model. The simplified diagram omits secondary fields for readability; the Data Dictionary lists the principal fields and their purposes.

### Data Processes

| Process | Input | Data stores or services used | Output |
| --- | --- | --- | --- |
| 1.0 Authenticate User | Member/applicant or administrator credentials | Supabase Auth; D1 `profiles` for role lookup | Authenticated session and role-based routing, or an authentication error. |
| 2.0 Process Membership Applications | Registration or renewal details; administrator approval or rejection | D2 `membership_applications`; D3 `members`; D8 `membership_history`; D6 `sales` when a membership transaction is recorded | Updated application status, member record and related transaction result. |
| 3.0 Manage Member Portal | Member requests, supported profile updates, renewal submissions | D1 `profiles`; D2 `membership_applications`; D3 `members`; D4 `attendance`; D5 `products` | Member's permitted membership, attendance, and active product information; renewal or update result. |
| 4.0 Record Attendance | Staff QR scan and check-in/check-out action | D3 `members` for member lookup; D4 `attendance` for attendance records | Saved attendance event and confirmation; attendance history for permitted member access. |
| 5.0 Manage Inventory | Administrator product, price, category, or stock changes | D5 `products` | Updated product and inventory records; active catalog data for members. |
| 6.0 Process Walk-in Sale | Staff-entered customer and sale-item details | D5 `products` for validation and stock; D6 `sales`; D7 `sale_items` | Validated sale, receipt details, and applicable merchandise stock update. |
| 7.0 Query Reports and History | Administrator report type and filters, including date range | D2 `membership_applications`; D3 `members`; D4 `attendance`; D5 `products`; D6 `sales`; D7 `sale_items`; D8 `membership_history` | Dashboard summaries, filtered report data, and available exports. |
| 8.0 Email Notifications (planned) | Future approval or expiry events | No live notification store or external provider configured | No email output is currently produced; this process remains planned. |

### Data Stores

| ID | Data store | Contents |
| --- | --- | --- |
| D1 | `profiles` | Authenticated user's application profile and role. |
| D2 | `membership_applications` | Registration and renewal submissions, review status, and decision information. |
| D3 | `members` | Approved member and membership records. |
| D4 | `attendance` | Staff-recorded member check-in and check-out events. |
| D5 | `products` | Product catalog, categories, prices, units, and merchandise stock. |
| D6 | `sales` | Transaction headers and receipt details, including membership sales where recorded. |
| D7 | `sale_items` | Itemized transaction lines. |
| D8 | `membership_history` | Expiration, renewal, and plan-change events. |

## Overall Description

IronGrind is a browser-based membership and operations system for applicants, members, and administrators. Users submit requests through the website; Supabase Auth manages authentication and sessions; authorized data requests pass through the Supabase Data API or database RPC functions; and PostgreSQL stores operational records. RLS and function-level checks restrict access. The system supports application review, member records, staff-recorded attendance, inventory, sales and receipts, and administrative reports. Realtime subscriptions currently cover membership applications and attendance. Email notifications remain planned and are not operational.

## Data Dictionary

This data dictionary summarizes the public-schema fields and relationships defined in the project SQL. Supabase Auth manages credentials separately from these application tables.

| Entity | Key fields and data types | Purpose and relationships |
| --- | --- | --- |
| `profiles` | `id` UUID (PK, Auth FK); `email`, `username`, `full_name`, `role`, `account_status` TEXT; timestamps | User profile and role used by the application. `username` is unique. |
| `members` | `id` UUID (PK); `auth_user_id` UUID (nullable, unique Auth FK); `application_id` UUID (nullable, unique FK); `full_name`, `email`, `username`, `mobile` TEXT; `date_of_birth` DATE; `age` SMALLINT; `height`, `weight_kg` NUMERIC; `height_unit`, `sex`, `plan`, `status`, `registration_source` TEXT; `emergency_contact` JSONB; `plan_price`, `paid` NUMERIC; membership dates; `fitness_goals`, `health_conditions` TEXT[]; `other_medical_conditions`, `signature_path` TEXT; timestamps | Approved member and membership record. Referenced by applications, attendance, sales, sale items, and membership history. |
| `membership_applications` | `id` UUID (PK); `auth_user_id` UUID (nullable Auth FK); `member_id` UUID (nullable FK); `application_type`, `status`, applicant and plan details; demographic, health, and signature fields; submission/review timestamps; `reviewed_by` UUID (FK to `profiles`) | Registration and renewal requests and their review state. `member_id` can be empty before a member is linked. |
| `attendance` | `id` UUID (PK); `member_id` UUID (FK); `time_in`, `time_out`, `created_at` TIMESTAMPTZ; `recorded_by` UUID (Auth FK) | Staff-recorded check-in and check-out. A member may have multiple attendance records. |
| `products` | `id` UUID (PK); `name`, `category`, `unit`, `size`, `image_path` TEXT; `price_per_unit` NUMERIC; `stock` INTEGER; `is_active` BOOLEAN; timestamps | Product catalog and inventory. Supplements use gram units; merchandise uses item units and stock. |
| `sales` | `id` UUID (PK); `receipt_number` TEXT (unique); `customer_type`, `customer_name`, `status` TEXT; `member_id` UUID (nullable FK); `total` NUMERIC; `sold_at` TIMESTAMPTZ; `processed_by` UUID (Auth FK) | Sale header and receipt information. A sale may be associated with a member or a walk-in customer. |
| `sale_items` | `id` UUID (PK); `sale_id` UUID (FK); `product_id` UUID (nullable FK); `item_name`, `category`, `unit` TEXT; `quantity` NUMERIC; `unit_price`, `line_total` NUMERIC | Itemized sale lines. Product reference can be null; item name and price are stored on the sale line. |
| `membership_history` | `id` UUID (PK); `member_id` UUID (FK); `event_type`, previous/new plan, `notes` TEXT; previous/new prices NUMERIC; previous/new dates DATE; `recorded_at` TIMESTAMPTZ; `recorded_by` UUID (Auth FK) | Expiration, renewal, and plan-change history for a member. |

## Forms

| Form or screen | User | Purpose and principal inputs |
| --- | --- | --- |
| Sign-in (`index.html`) | Applicant, member, administrator | Collects credentials for Supabase Auth and role-based routing. |
| Registration (`register.html`) | Applicant | Collects account and membership application details for administrator review. |
| Application review | Administrator | Displays application details and records approval or rejection. |
| Member portal (`customer.html`) | Member | Displays membership information, QR code, attendance history, active catalog, renewal request, and supported profile settings. |
| Attendance scanner | Administrator or staff using an administrator account | Scans member QR code and records check-in/check-out. |
| Product and inventory forms | Administrator | Creates or updates products, prices, units, active status, and merchandise stock. |
| Walk-in POS and receipt | Administrator | Records walk-in customer and sale-item details; displays receipt information. |
| Report filters | Administrator | Selects report type and available filters/date range; views or prints/saves results. |
| Password recovery (`reset-password.html`) | Account holder | Supports the password-reset workflow. |

## Prototype

The prototype consists of the interactive website pages and workflows described above. It includes login, registration, the member portal, administrator dashboard, attendance scanning, inventory, POS, receipts, and reports. The project files provide the implemented pages and interfaces; screenshots can be inserted here if required by the school template. Do not claim stakeholder testing or user feedback unless those activities were conducted and recorded.

## Reports

Available administrator reports cover membership, member status, archives, payments, attendance, renewals, inventory, and sales. Report data comes from the records stored by the corresponding system processes. Reports can be viewed and printed or saved where the interface provides that option. They summarize recorded data and do not by themselves demonstrate improved performance.

## System Verification and Evaluation

System verification and user evaluation serve different purposes. Verification checks whether each implemented workflow behaves according to its requirement. User evaluation examines the system's perceived quality and usefulness. No test results or user-evaluation results are asserted in this chapter; actual outcomes must be collected and reported after the procedures are carried out.

### Functional Verification

The following scenarios provide a minimum verification basis. The research team should record the test date, environment, test account role, observed result, and any defect for each executed scenario.

| Test area | Verification scenario | Expected result |
| --- | --- | --- |
| Authentication and access | Sign in with authorized administrator and member accounts and attempt role-restricted actions. | Each account reaches its intended interface; unauthorized database operations are denied by the configured policies. |
| Application workflow | Submit a registration application, review it as staff, and test both approval and rejection paths. | The application is recorded with its review status; approval creates or links the member record and associated transaction as configured. |
| Renewal | Submit a renewal request within the allowed period and review it as staff. | An eligible request is pending until staff decision; the membership is not renewed automatically. |
| Attendance | Scan a member QR code as staff for check-in and check-out, then view the member's history. | The event is recorded and the member can view their own history; the member cannot create the event through self-scan. |
| Inventory and sales | Record a merchandise sale and a gram-based supplement sale, then inspect the receipt and inventory records. | The sale and line items are saved with their units and totals; merchandise stock is updated according to the configured sales workflow. |
| Reports | Open and print or save available reports using records from the test data. | The report presents the corresponding stored records and totals for the selected report type. |
| Personal-data access | Attempt to read or update records using member and administrator accounts. | Members can access only their permitted personal data; administrator access follows the deployed policy configuration. |

### User Evaluation Framework

Chapter 2 identifies the DeLone and McLean Information Systems Success Model as a possible framework for evaluating system quality, information quality, use, user satisfaction, and net benefits. The evaluation should measure only dimensions included in the approved study instrument. The table below connects those dimensions to IronGrind and does not represent results.

| Dimension | Possible IronGrind evaluation focus |
| --- | --- |
| System quality | Ease of navigating the browser workflows, reliability of common operations, and access behavior across member and administrator roles. |
| Information quality | Completeness, consistency, and usefulness of member, attendance, inventory, sales, and report information. |
| Use | Whether intended users can perform the workflows relevant to their role. |
| User satisfaction | Users' assessment of the system after completing representative tasks. |
| Net benefits | Perceived contribution to organizing the gym's records and operations; claims of improved efficiency or accuracy require evidence collected through the approved method. |

Before administering an evaluation, the researchers should identify the actual participant population, sampling method, instrument, rating scale, consent procedure, and statistical treatment required by the approved proposal. These details and the resulting data are not present in the supplied project files and must not be invented. If the study uses a questionnaire, the instrument should be reviewed and approved before data collection, and the analysis should report the actual number of respondents and results.

## Scope and Limitations

IronGrind supports online membership applications and renewal requests for staff review; member access to selected membership and attendance information; staff-operated QR check-in and check-out; product and inventory records; in-person product and membership sales; receipts; and administrative operational reports. Its data model and workflows are tailored to the stated operations of Iron Grind Fitness Gym.

The project does not provide online payment processing, online product checkout or reservations, member-operated attendance entry, automated gate access, AI fitness coaching, or a native mobile application. The member QR code identifies the member for staff scanning; it does not itself grant gym access. The system's reports reflect the records entered and do not independently establish business outcomes. Data protection depends on correct deployment, configured policies, appropriate user practices, and the gym's operational procedures.

## Gantt Chart

The development schedule follows the order of the Agile activities. The table records each phase, its main work, and its expected output. Calendar start and end dates should follow the approved project schedule.

| Phase | Main activities | Expected output |
| --- | --- | --- |
| 1. Requirements planning | Define scope, users, workflows, data needs, and access requirements. | Prioritized requirements and acceptance criteria. |
| 2. User design and prototyping | Refine page flows, forms, reports, database relationships, and role permissions. | Reviewed interface prototype and system diagrams. |
| 3. Construction iterations | Implement prioritized features in the browser client and Supabase services; verify each increment. | Integrated feature increments and recorded issues. |
| 4. Refinement | Resolve verification findings and update the prioritized requirements. | Refined system ready for deployment preparation. |
| 5. Implementation and transition | Configure the intended environment, prepare administrator access, and orient staff. | Configured deployment and user-orientation records. |
| 6. Evaluation | Conduct the approved user evaluation and analyze collected responses. | Evaluation dataset and reported findings. |

Exact calendar dates and durations are not included because no approved dated schedule was present in the project files. Add those dates from the project plan before submitting a date-based Gantt chart.
