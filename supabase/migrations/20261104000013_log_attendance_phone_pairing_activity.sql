-- Audit attendance pairing QR creation, successful pairing, and ending a pair.
-- The secret token and QR payload are never written to activity_logs.
begin;

create or replace function public.create_mobile_attendance_scan_session(p_remember_phone boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz;
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
    remember_phone boolean := coalesce(p_remember_phone, false);
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    session_expiry := now() + case when remember_phone then interval '30 days' else interval '10 minutes' end;
    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles where id = actor_id;

    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    insert into public.mobile_attendance_scan_sessions (id, token_hash, created_by, expires_at)
    values (session_id, md5(session_token), actor_id, session_expiry);

    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pair_qr_created', 'mobile_attendance_scan_sessions', session_id::text,
        'Attendance phone pairing',
        case when remember_phone then 'Created a phone attendance pairing QR with 30-day access.'
             else 'Created a one-time phone attendance pairing QR that expires in 10 minutes.' end
    );

    return jsonb_build_object(
        'session_id', session_id,
        'token', session_token,
        'expires_at', session_expiry,
        'remember_phone', remember_phone
    );
end;
$$;

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
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    device_label text := left(btrim(p_device_label), 100);
    actor_display text;
    actor_role text;
begin
    if p_token is null or nullif(device_label, '') is null then
        raise exception 'Invalid phone pairing details';
    end if;

    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id
      and token_hash = md5(p_token)
      and expires_at > now()
    for update;
    if not found then raise exception 'Phone scanner session is invalid or expired'; end if;

    update public.mobile_attendance_scan_sessions
    set paired_device = device_label,
        paired_at = now()
    where id = p_session_id;

    if session_row.paired_at is null or session_row.paired_device is distinct from device_label then
        select coalesce(nullif(full_name, ''), username, email, id::text), role
        into actor_display, actor_role
        from public.profiles where id = session_row.created_by;

        insert into public.activity_logs (
            actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details,
            changed_fields
        ) values (
            session_row.created_by, coalesce(actor_display, session_row.created_by::text), coalesce(actor_role, 'admin'),
            'phone_paired', 'mobile_attendance_scan_sessions', p_session_id::text, device_label,
            'Paired ' || device_label || ' with the attendance pairing QR.',
            array['paired_device', 'paired_at']
        );
    end if;
end;
$$;

create or replace function public.close_mobile_attendance_scan_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id and created_by = actor_id
    for update;
    if not found then return; end if;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles where id = actor_id;

    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        case when session_row.paired_at is null then 'phone_pairing_ended' else 'phone_unpaired' end,
        'mobile_attendance_scan_sessions', session_row.id::text,
        coalesce(nullif(session_row.paired_device, ''), 'Attendance phone pairing'),
        case when session_row.paired_at is null then 'Ended an unused attendance phone pairing QR.'
             else 'Ended the attendance phone pairing for ' || session_row.paired_device || '.' end
    );

    delete from public.mobile_attendance_scan_sessions where id = p_session_id and created_by = actor_id;
end;
$$;

-- Bring currently active sessions into the audit trail when this migration is
-- installed after a phone has already been paired. The guards make reruns safe.
insert into public.activity_logs (
    actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details
)
select session.created_by,
    coalesce(nullif(profile.full_name, ''), profile.username, profile.email, session.created_by::text),
    coalesce(profile.role, 'admin'), 'phone_pair_qr_created', 'mobile_attendance_scan_sessions',
    session.id::text, 'Attendance phone pairing',
    'Created an attendance phone pairing QR. The session expires at ' || to_char(session.expires_at at time zone 'Asia/Manila', 'YYYY-MM-DD HH12:MI AM') || ' Manila time.'
from public.mobile_attendance_scan_sessions session
left join public.profiles profile on profile.id = session.created_by
where session.expires_at > now()
  and not exists (
      select 1 from public.activity_logs log
      where log.entity_type = 'mobile_attendance_scan_sessions'
        and log.entity_id = session.id::text
        and log.action = 'phone_pair_qr_created'
  );

insert into public.activity_logs (
    actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details,
    changed_fields
)
select session.created_by,
    coalesce(nullif(profile.full_name, ''), profile.username, profile.email, session.created_by::text),
    coalesce(profile.role, 'admin'), 'phone_paired', 'mobile_attendance_scan_sessions',
    session.id::text, coalesce(session.paired_device, 'Phone'),
    'Paired ' || coalesce(session.paired_device, 'a phone') || ' with the attendance pairing QR.',
    array['paired_device', 'paired_at']
from public.mobile_attendance_scan_sessions session
left join public.profiles profile on profile.id = session.created_by
where session.paired_at is not null
  and not exists (
      select 1 from public.activity_logs log
      where log.entity_type = 'mobile_attendance_scan_sessions'
        and log.entity_id = session.id::text
        and log.action = 'phone_paired'
  );

revoke all on function public.create_mobile_attendance_scan_session(boolean) from public, anon;
grant execute on function public.create_mobile_attendance_scan_session(boolean) to authenticated;
revoke all on function public.register_mobile_attendance_device(uuid, text, text) from public, authenticated;
grant execute on function public.register_mobile_attendance_device(uuid, text, text) to anon;
revoke all on function public.close_mobile_attendance_scan_session(uuid) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
