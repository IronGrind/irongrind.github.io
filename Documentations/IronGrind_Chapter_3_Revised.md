# CHAPTER 3

# RESEARCH METHODOLOGY

This chapter discusses the methodology used to develop **IronGrind: A Web-Based Fitness Gym Membership and Operations Management System for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte**. It describes the development process, system requirements, design, data organization, and evaluation procedures. The system is intended to organize membership applications and records, membership periods and renewals, staff-recorded attendance, products, sales, and reports. Its development is organized using Agile, with work planned and delivered incrementally. Proposed evaluation activities are distinguished from results that have not yet been collected.

### System Development Methodology

Agile is an iterative system-development approach in which stakeholder needs are gathered and prioritized, selected work is developed and tested in increments, and review results inform the next iteration. Figure 1 presents two connected flows for IronGrind. The circular cycle represents the repeated Develop, Test, and Review activities; feedback from a review informs the next increment. The lower project flow shows Data Gathering, Plan, and Design, followed by Launch only after the completed increments have been verified. The system work is organized around the gym's applicant/member and administrator workflows. The project does not assume a specific Agile framework such as Scrum; the research team should document the actual iteration length and review practices used and confirm that Agile is the methodology approved in the study proposal.

![Figure 1. Agile Methodology](iron-grind-agile-methodology.svg)

**Figure 1.** Agile Methodology.

### Requirements Planning

Requirements planning begins with gathering information about the gym's workflows and needs from the owner and authorized staff and reviewing the project scope in Chapters 1 and 2. The information is translated into system requirements and organized in a prioritized task list, beginning with account access and membership applications, followed by staff review, member access, attendance, inventory, sales, and reporting. Each selected requirement is given acceptance criteria. The final study should identify the data-gathering techniques and participants actually used. Privacy and authorization requirements apply throughout development because the system handles personal and health-related information.

### User Design

For each iteration, the relevant user workflows, page layouts, forms, reports, data relationships, and role permissions are designed or refined. The design distinguishes pending applications from approved member records, keeps attendance as a separate operational record, and stores sales with their itemized lines. The architecture, use-case, and data-flow figures in this chapter summarize the system design.

### System Prototype
### Prototypes

The system prototype is an interactive, browser-based version of the proposed gym workflows rather than a set of static screen mockups. Applicants can use the sign-in and registration pages to enter the application workflow. Members use the member portal to review membership information, display their QR code, view attendance history, and submit an eligible renewal request. Administrators use the dashboard to review applications and manage membership, staff-scanned attendance, products, sales, receipts, and reports. The prototype uses Supabase Auth and the configured database services for supported operations. Its key pages are listed in the User Interface Modules section. It should be treated as a prototype until deployment and operational readiness have been verified.

### Construction

Selected requirements are implemented in the HTML, CSS, and JavaScript client and the Supabase authentication and PostgreSQL services. Database policies and functions support authorization and operational transactions. Each increment is tested against its acceptance criteria. At the end of an iteration, issues and feedback are recorded, priorities are updated, and unfinished or revised work returns to the prioritized task list. Stakeholder reviews or user feedback should be reported as completed only when the team has records of those activities.

### Implementation

Launch takes place after the required increments pass verification; it is not repeated at the end of every iteration. The website and Supabase project can then be configured for the intended environment using the correct project settings, access policies, and authorized administrator accounts. Staff should verify the workflows and receive appropriate orientation. This chapter does not claim a production deployment, completed training, or user acceptance unless those activities are documented separately.

## Requirement Specifications

### Study Setting and Intended Users

The system is intended for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte. Its intended users are applicants, members, authorized administrators, and walk-in customers served by staff. The database defines `admin` and `member` profile roles; it does not define a separate staff role.

### Functionality Requirements

| ID | Requirement | Description |
| --- | --- | --- |
| FR-01 | Authentication and access | Users authenticate through Supabase Auth. Administrator and member access is governed by profile roles and database authorization policies. |
| FR-02 | Online application | An applicant submits registration details through the website. The application is stored for administrator review and is not automatically an active membership. |
| FR-03 | Application review | Authorized staff view, approve, or reject registration and renewal applications. The decision and application status are retained. |
| FR-04 | Membership management | Authorized staff manage member records, plan and membership dates, status, payment information, and membership lifecycle records. |
| FR-05 | Member portal | A member views membership status and progress, personal attendance history, and a QR code; updates are limited to supported account and personal-information fields. |
| FR-06 | Renewal request | An eligible member can submit a renewal request for staff review. A request is not an automatic renewal. Chapter 2 specifies the five-calendar-day renewal window before and including the current expiry date. |
| FR-07 | Attendance | Staff scan a member's QR code to record check-in and check-out. Members can view their own attendance history; the member does not record their own attendance. |
| FR-08 | Product and inventory management | Authorized staff maintain products and inventory. Supplements use gram-based quantities; merchandise uses item quantities and stock tracking. |
| FR-09 | Sales and receipts | Staff record in-person product and membership sales for members or walk-in customers. The system stores a sale record and its line items and supports receipt/report views. |
| FR-10 | Operational reports | Authorized staff view and print or save the available membership, member-status, archive, payment, attendance, renewal, inventory, and sales reports. Report contents depend on the records entered into the system. |

### Nonfunctional Requirements

| Area | Requirement |
| --- | --- |
| Platform | The application is accessed through a modern browser with JavaScript enabled. The user interface is implemented as web pages and client-side scripts. |
| Connectivity | Authenticated database-backed functions require an internet connection to reach Supabase. |
| QR scanning | The staff device requires a camera and browser permission to scan QR codes. Production camera access should be served from a secure HTTPS origin. |
| Access control | Database access is restricted through authenticated roles and PostgreSQL Row Level Security policies. Privileged account creation is routed through the administrator-verified Edge Function. The deployed configuration must be tested before use. |
| Data handling | The application stores contact, emergency-contact, and health-related information. Access and retention practices should follow the gym's approved privacy procedures and applicable law. This description is not a certification of legal compliance. |
| Availability | Users depend on the availability of the website host, internet connection, and Supabase services. Operational backup and recovery procedures must be defined for the deployed environment. |

### Software Requirements

| Software | Requirement or purpose |
| --- | --- |
| Web browser | Current browser with JavaScript enabled for applicant, member, and administrator workflows. |
| Frontend | HTML, CSS, and JavaScript files served by a compatible web host. |
| Backend services | Supabase Auth and PostgreSQL, with the project schema, Row Level Security policies, and required database functions configured. |
| Edge Function | Supabase Edge Function runtime for administrator-authorized member account creation. |
| Development environment | Node.js 20 or later to run the repository's local static-file server. This local server is for development, not the production database backend. |
| QR scanning | Browser camera permission and a secure HTTPS origin for production QR scanning. |

### Hardware Requirements

| User or component | Requirement |
| --- | --- |
| Administrator or staff | Desktop computer, laptop, or compatible mobile device with a current browser and internet access. A camera-enabled device is needed when staff scan member QR codes. |
| Applicant or member | Smartphone, tablet, laptop, or desktop computer with a current browser and internet access. |
| Web hosting | Hosting capable of serving the static HTML, CSS, JavaScript, and image assets over HTTPS. Supabase provides the separate authentication and database services. |

### Inputs and Outputs

### Input Requirements

| Input | Examples |
| --- | --- |
| Account credentials | Email and password submitted to Supabase Auth. |
| Registration or renewal application | Name, contact information, membership plan, emergency contact, fitness goals, health declarations, and signature where collected by the form. |
| Attendance | Member QR identifier and staff check-in/check-out action. |
| Product and inventory | Product name, category, price, unit, and merchandise stock quantity where applicable. |
| Sale | Customer type and name, selected products or membership, quantities, and transaction details entered by staff. |
| Report request | Report type, filters, and date range selected by an administrator. |

### Output Requirements

| Output | Description |
| --- | --- |
| Authentication result | Authenticated session and role-based routing, or an error message. |
| Application result | Application status and, after review, the recorded decision. |
| Member portal information | Membership status and progress, QR code, personal attendance history, and active product catalog. |
| Attendance result | Confirmation of staff-recorded check-in/check-out and permitted attendance history. |
| Sale receipt | Receipt details, line items, quantities, prices, and totals. |
| Administrative reports | Membership, member status, archives, payments, attendance, renewals, inventory, and sales information based on stored records. |

## Data Process Modeling

Data process modeling describes how information enters IronGrind, which processes handle it, where records are stored, and what results are returned to applicants, members, and administrators. The model is based on the current Supabase schema and implemented workflows. Email notification is shown only as a planned feature.

### Diagrams

#### System Architecture

Figure 2 shows applicants and members using the login, registration, and member pages, while administrators use the admin dashboard. Supabase Auth verifies credentials and creates the authenticated session; the application then routes users to the member or administrator experience based on profile role. The browser modules are organized as Applications and Membership, Attendance and QR, Inventory and Products, Walk-in POS and Receipts, Member Portal, and Reports and Exports. These modules send requests through the Supabase Data API or database RPC functions. PostgreSQL Row Level Security (RLS) and function-level checks govern access to the Supabase PostgreSQL database, which stores profiles, membership applications, members, attendance, products, sales, sale items, and membership history. The current Realtime configuration publishes changes from `membership_applications` and `attendance` to subscribed website views. The diagram also shows email notification delivery as in development, with no external email provider selected; it should not be described as an operational feature until it is implemented and configured. The Node.js server in the repository serves static files for local development and is not the production database backend.

![Figure 2. IronGrind system architecture](iron-grind-system-architecture.svg)

**Figure 2.** System architecture of IronGrind.

#### Context Diagram

The context diagram treats IronGrind as one system and shows the information exchanged with external actors and backend services. Applicants and members submit credentials, registration or renewal details, and supported profile requests; they receive authentication results and permitted membership, attendance, and catalog information. Administrators submit review decisions, operational updates, sale entries, and report filters; they receive records, receipts, and reports. Walk-in purchase details are entered by staff. Supabase Auth and Supabase data services provide authentication and authorized data access. Email notification integration is planned, not operational.

![Figure 3. IronGrind system context diagram](iron-grind-context-diagram.svg)

**Figure 3.** System context diagram of IronGrind.

#### Data Flow Diagram
**Figure 4.** Level 1 data-process model for IronGrind.

#### Use-Case Diagram

The use-case diagram presents applicant/member and administrator interactions with IronGrind. Applicants and members use the account, application, portal, and attendance-history functions available to their roles. Administrators review applications and manage membership, attendance, products, sales, and reports. Walk-in transactions are entered by staff.

![Figure 5. IronGrind use-case diagram](iron-grind-use-case.svg)

**Figure 5.** Use-case diagram of IronGrind.

#### Entity Relationship Diagram

The entity relationship diagram (ERD) summarizes the principal relationships in the Supabase PostgreSQL schema. A member can have multiple applications, attendance events, membership-history records, and sales. Each sale can have multiple sale items; a sale item may reference a product. Supabase Auth manages account identities separately, with profile and member records linked to authenticated users where configured.

![Figure 6. IronGrind entity relationship diagram](iron-grind-erd.svg)

**Figure 6.** Entity relationship diagram of IronGrind.

The Level 1 data-process model shows how information moves between external actors, system processes, and Supabase data stores. The external actors are the member/applicant and the administrator. The numbered processes cover authentication, membership applications, the member portal, attendance, inventory, sales, and reporting. Email notification is included as a planned process only; it is not yet implemented and has no selected provider. Solid arrows represent requests or data writes, while dashed response arrows represent returned results.

![Figure 4. Level 1 data-process model for IronGrind](iron-grind-data-flow.svg)

**Figure 4.** Level 1 data-process model for IronGrind.

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
| `profiles` | `id` UUID (PK, Auth user); `email` TEXT; `username` TEXT; `full_name` TEXT; `role` TEXT; `created_at` TIMESTAMPTZ | User profile and role used by the application. |
| `members` | `id` UUID (PK); `auth_user_id` UUID (unique, Auth FK); `full_name`, `email`, `username`, `mobile` TEXT; `date_of_birth` DATE; `age` SMALLINT; `height`, `weight_kg` NUMERIC; `height_unit`, `sex`, `plan`, `status`, `registration_source` TEXT; `emergency_contact` JSONB; `plan_price` NUMERIC; `start_date`, `expiry_date` DATE; `paid` BOOLEAN; `fitness_goals`, `health_conditions` TEXT[]; `other_medical_conditions`, `signature_path` TEXT; timestamps | Approved member and membership record. Referenced by applications, attendance, sales, sale items, and membership history. |
| `membership_applications` | `id` UUID (PK); `auth_user_id` UUID (Auth FK); `member_id` UUID (nullable FK); `application_type`, `status`, applicant and plan details TEXT; demographic fields; `emergency_contact` JSONB; goals and conditions TEXT[]; `plan_price` NUMERIC; submission/review TIMESTAMPTZ fields; `reviewed_by` UUID (Auth FK) | Registration and renewal requests and their review state. `member_id` can be empty before approval. |
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

The Gantt chart should show the actual schedule for requirements planning, user design and prototype refinement, construction iterations, verification, implementation, and evaluation. The project files do not establish approved calendar dates, so enter the actual dates and durations from the project records rather than estimating them.

| Activity | Planned start | Planned end | Deliverable |
| --- | --- | --- | --- |
| Data gathering and requirements planning | To be completed from project records | To be completed from project records | Approved requirements specification. |
| User design and prototype | To be completed from project records | To be completed from project records | Reviewed interface and diagrams. |
| Construction iterations | To be completed from project records | To be completed from project records | Working feature increments. |
| Verification and refinement | To be completed from project records | To be completed from project records | Test records and refined system. |
| Implementation and transition | To be completed from project records | To be completed from project records | Deployment and user-orientation records. |
| Evaluation | To be completed from project records | To be completed from project records | Evaluation data and findings. |
