-- Pairing QR codes still expire after ten minutes; paired devices last 30 days.
do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.register_mobile_attendance_device(uuid,text,text)'::regprocedure);
  definition:=replace(definition,
    'then now() + case when remember_phone then interval ''30 days'' else interval ''10 minutes'' end',
    'then now() + interval ''30 days''');
  execute definition;
end;
$$;
-- Upgrade active temporary pairings without reviving expired or removed devices.
update public.mobile_attendance_scan_sessions
set expires_at=greatest(expires_at,paired_at+interval '30 days'),remember_phone=true
where paired_at is not null and expires_at>now();
