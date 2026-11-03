-- Let an admin remember a trusted attendance phone for 30 days and restore
-- the admin-side scan queue after refreshing the dashboard.
begin;

drop function if exists public.create_mobile_attendance_scan_session();
drop function if exists public.create_mobile_attendance_scan_session(boolean);

create function public.create_mobile_attendance_scan_session(p_remember_phone boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    session_expiry := now() + case when coalesce(p_remember_phone, false)
        then interval '30 days' else interval '10 minutes' end;

    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    insert into public.mobile_attendance_scan_sessions (id, token_hash, created_by, expires_at)
    values (session_id, md5(session_token), (select auth.uid()), session_expiry);

    return jsonb_build_object(
        'session_id', session_id,
        'token', session_token,
        'expires_at', session_expiry,
        'remember_phone', coalesce(p_remember_phone, false)
    );
end;
$$;

drop function if exists public.is_admin_mobile_attendance_scan_session_active(uuid);
create function public.is_admin_mobile_attendance_scan_session_active(p_session_id uuid)
returns boolean
language sql
security definer
set search_path = ''
as $$
    select (select private.is_admin()) is true and exists (
        select 1
        from public.mobile_attendance_scan_sessions
        where id = p_session_id
          and created_by = (select auth.uid())
          and expires_at > now()
    );
$$;

drop function if exists public.close_mobile_attendance_scan_session(uuid);
create function public.close_mobile_attendance_scan_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    delete from public.mobile_attendance_scan_sessions
    where id = p_session_id and created_by = (select auth.uid());
end;
$$;

revoke all on function public.create_mobile_attendance_scan_session(boolean) from public, anon;
grant execute on function public.create_mobile_attendance_scan_session(boolean) to authenticated;
revoke all on function public.is_admin_mobile_attendance_scan_session_active(uuid) from public, anon;
grant execute on function public.is_admin_mobile_attendance_scan_session_active(uuid) to authenticated;
revoke all on function public.close_mobile_attendance_scan_session(uuid) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid) to authenticated;
notify pgrst, 'reload schema';

commit;
