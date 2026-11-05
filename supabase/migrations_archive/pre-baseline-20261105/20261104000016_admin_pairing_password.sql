-- Give phone pairing its own admin-only password, independent of the normal
-- account password. Every sensitive pairing RPC checks this password itself.
begin;

create extension if not exists pgcrypto with schema extensions;
alter table public.mobile_attendance_pairing_policy
    add column if not exists pairing_password_hash text;

create or replace function private.require_pairing_password(p_password text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare stored_hash text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select pairing_password_hash into stored_hash
    from public.mobile_attendance_pairing_policy where singleton;
    if stored_hash is null then raise exception 'Set the admin phone pairing password first'; end if;
    if p_password is null or octet_length(p_password) > 72 or extensions.crypt(p_password, stored_hash) <> stored_hash then
        raise exception 'Incorrect phone pairing password';
    end if;
end;
$$;
revoke all on function private.require_pairing_password(text) from public, anon, authenticated;

create or replace function public.verify_mobile_attendance_pairing_password(p_password text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform private.require_pairing_password(p_password);
    return true;
exception when others then
    return false;
end;
$$;

create or replace function public.get_mobile_attendance_pairing_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare configured_limit integer; active_pairs integer; configured boolean;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select max_pairs, pairing_password_hash is not null
    into configured_limit, configured from public.mobile_attendance_pairing_policy where singleton;
    select count(*)::integer into active_pairs from public.mobile_attendance_scan_sessions where expires_at > now();
    return jsonb_build_object('max_pairs', configured_limit, 'active_count', active_pairs, 'password_configured', configured);
end;
$$;

create or replace function public.set_mobile_attendance_pairing_password(p_password text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    if p_password is null or length(p_password) < 8 or octet_length(p_password) > 72 then
        raise exception 'Pairing password must be at least 8 characters and no more than 72 bytes';
    end if;
    update public.mobile_attendance_pairing_policy
    set pairing_password_hash = extensions.crypt(p_password, extensions.gen_salt('bf')),
        updated_at = now(), updated_by = auth.uid()
    where singleton;
end;
$$;

drop function if exists public.create_mobile_attendance_scan_session(boolean);
create function public.create_mobile_attendance_scan_session(p_remember_phone boolean, p_pairing_password text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz;
    actor_id uuid := auth.uid(); actor_display text; actor_role text;
    remember_phone boolean := coalesce(p_remember_phone, false);
    pairing_limit integer; active_pairs integer;
begin
    perform private.require_pairing_password(p_pairing_password);
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into pairing_limit from public.mobile_attendance_pairing_policy where singleton;
    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    select count(*)::integer into active_pairs from public.mobile_attendance_scan_sessions where expires_at > now();
    if active_pairs >= pairing_limit then
        raise exception 'Phone pairing limit reached (% of %). End an existing pairing or increase the limit.', active_pairs, pairing_limit;
    end if;
    session_expiry := now() + case when remember_phone then interval '30 days' else interval '10 minutes' end;
    select coalesce(nullif(full_name, ''), username, email, id::text), role into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.mobile_attendance_scan_sessions (id, token_hash, created_by, expires_at)
    values (session_id, md5(session_token), actor_id, session_expiry);
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pair_qr_created', 'mobile_attendance_scan_sessions', session_id::text, 'Attendance phone pairing',
        case when remember_phone then 'Created a phone attendance pairing QR with 30-day access.'
             else 'Created a one-time phone attendance pairing QR that expires in 10 minutes.' end);
    return jsonb_build_object('session_id', session_id, 'token', session_token, 'expires_at', session_expiry, 'remember_phone', remember_phone);
end;
$$;

drop function if exists public.set_mobile_attendance_pairing_limit(integer);
create function public.set_mobile_attendance_pairing_limit(p_max_pairs integer, p_pairing_password text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare previous_limit integer; actor_id uuid := auth.uid(); actor_display text; actor_role text;
begin
    perform private.require_pairing_password(p_pairing_password);
    if p_max_pairs is null or p_max_pairs not between 2 and 50 then raise exception 'Phone pairing limit must be between 2 and 50'; end if;
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into previous_limit from public.mobile_attendance_pairing_policy where singleton for update;
    update public.mobile_attendance_pairing_policy set max_pairs = p_max_pairs, updated_at = now(), updated_by = actor_id where singleton;
    select coalesce(nullif(full_name, ''), username, email, id::text), role into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details, changed_fields)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'), 'phone_pairing_limit_changed',
        'mobile_attendance_pairing_policy', 'true', 'Attendance phone pairing limit',
        'Changed the active phone pairing limit from ' || previous_limit || ' to ' || p_max_pairs || '.', array['max_pairs']);
    return jsonb_build_object('previous_limit', previous_limit, 'max_pairs', p_max_pairs);
end;
$$;

drop function if exists public.close_mobile_attendance_scan_session(uuid);
create function public.close_mobile_attendance_scan_session(p_session_id uuid, p_pairing_password text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    actor_id uuid := auth.uid(); actor_display text; actor_role text;
begin
    perform private.require_pairing_password(p_pairing_password);
    select * into session_row from public.mobile_attendance_scan_sessions
    where id = p_session_id and created_by = actor_id for update;
    if not found then return; end if;
    select coalesce(nullif(full_name, ''), username, email, id::text), role into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        case when session_row.paired_at is null then 'phone_pairing_ended' else 'phone_unpaired' end,
        'mobile_attendance_scan_sessions', session_row.id::text,
        coalesce(nullif(session_row.paired_device, ''), 'Attendance phone pairing'),
        case when session_row.paired_at is null then 'Ended an unused attendance phone pairing QR.'
             else 'Ended the attendance phone pairing for ' || session_row.paired_device || '.' end);
    delete from public.mobile_attendance_scan_sessions where id = p_session_id and created_by = actor_id;
end;
$$;

revoke all on function public.get_mobile_attendance_pairing_settings() from public, anon;
grant execute on function public.get_mobile_attendance_pairing_settings() to authenticated;
revoke all on function public.verify_mobile_attendance_pairing_password(text) from public, anon;
grant execute on function public.verify_mobile_attendance_pairing_password(text) to authenticated;
revoke all on function public.set_mobile_attendance_pairing_password(text) from public, anon, authenticated;
revoke all on function public.create_mobile_attendance_scan_session(boolean, text) from public, anon;
grant execute on function public.create_mobile_attendance_scan_session(boolean, text) to authenticated;
revoke all on function public.set_mobile_attendance_pairing_limit(integer, text) from public, anon;
grant execute on function public.set_mobile_attendance_pairing_limit(integer, text) to authenticated;
revoke all on function public.close_mobile_attendance_scan_session(uuid, text) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid, text) to authenticated;

notify pgrst, 'reload schema';
commit;
