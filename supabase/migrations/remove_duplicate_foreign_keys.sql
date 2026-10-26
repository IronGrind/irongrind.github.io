-- Remove only the duplicate constraints introduced by
-- auth_user_foreign_keys.sql after the pre-existing equivalent constraints
-- were found in Supabase. Keep the original constraints and validated
-- sale_items_sale_id_fkey.

begin;

alter table public.profiles
    drop constraint if exists profiles_id_auth_users_fkey;

alter table public.members
    drop constraint if exists members_auth_user_id_auth_users_fkey;

alter table public.membership_applications
    drop constraint if exists membership_applications_auth_user_id_auth_users_fkey;

alter table public.attendance
    drop constraint if exists attendance_recorded_by_auth_users_fkey;

alter table public.sales
    drop constraint if exists sales_processed_by_auth_users_fkey;

alter table public.membership_history
    drop constraint if exists membership_history_recorded_by_auth_users_fkey;

-- This was already duplicated before the Auth-FK migration: the validated
-- sale_items_sale_id_fkey enforces the same relation and ON DELETE action.
alter table public.sale_items
    drop constraint if exists sale_items_sale_id_compat_fkey;

commit;

notify pgrst, 'reload schema';
