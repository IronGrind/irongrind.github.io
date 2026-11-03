-- Record a friendly device label when the attendance phone pairs and expose it
-- only to the admin that owns the active scanner session.
begin;

alter table public.mobile_attendance_scan_sessions
    add column if not exists paired_device text,
    add column if not exists paired_at timestamptz;

create or replace function public.register_mobile_attendance_device(
    p_session_id uuid,
    p_token text,
    p_device_label text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if p_token is null or nullif(btrim(p_device_label), '') is null then
        raise exception 'Invalid phone pairing details';
    end if;

    update public.mobile_attendance_scan_sessions
    set paired_device = left(btrim(p_device_label), 100),
        paired_at = now()
    where id = p_session_id
      and token_hash = md5(p_token)
      and expires_at > now();

    if not found then raise exception 'Phone scanner session is invalid or expired'; end if;
end;
$$;

create or replace function public.get_admin_mobile_attendance_device(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id
      and created_by = (select auth.uid())
      and expires_at > now();

    if not found then raise exception 'Phone scanner session is inactive or expired'; end if;

    return jsonb_build_object(
        'paired', session_row.paired_at is not null,
        'device', session_row.paired_device,
        'paired_at', session_row.paired_at,
        'expires_at', session_row.expires_at
    );
end;
$$;

revoke all on function public.register_mobile_attendance_device(uuid, text, text) from public, authenticated;
grant execute on function public.register_mobile_attendance_device(uuid, text, text) to anon;
revoke all on function public.get_admin_mobile_attendance_device(uuid) from public, anon;
grant execute on function public.get_admin_mobile_attendance_device(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
