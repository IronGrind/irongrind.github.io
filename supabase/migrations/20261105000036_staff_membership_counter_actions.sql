-- Allow active staff to search for the minimum member details needed at the
-- counter and process renewals or standard-price plan changes via RPC only.
begin;

create or replace function public.staff_search_members(p_query text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    search_text text := btrim(coalesce(p_query, ''));
    result jsonb;
begin
    if not private.is_staff() then raise exception 'Staff access required'; end if;
    if length(search_text) < 2 or length(search_text) > 80 then
        raise exception 'Enter between 2 and 80 characters to search';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'id', member_row.id,
        'full_name', member_row.full_name,
        'mobile', member_row.mobile,
        'plan', member_row.plan,
        'plan_price', member_row.plan_price,
        'status', member_row.status,
        'start_date', member_row.start_date,
        'expiry_date', coalesce(member_row.expiry_date, member_row.end_date)
    ) order by member_row.full_name), '[]'::jsonb)
    into result
    from (
        select id, full_name, mobile, plan, plan_price, status, start_date, expiry_date, end_date
        from public.members
        where full_name ilike '%' || search_text || '%'
           or mobile ilike '%' || search_text || '%'
        order by full_name
        limit 25
    ) member_row;

    return result;
end;
$$;
revoke all on function public.staff_search_members(text) from public, anon;
grant execute on function public.staff_search_members(text) to authenticated;

create or replace function public.admin_record_membership_change(
    p_member_id uuid,
    p_event_type text,
    p_new_plan text,
    p_new_price numeric,
    p_new_start_date date,
    p_new_expiry_date date,
    p_customer_name text,
    p_mobile text,
    p_receipt_number text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    member_row public.members%rowtype;
    new_sale_id uuid;
    item_label text;
    paid_type text;
    operator_role text;
    business_date date := (now() at time zone 'Asia/Manila')::date;
begin
    select role into operator_role
    from public.profiles
    where id = (select auth.uid()) and is_active;
    if operator_role is distinct from 'admin' and operator_role is distinct from 'staff' then
        raise exception 'Active staff or admin access required';
    end if;
    if p_event_type is null or p_event_type not in ('renewal', 'plan_change') then raise exception 'Unsupported membership event'; end if;
    if p_new_price is null or p_new_price <= 0 then raise exception 'Membership price must be greater than zero'; end if;
    if nullif(btrim(p_new_plan), '') is null or nullif(btrim(p_customer_name), '') is null
       or nullif(btrim(p_receipt_number), '') is null then
        raise exception 'Plan, customer name, and receipt number are required';
    end if;
    if p_new_start_date is null or p_new_expiry_date is null or p_new_expiry_date < p_new_start_date then
        raise exception 'Valid membership start and expiry dates are required';
    end if;

    if operator_role = 'staff' then
        if not (
            (p_new_plan = 'Monthly' and p_new_price = 800)
            or (p_new_plan = 'Half Month' and p_new_price = 400)
            or (p_new_plan = 'Walk-in' and p_new_price = 80)
        ) then raise exception 'Staff may use only standard membership plans and prices'; end if;
        if p_new_start_date <> business_date then raise exception 'Membership changes must start today'; end if;
        if p_new_expiry_date <> p_new_start_date + (case p_new_plan when 'Monthly' then 30 when 'Half Month' then 15 else 1 end) then
            raise exception 'Membership expiry does not match the selected plan';
        end if;
    end if;

    select * into member_row from public.members where id = p_member_id for update;
    if not found then raise exception 'Member not found'; end if;
    if operator_role = 'staff' and (
        btrim(p_customer_name) is distinct from member_row.full_name
        or nullif(btrim(p_mobile), '') is distinct from member_row.mobile
    ) then
        raise exception 'Staff membership transactions must use the member name and mobile on file';
    end if;
    if p_event_type = 'plan_change' and member_row.plan is not distinct from p_new_plan
       and member_row.plan_price = p_new_price then
        raise exception 'The member already has this plan and price';
    end if;

    select id into new_sale_id from public.sales where receipt_number = btrim(p_receipt_number);
    if found then
        return jsonb_build_object('receipt_number', btrim(p_receipt_number), 'sale_id', new_sale_id,
            'start_date', p_new_start_date, 'expiry_date', p_new_expiry_date);
    end if;

    if coalesce(member_row.expiry_date, member_row.end_date) < business_date
       and not exists (
           select 1 from public.membership_history h
           where h.member_id = member_row.id and h.event_type = 'expired'
             and h.previous_expiry_date = coalesce(member_row.expiry_date, member_row.end_date)
             and h.previous_plan is not distinct from member_row.plan
       ) then
        insert into public.membership_history (
            member_id, event_type, previous_plan, previous_price,
            previous_start_date, previous_expiry_date, notes, recorded_by
        ) values (
            member_row.id, 'expired', member_row.plan, coalesce(member_row.plan_price, 0),
            member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
            'Archived when renewed; receipt ' || btrim(p_receipt_number), (select auth.uid())
        );
    end if;

    insert into public.membership_history (
        member_id, event_type, previous_plan, new_plan, previous_price, new_price,
        previous_start_date, previous_expiry_date, new_start_date, new_expiry_date, notes, recorded_by
    ) values (
        member_row.id, p_event_type, member_row.plan, p_new_plan,
        coalesce(member_row.plan_price, 0), p_new_price,
        member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
        p_new_start_date, p_new_expiry_date, 'Receipt ' || btrim(p_receipt_number), (select auth.uid())
    );

    if p_event_type = 'renewal' and member_row.plan is distinct from p_new_plan then
        insert into public.membership_history (
            member_id, event_type, previous_plan, new_plan, previous_price, new_price,
            previous_start_date, previous_expiry_date, new_start_date, new_expiry_date, notes, recorded_by
        ) values (
            member_row.id, 'plan_change', member_row.plan, p_new_plan,
            coalesce(member_row.plan_price, 0), p_new_price,
            member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
            p_new_start_date, p_new_expiry_date,
            'Plan changed during counter renewal; receipt ' || btrim(p_receipt_number), (select auth.uid())
        );
    end if;

    update public.members set plan = p_new_plan, plan_price = p_new_price,
        start_date = p_new_start_date, end_date = p_new_expiry_date,
        expiry_date = p_new_expiry_date, status = 'active',
        mobile = coalesce(nullif(btrim(p_mobile), ''), mobile), updated_at = now()
    where id = member_row.id;

    select data_type into paid_type from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        execute 'update public.members set paid = $1 where id = $2' using p_new_price, member_row.id;
    elsif paid_type = 'boolean' then
        execute 'update public.members set paid = $1 where id = $2' using true, member_row.id;
    end if;

    item_label := p_new_plan || case when p_event_type = 'renewal'
        then ' Membership Renewal' else ' Membership Plan Change' end;
    insert into public.sales (
        receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by
    ) values (
        btrim(p_receipt_number), 'member', btrim(p_customer_name), member_row.id,
        p_new_price, 'paid', now(), (select auth.uid())
    ) returning id into new_sale_id;
    insert into public.sale_items (sale_id, item_name, category, quantity, unit, unit_price, line_total)
    values (new_sale_id, item_label, 'membership', 1, 'membership', p_new_price, p_new_price);
    return jsonb_build_object('receipt_number', btrim(p_receipt_number), 'sale_id', new_sale_id,
        'start_date', p_new_start_date, 'expiry_date', p_new_expiry_date);
end;
$$;
revoke all on function public.admin_record_membership_change(uuid, text, text, numeric, date, date, text, text, text)
    from public, anon;
grant execute on function public.admin_record_membership_change(uuid, text, text, numeric, date, date, text, text, text)
    to authenticated;

notify pgrst, 'reload schema';
commit;
