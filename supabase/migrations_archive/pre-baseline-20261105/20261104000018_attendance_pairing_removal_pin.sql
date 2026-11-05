-- Keep pairing management reachable at capacity. Admins can list pending and
-- paired sessions across the project and use a separate four-digit PIN to end them.
begin;

alter table public.mobile_attendance_pairing_policy
    add column if not exists pairing_removal_pin_hash text;

create or replace function private.require_attendance_removal_pin(p_pin text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare stored_hash text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    if p_pin is null or p_pin !~ '^[0-9]{4}$' then raise exception 'Enter the four-digit pairing removal PIN'; end if;
    select pairing_removal_pin_hash into stored_hash
    from public.mobile_attendance_pairing_policy where singleton;
    if stored_hash is null then raise exception 'Set the four-digit removal PIN in the database first'; end if;
    if extensions.crypt(p_pin, stored_hash) <> stored_hash then raise exception 'Incorrect four-digit pairing removal PIN'; end if;
end;
$$;
revoke all on function private.require_attendance_removal_pin(text) from public, anon, authenticated;

create or replace function public.verify_mobile_attendance_removal_pin(p_pin text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare configured boolean;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select pairing_removal_pin_hash is not null into configured
    from public.mobile_attendance_pairing_policy where singleton;
    if not configured then return jsonb_build_object('configured', false, 'valid', false); end if;
    if p_pin is null or p_pin !~ '^[0-9]{4}$' then return jsonb_build_object('configured', true, 'valid', false); end if;
    if exists (select 1 from public.mobile_attendance_pairing_policy
        where singleton and extensions.crypt(p_pin, pairing_removal_pin_hash) = pairing_removal_pin_hash) then
        return jsonb_build_object('configured', true, 'valid', true);
    end if;
    return jsonb_build_object('configured', true, 'valid', false);
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
        'paired', paired_at is not null,
        'paired_at', paired_at,
        'created_at', created_at,
        'expires_at', expires_at
    ) order by paired_at desc nulls last, created_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where expires_at > now();
    return result;
end;
$$;

drop function if exists public.close_mobile_attendance_scan_session(uuid, text);
create function public.close_mobile_attendance_scan_session(p_session_id uuid, p_pairing_pin text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    actor_id uuid := auth.uid(); actor_display text; actor_role text;
begin
    perform private.require_attendance_removal_pin(p_pairing_pin);
    select * into session_row from public.mobile_attendance_scan_sessions
    where id = p_session_id for update;
    if not found then return; end if;
    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role from public.profiles where id = actor_id;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        case when session_row.paired_at is null then 'phone_pairing_ended' else 'phone_unpaired' end,
        'mobile_attendance_scan_sessions', session_row.id::text,
        coalesce(nullif(session_row.paired_device, ''), 'Pending phone pairing'),
        case when session_row.paired_at is null then 'Ended a pending attendance phone pairing QR.'
             else 'Ended the attendance phone pairing for ' || session_row.paired_device || '.' end);
    delete from public.mobile_attendance_scan_sessions where id = p_session_id;
end;
$$;

revoke all on function public.verify_mobile_attendance_removal_pin(text) from public, anon;
grant execute on function public.verify_mobile_attendance_removal_pin(text) to authenticated;
revoke all on function public.list_admin_mobile_attendance_devices() from public, anon;
grant execute on function public.list_admin_mobile_attendance_devices() to authenticated;
revoke all on function public.close_mobile_attendance_scan_session(uuid, text) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid, text) to authenticated;

notify pgrst, 'reload schema';
commit;
