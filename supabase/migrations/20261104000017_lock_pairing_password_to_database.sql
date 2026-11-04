-- Password setup is performed by the database owner in the SQL editor.
-- The application can verify the password, but cannot replace it.
begin;
revoke all on function public.set_mobile_attendance_pairing_password(text) from public, anon, authenticated;
commit;
