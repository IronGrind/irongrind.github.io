-- Repair deployments where migration 00011 was rerun after newer migrations.
-- Keep the configured password and existing phone pairings.
begin;

create or replace function public.verify_mobile_attendance_pairing_password(p_password text)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
    perform private.require_pairing_password(p_password);
    return true;
end;
$$;
revoke all on function public.verify_mobile_attendance_pairing_password(text) from public, anon;
grant execute on function public.verify_mobile_attendance_pairing_password(text) to authenticated;

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

revoke all on function public.register_mobile_attendance_device(uuid, text, text) from public, authenticated;
grant execute on function public.register_mobile_attendance_device(uuid, text, text) to anon;
notify pgrst, 'reload schema';
commit;
