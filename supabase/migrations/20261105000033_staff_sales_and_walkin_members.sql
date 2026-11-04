-- Give staff only two new POS operations: product walk-in sales and fixed-price
-- walk-in member registrations. Direct table access remains admin-only.
begin;

create or replace function public.record_walk_in_sale(
    p_receipt_number text,
    p_customer_name text,
    p_product_id uuid,
    p_quantity numeric,
    p_quantity_unit text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    product_row public.products%rowtype;
    new_sale_id uuid;
    sale_total numeric(12, 2);
    resulting_stock numeric(14, 6);
    quantity_factor numeric;
    stock_factor numeric;
    quantity_in_base_unit numeric(14, 6);
    stock_deduction numeric(14, 6);
    sale_unit_price numeric(12, 2);
begin
    if not private.is_admin() and not private.is_staff() then
        raise exception 'Staff sales access required';
    end if;
    if nullif(btrim(p_customer_name), '') is null then raise exception 'Customer name is required'; end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Transaction reference is required'; end if;
    if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;
    if not found then raise exception 'Product is unavailable'; end if;
    if product_row.stock is null then raise exception 'Product inventory is not configured'; end if;

    quantity_factor := case p_quantity_unit
        when 'gram' then 1 when 'kilogram' then 1000 when 'ounce' then 28.349523125
        when 'pound' then 453.59237 when 'milliliter' then 1 when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625 when 'item' then 1 when 'piece' then 1
        when 'box' then 1 else null
    end;
    if quantity_factor is null then raise exception 'Unsupported sale unit'; end if;

    if product_row.unit = 'gram' and p_quantity_unit not in ('gram', 'kilogram', 'ounce', 'pound') then
        raise exception 'Powder supplements must be sold by weight';
    elsif product_row.unit = 'milliliter' and p_quantity_unit not in ('milliliter', 'liter', 'fluid_ounce') then
        raise exception 'Drinkable supplements must be sold by volume';
    elsif product_row.unit in ('item', 'piece', 'box')
        and (p_quantity_unit is distinct from product_row.unit or p_quantity <> trunc(p_quantity)) then
        raise exception 'Discrete products must use their configured unit and a whole-number quantity';
    end if;

    stock_factor := case product_row.stock_unit
        when 'gram' then 1 when 'kilogram' then 1000 when 'ounce' then 28.349523125
        when 'pound' then 453.59237 when 'milliliter' then 1 when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625 when 'item' then 1 when 'piece' then 1
        when 'box' then 1 else null
    end;
    if stock_factor is null then raise exception 'Unsupported inventory unit'; end if;
    if product_row.unit = 'gram' and product_row.stock_unit not in ('gram', 'kilogram', 'ounce', 'pound') then
        raise exception 'Weight sale unit does not match inventory unit';
    elsif product_row.unit = 'milliliter' and product_row.stock_unit not in ('milliliter', 'liter', 'fluid_ounce') then
        raise exception 'Volume sale unit does not match inventory unit';
    elsif product_row.unit in ('item', 'piece', 'box') and product_row.stock_unit <> product_row.unit then
        raise exception 'Discrete sale unit does not match inventory unit';
    end if;

    quantity_in_base_unit := p_quantity * quantity_factor;
    stock_deduction := quantity_in_base_unit / stock_factor;
    if product_row.stock < stock_deduction then raise exception 'Not enough stock available'; end if;
    sale_unit_price := round(product_row.price_per_unit * quantity_factor, 2);
    sale_total := round(product_row.price_per_unit * quantity_in_base_unit, 2);

    insert into public.sales (receipt_number, customer_type, customer_name, total, status, processed_by)
    values (btrim(p_receipt_number), 'walk_in', btrim(p_customer_name), sale_total, 'paid', (select auth.uid()))
    returning id into new_sale_id;
    insert into public.sale_items (sale_id, product_id, item_name, category, quantity, unit, unit_price, line_total)
    values (new_sale_id, product_row.id, product_row.name, product_row.category, p_quantity, p_quantity_unit, sale_unit_price, sale_total);
    update public.products
    set stock = round(stock - stock_deduction, 6), updated_at = now()
    where id = product_row.id
    returning stock into resulting_stock;

    return jsonb_build_object(
        'id', new_sale_id, 'receipt_number', btrim(p_receipt_number),
        'customer_name', btrim(p_customer_name), 'total', sale_total, 'sold_at', now(),
        'product_id', product_row.id, 'item_name', product_row.name, 'category', product_row.category,
        'quantity', p_quantity, 'unit', p_quantity_unit, 'unit_price', sale_unit_price,
        'line_total', sale_total, 'stock', resulting_stock, 'stock_unit', product_row.stock_unit
    );
end;
$$;

-- Sales history is limited to this staff member's recent product transactions.
create or replace function public.staff_list_own_product_sales()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
    if not private.is_staff() then raise exception 'Staff access required'; end if;
    select coalesce(jsonb_agg(jsonb_build_object(
        'receipt_number', s.receipt_number,
        'customer_name', s.customer_name,
        'total', s.total,
        'sold_at', s.sold_at,
        'items', (select coalesce(jsonb_agg(jsonb_build_object(
            'item_name', si.item_name, 'quantity', si.quantity, 'unit', si.unit,
            'line_total', si.line_total, 'category', si.category
        )), '[]'::jsonb) from public.sale_items si
          where si.sale_id = s.id and si.category in ('supplement', 'merchandise'))
    ) order by s.sold_at desc), '[]'::jsonb)
    into result
    from (
        select distinct s.id, s.receipt_number, s.customer_name, s.total, s.sold_at
        from public.sales s
        join public.sale_items si on si.sale_id = s.id
        where s.processed_by = (select auth.uid())
          and s.customer_type = 'walk_in'
          and s.status = 'paid'
          and si.category in ('supplement', 'merchandise')
        order by s.sold_at desc
        limit 50
    ) s;
    return result;
end;
$$;

-- The edge function is service-role-only and validates the caller and fixed
-- membership choices before invoking this transactional member/sale writer.
create or replace function public.admin_create_member_and_sale(
    p_admin_id uuid,
    p_member jsonb,
    p_receipt_number text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    member_data jsonb := p_member;
    member_row public.members%rowtype;
    sale_id uuid;
    paid_type text;
    caller_role text;
    caller_active boolean;
begin
    if jsonb_typeof(member_data) is distinct from 'object'
        or nullif(member_data ->> 'auth_user_id', '') is null then
        raise exception 'Member details and Auth user link are required';
    end if;
    select role, is_active into caller_role, caller_active from public.profiles where id = p_admin_id;
    if caller_role not in ('admin', 'staff') or caller_active is distinct from true then
        raise exception 'Active admin or staff access required';
    end if;
    if caller_role = 'staff' and not (
        (member_data ->> 'plan' = 'Monthly' and member_data ->> 'plan_price' = '800')
        or (member_data ->> 'plan' = 'Half Month' and member_data ->> 'plan_price' = '400')
        or (member_data ->> 'plan' = 'Walk-in' and member_data ->> 'plan_price' = '80')
    ) then
        raise exception 'Staff may register only the standard membership plans';
    end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Receipt number is required'; end if;

    select data_type into paid_type from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    member_data := jsonb_set(member_data, '{id}', to_jsonb(gen_random_uuid()), true);
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        member_data := jsonb_set(member_data, '{paid}', member_data -> 'plan_price', true);
    else
        member_data := jsonb_set(member_data, '{paid}', 'true'::jsonb, true);
    end if;
    insert into public.members select (jsonb_populate_record(null::public.members, member_data)).* returning * into member_row;

    insert into public.sales (receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by)
    values (btrim(p_receipt_number), 'member', member_row.full_name, member_row.id,
        coalesce(member_row.plan_price, 0), 'paid', now(), p_admin_id) returning id into sale_id;
    insert into public.sale_items (sale_id, item_name, category, quantity, unit, unit_price, line_total)
    values (sale_id, coalesce(member_row.plan, 'Membership') || ' Membership', 'membership', 1,
        'membership', coalesce(member_row.plan_price, 0), coalesce(member_row.plan_price, 0));
    return jsonb_build_object('member_id', member_row.id, 'sale_id', sale_id, 'receipt_number', btrim(p_receipt_number));
end;
$$;

revoke all on function public.record_walk_in_sale(text, text, uuid, numeric, text) from public, anon;
grant execute on function public.record_walk_in_sale(text, text, uuid, numeric, text) to authenticated;
revoke all on function public.staff_list_own_product_sales() from public, anon;
grant execute on function public.staff_list_own_product_sales() to authenticated;
revoke all on function public.admin_create_member_and_sale(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.admin_create_member_and_sale(uuid, jsonb, text) to service_role;

notify pgrst, 'reload schema';
commit;
