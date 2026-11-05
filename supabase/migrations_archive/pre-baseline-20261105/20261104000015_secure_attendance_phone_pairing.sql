-- Require recent admin password verification, and enforce a configurable
-- global cap on active attendance phone pairing sessions.
begin;

create table if not exists public.mobile_attendance_pairing_policy (
    singleton boolean primary key default true check (singleton),
    max_pairs integer not null default 2 check (max_pairs between 2 and 50),
    updated_at timestamptz not null default now(),
    updated_by uuid references auth.users (id)
);
insert into public.mobile_attendance_pairing_policy (singleton, max_pairs)
values (true, 2)
on conflict (singleton) do nothing;
alter table public.mobile_attendance_pairing_policy enable row level security;
revoke all on public.mobile_attendance_pairing_policy from public, anon, authenticated;

create or replace function private.require_recent_admin_auth()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    authenticated_at bigint;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;
    authenticated_at := nullif((select auth.jwt())->>'auth_time', '')::bigint;
    if authenticated_at is null or extract(epoch from now())::bigint - authenticated_at > 300 then
        raise exception 'Re-enter the admin password to authorize this action';
    end if;
end;
$$;
revoke all on function private.require_recent_admin_auth() from public, anon, authenticated;

create or replace function public.get_mobile_attendance_pairing_settings()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    configured_limit integer;
    active_pairs integer;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select max_pairs into configured_limit from public.mobile_attendance_pairing_policy where singleton;
    select count(*)::integer into active_pairs
    from public.mobile_attendance_scan_sessions where expires_at > now();
    return jsonb_build_object('max_pairs', configured_limit, 'active_count', active_pairs);
end;
$$;

create or replace function public.set_mobile_attendance_pairing_limit(p_max_pairs integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    previous_limit integer;
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
begin
    perform private.require_recent_admin_auth();
    if p_max_pairs is null or p_max_pairs not between 2 and 50 then
        raise exception 'Phone pairing limit must be between 2 and 50';
    end if;
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into previous_limit
    from public.mobile_attendance_pairing_policy where singleton for update;
    update public.mobile_attendance_pairing_policy
    set max_pairs = p_max_pairs, updated_at = now(), updated_by = actor_id
    where singleton;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role from public.profiles where id = actor_id;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details, changed_fields)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pairing_limit_changed', 'mobile_attendance_pairing_policy', 'true', 'Attendance phone pairing limit',
        'Changed the active phone pairing limit from ' || previous_limit || ' to ' || p_max_pairs || '.',
        array['max_pairs']);

    return jsonb_build_object('previous_limit', previous_limit, 'max_pairs', p_max_pairs);
end;
$$;

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
    pairing_limit integer;
    active_pairs integer;
begin
    perform private.require_recent_admin_auth();
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into pairing_limit from public.mobile_attendance_pairing_policy where singleton;
    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    select count(*)::integer into active_pairs from public.mobile_attendance_scan_sessions where expires_at > now();
    if active_pairs >= pairing_limit then
        raise exception 'Phone pairing limit reached (% of %). End an existing pairing or ask an admin to increase the limit.', active_pairs, pairing_limit;
    end if;

    session_expiry := now() + case when remember_phone then interval '30 days' else interval '10 minutes' end;
    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role from public.profiles where id = actor_id;
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
    perform private.require_recent_admin_auth();
    select * into session_row from public.mobile_attendance_scan_sessions
    where id = p_session_id and created_by = actor_id for update;
    if not found then return; end if;
    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role from public.profiles where id = actor_id;
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
revoke all on function public.set_mobile_attendance_pairing_limit(integer) from public, anon;
grant execute on function public.set_mobile_attendance_pairing_limit(integer) to authenticated;
revoke all on function public.create_mobile_attendance_scan_session(boolean) from public, anon;
grant execute on function public.create_mobile_attendance_scan_session(boolean) to authenticated;
revoke all on function public.close_mobile_attendance_scan_session(uuid) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
