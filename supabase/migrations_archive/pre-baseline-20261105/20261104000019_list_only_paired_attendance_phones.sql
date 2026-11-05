-- Show only successfully paired devices in the device list. Pending QR
-- sessions continue to reserve capacity and are reflected in active_count.
begin;

create or replace function public.get_mobile_attendance_pairing_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    configured_limit integer;
    active_sessions integer;
    paired_devices integer;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select max_pairs into configured_limit
    from public.mobile_attendance_pairing_policy where singleton;
    select count(*)::integer into active_sessions
    from public.mobile_attendance_scan_sessions where expires_at > now();
    select count(*)::integer into paired_devices
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    return jsonb_build_object(
        'max_pairs', configured_limit,
        'active_count', active_sessions,
        'paired_count', paired_devices,
        'password_configured', (select pairing_password_hash is not null
            from public.mobile_attendance_pairing_policy where singleton)
    );
end;
$$;

create or replace function public.list_admin_mobile_attendance_devices()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select coalesce(jsonb_agg(jsonb_build_object(
        'session_id', id,
        'device', paired_device,
        'paired', true,
        'paired_at', paired_at,
        'created_at', created_at,
        'expires_at', expires_at
    ) order by paired_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    return result;
end;
$$;

revoke all on function public.get_mobile_attendance_pairing_settings() from public, anon;
grant execute on function public.get_mobile_attendance_pairing_settings() to authenticated;
revoke all on function public.list_admin_mobile_attendance_devices() from public, anon;
grant execute on function public.list_admin_mobile_attendance_devices() to authenticated;

notify pgrst, 'reload schema';
commit;
