# Public database schema reference

12 public tables; 162 fields; 18 declared foreign keys. Key roles, nullability, referenced columns and deletion actions are included below. Types retain declared lengths and precision from the verified project schema. Full CHECK expressions remain in the SQL schema; the paper data dictionary explains relevant checks.

The retained sales.receipt_number column is an internal transaction reference. Its name does not establish that customer receipts are issued. RLS policies describe access rules and are documented separately from entity relationships.

## Table `profiles`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; Foreign key: `auth.users(id)`; ON DELETE CASCADE; NOT NULL |
| `username` | `varchar(30)` | Unique; Nullable |
| `full_name` | `varchar(150)` | NOT NULL |
| `role` | `varchar(20)` | NOT NULL |
| `account_status` | `text` | NOT NULL |
| `created_at` | `timestamptz` | NOT NULL |
| `updated_at` | `timestamptz` | NOT NULL |
| `email` | `varchar(254)` | Unique; Nullable |
| `is_active` | `boolean` | NOT NULL |
| `phone_number` | `text` | Nullable |
| `gender` | `text` | Nullable |

## Table `membership_applications`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `full_name` | `varchar(150)` | NOT NULL |
| `date_of_birth` | `date` | Nullable |
| `age` | `integer` | Nullable |
| `sex` | `varchar(30)` | Nullable |
| `mobile` | `varchar(11)` | Nullable |
| `height` | `numeric(6,2)` | Nullable |
| `height_unit` | `varchar(3)` | Nullable |
| `weight` | `numeric(6,2)` | Nullable |
| `emergency_name` | `text` | Nullable |
| `emergency_relationship` | `text` | Nullable |
| `emergency_contact` | `text` | Nullable |
| `plan` | `varchar(30)` | NOT NULL |
| `plan_price` | `numeric(10,2)` | NOT NULL |
| `start_date` | `date` | Nullable |
| `end_date` | `date` | Nullable |
| `health_conditions` | `text[]` | NOT NULL |
| `other_medical_conditions` | `text` | Nullable |
| `fitness_goals` | `text[]` | NOT NULL |
| `signature_data` | `text` | Nullable |
| `status` | `varchar(20)` | NOT NULL |
| `reviewed_by` | `uuid` | Foreign key: `public.profiles(id)`; ON DELETE NO ACTION; Nullable |
| `reviewed_at` | `timestamptz` | Nullable |
| `created_at` | `timestamptz` | NOT NULL |
| `auth_user_id` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE CASCADE; Nullable |
| `member_id` | `uuid` | Foreign key: `public.members(id)`; ON DELETE SET NULL; Nullable |
| `application_type` | `varchar(20)` | NOT NULL |
| `submitted_at` | `timestamptz` | NOT NULL |
| `email` | `varchar(254)` | Nullable |
| `username` | `varchar(30)` | Nullable |
| `emergency_contact_data` | `jsonb` | NOT NULL |
| `weight_kg` | `numeric(7,2)` | Nullable |
| `signature_path` | `text` | Nullable |

## Table `members`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `application_id` | `uuid` | Foreign key: `public.membership_applications(id)`; ON DELETE SET NULL; Unique; Nullable |
| `full_name` | `varchar(150)` | NOT NULL |
| `mobile` | `varchar(11)` | Nullable |
| `plan` | `varchar(30)` | NOT NULL |
| `start_date` | `date` | Nullable |
| `end_date` | `date` | Nullable |
| `status` | `varchar(20)` | NOT NULL |
| `paid` | `numeric(10,2)` | NOT NULL |
| `fitness_goals` | `text[]` | NOT NULL |
| `height` | `numeric(6,2)` | Nullable |
| `height_unit` | `varchar(3)` | Nullable |
| `weight` | `numeric(6,2)` | Nullable |
| `health_conditions` | `text[]` | NOT NULL |
| `other_medical_conditions` | `text` | Nullable |
| `signature_data` | `text` | Nullable |
| `created_at` | `timestamptz` | NOT NULL |
| `auth_user_id` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE SET NULL; Unique; Nullable |
| `email` | `varchar(254)` | Nullable |
| `username` | `varchar(30)` | Nullable |
| `date_of_birth` | `date` | Nullable |
| `age` | `smallint` | Nullable |
| `sex` | `varchar(30)` | Nullable |
| `weight_kg` | `numeric(7,2)` | Nullable |
| `emergency_contact` | `jsonb` | NOT NULL |
| `plan_price` | `numeric(12,2)` | NOT NULL |
| `expiry_date` | `date` | Nullable |
| `registration_source` | `varchar(40)` | NOT NULL |
| `signature_path` | `text` | Nullable |
| `updated_at` | `timestamptz` | NOT NULL |

## Table `products`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `name` | `varchar(120)` | NOT NULL |
| `category` | `varchar(20)` | NOT NULL |
| `price` | `numeric(10,2)` | NOT NULL |
| `stock` | `numeric(14,6)` | NOT NULL |
| `size` | `varchar(30)` | Nullable |
| `created_at` | `timestamptz` | NOT NULL |
| `updated_at` | `timestamptz` | NOT NULL |
| `is_active` | `boolean` | NOT NULL |
| `archived_at` | `timestamptz` | Nullable |
| `image_path` | `text` | Nullable |
| `price_per_unit` | `numeric(12,2)` | NOT NULL |
| `unit` | `varchar(12)` | NOT NULL |
| `stock_unit` | `text` | NOT NULL |
| `merch_type` | `text` | Nullable |
| `supplement_form` | `text` | Nullable |
| `supplement_type` | `text` | Nullable |

## Table `sales`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `member_id` | `uuid` | Foreign key: `public.members(id)`; ON DELETE SET NULL; Nullable |
| `customer_name` | `varchar(150)` | NOT NULL |
| `items` | `jsonb` | NOT NULL |
| `total` | `numeric(10,2)` | NOT NULL |
| `status` | `varchar(12)` | NOT NULL |
| `sold_at` | `timestamptz` | NOT NULL |
| `receipt_number` | `varchar(64)` | Unique; NOT NULL |
| `customer_type` | `varchar(15)` | NOT NULL |
| `processed_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE SET NULL; Nullable |

## Table `attendance`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `member_id` | `uuid` | Foreign key: `public.members(id)`; ON DELETE CASCADE; NOT NULL |
| `date` | `date` | NOT NULL |
| `time_in` | `timestamptz` | NOT NULL |
| `time_out` | `timestamptz` | Nullable |
| `created_at` | `timestamptz` | NOT NULL |
| `recorded_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE SET NULL; Nullable |
| `checked_out_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE SET NULL; Nullable |

## Table `sale_items`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `sale_id` | `uuid` | Foreign key: `public.sales(id)`; ON DELETE CASCADE; NOT NULL |
| `product_id` | `uuid` | Foreign key: `public.products(id)`; ON DELETE SET NULL; Nullable |
| `item_name` | `varchar(150)` | NOT NULL |
| `category` | `varchar(20)` | NOT NULL |
| `quantity` | `numeric(12,3)` | NOT NULL |
| `unit` | `varchar(12)` | NOT NULL |
| `unit_price` | `numeric(12,2)` | NOT NULL |
| `line_total` | `numeric(12,2)` | NOT NULL |

## Table `membership_history`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `member_id` | `uuid` | Foreign key: `public.members(id)`; ON DELETE RESTRICT; NOT NULL |
| `event_type` | `varchar(30)` | NOT NULL |
| `previous_plan` | `varchar(30)` | Nullable |
| `new_plan` | `varchar(30)` | Nullable |
| `previous_price` | `numeric(12,2)` | Nullable |
| `new_price` | `numeric(12,2)` | Nullable |
| `previous_start_date` | `date` | Nullable |
| `previous_expiry_date` | `date` | Nullable |
| `new_start_date` | `date` | Nullable |
| `new_expiry_date` | `date` | Nullable |
| `notes` | `text` | NOT NULL |
| `recorded_at` | `timestamptz` | NOT NULL |
| `recorded_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE SET NULL; Nullable |

## Table `activity_logs`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `bigint` | Primary key; Identity; NOT NULL |
| `occurred_at` | `timestamptz` | NOT NULL |
| `actor_id` | `uuid` | Nullable |
| `actor_name` | `text` | NOT NULL |
| `actor_role` | `text` | NOT NULL |
| `action` | `text` | NOT NULL |
| `entity_type` | `text` | NOT NULL |
| `entity_id` | `text` | Nullable |
| `record_label` | `text` | NOT NULL |
| `changed_fields` | `text[]` | NOT NULL |
| `details` | `text` | NOT NULL |

## Table `mobile_attendance_scan_sessions`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `token_hash` | `text` | NOT NULL |
| `created_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE CASCADE; NOT NULL |
| `created_at` | `timestamptz` | NOT NULL |
| `expires_at` | `timestamptz` | NOT NULL |
| `paired_device` | `text` | Nullable |
| `paired_at` | `timestamptz` | Nullable |
| `remember_phone` | `boolean` | NOT NULL |
| `paired_device_id` | `uuid` | Nullable |

## Table `mobile_attendance_scan_events`

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary key; NOT NULL |
| `session_id` | `uuid` | Foreign key: `public.mobile_attendance_scan_sessions(id)`; ON DELETE CASCADE; NOT NULL |
| `qr_payload` | `text` | NOT NULL |
| `created_at` | `timestamptz` | NOT NULL |

## Table `mobile_attendance_pairing_policy`

| Name | Type | Constraints |
|------|------|-------------|
| `singleton` | `boolean` | Primary key; NOT NULL |
| `max_pairs` | `integer` | NOT NULL |
| `updated_at` | `timestamptz` | NOT NULL |
| `updated_by` | `uuid` | Foreign key: `auth.users(id)`; ON DELETE NO ACTION; Nullable |
| `pairing_password_hash` | `text` | Nullable |
| `pairing_removal_pin_hash` | `text` | Nullable |
