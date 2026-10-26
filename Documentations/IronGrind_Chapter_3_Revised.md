# CHAPTER 3

# RESEARCH METHODOLOGY

This chapter discusses the methodology used to develop **IronGrind: A Web-Based Fitness Gym Membership and Operations Management System for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte**. It describes the development process, system requirements, design, data organization, and evaluation procedures. The system is intended to organize membership applications and records, membership periods and renewals, staff-recorded attendance, products, sales, and reports. Its development is organized using Agile, with work planned and delivered incrementally. Proposed evaluation activities are distinguished from results that have not yet been collected.

### System Development Methodology

Agile is an iterative system-development approach in which stakeholder needs are gathered and prioritized, selected work is developed and tested in increments, and the results inform the next iteration. For IronGrind, this approach organizes development around the gym's applicant/member and administrator workflows. The iteration cycle is summarized in Figure 1. The project does not assume a specific Agile framework such as Scrum; the research team should document the actual iteration length and review practices used and confirm that Agile is the methodology approved in the study proposal.

![Figure 1. Agile Methodology](iron-grind-agile-methodology.svg)

**Figure 1.** Agile Methodology.

### Requirements Planning

Requirements planning begins with gathering information about the gym's workflows and needs from the owner and authorized staff and reviewing the project scope in Chapters 1 and 2. The information is translated into system requirements and organized in a prioritized task list, beginning with account access and membership applications, followed by staff review, member access, attendance, inventory, sales, and reporting. Each selected requirement is given acceptance criteria. The final study should identify the data-gathering techniques and participants actually used. Privacy and authorization requirements apply throughout development because the system handles personal and health-related information.

### User Design

For each iteration, the relevant user workflows, page layouts, forms, reports, data relationships, and role permissions are designed or refined. The design distinguishes pending applications from approved member records, keeps attendance as a separate operational record, and stores sales with their itemized lines. The architecture, use-case, and data-flow figures in this chapter summarize the system design.

### Construction

Selected requirements are implemented in the HTML, CSS, and JavaScript client and the Supabase authentication and PostgreSQL services. Database policies and functions support authorization and operational transactions. Each increment is tested against its acceptance criteria. At the end of an iteration, issues and feedback are recorded, priorities are updated, and unfinished or revised work returns to the prioritized task list. Stakeholder reviews or user feedback should be reported as completed only when the team has records of those activities.

### Implementation

After the required increments pass verification, the website and Supabase project can be configured for the intended environment. Deployment must use the correct project settings, access policies, and authorized administrator accounts. Staff should verify the workflows and receive appropriate orientation. This chapter does not claim a production deployment, completed training, or user acceptance unless those activities are documented separately.

## Study Setting and Intended Users

The system is intended for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte. Its primary users are:

- **Administrator or authorized staff:** review applications, maintain member and membership records, record attendance, manage products and inventory, record sales, and view reports.
- **Applicant:** create an account, submit a membership application, and view application status where supported by the account workflow.
- **Member:** view membership status and period progress, display a QR code for staff scanning, view personal attendance history, update supported personal details, view the active product catalog, and submit an eligible renewal request.
- **Walk-in customer:** purchase products or a membership through staff. A walk-in customer does not use a separate self-service system account for the transaction.

The deployed database distinguishes `admin` and `member` profile roles. Staff functions are performed through an authorized administrator account; the system does not define a separate staff role in the database schema.

## System Requirements

### Functional Requirements

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

### Inputs and Outputs

| Category | Examples |
| --- | --- |
| Account | Sign-in and account information handled by Supabase Auth. |
| Application and member record | Identity and contact information, selected plan, membership dates, emergency contact, fitness goals, and health declarations collected by the forms. |
| Attendance | Member identity and staff-recorded check-in/check-out events. |
| Product and inventory | Product name, category, price, unit, and merchandise stock quantity where applicable. |
| Sale | Customer type and name, selected products or membership, quantities, prices, and transaction status. |
| Member output | Membership status and progress, QR code, attendance history, and active catalog information. |
| Staff output | Applications, member and attendance records, inventory, sale and receipt details, and operational reports. |

## System Design

### System Architecture

The browser presents the applicant/member pages and administrator dashboard. Client-side JavaScript sends authentication and data requests to Supabase. Supabase Auth manages user identity and sessions; the PostgreSQL database stores the operational records. Row Level Security policies and database functions restrict and validate database operations. Privileged account creation uses a server-side Edge Function that verifies administrator authorization. The Node.js server in the repository is a local static-file development server; it is not the production database backend.

![Figure 2. IronGrind system architecture](iron-grind-system-architecture.svg)

**Figure 2.** System architecture of IronGrind.

### Use-Case Model

The use-case model summarizes the actions available to applicants, members, and authorized staff. Applicants submit registration information; members review their own membership and attendance information and may request renewal; staff handle approvals and the gym's operational records. Walk-in sales are entered by staff rather than through a separate customer portal.

![Figure 3. IronGrind use-case diagram](iron-grind-use-case.svg)

**Figure 3.** Use-case diagram of IronGrind.

### Data-Flow Model

Registration information is submitted to the application workflow and remains pending until staff review it. Approval connects the application to a member record and records the associated membership transaction. Renewal submissions follow the same staff-review principle. During a gym visit, staff scan the member QR code and record attendance. Staff maintain product records and enter in-person sales; each sale is stored with its line items. Authorized staff request operational views and reports from the records maintained by the system.

![Figure 4. IronGrind data-flow diagram](iron-grind-data-flow.svg)

**Figure 4.** Data-flow diagram of IronGrind.

## Database Design

The system uses Supabase PostgreSQL for application data. Supabase Auth manages account credentials and sessions separately from the business records. The public-schema tables in the project represent the following entities:

| Entity | Purpose |
| --- | --- |
| `profiles` | Application profile and role associated with an authenticated user. |
| `members` | Approved member record, including contact and membership details, status, plan dates, payment status, goals, emergency contact, and health-related fields. |
| `membership_applications` | Registration and renewal submissions, requested information, review status, and decision metadata. |
| `attendance` | Member check-in and check-out records, including the staff account that recorded the event where available. |
| `products` | Product catalog and inventory details, including category and unit. Supplements use grams; merchandise uses item units. |
| `sales` | Transaction header, receipt identifier, customer information, total, status, timestamp, and processing staff account. |
| `sale_items` | Itemized sale details, including product description, quantity, unit, price, and line total. Membership transactions are represented as sale items. |
| `membership_history` | Membership lifecycle events, such as expiration, renewal, and plan changes. |

The principal relationships are one member to many attendance records, applications, and membership-history records; one sale to many sale items; and one product to many sale items where a product reference is retained. A sale may refer to a member or represent a walk-in customer. Payment-related reports are derived from recorded membership and sales information; the schema does not define a separate payments table.

## User Interface Modules

| Page or module | Purpose |
| --- | --- |
| Sign-in page (`index.html`) | Authenticates users and routes them to the appropriate application experience. |
| Registration page (`register.html`) | Collects an online membership application for review. |
| Administrator dashboard (`admin.html`) | Provides application review, membership administration, attendance, inventory, sales, receipts, and reports. |
| Member portal (`customer.html`) | Provides member status and progress, QR display, attendance history, renewal request, supported personal settings, and the active catalog. |
| Password recovery (`reset-password.html`) | Supports the account password-reset workflow. |

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

## Development Phase Schedule

The Agile schedule below describes recurring iteration work and release activities; it is not a record of dates or completed milestones. Add the actual iteration length, dates, completed increments, and deliverables required by the institution.

| Agile activity | Activities | Deliverable |
| --- | --- | --- |
| Data gathering and task prioritization | Gather information about scope, user roles, workflows, data needs, and privacy requirements; identify priorities and acceptance criteria. | Confirmed needs and prioritized task list. |
| Iteration planning and design | Select tasks from the prioritized task list and refine the relevant page flows, data relationships, and permissions. | Iteration goal and design notes. |
| Incremental implementation | Build and integrate the selected browser workflows, Supabase schema, access policies, and database functions. | Working software increment. |
| Iteration testing and review | Test the increment against its acceptance criteria, record defects, and review the result with intended stakeholders where arranged. | Test records, review feedback, and updated task list. |
| Repeat and refine | Prioritize remaining work and repeat planning, design, implementation, testing, and review until the agreed scope is complete. | Successive verified increments. |
| Release and transition | Configure the intended environment, verify access, prepare approved records, and orient users. | Deployment and transition records. |
| Evaluation | Administer the approved user-evaluation instrument and analyze the collected data. | Evaluation dataset, analysis, and findings. |

## Alignment Notes for Final Submission

1. Confirm that Agile is the methodology approved in the study proposal. State the actual iteration length, planning and review practices, and team responsibilities used; the source files do not independently establish those details.
2. Add the actual respondents or participants, sampling method, instrument, statistical treatment, and evaluation results required by the institution. Do not infer or fabricate these details from the application code.
3. Confirm the final renewal-window wording against the approved Chapter 1 and the deployed system configuration.
4. Keep the stated system limitations and security claims consistent with the production configuration and the final scope approved for the study.
