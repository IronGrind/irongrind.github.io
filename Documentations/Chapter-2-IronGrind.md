# CHAPTER 2
# REVIEW OF RELATED LITERATURE AND SYSTEMS

This chapter reviews concepts and existing systems related to IronGrind: A Web-Based Fitness Gym Membership and Operations Management System. It discusses gym operations software, centralized information management, membership administration, QR-based attendance, product inventory and point-of-sale records, reporting, and access control. The review is limited to the functions identified in Chapter 1 and relates them to the implementation for Iron Grind Fitness Gym in Purok Mangga, Sulongon, Dapitan City, Zamboanga del Norte.

## Review of Related Literature

### Digital Management of Gym Operations

A fitness gym handles several connected administrative activities. These include maintaining member profiles, processing applications and renewals, monitoring membership validity, recording attendance, managing products, and preparing sales and operating reports. When these activities are kept in separate paper forms, logbooks, or files, staff may need to search multiple records to answer a basic operational question. Repeated encoding can also create inconsistent or incomplete information. A shared information system can organize these records around the member, transaction, or product to which they belong.

Commercial gym-management platforms illustrate how these activities can be brought together. GymMaster describes its software as supporting member profiles, membership administration, billing, access control, point-of-sale and inventory, online sign-ups, and reporting-related functions (GymMaster, n.d.). GYMMANAGER similarly presents an integrated platform for sales, customer management, access control, club operations, and analytics (GYMMANAGER, n.d.). These descriptions are useful examples of the functional range available in the sector. Because both sources describe their own products, their feature statements are treated here as vendor documentation rather than independent evidence of effectiveness.

The relevance to IronGrind is the principle of organizing related gym work in a common administrative environment. IronGrind is scoped to the processes of one local gym rather than the broader capabilities advertised by commercial platforms. Its admin dashboard brings together applications, membership information, staff-recorded attendance, products, sales, and reports. Its member dashboard provides access to selected account and membership information. The system is not described as a multi-branch platform or as a complete replacement for every commercial gym-management function.

### Centralized Information and Membership Records

Member administration involves more than recording a name and contact details. A gym may need to retrieve the member's selected plan, membership dates, current status, payment record, renewal history, and related application. When these details are maintained separately, it can be difficult to reconstruct a member's history or determine which record is current. A centralized database can associate records through identifiers and relationships, making retrieval and updates more consistent when the data is entered and maintained correctly.

IronGrind applies this idea through its Supabase PostgreSQL data model. The project includes separate records for account profiles, members, membership applications, membership history, attendance, products, sales, and sale items. Applications retain their review status, while membership history records lifecycle events such as renewal, expiry, and plan changes. These distinctions support the Chapter 1 objectives to organize member profiles, plans, payment records, and membership histories and to provide separate reports for membership-related activity.

Centralization does not by itself guarantee accurate information. The quality of reports and member-facing details depends on valid inputs, consistent staff procedures, and suitable authorization rules. IronGrind therefore treats the database as the shared source for its browser-based views while retaining staff responsibilities for reviewing applications, recording counter transactions, and maintaining operational data.

### Membership Applications, Renewals, and Lifecycle Tracking

Membership administration commonly includes an intake stage, a decision stage, an active membership period, and subsequent renewal or expiry. Keeping an application distinct from an approved membership record preserves the review process: a submission can remain pending until an administrator approves or rejects it. Recording renewal and plan-change events also provides historical context instead of overwriting all prior membership details.

In IronGrind, applicants submit registration information online, and the administrator reviews the resulting application. Approval connects the approved membership details to the member record and records the associated membership transaction. The system also accepts member renewal requests only within the configured five-calendar-day period before expiry. A renewal request is subject to staff review and approval; it is not an automatic renewal or automatic charge. Membership progress in the member dashboard represents elapsed time in the membership period, not measured exercise or fitness progress.

This workflow directly addresses Chapter 1's questions about reviewing registrations and renewal requests, monitoring status, and maintaining membership history. It also establishes an important scope distinction: the system records payment information for transactions handled by the gym but does not collect payment through an online gateway.

### QR-Based Attendance Recording

Attendance records help a gym review member visits and maintain an operational history of check-ins and check-outs. Manual logs can be difficult to search and may contain unclear, missing, or duplicate entries. A digital attendance workflow can associate an attendance event with a member and a timestamp, making the resulting records available for authorized review. A QR code can serve as a scannable identifier in this process, but the scan itself does not replace the access rules and staff procedures that determine whether and how an attendance event is recorded.

IronGrind uses a staff-operated QR scanning workflow. Staff scan a member's QR code to record check-in and check-out times; members can view their own attendance history in the member dashboard. The QR code is therefore an operational identifier used at the gym, not a self-service attendance control. This design matches Chapter 1, which specifies staff scanning and excludes members independently recording their own attendance. The database stores attendance events separately from membership records so that visit history can be reviewed without treating each visit as a change to the membership itself.

### Product Inventory, Point of Sale, and Receipts

A gym store may handle products with different units and stock rules. Merchandise such as shirts is typically counted by item and can have a finite stock quantity. Supplements sold by measured quantity require a different unit and may not use the same item-count stock field. Sales records also need enough detail to identify the transaction, customer type, products, quantities, and totals. Retaining a receipt record and its line items allows the gym to review transactions and produce sales summaries.

IronGrind reflects these distinctions in its product and sales data. The system categorizes supplements and merchandise separately. Supplements are priced and sold by gram, while merchandise is tracked by item and stock quantity. Staff record in-person product sales and membership transactions; walk-in purchases may be included without creating a member account. Sales and sale-item records support receipt information and reporting. The implemented scope does not include online product reservations, checkout, or payment processing. These boundaries are important when describing the system: it supports the gym's recording of in-person transactions, not an e-commerce storefront.

### Operational Reporting

Reports make operational records easier to review by grouping information according to a question, such as which memberships are active, which applications are awaiting review, what attendance was recorded, what products remain available, or what sales were entered during a period. A report is only as dependable as the records and rules behind it. Definitions such as membership status, transaction date, and product unit therefore need to remain consistent across data entry and report views.

IronGrind's reporting scope follows the records maintained by its operational modules. Chapter 1 identifies reports for membership, member status, archives, payments, attendance, renewals, inventory, and sales. These views are intended to help the gym's owner and administrator retrieve and review available system information. The chapter does not claim measured improvements in accuracy, processing time, or business performance; those outcomes would require a separate evaluation using an agreed method and collected results.

### Web-Based Access, Authorization, and Privacy

A browser-based system makes information available through web pages, but each user should receive only the access needed for their role. PostgreSQL Row-Level Security (RLS) policies can restrict which rows a database operation may return or modify. Supabase explains that RLS policies are evaluated as part of table access and can be used with Supabase Auth to enforce row-level access rules (Supabase, n.d.). The PostgreSQL documentation likewise describes policies that limit rows available for selection or modification according to the current role and policy conditions (PostgreSQL Global Development Group, n.d.).

IronGrind uses Supabase Auth for account identity and session management, profile roles to distinguish administrators from members, and database policies and authorized database operations to protect records. Administrative operations are not intended to rely only on hiding controls in the browser. The project also routes privileged staff-created account operations through a server-side Edge Function that checks the administrator role. The effectiveness of these controls depends on the deployed database configuration and must be verified through appropriate policy and role tests.

Privacy is especially relevant because registration records may contain contact information, emergency-contact details, and health declarations. Republic Act No. 10173, or the Data Privacy Act of 2012, sets principles for processing personal information, including transparency, legitimate purpose, and proportionality; it also treats health information as sensitive personal information (Republic Act No. 10173, 2012, secs. 3, 11, 13). Applied to IronGrind, this means the gym should explain why information is collected, limit collection and access to legitimate operational needs, protect the records, and establish appropriate retention and handling procedures. Mentioning the law in this review does not by itself certify that a system or organization is compliant; compliance depends on actual practices, notices, safeguards, and governance.

## Review of Related Systems

### GymMaster

GymMaster is a commercial gym-management product whose vendor describes functions for memberships, member profiles, billing, access control, point-of-sale, inventory, online sign-ups, and member-facing applications (GymMaster, n.d.). These functions show that membership administration and front-desk sales are established categories in gym-management software. IronGrind shares the narrower operational concern of organizing member records, applications, attendance, products, sales, and reports. Its implementation is tailored to the stated workflow of Iron Grind Fitness Gym and does not claim feature parity with GymMaster, particularly for billing integrations, automated access hardware, or native mobile applications.

### GYMMANAGER

GYMMANAGER describes a platform that combines customer management, sales, access control, facility operations, and analytics for sports and fitness facilities (GYMMANAGER, n.d.). This provides another example of an integrated approach to club administration. IronGrind similarly places several administrative records in one system, but its scope is deliberately smaller: staff manage check-in/check-out by scanning member QR codes, members view selected information through a web portal, and payments remain in person. Features advertised by GYMMANAGER, such as broader payment integrations, booking, or dedicated apps, are not assumed to exist in IronGrind.

### Comparison of Related Systems and IronGrind

| Area | Related-system context | IronGrind implementation and boundary |
|---|---|---|
| Member administration | Commercial platforms describe member and customer management. | Stores member profiles, plan and membership dates, status, application links, and membership history. |
| Applications and renewals | Online sign-up and membership workflows appear in commercial gym software. | Applicants submit registration online; staff review applications; eligible members can submit a renewal request during the configured five-day pre-expiry window. |
| Attendance | Gym platforms may connect membership to access-control functions. | Staff scan a member QR code to record check-in/check-out; members can view attendance history. No automated gate access is claimed. |
| Products and sales | Point-of-sale and inventory management are common commercial categories. | Staff record in-person sales; supplements use gram-based quantities and merchandise uses item stock. Online checkout is excluded. |
| Reports | Commercial products describe analytics and operational reporting. | Admin reports cover the data areas specified in Chapter 1: membership, status, archives, payments, attendance, renewals, inventory, and sales. |
| User access | Web and member-facing tools are offered in the sector. | Browser-based admin and member pages use Supabase Auth and configured role/database controls; a native mobile application is not included. |

The comparison is functional rather than evaluative. It does not rank vendors or claim that one product performs better than another. The commercial sources establish examples of available features, while IronGrind's scope is determined by the requirements and boundaries in Chapter 1.

## Synthesis of the Review

The reviewed literature and systems point to a shared operational pattern: gym administration connects member information, membership lifecycle events, attendance, products, sales, and management reports. Keeping these records related can make them easier to retrieve and review, while role-based authorization and careful handling of personal information are necessary because the system stores identifiable and potentially sensitive data. Existing commercial products demonstrate that these functional areas are recognized parts of gym-management software, but their broader feature sets are not a specification for every local system.

IronGrind applies these concepts to the workflow described in Chapter 1. It uses a centralized Supabase database for profile, member, application, attendance, product, sale, and history records; separates applicant review from approved membership; lets staff record attendance through QR scanning; distinguishes gram-based supplements from item-count merchandise; records in-person transactions; and provides role-appropriate browser views and reports. The member portal supports access to membership information, attendance history, QR code, supported account settings, and renewal requests.

The practical need addressed by the study is therefore not to reproduce a commercial platform in full. It is to provide Iron Grind Fitness Gym with one web-based workspace for its specified membership and operations activities while preserving its stated limits: no online payment gateway, no online product checkout, no member-operated attendance entry, no automated fitness coaching, and no native mobile application. The expected organizational value is improved access to the records the system captures; any claims about actual efficiency, accuracy, or user satisfaction must be established through the evaluation described in the succeeding chapter.

## Conceptual Framework

The study may be represented using an Input-Process-Output (IPO) framework. Inputs are operational information entered by applicants, members, and authorized staff. Processes are the system functions that validate, organize, and connect those inputs. Outputs are the views and records made available to authorized users.

| Input | Process | Output |
|---|---|---|
| Applicant and member details, membership plan, application or renewal information | Authenticate user; submit and review application; maintain member and membership-history records | Member profile, application status, membership status and period, renewal information |
| Member QR code and staff attendance action | Resolve member identity and record check-in/check-out timestamps | Attendance history for authorized admin and member views |
| Product details, unit, price, and merchandise stock | Maintain catalog; record in-person sale and line items; update merchandise quantity when applicable | Product availability, transaction and receipt records |
| Membership, attendance, inventory, and sales records; report filters | Retrieve and group authorized records by operational category and period | Admin reports and member-facing account information |
| Account identity and role | Apply Supabase Auth, role checks, database authorization, and configured RLS policies | Role-appropriate access to permitted system functions and records |

The framework describes the relationship between the study's inputs, system processes, and intended outputs; it is not a claim that all outputs have already been evaluated or that every result is produced automatically. Figure 2.1 may be prepared from this table if the institution requires an illustrated framework.

## Alignment with the Objectives of Chapter 1

| Chapter 1 objective | Related concept reviewed | Corresponding IronGrind capability |
|---|---|---|
| Organize member profiles, plans, membership dates and status, and membership history. | Centralized records and membership lifecycle tracking. | Member, profile, and membership-history data stored in Supabase. |
| Provide online registration and renewal requests for administrator review. | Application intake, approval workflow, and renewal management. | Online registration applications and renewal submissions; staff approve or reject; renewals are constrained to the configured five-day eligibility period. |
| Provide membership payment records and QR-based attendance. | Transaction records and timestamped attendance events. | Membership sales are recorded; staff scan member QR codes for check-in/check-out; attendance is available in admin and member views. |
| Manage supplement and merchandise products, stock, and in-person sales. | Unit-aware inventory and point-of-sale records. | Supplements are sold by gram; merchandise uses item stock; staff record member or walk-in sales and receipts. |
| Provide reports for membership, status, archives, payments, attendance, renewals, inventory, and sales. | Operational reporting from consistent source records. | Admin reporting views draw on the system's operational database records. |
| Let members access membership information, attendance, QR code, and renewal form. | Member self-service with role-appropriate access. | Member dashboard provides these scoped features and supported personal-information updates. |

## References

DeLone, W. H., & McLean, E. R. (2003). The DeLone and McLean model of information systems success: A ten-year update. *Journal of Management Information Systems, 19*(4), 9–30. https://doi.org/10.1080/07421222.2003.11045748

GYMMANAGER. (n.d.). *Gym management software*. Retrieved October 25, 2026, from https://gymmanager.io/

GymMaster. (n.d.). *About us*. Retrieved October 25, 2026, from https://www.gymmaster.com/about-us/

National Privacy Commission. (2012). *Republic Act No. 10173: Data Privacy Act of 2012*. https://privacy.gov.ph/data-privacy-act/

PostgreSQL Global Development Group. (n.d.). *Row security policies*. In *PostgreSQL 18 documentation*. Retrieved October 25, 2026, from https://www.postgresql.org/docs/current/ddl-rowsecurity.html

Supabase. (n.d.). *Row level security*. Retrieved October 25, 2026, from https://supabase.com/docs/guides/database/postgres/row-level-security
