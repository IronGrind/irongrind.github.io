-- Remove the staff-account feature and the staff accounts it created.
-- Attendance records are retained; deleting Auth users clears their recorded_by
-- references through the existing ON DELETE SET NULL foreign key.
begin;

drop policy if exists staff_read_attendance on public.attendance;
drop policy if exists staff_insert_attendance on public.attendance;
drop policy if exists staff_update_attendance on public.attendance;

drop function if exists public.staff_resolve_attendance_member(text);
drop function if exists public.staff_list_attendance();
drop function if exists private.is_staff();

delete from auth.users auth_user
using public.profiles profile
where profile.id = auth_user.id
  and profile.role = 'staff';

update public.profiles set role = 'member' where role = 'staff';

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
    add constraint profiles_role_check check (role in ('admin', 'member'));

revoke select (email, is_active, created_at) on public.profiles from service_role;
revoke update (is_active) on public.profiles from service_role;
alter table public.profiles drop column if exists is_active;

notify pgrst, 'reload schema';
commit;
