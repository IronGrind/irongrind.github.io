-- End every currently active attendance phone pairing and pending pairing QR.
-- Scan queue rows are removed by the session foreign key's ON DELETE CASCADE.
-- Historical activity_logs rows are intentionally retained for audit history.
begin;

delete from public.mobile_attendance_scan_sessions
where expires_at > now();

commit;
