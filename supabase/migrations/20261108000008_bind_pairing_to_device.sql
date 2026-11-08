alter table public.mobile_attendance_scan_sessions add column if not exists paired_device_id uuid;

create or replace function public.register_mobile_attendance_device(
  p_session_id uuid,p_token text,p_device_label text,p_device_id uuid
) returns void language plpgsql security definer set search_path='' as $$
declare pairing public.mobile_attendance_scan_sessions%rowtype;
begin
  if p_device_id is null then raise exception 'Phone identity is required. Reload the attendance page.'; end if;
  -- Use the same lock order as the original pairing/limit check.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('mobile_attendance_pairing_limit'));
  select * into pairing from public.mobile_attendance_scan_sessions
    where id=p_session_id and token_hash=md5(p_token) and expires_at>now() for update;
  if not found then raise exception 'Phone pairing is invalid or expired'; end if;
  if pairing.paired_device_id is not null and pairing.paired_device_id<>p_device_id then
    raise exception 'This QR is already assigned to another phone. Ask the administrator to select Pair another phone and scan the new QR.';
  end if;
  if exists(select 1 from public.mobile_attendance_scan_sessions where id<>p_session_id
      and paired_device_id=p_device_id and paired_at is not null and expires_at>now()) then
    raise exception 'This phone already has an active pairing. End that pairing before using another QR.';
  end if;
  perform public.register_mobile_attendance_device(p_session_id,p_token,p_device_label);
  update public.mobile_attendance_scan_sessions set paired_device_id=p_device_id where id=p_session_id;
end;
$$;
revoke all on function public.register_mobile_attendance_device(uuid,text,text) from public,anon,authenticated;
revoke all on function public.register_mobile_attendance_device(uuid,text,text,uuid) from public;
grant execute on function public.register_mobile_attendance_device(uuid,text,text,uuid) to anon,authenticated;
notify pgrst,'reload schema';
