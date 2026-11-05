-- Allow admins to list all active attendance phones they own.
begin;

create or replace function public.list_admin_mobile_attendance_devices()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    result jsonb;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'session_id', id,
        'device', paired_device,
        'paired_at', paired_at,
        'expires_at', expires_at
    ) order by paired_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where created_by = (select auth.uid())
      and expires_at > now()
      and paired_at is not null;

    return result;
end;
$$;

revoke all on function public.list_admin_mobile_attendance_devices() from public, anon;
grant execute on function public.list_admin_mobile_attendance_devices() to authenticated;
notify pgrst, 'reload schema';
commit;
