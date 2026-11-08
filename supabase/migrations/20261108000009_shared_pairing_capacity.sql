-- A pending QR reserves a slot. Pairing consumes that reservation, not a new slot.
do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.create_mobile_attendance_scan_session(boolean,text)'::regprocedure);
  definition:=replace(definition,'where expires_at > now() and paired_at is not null;', 'where expires_at > now();');
  execute definition;
  definition:=pg_get_functiondef('public.get_mobile_attendance_pairing_settings()'::regprocedure);
  definition:=replace(definition,'''active_count'', paired_devices,','''active_count'', paired_devices + pending_qrs,');
  execute definition;
end;
$$;

create or replace function private.trim_pending_attendance_pairings(p_limit integer)
returns void language sql security definer set search_path='' as $$
  with pending as (
    select id,row_number() over(order by created_at desc,id desc) as position
    from public.mobile_attendance_scan_sessions where paired_at is null and expires_at>now()
  ), capacity as (
    select greatest(0,p_limit-count(*)::integer) as remaining
    from public.mobile_attendance_scan_sessions where paired_at is not null and expires_at>now()
  )
  update public.mobile_attendance_scan_sessions set expires_at=now()
    where id in(select pending.id from pending cross join capacity where position>remaining);
$$;
revoke all on function private.trim_pending_attendance_pairings(integer) from public,anon,authenticated;

do $$
declare definition text; configured_limit integer;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('mobile_attendance_pairing_limit'));
  select max_pairs into configured_limit from public.mobile_attendance_pairing_policy where singleton;
  perform private.trim_pending_attendance_pairings(configured_limit);
  definition:=pg_get_functiondef('public.set_mobile_attendance_pairing_limit(integer,text)'::regprocedure);
  definition:=replace(definition,'select max_pairs into previous_limit',
    'if (select count(*) from public.mobile_attendance_scan_sessions where paired_at is not null and expires_at>now()) > p_max_pairs then raise exception ''End paired phones before reducing the limit below their count''; end if; select max_pairs into previous_limit');
  definition:=replace(definition,'return jsonb_build_object(''previous_limit''',
    'perform private.trim_pending_attendance_pairings(p_max_pairs); return jsonb_build_object(''previous_limit''');
  execute definition;
end;
$$;
notify pgrst,'reload schema';
