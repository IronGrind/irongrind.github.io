# IronGrind Entity Relationship Diagram Explanation

## Overview

The simplified entity relationship diagram (ERD) describes how IronGrind organizes information for user accounts, membership applications, gym members, attendance, products, sales, and membership history. Each entity represents a category of records. Primary keys (PKs) uniquely identify records, while foreign keys (FKs) connect records in related entities.

The diagram presents **eight application tables**: `profiles`, `membership_applications`, `members`, `attendance`, `products`, `sales`, `sale_items`, and `membership_history`. `auth_users` is also drawn to show the account links, but it is managed by Supabase Authentication and is not one of the eight application tables in the public database schema.

![Simplified IronGrind entity relationship diagram](iron-grind-erd-simplified.svg)

**Figure.** Simplified entity relationship diagram of IronGrind.

## The Eight Tables

| Table | Purpose | Important links |
| --- | --- | --- |
| `profiles` | Stores application-facing user details and role information, such as username, name, and whether the user has an administrator or member role. | Its `id` is also the ID of the corresponding Supabase Auth user. |
| `membership_applications` | Stores submitted registration and renewal requests, their plan and application type, submission time, status, and review information. | Links to the applicant's Auth account; may link to a member record; identifies the reviewer. |
| `members` | Stores the gym's member and membership details, including plan, dates, status, and the linked account when one exists. | May link to an Auth account and an originating application. A member can have multiple applications, attendance records, sales, and membership-history entries. |
| `attendance` | Stores each member check-in and check-out as an individual attendance record, including the times and staff account that recorded it. | Links to one member and optionally to the recording Auth user. |
| `products` | Stores the active product catalog and inventory details, including product name, category, price, stock, and active status. | A product may be referenced by sale-item records. |
| `sales` | Stores each transaction's receipt number, customer/member association, total, status, time, and staff account that processed it. | May link to a member and can contain multiple sale items. |
| `sale_items` | Stores the individual lines within a sale, including the item description, quantity, unit price, and line total. | Each line belongs to a sale and may link to a product. The saved item name and price preserve sale details even if the product record later changes or is removed. |
| `membership_history` | Records membership lifecycle events, such as expiration, renewal, and plan changes, with relevant previous and new values. | Each history entry links to one member and may identify the Auth user who recorded it. |

## Relationships

- **Auth users and profiles:** Each profile uses the same ID as its Supabase Auth user. Authentication credentials are managed by Supabase, separately from the eight application tables.
- **Auth users and members:** A member may be connected to an Auth account for portal access. The account link can be absent, for example, for a record created by an administrator. The database enforces at most one member record per Auth user.
- **Auth users and applications:** An application is associated with the account that submitted it. A member may submit multiple applications over time, including renewal requests.
- **Applications and members:** An application can be linked to a member after it is reviewed and processed. The member record may also store the originating application ID. This is shown as a one-to-one-style link in the simplified diagram, but the live schema does not enforce uniqueness on `members.application_id`; treat that cardinality as the intended workflow, not a database-enforced guarantee.
- **Members and attendance:** One member can have many attendance records; each attendance record belongs to one member.
- **Members and sales:** A sale may be associated with a member, while a walk-in sale may have no member link. A member can have multiple sales.
- **Sales and sale items:** One sale can contain multiple sale-item rows. Each sale-item row belongs to one sale.
- **Products and sale items:** A product can appear in many sale-item rows. A sale-item product link may be empty, while the line still retains its item description and price.
- **Members and membership history:** One member can have multiple history entries; each entry belongs to one member.
- **Staff attribution:** Attendance, sales, and membership-history records can identify the Auth user who recorded or processed them. Application review also records the reviewer. These IDs provide accountability without making the staff account itself an operational record.

In the current SQL schema, `membership_applications.reviewed_by` references `auth.users`. The diagram draws this review relationship through `profiles` to make the application role visible. Both represent the reviewing user's account identity, but the direct foreign-key target in the database is the Auth user table.

## Entity Process Flow

### 1. Account and profile creation

When a user registers an account, Supabase Auth creates the authentication record. A corresponding `profiles` row uses the same user ID and stores the application role and profile information. If the person later becomes a gym member, a `members` row can be linked to that Auth account.

### 2. Registration or renewal application

An applicant or member submits a request, which is stored in `membership_applications` with its type and pending status. An authorized administrator reviews it, and the reviewer's account and decision are recorded. An approved registration can result in a `members` record linked to the application. A renewal request remains an application until reviewed; submitting it does not itself renew the membership. When a membership change is completed, the corresponding event can be retained in `membership_history`.

### 3. Attendance recording

Staff use the member's QR code to identify the member. The system stores each check-in or check-out in `attendance`, linked to the member and, when available, the staff Auth account that recorded it. A member's visit history is therefore a set of attendance records rather than fields embedded in the member row.

### 4. Product sales

Administrators maintain available items in `products`. When staff process a sale, the transaction header is stored in `sales`; each purchased item is stored separately in `sale_items`. This parent-and-detail structure lets one receipt contain multiple lines. A line may keep its product reference when available, as well as a snapshot of the item name and pricing used for that transaction. A sale can be associated with a member or recorded for a walk-in customer.

### 5. Membership history and reporting

Membership events are stored as separate `membership_history` records so changes over time can be reviewed without replacing the current values in `members`. Administrative reports can combine the relevant application, member, attendance, product, sale, sale-item, and history records. The ERD shows where those records are related; it does not prescribe a particular report or guarantee that records are complete.

## Reading the Diagram

The crow's-foot symbols indicate whether a relationship is one-to-one, one-to-many, or optional. For example, the member-to-attendance relationship means a member can have zero or many attendance entries, while each attendance entry refers to one member. Optional links allow records such as walk-in sales or administrator-created members to exist without a linked member account. The diagram is intentionally simplified: it shows the principal keys and relationships and omits many descriptive fields and database implementation details. Where an exact constraint matters, the Supabase SQL schema is authoritative.