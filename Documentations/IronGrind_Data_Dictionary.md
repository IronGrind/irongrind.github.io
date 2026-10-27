# IronGrind Data Dictionary

## Purpose and Scope

This dictionary describes the eight application tables in the PostgreSQL `public` schema. It follows `supabase/schema.sql` and the schema-affecting migrations in `supabase/migrations/`; the live Supabase catalog is authoritative if an installation differs.

The field tables use the earlier per-entity format. Type modifiers such as `numeric(7, 2)` state precision and scale; PostgreSQL `text` and `text[]` have no declared character limit, and `jsonb` has no fixed maximum length. Supabase-managed `auth.users` is outside these eight application tables, but its UUID `id` is referenced by application records.

## Table Summary

| Table | Purpose |
| --- | --- |
| `profiles` | Stores application-facing account details, access roles, and account status where deployed. It connects a signed-in Supabase Auth user to IronGrind permissions. |
| `members` | Stores current personal and membership details for gym members. It links member records to accounts and applications where applicable. |
| `membership_applications` | Stores submitted registration and renewal requests. It tracks application details and administrative review outcomes. |
| `attendance` | Stores member check-ins and check-outs. It provides visit history for attendance tracking. |
| `products` | Stores the product catalog, prices, and inventory state. It supports product availability and sales. |
| `sales` | Stores receipt-level transaction details. It records the customer, total, status, and staff attribution. |
| `sale_items` | Stores individual product or membership charges for a sale. It preserves item details used for the transaction. |
| `membership_history` | Stores membership lifecycle events and prior/new values. It supports administration and historical reporting. |

## 1. `profiles`

**Description:** Stores application-facing account details and the user's access role. Each profile uses the same identifier as its Supabase Auth account, with account status available in deployments that include that field.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL | PK; FK to `auth.users.id`, ON DELETE CASCADE | Account identifier shared with Supabase Auth. |
| `email` | `text` | NOT NULL | UNIQUE | Account email, synchronized from Supabase Auth. |
| `username` | `text` | NULL | UNIQUE | Application username; availability checks compare case-insensitively. |
| `full_name` | `text` | NOT NULL; `''` | — | Display name associated with the account. |
| `role` | `text` | NOT NULL; `'member'` | CHECK `admin` or `member` | Controls application administrator or member access. |
| `account_status` | `text` | Deployment-dependent | No constraint documented | Optional live-schema field where deployed. Represents the account availability state. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Profile creation time. |
| `updated_at` | `timestamptz` | Deployment-dependent | No default documented | Optional live-schema field where deployed. Records the most recent profile update time. |

## 2. `members`

**Description:** Stores each gym member's current personal details and membership information. Previous membership changes are recorded separately in `membership_history`.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Internal member identifier. |
| `auth_user_id` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL; unique when non-NULL | Portal account linked to the member. A partial unique index allows at most one member per Auth account. |
| `application_id` | `uuid` | NULL | FK to `membership_applications.id`, ON DELETE SET NULL; indexed, not unique | Registration application associated with the member record. It can be empty for members created by an administrator. |
| `full_name` | `text` | NOT NULL | — | Member's full name. |
| `email` | `text` | NULL | — | Member contact email; synchronized from Auth when linked. |
| `username` | `text` | NULL | — | Member's application username, when available. |
| `mobile` | `text` | NULL | — | Member contact number; profile updates validate Philippine mobile format. |
| `date_of_birth` | `date` | NULL | — | Member's birth date. |
| `age` | `smallint` | NULL | CHECK NULL or >= 0 | Age value captured or calculated by profile updates. |
| `sex` | `text` | NULL | — | Member-provided sex value. |
| `height` | `numeric(7, 2)` | NULL | — | Height measurement; unit is stored separately. |
| `height_unit` | `text` | NULL | CHECK NULL, `cm`, `in`, or `ft` | Unit for `height`. |
| `weight_kg` | `numeric(7, 2)` | NULL | — | Weight in kilograms. |
| `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Structured emergency-contact details. |
| `plan` | `text` | NULL | — | Current membership plan name. |
| `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK >= 0 | Current membership price. |
| `start_date` | `date` | NULL | — | Start date of the current membership period. |
| `expiry_date` | `date` | NULL | — | Canonical membership expiry date. |
| `end_date` | `date` | NULL | — | Compatibility date retained by membership operations; may be used when `expiry_date` is empty. |
| `status` | `text` | NOT NULL; `'active'` | CHECK `active`, `expired`, or `inactive` | Current member/membership status. |
| `registration_source` | `text` | NOT NULL; `'Online application'` | — | Origin of the member record. |
| `paid` | `boolean` | NOT NULL; `false` | — | Whether the membership payment has been recorded as paid. |
| `fitness_goals` | `text[]` | NOT NULL; `{}` | — | List of member fitness goals. |
| `health_conditions` | `text[]` | NOT NULL; `{}` | — | List of declared health conditions. |
| `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information. |
| `signature_path` | `text` | NULL | — | Storage path or reference for the member's signature asset. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Member record creation time. |
| `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent member record update time. |

## 3. `membership_applications`

**Description:** Stores submitted registration and renewal requests with the information provided by the applicant. Review status, reviewer, and timestamps track each request through processing.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Application identifier. |
| `auth_user_id` | `uuid` | NOT NULL | FK to `auth.users.id`, ON DELETE CASCADE; indexed | Auth account that submitted the request. |
| `member_id` | `uuid` | NULL | FK to `members.id`, ON DELETE SET NULL | Existing member associated with a renewal or processed application. |
| `application_type` | `text` | NOT NULL | CHECK `registration` or `renewal` | Distinguishes new-member registration from renewal. |
| `full_name` | `text` | NOT NULL | — | Applicant/member name submitted with the request. |
| `email` | `text` | NOT NULL | — | Email captured with the application. |
| `username` | `text` | NULL | — | Username captured with the application. |
| `mobile` | `text` | NULL | — | Contact number submitted by the applicant. |
| `date_of_birth` | `date` | NULL | — | Applicant's birth date. |
| `age` | `smallint` | NULL | CHECK NULL or >= 0 | Applicant's age. |
| `sex` | `text` | NULL | — | Applicant-provided sex value. |
| `height` | `numeric(7, 2)` | NULL | — | Height measurement; unit is stored separately. |
| `height_unit` | `text` | NULL | CHECK NULL, `cm`, `in`, or `ft` | Unit for `height`. |
| `weight_kg` | `numeric(7, 2)` | NULL | — | Weight in kilograms. |
| `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Emergency contact in the main application payload. |
| `emergency_contact_data` | `jsonb` | NOT NULL; `{}` | — | Compatibility emergency-contact payload; not automatically synchronized with `emergency_contact`. |
| `plan` | `text` | NOT NULL | — | Membership plan requested. |
| `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK >= 0 | Price submitted for the requested plan. |
| `start_date` | `date` | NULL | — | Requested membership start date. |
| `end_date` | `date` | NULL | — | Requested membership end date. |
| `fitness_goals` | `text[]` | NOT NULL; `{}` | — | Applicant's fitness goals. |
| `health_conditions` | `text[]` | NOT NULL; `{}` | — | Applicant's declared health conditions. |
| `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information. |
| `signature_path` | `text` | NULL | — | Storage path or reference for the submitted signature. |
| `status` | `text` | NOT NULL; `'pending'` | CHECK `pending`, `approved`, or `rejected` | Current application review outcome. |
| `submitted_at` | `timestamptz` | NOT NULL; `now()` | Indexed with `status` | Submission timestamp. |
| `reviewed_at` | `timestamptz` | NULL | — | Time the application was reviewed. |
| `reviewed_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Auth account of the reviewer. |

## 4. `attendance`

**Description:** Stores one record for each member visit to the gym. Check-in and optional check-out timestamps support attendance history and visit tracking.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Attendance record identifier. |
| `member_id` | `uuid` | NOT NULL | FK to `members.id`, ON DELETE RESTRICT; indexed with `time_in` | Member who attended; referenced members cannot be deleted. |
| `time_in` | `timestamptz` | NOT NULL; `now()` | Part of `(member_id, time_in DESC)` index | Member check-in time. |
| `time_out` | `timestamptz` | NULL | CHECK NULL or >= `time_in` | Member check-out time; NULL can indicate an open visit or missing check-out. |
| `recorded_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Staff account that recorded the attendance event. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Attendance row creation time. |

## 5. `products`

**Description:** Stores products offered for sale, including prices, units, and inventory information. Active and archived product records support catalog management and sales history.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Product identifier. |
| `name` | `text` | NOT NULL | — | Product display name. |
| `category` | `text` | NOT NULL | CHECK `supplement` or `merchandise` | Determines product type and inventory behavior. |
| `price_per_unit` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Price for one stored unit (gram or item). |
| `unit` | `text` | NOT NULL | CHECK `gram` or `item` | Unit in which the product is sold. Supplements use `gram`; merchandise uses `item`. |
| `size` | `text` | NULL | — | Optional product size or package description. |
| `stock` | `integer` | NULL | CHECK NULL or >= 0 | Merchandise quantity on hand. Supplements use NULL stock; sale operations expect merchandise stock to be set. |
| `image_path` | `text` | NULL | — | Storage path or reference for the product image. |
| `is_active` | `boolean` | NOT NULL; `true` | — | Whether the product is currently offered for sale. |
| `archived_at` | `timestamptz` | NULL | Added by `operational_data.sql` migration | Time the product was archived, if applicable. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Product creation time. |
| `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent product update time. |

Supplements use `gram` and NULL stock; merchandise uses `item`. Merchandise stock should be set for inventory operations.

## 6. `sales`

**Description:** Stores one record for each receipt-level transaction. It captures the customer, total, sale status, and staff account that processed the transaction.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale identifier. |
| `receipt_number` | `text` | NOT NULL | UNIQUE | Human-readable receipt identifier. |
| `customer_type` | `text` | NOT NULL | CHECK `member` or `walk_in` | Identifies the customer category. |
| `customer_name` | `text` | NOT NULL | — | Customer name saved on the receipt. |
| `member_id` | `uuid` | NULL | FK to `members.id`, ON DELETE SET NULL | Member associated with the transaction; NULL for walk-in sales. |
| `total` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Total transaction amount. |
| `status` | `text` | NOT NULL; `'paid'` | Canonical values `paid`, `voided` | Sale state; compatibility migration normalizes stored status to lowercase. |
| `sold_at` | `timestamptz` | NOT NULL; `now()` | Indexed descending | Time of sale. |
| `processed_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Auth account of the staff member who processed the sale. |

## 7. `sale_items`

**Description:** Stores each product or membership charge associated with a sale. Item name and price are retained as a transaction snapshot if the catalog record later changes or is removed.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale-line identifier. |
| `sale_id` | `uuid` | NOT NULL | FK to `sales.id`, ON DELETE CASCADE; indexed | Parent receipt; deleting a sale deletes its line items. |
| `product_id` | `uuid` | NULL | FK to `products.id`, ON DELETE SET NULL | Catalog product represented by this line, if applicable. |
| `item_name` | `text` | NOT NULL | — | Item/plan name snapshot printed on the receipt. |
| `category` | `text` | NOT NULL | CHECK `supplement`, `merchandise`, or `membership` | Type of item charged. |
| `quantity` | `numeric(12, 3)` | NOT NULL | CHECK > 0 | Sold quantity, supporting fractional gram amounts. |
| `unit` | `text` | NOT NULL | CHECK `gram`, `item`, or `membership` | Unit used for the line quantity. |
| `unit_price` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Price per unit at transaction time. |
| `line_total` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Total price for this line. |

## 8. `membership_history`

**Description:** Stores membership lifecycle events and the relevant membership values before and after each event. These records support administrative review and reporting without replacing the member's current details.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | History event identifier. |
| `member_id` | `uuid` | NOT NULL | FK to `members.id`, ON DELETE RESTRICT; indexed with `recorded_at` | Member whose membership changed; referenced members cannot be deleted. |
| `event_type` | `text` | NOT NULL | CHECK `expired`, `renewal`, or `plan_change` | Type of lifecycle event recorded. |
| `previous_plan` | `text` | NULL | — | Plan before the event. |
| `new_plan` | `text` | NULL | — | Plan after the event. |
| `previous_price` | `numeric(12, 2)` | NULL | CHECK NULL or >= 0 | Price before the event. |
| `new_price` | `numeric(12, 2)` | NULL | CHECK NULL or >= 0 | Price after the event. |
| `previous_start_date` | `date` | NULL | — | Membership start date before the event. |
| `previous_expiry_date` | `date` | NULL | — | Membership expiry date before the event. |
| `new_start_date` | `date` | NULL | — | Membership start date after the event. |
| `new_expiry_date` | `date` | NULL | — | Membership expiry date after the event. |
| `notes` | `text` | NOT NULL; `''` | — | Additional event context, such as a receipt reference. |
| `recorded_at` | `timestamptz` | NOT NULL; `now()` | Part of `(member_id, recorded_at DESC)` index | Time the event was recorded. |
| `recorded_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Auth account that recorded the event. |

## Relationships and Delete Behavior

| Relationship | Cardinality and behavior |
| --- | --- |
| `auth.users` to `profiles` | One-to-one by shared `id`; deleting the Auth user cascades to its profile. |
| `auth.users` to `members` | Optional one-to-one; unique when `auth_user_id` is non-NULL. Deleting the Auth user clears the member's `auth_user_id`. |
| `auth.users` to `membership_applications` | One Auth user can submit multiple applications; deleting the Auth user cascades to those applications. |
| `members` to `membership_applications` | A member can have multiple linked applications; deleting the member clears each application's `member_id`. |
| `membership_applications` to `members` | `members.application_id` is an optional indexed origin link, not unique; deleting the application clears the member's `application_id`. |
| `members` to `attendance` | One-to-many; attendance records prevent deletion of a referenced member. |
| `members` to `sales` | One-to-many; deleting a member clears the optional sale `member_id`. |
| `sales` to `sale_items` | One-to-many; deleting a sale cascades to its line items. |
| `products` to `sale_items` | One-to-many; deleting a product clears `product_id`, while receipt snapshots remain. |
| `members` to `membership_history` | One-to-many; history records prevent deletion of a referenced member. |
| Auth users to `recorded_by`, `reviewed_by`, `processed_by` | Optional attribution links; deleting the Auth user clears the attribution field. |

## Indexes and Keys

| Index | Fields | Purpose |
| --- | --- | --- |
| `members_auth_user_id_uidx` | `members(auth_user_id)` WHERE `auth_user_id IS NOT NULL` | Enforces at most one linked member per Auth user. |
| `members_application_id_idx` | `members(application_id)` | Finds a member from its originating application; not unique. |
| `applications_auth_user_id_idx` | `membership_applications(auth_user_id)` | Finds applications submitted by an account. |
| `applications_status_submitted_idx` | `membership_applications(status, submitted_at DESC)` | Supports application review queues. |
| `attendance_member_time_idx` | `attendance(member_id, time_in DESC)` | Retrieves a member's visits in time order. |
| `sales_sold_at_idx` | `sales(sold_at DESC)` | Supports recent sales and date-based reports. |
| `sale_items_sale_id_idx` | `sale_items(sale_id)` | Retrieves a receipt's line items. |
| `membership_history_member_date_idx` | `membership_history(member_id, recorded_at DESC)` | Retrieves a member's history in time order. |

`profiles.email`, `profiles.username`, and `sales.receipt_number` are unique in the canonical schema. Compatibility migrations may use partial unique indexes for nullable profile fields; `members.auth_user_id` is unique only when non-NULL.

## Data Access and Operational Notes

- Row-level security is enabled for all eight application tables. Members can access their own permitted records; administrators have broader management access as defined by database policies.
- Auth and staff IDs reference `auth.users`; they do not contain authentication credentials.
- `emergency_contact` and `emergency_contact_data` coexist on applications for compatibility and are not automatically synchronized.
- `expiry_date` is canonical; `end_date` is retained for compatibility with membership operations.
- Existing installations may retain legacy columns or schema differences. Inspect the target project's PostgreSQL catalog before database changes.
