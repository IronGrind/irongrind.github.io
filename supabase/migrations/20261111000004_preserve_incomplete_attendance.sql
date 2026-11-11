-- A missing checkout from a previous Manila calendar day is incomplete, not an open visit to close.
-- Keep it intact and create a fresh check-in when the member next attends.
create or replace function public.record_attendance_scan(
    p_identifier text,
    p_request_id uuid,
    p_session_id uuid default null,
    p_token text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    operator_id uuid := auth.uid();
    member_row public.members%rowtype;
    visit public.attendance%rowtype;
    saved_request private.attendance_scan_requests%rowtype;
    result jsonb;
    identifier text := btrim(p_identifier);
    expiry date;
begin
    if not exists (
        select 1 from public.profiles
        where id = operator_id and role in ('admin', 'staff') and is_active
    ) then
        raise exception 'Active staff or admin sign-in required';
    end if;
    if p_request_id is null or identifier is null or length(identifier) not between 1 and 500 then
        raise exception 'Invalid attendance scan';
    end if;
    if p_session_id is not null or p_token is not null then
        perform 1 from public.mobile_attendance_scan_sessions
        where id = p_session_id and token_hash = md5(p_token)
            and expires_at > now() and paired_at is not null for update;
        if not found then raise exception 'Phone pairing is invalid or expired'; end if;
    end if;
    perform pg_advisory_xact_lock(hashtext(p_request_id::text));
    select * into saved_request
    from private.attendance_scan_requests
    where request_id = p_request_id;
    if found then
        if saved_request.operator_id <> operator_id then raise exception 'Scan belongs to another operator'; end if;
        return saved_request.result;
    end if;
    if upper(left(identifier, 10)) = 'IRONGRIND|' then identifier := substr(identifier, 11); end if;
    select * into member_row
    from public.members
    where id::text = lower(identifier)
       or auth_user_id::text = lower(identifier)
       or lower(username) = lower(identifier)
    limit 1;
    if not found then raise exception 'Member QR was not recognized'; end if;

    perform pg_advisory_xact_lock(hashtext(member_row.id::text));
    select * into visit
    from public.attendance
    where member_id = member_row.id
    order by time_in desc
    limit 1
    for update;

    -- Repeated camera callbacks or two phones scanning together must not toggle a visit.
    if found and greatest(visit.time_in, visit.time_out) > now() - interval '8 seconds' then
        result := jsonb_build_object('action', 'duplicate', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    elsif visit.id is not null
       and visit.time_out is null
       and (visit.time_in at time zone 'Asia/Manila')::date = (now() at time zone 'Asia/Manila')::date then
        update public.attendance
        set time_out = now(), checked_out_by = operator_id
        where id = visit.id;
        result := jsonb_build_object('action', 'check_out', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    else
        expiry := coalesce(member_row.expiry_date, member_row.end_date);
        if expiry is not null and expiry < (now() at time zone 'Asia/Manila')::date then
            raise exception 'Membership is expired. Ask the admin to check renewal status';
        end if;
        insert into public.attendance(member_id, time_in, recorded_by)
        values (member_row.id, now(), operator_id)
        returning * into visit;
        result := jsonb_build_object('action', 'check_in', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    end if;

    insert into private.attendance_scan_requests(request_id, operator_id, member_id, result)
    values (p_request_id, operator_id, member_row.id, result);
    return result;
end;
$$;
