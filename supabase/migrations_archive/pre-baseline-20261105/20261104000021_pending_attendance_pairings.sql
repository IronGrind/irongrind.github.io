-- Expose unpaired QR sessions separately so they can be removed when pending
-- sessions have reserved all available phone slots.
begin;

create or replace function public.list_admin_mobile_attendance_pending_sessions()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'session_id', id,
        'created_at', created_at,
        'expires_at', expires_at
    ) order by created_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is null;

    return result;
end;
$$;

revoke all on function public.list_admin_mobile_attendance_pending_sessions() from public, anon;
grant execute on function public.list_admin_mobile_attendance_pending_sessions() to authenticated;

notify pgrst, 'reload schema';
commit;
