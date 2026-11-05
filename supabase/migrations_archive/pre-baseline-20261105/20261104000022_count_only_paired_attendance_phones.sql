-- Count completed phone pairings toward the device limit. Pending pairing QR
-- links expire after 10 minutes; a successful remembered pairing then lasts
-- 30 days. The database rechecks capacity when each phone completes pairing.
begin;

alter table public.mobile_attendance_scan_sessions
    add column if not exists remember_phone boolean not null default false;

update public.mobile_attendance_scan_sessions
set remember_phone = (expires_at - created_at) > interval '1 day'
where paired_at is not null;

-- Previously created pending QR codes could remain active for 30 days and
-- make an empty device list appear full. Invalidate those links once so admins
-- can create fresh 10-minute QR codes under the corrected slot rules.
update public.mobile_attendance_scan_sessions
set expires_at = now()
where paired_at is null and expires_at > now();

create or replace function public.get_mobile_attendance_pairing_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    configured_limit integer;
    paired_devices integer;
    pending_qrs integer;
    configured boolean;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;

    select max_pairs, pairing_password_hash is not null
    into configured_limit, configured
    from public.mobile_attendance_pairing_policy where singleton;
    select count(*)::integer into paired_devices
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    select count(*)::integer into pending_qrs
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is null;

    return jsonb_build_object(
        'max_pairs', configured_limit,
        'active_count', paired_devices,
        'paired_count', paired_devices,
        'pending_count', pending_qrs,
        'session_count', paired_devices + pending_qrs,
        'password_configured', configured
    );
end;
$$;

create or replace function public.create_mobile_attendance_scan_session(
    p_remember_phone boolean,
    p_pairing_password text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz := now() + interval '10 minutes';
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
    remember_requested boolean := coalesce(p_remember_phone, false);
    pairing_limit integer;
    paired_devices integer;
begin
    perform private.require_pairing_password(p_pairing_password);
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into pairing_limit
    from public.mobile_attendance_pairing_policy where singleton;
    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    select count(*)::integer into paired_devices
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    if paired_devices >= pairing_limit then
        raise exception 'Phone pairing limit reached (% of %). End an existing pairing or increase the limit.', paired_devices, pairing_limit;
    end if;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.mobile_attendance_scan_sessions (
        id, token_hash, created_by, expires_at, remember_phone
    ) values (
        session_id, md5(session_token), actor_id, session_expiry, remember_requested
    );
    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pair_qr_created', 'mobile_attendance_scan_sessions', session_id::text,
        'Attendance phone pairing',
        case when remember_requested
            then 'Created a 10-minute attendance phone pairing QR. A successful pairing will remain active for 30 days.'
            else 'Created a one-time 10-minute attendance phone pairing QR.' end
    );

    return jsonb_build_object(
        'session_id', session_id,
        'token', session_token,
        'expires_at', session_expiry,
        'remember_phone', remember_requested
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
    pairing_limit integer;
    paired_devices integer;
    actor_display text;
    actor_role text;
    log_action text;
    log_details text;
    changed text[];
begin
    if p_token is null or nullif(device_label, '') is null then
        raise exception 'Invalid phone pairing details';
    end if;

    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id
      and token_hash = md5(p_token)
      and expires_at > now()
    for update;
    if not found then
        raise exception 'Phone scanner session is invalid or expired';
    end if;

    if session_row.paired_at is null then
        select max_pairs into pairing_limit
        from public.mobile_attendance_pairing_policy where singleton;
        select count(*)::integer into paired_devices
        from public.mobile_attendance_scan_sessions
        where expires_at > now() and paired_at is not null;
        if paired_devices >= pairing_limit then
            raise exception 'Phone pairing limit reached. Ask the admin to free a paired-phone slot.';
        end if;
    end if;

    update public.mobile_attendance_scan_sessions
    set paired_device = device_label,
        paired_at = coalesce(paired_at, now()),
        expires_at = case when paired_at is null
            then now() + case when remember_phone then interval '30 days' else interval '10 minutes' end
            else expires_at end
    where id = p_session_id;

    if session_row.paired_at is null then
        log_action := 'phone_paired';
        log_details := 'Paired ' || device_label || ' with the attendance pairing QR.';
        changed := array['paired_device', 'paired_at'];
    elsif session_row.paired_device is distinct from device_label then
        log_action := 'phone_device_updated';
        log_details := 'Updated the paired attendance phone label to ' || device_label || '.';
        changed := array['paired_device'];
    end if;

    if log_action is not null then
        select coalesce(nullif(full_name, ''), username, email, id::text), role
        into actor_display, actor_role
        from public.profiles where id = session_row.created_by;
        insert into public.activity_logs (
            actor_id, actor_name, actor_role, action, entity_type, entity_id,
            record_label, details, changed_fields
        ) values (
            session_row.created_by, coalesce(actor_display, session_row.created_by::text), coalesce(actor_role, 'admin'),
            log_action, 'mobile_attendance_scan_sessions', p_session_id::text,
            device_label, log_details, changed
        );
    end if;
end;
$$;

revoke all on function public.create_mobile_attendance_scan_session(boolean, text) from public, anon;
grant execute on function public.create_mobile_attendance_scan_session(boolean, text) to authenticated;
revoke all on function public.register_mobile_attendance_device(uuid, text, text) from public, authenticated;
grant execute on function public.register_mobile_attendance_device(uuid, text, text) to anon;
revoke all on function public.get_mobile_attendance_pairing_settings() from public, anon;
grant execute on function public.get_mobile_attendance_pairing_settings() to authenticated;

notify pgrst, 'reload schema';
commit;
