-- Allow capsules and tablets to be tracked and sold as pieces or boxes.
-- A product uses one discrete unit at a time; no box-to-piece conversion is assumed.
begin;

alter table public.products drop constraint if exists products_check;
alter table public.products drop constraint if exists products_unit_check;
alter table public.products drop constraint if exists products_category_unit_check;
alter table public.products drop constraint if exists products_stock_unit_check;

update public.products
set unit = 'piece', stock_unit = 'piece'
where category = 'supplement'
  and supplement_form in ('capsule', 'tablet')
  and unit = 'item'
  and stock_unit = 'item';

alter table public.products
    add constraint products_category_unit_check
    check (
        (category = 'supplement' and (
            (supplement_form = 'powder' and unit = 'gram')
            or (supplement_form = 'drinkable' and unit = 'milliliter')
            or (supplement_form in ('capsule', 'tablet') and unit in ('piece', 'box') and unit = stock_unit)
            or (supplement_form = 'other' and unit = 'item')
        ))
        or (category = 'merchandise' and unit = 'item')
    );

alter table public.products
    add constraint products_stock_unit_check
    check (
        (category = 'supplement' and (
            (supplement_form = 'powder' and stock_unit in ('gram', 'kilogram', 'ounce', 'pound'))
            or (supplement_form = 'drinkable' and stock_unit in ('milliliter', 'liter', 'fluid_ounce'))
            or (supplement_form in ('capsule', 'tablet') and stock_unit in ('piece', 'box'))
            or (supplement_form = 'other' and stock_unit = 'item')
        ))
        or (category = 'merchandise' and stock_unit = 'item')
    );

alter table public.sale_items drop constraint if exists sale_items_unit_check;
alter table public.sale_items
    add constraint sale_items_unit_check
    check (unit in (
        'gram', 'kilogram', 'ounce', 'pound',
        'milliliter', 'liter', 'fluid_ounce',
        'item', 'piece', 'box', 'membership'
    ));

create or replace function public.restock_product(
    p_product_id uuid,
    p_quantity numeric,
    p_quantity_unit text
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
    product_row public.products%rowtype;
    stock_increment numeric(14, 6);
    quantity_factor numeric;
    stock_factor numeric;
    resulting_stock numeric(14, 6);
begin
    if not private.is_admin() then raise exception 'Admin access required'; end if;
    if p_quantity is null or p_quantity <= 0 then raise exception 'Restock quantity must be greater than zero'; end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;
    if not found then raise exception 'Product is unavailable'; end if;

    if product_row.stock_unit in ('item', 'piece', 'box') then
        if p_quantity_unit is distinct from product_row.stock_unit or p_quantity <> trunc(p_quantity) then
            raise exception 'Discrete stock must use the product unit and a whole-number quantity';
        end if;
        stock_increment := p_quantity;
    else
        quantity_factor := case p_quantity_unit
            when 'gram' then 1
            when 'kilogram' then 1000
            when 'ounce' then 28.349523125
            when 'pound' then 453.59237
            when 'milliliter' then 1
            when 'liter' then 1000
            when 'fluid_ounce' then 29.5735295625
            else null
        end;
        stock_factor := case product_row.stock_unit
            when 'gram' then 1
            when 'kilogram' then 1000
            when 'ounce' then 28.349523125
            when 'pound' then 453.59237
            when 'milliliter' then 1
            when 'liter' then 1000
            when 'fluid_ounce' then 29.5735295625
            else null
        end;
        if quantity_factor is null or stock_factor is null then raise exception 'Unsupported restock unit'; end if;
        if (p_quantity_unit in ('gram', 'kilogram', 'ounce', 'pound'))
            <> (product_row.stock_unit in ('gram', 'kilogram', 'ounce', 'pound')) then
            raise exception 'Restock unit does not match the product stock type';
        end if;
        stock_increment := p_quantity * quantity_factor / stock_factor;
    end if;

    update public.products
    set stock = round(stock + stock_increment, 6), updated_at = now()
    where id = product_row.id
    returning stock into resulting_stock;
    return resulting_stock;
end;
$$;

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
    if not private.is_admin() then raise exception 'Admin access required'; end if;
    if nullif(btrim(p_customer_name), '') is null then raise exception 'Customer name is required'; end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Transaction reference is required'; end if;
    if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;
    if not found then raise exception 'Product is unavailable'; end if;

    quantity_factor := case p_quantity_unit
        when 'gram' then 1
        when 'kilogram' then 1000
        when 'ounce' then 28.349523125
        when 'pound' then 453.59237
        when 'milliliter' then 1
        when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625
        when 'item' then 1
        when 'piece' then 1
        when 'box' then 1
        else null
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
        when 'gram' then 1
        when 'kilogram' then 1000
        when 'ounce' then 28.349523125
        when 'pound' then 453.59237
        when 'milliliter' then 1
        when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625
        when 'item' then 1
        when 'piece' then 1
        when 'box' then 1
        else null
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
        'id', new_sale_id,
        'receipt_number', btrim(p_receipt_number),
        'customer_name', btrim(p_customer_name),
        'total', sale_total,
        'sold_at', now(),
        'product_id', product_row.id,
        'item_name', product_row.name,
        'category', product_row.category,
        'quantity', p_quantity,
        'unit', p_quantity_unit,
        'unit_price', sale_unit_price,
        'line_total', sale_total,
        'stock', resulting_stock,
        'stock_unit', product_row.stock_unit
    );
end;
$$;

revoke all on function public.restock_product(uuid, numeric, text) from public, anon;
grant execute on function public.restock_product(uuid, numeric, text) to authenticated;
revoke all on function public.record_walk_in_sale(text, text, uuid, numeric, text) from public, anon;
grant execute on function public.record_walk_in_sale(text, text, uuid, numeric, text) to authenticated;

notify pgrst, 'reload schema';
commit;
