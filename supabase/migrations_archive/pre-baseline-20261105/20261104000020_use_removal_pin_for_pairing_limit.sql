-- Protect limit changes with the same four-digit PIN used to remove a paired
-- phone, rather than the separate password used to create phone pairings.
begin;

drop function if exists public.set_mobile_attendance_pairing_limit(integer, text);

create function public.set_mobile_attendance_pairing_limit(
    p_max_pairs integer,
    p_removal_pin text
)
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
    perform private.require_attendance_removal_pin(p_removal_pin);
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
    into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id,
        record_label, details, changed_fields
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pairing_limit_changed', 'mobile_attendance_pairing_policy', 'true',
        'Attendance phone pairing limit',
        'Changed the active phone pairing limit from ' || previous_limit || ' to ' || p_max_pairs || '.',
        array['max_pairs']
    );
    return jsonb_build_object('previous_limit', previous_limit, 'max_pairs', p_max_pairs);
end;
$$;

revoke all on function public.set_mobile_attendance_pairing_limit(integer, text) from public, anon;
grant execute on function public.set_mobile_attendance_pairing_limit(integer, text) to authenticated;

notify pgrst, 'reload schema';
commit;
