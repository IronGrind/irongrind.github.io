# IronGrind Data Dictionary

## Purpose and Scope

This document describes the eight application tables in the PostgreSQL `public` schema used by IronGrind. It identifies each field's data type, nullability, default, keys or constraints, and purpose. The definitions follow `supabase/schema.sql` plus the schema-affecting migrations in `supabase/migrations/`.

Supabase Authentication manages `auth.users` separately from the application tables. Its `id` field is a UUID and is referenced by account and staff-attribution fields in this dictionary. The live PostgreSQL catalog is authoritative: existing installations may retain legacy columns or have differences depending on which migrations have been applied.

PostgreSQL `text` and `text[]` have no declared character limit; `jsonb` has no declared length. `numeric(p, s)` means precision `p` digits total and scale `s` digits after the decimal point. `timestamptz` stores a timestamp with time-zone awareness. `NULL` means a value may be absent. `DEFAULT` is applied when an insert omits that field.

## Table Summary

| Table | Purpose |
| --- | --- |
| `profiles` | Application profile and authorization role for a Supabase Auth account. |
| `members` | Current gym member profile, membership, and account link. |
| `membership_applications` | Submitted registration and renewal requests and their review outcomes. |
| `attendance` | Member check-in and check-out records. |
| `products` | Product catalog, prices, inventory, and archive state. |
| `sales` | Transaction header, receipt, customer, payment total, and staff attribution. |
| `sale_items` | Product or membership line items belonging to a sale. |
| `membership_history` | Historical membership lifecycle events and before/after details. |

## 1. `profiles`

**Description:** One row per application user account. `id` is also the Supabase Auth user ID.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL | PK; FK to `auth.users.id`, ON DELETE CASCADE | Account identifier shared with Supabase Auth. |
| `email` | `text` | NOT NULL | UNIQUE | Account email, synchronized from Supabase Auth. |
| `username` | `text` | NULL | UNIQUE | Application username; usernames are checked case-insensitively during availability checks. |
| `full_name` | `text` | NOT NULL; `''` | — | Display name associated with the account. |
| `role` | `text` | NOT NULL; `'member'` | CHECK: `admin` or `member` | Controls application administrator or member access. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Profile creation time. |

## 2. `members`

**Description:** One row per gym member. This table holds current profile and membership values; prior changes are kept in `membership_history`.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Internal member identifier. |
| `auth_user_id` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL; unique when non-NULL | Portal account linked to the member. A partial unique index allows at most one member per Auth account. |
| `application_id` | `uuid` | NULL | FK to `membership_applications.id`, ON DELETE SET NULL; indexed, not unique | Registration application associated with the member record. It can be empty for members created by an administrator. |
| `full_name` | `text` | NOT NULL | — | Member's legal or preferred full name. |
| `email` | `text` | NULL | — | Member contact email; synchronized from Auth when linked. |
| `username` | `text` | NULL | — | Member's application username, when available. |
| `mobile` | `text` | NULL | — | Member contact number. The profile update function validates Philippine mobile numbers as `09` followed by nine digits. |
| `date_of_birth` | `date` | NULL | — | Member's birth date. |
| `age` | `smallint` | NULL | CHECK: NULL or >= 0 | Age value captured or calculated by profile updates. |
| `sex` | `text` | NULL | — | Member-provided sex value. |
| `height` | `numeric(7, 2)` | NULL | — | Height measurement; unit is stored separately. |
| `height_unit` | `text` | NULL | CHECK: NULL, `cm`, `in`, or `ft` | Unit for `height`. |
| `weight_kg` | `numeric(7, 2)` | NULL | — | Weight in kilograms. |
| `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Structured emergency-contact details, typically name, relationship, and contact number. |
| `plan` | `text` | NULL | — | Current membership plan name. |
| `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK: >= 0 | Current membership price. |
| `start_date` | `date` | NULL | — | Start date of the current membership period. |
| `expiry_date` | `date` | NULL | — | Canonical membership expiry date. |
| `end_date` | `date` | NULL | — | Compatibility date retained by membership-operation migrations; operations may fall back to this when `expiry_date` is empty. |
| `status` | `text` | NOT NULL; `'active'` | CHECK: `active`, `expired`, or `inactive` | Current member/membership status. |
| `registration_source` | `text` | NOT NULL; `'Online application'` | — | Origin of the member record. |
| `paid` | `boolean` | NOT NULL; `false` | — | Whether the membership payment has been recorded as paid. |
| `fitness_goals` | `text[]` | NOT NULL; `{}` | — | List of member fitness goals. |
| `health_conditions` | `text[]` | NOT NULL; `{}` | — | List of declared health conditions. |
| `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information not represented in the list. |
| `signature_path` | `text` | NULL | — | Storage path or reference for the member's signature asset. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Member record creation time. |
| `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent member record update time. |

## 3. `membership_applications`

**Description:** Stores a submitted membership registration or renewal request. Review details are retained independently from the member's current membership record.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Application identifier. |
| `auth_user_id` | `uuid` | NOT NULL | FK to `auth.users.id`, ON DELETE CASCADE; indexed | Auth account that submitted the request. |
| `member_id` | `uuid` | NULL | FK to `members.id`, ON DELETE SET NULL | Existing member associated with a renewal; can be populated when a request is processed. |
| `application_type` | `text` | NOT NULL | CHECK: `registration` or `renewal` | Distinguishes a new-member request from a renewal. |
| `full_name` | `text` | NOT NULL | — | Applicant/member name submitted with the request. |
| `email` | `text` | NOT NULL | — | Email captured with the application. |
| `username` | `text` | NULL | — | Username captured with the application. |
| `mobile` | `text` | NULL | — | Contact number submitted by the applicant. |
| `date_of_birth` | `date` | NULL | — | Applicant's birth date. |
| `age` | `smallint` | NULL | CHECK: NULL or >= 0 | Applicant's age. |
| `sex` | `text` | NULL | — | Applicant-provided sex value. |
| `height` | `numeric(7, 2)` | NULL | — | Height measurement; unit is stored separately. |
| `height_unit` | `text` | NULL | CHECK: NULL, `cm`, `in`, or `ft` | Unit for `height`. |
| `weight_kg` | `numeric(7, 2)` | NULL | — | Weight in kilograms. |
| `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Emergency contact in the main application payload. |
| `emergency_contact_data` | `jsonb` | NOT NULL; `{}` | — | Compatibility/structured emergency-contact payload retained by registration migrations. |
| `plan` | `text` | NOT NULL | — | Membership plan requested. |
| `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK: >= 0 | Price submitted for the requested plan. |
| `start_date` | `date` | NULL | — | Requested membership start date, when supplied. |
| `end_date` | `date` | NULL | — | Requested membership end date, when supplied. |
| `fitness_goals` | `text[]` | NOT NULL; `{}` | — | Applicant's fitness goals. |
| `health_conditions` | `text[]` | NOT NULL; `{}` | — | Applicant's declared health conditions. |
| `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information. |
| `signature_path` | `text` | NULL | — | Storage path or reference for the submitted signature. |
| `status` | `text` | NOT NULL; `'pending'` | CHECK: `pending`, `approved`, or `rejected` | Current application review outcome. |
| `submitted_at` | `timestamptz` | NOT NULL; `now()` | Indexed with `status` | Submission timestamp. |
| `reviewed_at` | `timestamptz` | NULL | — | Time the application was reviewed. |
| `reviewed_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Auth account of the reviewer. |

## 4. `attendance`

**Description:** One row per member visit, with check-in and optional check-out times.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Attendance record identifier. |
| `member_id` | `uuid` | NOT NULL | FK to `members.id`, ON DELETE RESTRICT; indexed with `time_in` | Member who attended; member deletion is blocked while attendance rows refer to them. |
| `time_in` | `timestamptz` | NOT NULL; `now()` | Part of `(member_id, time_in DESC)` index | Member check-in time. |
| `time_out` | `timestamptz` | NULL | CHECK: NULL or >= `time_in` | Member check-out time; NULL means the visit is still open or no check-out was recorded. |
| `recorded_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Staff account that recorded the attendance event. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Row creation time. |

## 5. `products`

**Description:** Stores products available for sale, including prices and inventory state.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Product identifier. |
| `name` | `text` | NOT NULL | — | Product display name. |
| `category` | `text` | NOT NULL | CHECK: `supplement` or `merchandise` | Determines product type and applicable unit/inventory behavior. |
| `price_per_unit` | `numeric(12, 2)` | NOT NULL | CHECK: >= 0 | Price for one stored unit (gram or item). |
| `unit` | `text` | NOT NULL | CHECK: `gram` or `item` | Unit in which the product is sold. Supplements use `gram`; merchandise uses `item`. |
| `size` | `text` | NULL | — | Optional product size or package description. |
| `stock` | `integer` | NULL | CHECK: NULL or >= 0 | Merchandise quantity on hand. Supplements use NULL stock; sales operations expect merchandise stock to be set. |
| `image_path` | `text` | NULL | — | Storage path or reference for the product image. |
| `is_active` | `boolean` | NOT NULL; `true` | — | Whether the product is currently offered for sale. |
| `archived_at` | `timestamptz` | NULL | Added by `operational_data.sql` migration | Time the product was archived, if applicable. |
| `created_at` | `timestamptz` | NOT NULL; `now()` | — | Product creation time. |
| `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent product update time. |

The table also has a category/unit consistency check: supplements must use `gram` and have NULL stock; merchandise must use `item`. The category/unit/stock rule is enforced by the canonical schema and inventory operations.

## 6. `sales`

**Description:** One row per receipt/transaction. Individual products and membership charges are stored in `sale_items`.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale identifier. |
| `receipt_number` | `text` | NOT NULL | UNIQUE | Human-readable receipt identifier. |
| `customer_type` | `text` | NOT NULL | CHECK: `member` or `walk_in` | Identifies the customer category. |
| `customer_name` | `text` | NOT NULL | — | Customer name saved on the receipt. |
| `member_id` | `uuid` | NULL | FK to `members.id`, ON DELETE SET NULL | Member associated with the transaction; NULL for walk-in sales or if the member is removed. |
| `total` | `numeric(12, 2)` | NOT NULL | CHECK: >= 0 | Total transaction amount. |
| `status` | `text` | NOT NULL; `'paid'` | Canonical values: `paid`, `voided` | Sale state. The base schema restricts values to these two states; a legacy compatibility migration normalizes status to lowercase. |
| `sold_at` | `timestamptz` | NOT NULL; `now()` | Indexed descending | Time of sale. |
| `processed_by` | `uuid` | NULL | FK to `auth.users.id`, ON DELETE SET NULL | Auth account of the staff member who processed the sale. |

## 7. `sale_items`

**Description:** One row per item/charge on a sale. The item name and price fields preserve the transaction description even if a product changes later.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale-line identifier. |
| `sale_id` | `uuid` | NOT NULL | FK to `sales.id`, ON DELETE CASCADE; indexed | Parent receipt. Deleting a sale deletes its line items. |
| `product_id` | `uuid` | NULL | FK to `products.id`, ON DELETE SET NULL | Catalog product represented by this line, if applicable. |
| `item_name` | `text` | NOT NULL | — | Item/plan name snapshot printed on the receipt. |
| `category` | `text` | NOT NULL | CHECK: `supplement`, `merchandise`, or `membership` | Type of item charged. |
| `quantity` | `numeric(12, 3)` | NOT NULL | CHECK: > 0 | Sold quantity, supporting fractional gram amounts. |
| `unit` | `text` | NOT NULL | CHECK: `gram`, `item`, or `membership` | Unit used for the line quantity. |
| `unit_price` | `numeric(12, 2)` | NOT NULL | CHECK: >= 0 | Price per unit at transaction time. |
| `line_total` | `numeric(12, 2)` | NOT NULL | CHECK: >= 0 | Total price for this line. |

## 8. `membership_history`

**Description:** Records membership events and prior/new values for administrative review and reporting.

| Field | Type | Null / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- |
| `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | History event identifier. |
| `member_id` | `uuid` | NOT NULL | FK to `members.id`, ON DELETE RESTRICT; indexed with `recorded_at` | Member whose membership changed; member deletion is blocked while history exists. |
| `event_type` | `text` | NOT NULL | CHECK: `expired`, `renewal`, or `plan_change` | Type of lifecycle event recorded. |
| `previous_plan` | `text` | NULL | — | Plan before the event. |
| `new_plan` | `text` | NULL | — | Plan after the event. |
| `previous_price` | `numeric(12, 2)` | NULL | CHECK: NULL or >= 0 | Price before the event. |
| `new_price` | `numeric(12, 2)` | NULL | CHECK: NULL or >= 0 | Price after the event. |
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

Primary and unique keys are identified in the table definitions above. In addition, the schema and migrations define these query-supporting indexes:

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

`profiles.email`, `profiles.username`, and `sales.receipt_number` are unique in the canonical schema. Some compatibility migrations implement nullable profile uniqueness with partial unique indexes. `members.auth_user_id` is deliberately a partial unique index because multiple unlinked member records may have NULL account IDs.

## Data Access and Operational Notes

- Row-level security is enabled for all eight application tables. Members can access their own permitted records; administrators have broader management access. Exact behavior is determined by the policies in `supabase/schema.sql` and subsequent migrations.
- Auth and staff IDs are UUID references to `auth.users`, not copies of authentication credentials.
- `emergency_contact` and `emergency_contact_data` coexist on applications for compatibility. New or maintained code should use the field expected by the current application flow and avoid assuming the two values are automatically synchronized.
- `expiry_date` is the canonical member expiry field; `end_date` remains for compatibility with existing membership operations. Code that reads older data may fall back between these fields.
- This dictionary describes the intended/current schema contract, not every possible legacy column on an upgraded installation. Before database changes, inspect `information_schema` and `pg_catalog` on the target Supabase project and apply migrations in the documented order.
# IronGrind Data Dictionary

## Purpose and Scope

This document describes the eight application tables in the PostgreSQL `public` schema used by IronGrind. It identifies each field's data type, nullability, default, keys or constraints, and purpose. The definitions follow `supabase/schema.sql` plus the schema-affecting migrations in `supabase/migrations/`.

Supabase Authentication manages `auth.users` separately from the application tables. Its `id` field is a UUID and is referenced by account and staff-attribution fields in this dictionary. The live PostgreSQL catalog is authoritative: existing installations may retain legacy columns or have differences depending on which migrations have been applied.

PostgreSQL `text` and `text[]` have no declared character limit; `jsonb` has no declared length. `numeric(p, s)` means precision `p` digits total and scale `s` digits after the decimal point. `timestamptz` stores a timestamp with time-zone awareness. `NULL` means a value may be absent. `DEFAULT` is applied when an insert omits that field.

## Table Summary

| Table | Purpose |
| --- | --- |
| `profiles` | Application profile and authorization role for a Supabase Auth account. |
| `members` | Current gym member profile, membership, and account link. |
| `membership_applications` | Submitted registration and renewal requests and their review outcomes. |
| `attendance` | Member check-in and check-out records. |
| `products` | Product catalog, prices, inventory, and archive state. |
| `sales` | Transaction header, receipt, customer, payment total, and staff attribution. |
| `sale_items` | Product or membership line items belonging to a sale. |
| `membership_history` | Historical membership lifecycle events and before/after details. |

## Master Field Dictionary

Each row documents one database field. Type precision and scale are included in the type; PostgreSQL `text`, `text[]`, and `jsonb` do not have a declared maximum length.

| Table | Field | Data type / length | Nullability / default | Key / constraint | Purpose |
| --- | --- | --- | --- | --- | --- |
| `profiles` | `id` | `uuid` | NOT NULL | PK; FK `auth.users.id`, ON DELETE CASCADE | Account identifier shared with Supabase Auth. |
| `profiles` | `email` | `text` | NOT NULL | UNIQUE | Account email, synchronized from Auth. |
| `profiles` | `username` | `text` | NULL | UNIQUE | Application username; availability check is case-insensitive. |
| `profiles` | `full_name` | `text` | NOT NULL; `''` | — | Account display name. |
| `profiles` | `role` | `text` | NOT NULL; `'member'` | CHECK `admin` or `member` | Application authorization role. |
| `profiles` | `created_at` | `timestamptz` | NOT NULL; `now()` | — | Profile creation time. |
| `members` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Internal member identifier. |
| `members` | `auth_user_id` | `uuid` | NULL | FK `auth.users.id`, ON DELETE SET NULL; unique when non-NULL | Portal account for the member; partial unique index limits one member per Auth user. |
| `members` | `application_id` | `uuid` | NULL | FK `membership_applications.id`, ON DELETE SET NULL; indexed, not unique | Originating registration application; optional for admin-created members. |
| `members` | `full_name` | `text` | NOT NULL | — | Member's full name. |
| `members` | `email` | `text` | NULL | — | Member contact email, synchronized from Auth when linked. |
| `members` | `username` | `text` | NULL | — | Member's application username, if available. |
| `members` | `mobile` | `text` | NULL | — | Contact number; profile update validates Philippine mobile format. |
| `members` | `date_of_birth` | `date` | NULL | — | Member's birth date. |
| `members` | `age` | `smallint` | NULL | CHECK NULL or >= 0 | Member age, which may be calculated during profile updates. |
| `members` | `sex` | `text` | NULL | — | Member-provided sex value. |
| `members` | `height` | `numeric(7, 2)` | NULL | — | Height measurement. |
| `members` | `height_unit` | `text` | NULL | CHECK NULL, `cm`, `in`, or `ft` | Unit for height. |
| `members` | `weight_kg` | `numeric(7, 2)` | NULL | — | Weight in kilograms. |
| `members` | `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Structured emergency-contact details. |
| `members` | `plan` | `text` | NULL | — | Current membership plan. |
| `members` | `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK >= 0 | Current membership price. |
| `members` | `start_date` | `date` | NULL | — | Current membership start date. |
| `members` | `expiry_date` | `date` | NULL | — | Canonical current membership expiry date. |
| `members` | `end_date` | `date` | NULL | — | Compatibility expiry field; membership operations may fall back to it. |
| `members` | `status` | `text` | NOT NULL; `'active'` | CHECK `active`, `expired`, or `inactive` | Current member/membership status. |
| `members` | `registration_source` | `text` | NOT NULL; `'Online application'` | — | Origin of the member record. |
| `members` | `paid` | `boolean` | NOT NULL; `false` | — | Whether payment is recorded as paid. |
| `members` | `fitness_goals` | `text[]` | NOT NULL; `{}` | — | Member's fitness goals. |
| `members` | `health_conditions` | `text[]` | NOT NULL; `{}` | — | Member's declared health conditions. |
| `members` | `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information. |
| `members` | `signature_path` | `text` | NULL | — | Storage path/reference for the signature asset. |
| `members` | `created_at` | `timestamptz` | NOT NULL; `now()` | — | Member record creation time. |
| `members` | `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent member record update time. |
| `membership_applications` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Application identifier. |
| `membership_applications` | `auth_user_id` | `uuid` | NOT NULL | FK `auth.users.id`, ON DELETE CASCADE; indexed | Auth account that submitted the application. |
| `membership_applications` | `member_id` | `uuid` | NULL | FK `members.id`, ON DELETE SET NULL | Existing member associated with a renewal or processed application. |
| `membership_applications` | `application_type` | `text` | NOT NULL | CHECK `registration` or `renewal` | Type of membership request. |
| `membership_applications` | `full_name` | `text` | NOT NULL | — | Applicant/member name submitted. |
| `membership_applications` | `email` | `text` | NOT NULL | — | Email captured with the application. |
| `membership_applications` | `username` | `text` | NULL | — | Username captured with the application. |
| `membership_applications` | `mobile` | `text` | NULL | — | Applicant contact number. |
| `membership_applications` | `date_of_birth` | `date` | NULL | — | Applicant birth date. |
| `membership_applications` | `age` | `smallint` | NULL | CHECK NULL or >= 0 | Applicant age. |
| `membership_applications` | `sex` | `text` | NULL | — | Applicant-provided sex value. |
| `membership_applications` | `height` | `numeric(7, 2)` | NULL | — | Applicant height measurement. |
| `membership_applications` | `height_unit` | `text` | NULL | CHECK NULL, `cm`, `in`, or `ft` | Unit for height. |
| `membership_applications` | `weight_kg` | `numeric(7, 2)` | NULL | — | Applicant weight in kilograms. |
| `membership_applications` | `emergency_contact` | `jsonb` | NOT NULL; `{}` | — | Emergency contact in the application payload. |
| `membership_applications` | `emergency_contact_data` | `jsonb` | NOT NULL; `{}` | — | Compatibility structured emergency-contact payload. |
| `membership_applications` | `plan` | `text` | NOT NULL | — | Requested membership plan. |
| `membership_applications` | `plan_price` | `numeric(12, 2)` | NOT NULL; `0` | CHECK >= 0 | Price submitted for the plan. |
| `membership_applications` | `start_date` | `date` | NULL | — | Requested membership start date. |
| `membership_applications` | `end_date` | `date` | NULL | — | Requested membership end date. |
| `membership_applications` | `fitness_goals` | `text[]` | NOT NULL; `{}` | — | Applicant fitness goals. |
| `membership_applications` | `health_conditions` | `text[]` | NOT NULL; `{}` | — | Applicant declared health conditions. |
| `membership_applications` | `other_medical_conditions` | `text` | NOT NULL; `''` | — | Additional medical information. |
| `membership_applications` | `signature_path` | `text` | NULL | — | Storage path/reference for the submitted signature. |
| `membership_applications` | `status` | `text` | NOT NULL; `'pending'` | CHECK `pending`, `approved`, or `rejected` | Application review outcome. |
| `membership_applications` | `submitted_at` | `timestamptz` | NOT NULL; `now()` | Indexed with `status` | Application submission time. |
| `membership_applications` | `reviewed_at` | `timestamptz` | NULL | — | Application review time. |
| `membership_applications` | `reviewed_by` | `uuid` | NULL | FK `auth.users.id`, ON DELETE SET NULL | Auth account of the reviewer. |
| `attendance` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Attendance record identifier. |
| `attendance` | `member_id` | `uuid` | NOT NULL | FK `members.id`, ON DELETE RESTRICT; indexed with `time_in` | Member who attended; referenced members cannot be deleted. |
| `attendance` | `time_in` | `timestamptz` | NOT NULL; `now()` | Part of `(member_id, time_in DESC)` index | Member check-in time. |
| `attendance` | `time_out` | `timestamptz` | NULL | CHECK NULL or >= `time_in` | Member check-out time; NULL can indicate an open visit. |
| `attendance` | `recorded_by` | `uuid` | NULL | FK `auth.users.id`, ON DELETE SET NULL | Staff account that recorded attendance. |
| `attendance` | `created_at` | `timestamptz` | NOT NULL; `now()` | — | Attendance row creation time. |
| `products` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Product identifier. |
| `products` | `name` | `text` | NOT NULL | — | Product display name. |
| `products` | `category` | `text` | NOT NULL | CHECK `supplement` or `merchandise` | Product type and inventory behavior. |
| `products` | `price_per_unit` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Price per gram or item. |
| `products` | `unit` | `text` | NOT NULL | CHECK `gram` or `item`; category consistency check | Unit in which the product is sold. |
| `products` | `size` | `text` | NULL | — | Optional size/package description. |
| `products` | `stock` | `integer` | NULL | CHECK NULL or >= 0; supplements require NULL | Merchandise quantity in stock; sale operations expect a value for merchandise. |
| `products` | `image_path` | `text` | NULL | — | Storage path/reference for product image. |
| `products` | `is_active` | `boolean` | NOT NULL; `true` | — | Whether the product is currently offered. |
| `products` | `archived_at` | `timestamptz` | NULL | Added by `operational_data.sql` | Time product was archived. |
| `products` | `created_at` | `timestamptz` | NOT NULL; `now()` | — | Product creation time. |
| `products` | `updated_at` | `timestamptz` | NOT NULL; `now()` | — | Most recent product update time. |
| `sales` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale identifier. |
| `sales` | `receipt_number` | `text` | NOT NULL | UNIQUE | Human-readable receipt identifier. |
| `sales` | `customer_type` | `text` | NOT NULL | CHECK `member` or `walk_in` | Customer category. |
| `sales` | `customer_name` | `text` | NOT NULL | — | Name saved on the receipt. |
| `sales` | `member_id` | `uuid` | NULL | FK `members.id`, ON DELETE SET NULL | Associated member; NULL for walk-in sales. |
| `sales` | `total` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Total transaction amount. |
| `sales` | `status` | `text` | NOT NULL; `'paid'` | Canonical values `paid` or `voided` | Sale state; legacy migration also normalizes status to lowercase. |
| `sales` | `sold_at` | `timestamptz` | NOT NULL; `now()` | Indexed descending | Time of sale. |
| `sales` | `processed_by` | `uuid` | NULL | FK `auth.users.id`, ON DELETE SET NULL | Staff account that processed the sale. |
| `sale_items` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | Sale-line identifier. |
| `sale_items` | `sale_id` | `uuid` | NOT NULL | FK `sales.id`, ON DELETE CASCADE; indexed | Parent receipt; deleting a sale deletes its lines. |
| `sale_items` | `product_id` | `uuid` | NULL | FK `products.id`, ON DELETE SET NULL | Catalog product represented by the line, if applicable. |
| `sale_items` | `item_name` | `text` | NOT NULL | — | Item or plan name snapshot for the receipt. |
| `sale_items` | `category` | `text` | NOT NULL | CHECK `supplement`, `merchandise`, or `membership` | Type of line item. |
| `sale_items` | `quantity` | `numeric(12, 3)` | NOT NULL | CHECK > 0 | Quantity sold, including fractional gram amounts. |
| `sale_items` | `unit` | `text` | NOT NULL | CHECK `gram`, `item`, or `membership` | Unit used for the line quantity. |
| `sale_items` | `unit_price` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Price per unit at sale time. |
| `sale_items` | `line_total` | `numeric(12, 2)` | NOT NULL | CHECK >= 0 | Total price for the line. |
| `membership_history` | `id` | `uuid` | NOT NULL; `gen_random_uuid()` | PK | History event identifier. |
| `membership_history` | `member_id` | `uuid` | NOT NULL | FK `members.id`, ON DELETE RESTRICT; indexed with `recorded_at` | Member whose membership changed; referenced members cannot be deleted. |
| `membership_history` | `event_type` | `text` | NOT NULL | CHECK `expired`, `renewal`, or `plan_change` | Membership lifecycle event type. |
| `membership_history` | `previous_plan` | `text` | NULL | — | Plan before the event. |
| `membership_history` | `new_plan` | `text` | NULL | — | Plan after the event. |
| `membership_history` | `previous_price` | `numeric(12, 2)` | NULL | CHECK NULL or >= 0 | Price before the event. |
| `membership_history` | `new_price` | `numeric(12, 2)` | NULL | CHECK NULL or >= 0 | Price after the event. |
| `membership_history` | `previous_start_date` | `date` | NULL | — | Membership start date before the event. |
| `membership_history` | `previous_expiry_date` | `date` | NULL | — | Membership expiry date before the event. |
| `membership_history` | `new_start_date` | `date` | NULL | — | Membership start date after the event. |
| `membership_history` | `new_expiry_date` | `date` | NULL | — | Membership expiry date after the event. |
| `membership_history` | `notes` | `text` | NOT NULL; `''` | — | Additional event context, such as receipt reference. |
| `membership_history` | `recorded_at` | `timestamptz` | NOT NULL; `now()` | Part of `(member_id, recorded_at DESC)` index | Time the event was recorded. |
| `membership_history` | `recorded_by` | `uuid` | NULL | FK `auth.users.id`, ON DELETE SET NULL | Auth account that recorded the event. |

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

Primary and unique keys are identified in the master field dictionary. The schema and migrations also define these query-supporting indexes:

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

| Unique field/index | Rule |
| --- | --- |
| `profiles.email` | Unique account email in the canonical schema. |
| `profiles.username` | Unique username; compatibility migrations may use a partial unique index when the field is nullable. Availability checks compare case-insensitively. |
| `sales.receipt_number` | Unique receipt number. |
| `members.auth_user_id` | Partial unique index; non-NULL Auth IDs can link to at most one member, while multiple unlinked members may have NULL. |

## Data Access and Operational Notes

| Topic | Notes |
| --- | --- |
| Row-level security | Enabled for all eight application tables. Members can access their own permitted records; administrators have broader management access. Exact behavior is defined by the policies in `supabase/schema.sql` and subsequent migrations. |
| Auth identifiers | Account and staff IDs reference `auth.users`; they do not contain authentication credentials. |
| Application emergency contacts | `emergency_contact` and `emergency_contact_data` coexist for compatibility and are not automatically synchronized. |
| Membership expiry | `expiry_date` is canonical; `end_date` is retained for compatibility. Operations may fall back between them. |
| Schema authority | This dictionary describes the intended/current contract, not every legacy column on upgraded installations. The target project's `information_schema` and `pg_catalog` are authoritative before database changes. |
| Migration source | Apply and review schema changes from `supabase/schema.sql` and `supabase/migrations/` in the documented order. |
