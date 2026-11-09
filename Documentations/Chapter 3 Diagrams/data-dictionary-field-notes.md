# Data dictionary field-purpose notes

Field descriptions retained from the detailed Chapter 3 dictionary before conversion to the Name / Type / Constraints table format. The Word document contains the current technical constraints; these notes retain field purposes for reference.

## public.profiles

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| username | Stores the optional sign-in username for staff and administrator accounts. Members sign in using their email address. |
| full_name | Stores the complete name submitted for the account, application, or member. |
| role | Identifies the account role as admin, staff, or member. |
| account_status | Stores the account-state value as pending, active, or disabled according to its database check constraint. |
| created_at | Records when the database record was created. |
| updated_at | Records the timestamp used to identify the latest update to the record. |
| email | Stores the email address associated with the account or submitted record. |
| is_active | Indicates whether the account or catalog record is enabled for its applicable workflow. |
| phone_number | Stores contact information for the account. |
| gender | Stores the gender value supplied for an account through the supported form. |

## public.members

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| application_id | Links a member record to the associated registration application when one exists. |
| full_name | Stores the complete name submitted for the account, application, or member. |
| mobile | Stores a Philippine mobile contact number for the member or applicant. |
| plan | Stores the name of the membership plan associated with the record. |
| start_date | Records the starting calendar date of the requested or current membership period. |
| end_date | Stores the membership end date retained by current and compatibility operations. |
| status | Stores the lifecycle or transaction state of the record. |
| paid | Stores the recorded membership payment amount as a number. |
| fitness_goals | Stores the selected fitness-goal entries as an array of text values. |
| height | Stores the submitted height measurement as a decimal number. |
| height_unit | Identifies the unit associated with the height measurement. |
| weight | Retains a compatibility weight measurement used by earlier or supporting data paths. |
| health_conditions | Stores declared health-condition entries as an array of text values. |
| other_medical_conditions | Stores additional health-condition details supplied by the person. |
| signature_data | Retains signature data submitted through the registration workflow. |
| created_at | Records when the database record was created. |
| auth_user_id | Links the record to a managed Supabase Auth account. |
| email | Stores the email address associated with the account or submitted record. |
| username | Retains a legacy username value for compatibility with older member records and lookups. New member records do not receive a username; members sign in using email. |
| date_of_birth | Records the person's birth date for registration and personal-information records. |
| age | Stores the recorded age value associated with the person. |
| sex | Stores the sex value submitted in the member or application form. |
| weight_kg | Stores the person's weight in kilograms as a decimal measurement. |
| emergency_contact | Stores emergency-contact information. |
| plan_price | Stores the monetary amount associated with the selected membership plan. |
| expiry_date | Stores the explicit expiration date of the member's recorded membership period. |
| registration_source | Identifies the workflow through which the member record was created, such as online application or an authorized counter registration. |
| signature_path | Stores a signature reference or payload used by the applicable workflow. |
| updated_at | Records the timestamp used to identify the latest update to the record. |

## public.membership_applications

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| full_name | Stores the complete name submitted for the account, application, or member. |
| date_of_birth | Records the person's birth date for registration and personal-information records. |
| age | Stores the recorded age value associated with the person. |
| sex | Stores the sex value submitted in the member or application form. |
| mobile | Stores a Philippine mobile contact number for the member or applicant. |
| height | Stores the submitted height measurement as a decimal number. |
| height_unit | Identifies the unit associated with the height measurement. |
| weight | Retains a compatibility weight measurement used by earlier or supporting data paths. |
| emergency_name | Retains the emergency contact person's name submitted with an application. |
| emergency_relationship | Retains the applicant's relationship to the emergency contact person. |
| emergency_contact | Stores emergency-contact information. |
| plan | Stores the name of the membership plan associated with the record. |
| plan_price | Stores the monetary amount associated with the selected membership plan. |
| start_date | Records the starting calendar date of the requested or current membership period. |
| end_date | Stores the membership end date retained by current and compatibility operations. |
| health_conditions | Stores declared health-condition entries as an array of text values. |
| other_medical_conditions | Stores additional health-condition details supplied by the person. |
| fitness_goals | Stores the selected fitness-goal entries as an array of text values. |
| signature_data | Retains signature data submitted through the registration workflow. |
| status | Stores the lifecycle or transaction state of the record. |
| reviewed_by | Identifies the profile of the staff member or administrator who reviewed the application. |
| reviewed_at | Records when the staff member or administrator reviewed the request. |
| created_at | Records when the database record was created. |
| auth_user_id | Links the record to a managed Supabase Auth account. |
| member_id | Identifies the member related to this operational record. |
| application_type | Distinguishes an initial registration application from a membership renewal request. |
| submitted_at | Records the submission timestamp associated with an application. |
| email | Stores the email address associated with the account or submitted record. |
| username | Retains a legacy username value on older application records. Current member registration uses email and does not collect a username. |
| emergency_contact_data | Stores the structured emergency-contact payload associated with an application. |
| weight_kg | Stores the person's weight in kilograms as a decimal measurement. |
| signature_path | Stores a signature reference or payload used by the applicable workflow. |

## public.attendance

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| member_id | Identifies the member related to this operational record. |
| date | Stores the date associated with the attendance row. |
| time_in | Records when the visit began. |
| time_out | Records when the visit ended. |
| created_at | Records when the database record was created. |
| recorded_by | Identifies the Auth account responsible for recording the attendance or history event. |
| checked_out_by | Identifies the Auth account that recorded check-out. |

## public.products

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| name | Stores the product's catalog name used in inventory and product selection. |
| category | Classifies the product or sale line for the appropriate operational behavior. |
| price | Retains the product price field declared in the physical schema. |
| stock | Stores the available product quantity using the configured inventory unit. |
| size | Stores an optional size or package description used to distinguish applicable merchandise or products. |
| created_at | Records when the database record was created. |
| updated_at | Records the timestamp used to identify the latest update to the record. |
| is_active | Indicates whether the account or catalog record is enabled for its applicable workflow. |
| archived_at | Records when a product was archived, when applicable. |
| image_path | Stores the catalog image reference associated with the product. |
| price_per_unit | Stores the product price for the configured pricing unit. |
| unit | Identifies the unit associated with a product price or sale-line quantity. |
| stock_unit | Identifies the unit in which inventory quantities are recorded. |
| merch_type | Identifies the merchandise classification, such as apparel, accessories, drinkware, gym_gear, or other. |
| supplement_form | Identifies the supplement form as powder, drinkable, capsule, tablet, or other where applicable. |
| supplement_type | Classifies a supplement as protein, creatine, pre_workout, vitamins, amino_acids, or other. |

## public.sales

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| member_id | Identifies the member related to this operational record. |
| customer_name | Preserves the customer name supplied for the transaction. |
| items | Retains a JSON transaction-item payload in the sales header. |
| total | Stores the complete transaction amount in the sale header. |
| status | Stores the lifecycle or transaction state of the record. |
| sold_at | Records the transaction timestamp. |
| receipt_number | Stores the existing internal transaction reference under its retained database column name. |
| customer_type | Stores the customer classification recorded for the sale. |
| processed_by | Identifies the Auth account of the authorized operator who recorded the transaction. |

## public.sale_items

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| sale_id | Links each sale line to its transaction header. |
| product_id | Links a sale line to its catalog product when applicable. |
| item_name | Preserves the product or membership label as it was recorded for the transaction line. |
| category | Classifies the product or sale line for the appropriate operational behavior. |
| quantity | Stores the quantity charged for a sale line, including fractional amounts where supported. |
| unit | Identifies the unit associated with a product price or sale-line quantity. |
| unit_price | Stores the price charged per recorded sale unit. |
| line_total | Stores the amount charged for an individual sale line. |

## public.membership_history

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| member_id | Identifies the member related to this operational record. |
| event_type | Identifies the membership-history event as expired, renewal, or plan_change. |
| previous_plan | Records the plan before the membership-history event. |
| new_plan | Records the plan associated with the membership after the recorded event. |
| previous_price | Stores the membership price before the recorded event. |
| new_price | Stores the membership price after the recorded event. |
| previous_start_date | Preserves the membership start date before the history event. |
| previous_expiry_date | Preserves the membership expiry date before the history event. |
| new_start_date | Records the start date after the membership-history event. |
| new_expiry_date | Records the expiry date after the membership-history event. |
| notes | Stores supporting context about the membership-history event. |
| recorded_at | Records when the membership-history event was saved. |
| recorded_by | Identifies the Auth account responsible for recording the attendance or history event. |

## public.activity_logs

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| occurred_at | Records when the activity entry was captured. |
| actor_id | Retains the identifier of the account responsible for the logged operation. |
| actor_name | Preserves the actor name captured with the activity entry. |
| actor_role | Preserves the role captured when the activity was recorded. |
| action | Identifies the recorded action, such as creation, update, approval, check-in, or a phone-pairing event. |
| entity_type | Identifies the system area or table associated with the logged action. |
| entity_id | Stores the identifier of the affected record when one is available. |
| record_label | Stores a readable label for the affected record. |
| changed_fields | Stores the field names associated with a recorded change as a text array. |
| details | Stores a descriptive account of the logged action. |

## public.mobile_attendance_pairing_policy

| Field | Purpose |
|---|---|
| singleton | Identifies the single configuration row for the phone-pairing policy. |
| max_pairs | Limits paired phones plus unexpired pending QR reservations. |
| updated_at | Records the timestamp used to identify the latest update to the record. |
| updated_by | Identifies the Auth account responsible for the recorded policy update. |
| pairing_password_hash | Stores the hashed pairing password used by the authorized phone-pairing workflow. |
| pairing_removal_pin_hash | Stores the hashed PIN used to authorize pairing removal. |

## public.mobile_attendance_scan_sessions

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| token_hash | Stores the hashed pairing token associated with the phone session. |
| created_by | Identifies the Auth account of the administrator who created the phone-pairing session. |
| created_at | Records when the database record was created. |
| expires_at | Records when the pairing session expires. |
| paired_device | Stores the descriptive label of the paired phone. |
| paired_at | Records when the phone was paired. |
| remember_phone | Retains the original remembered-phone preference. Current successful pairings last thirty days. |
| paired_device_id | Identifies the browser installation assigned to the pairing. Nullable for legacy pairings. |

## public.mobile_attendance_scan_events

| Field | Purpose |
|---|---|
| id | Uniquely identifies this record so that the system can retrieve it and relate it to other operational information without relying on a person or product name. |
| session_id | Links a retained scan-event record to its associated phone-pairing session. |
| qr_payload | Stores the QR payload retained in the scan-event table. |
| created_at | Records when the database record was created. |

## private.attendance_scan_requests

| Field | Purpose |
|---|---|
| request_id | Stores the unique request identifier used for duplicate attendance-request protection. |
| operator_id | Identifies the Auth account that submitted the attendance request. |
| member_id | Identifies the member related to this operational record. |
| result | Stores the saved attendance-processing result as structured JSON. |
| created_at | Records when the database record was created. |

## private.admin_login_attempts

| Field | Purpose |
|---|---|
| bucket | Identifies the grouping used by the private administrator-login attempt tracker. |
| window_start | Records the beginning of the attempt-tracking window. |
| attempts | Stores the number of attempts recorded for the associated tracking window. |

## private.account_sessions

| Field | Purpose |
|---|---|
| user_id | Identifies the Auth account owning the scoped session. |
| session_id | Identifies the accepted Auth session. |
| session_created_at | Records session creation time for replacement ordering. |
| session_scope | Separates dashboard and attendance sessions; CHECK limits values to dashboard or attendance. |
