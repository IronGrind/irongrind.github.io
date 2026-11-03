-- Let supplement form determine its sales and stock units.
begin;

alter table public.products
    add column if not exists supplement_form text;

update public.products
set supplement_form = 'powder'
where category = 'supplement' and supplement_form is null;

update public.products
set supplement_form = null
where category = 'merchandise' and supplement_form is not null;

update public.products
set unit = case supplement_form
    when 'powder' then 'gram'
    when 'drinkable' then 'milliliter'
    else 'item'
end
where category = 'supplement';

alter table public.products drop constraint if exists products_supplement_form_check;
alter table public.products
    add constraint products_supplement_form_check
    check (
        (category = 'supplement' and supplement_form is not null and supplement_form in ('powder', 'drinkable', 'capsule', 'tablet', 'other'))
        or (category = 'merchandise' and supplement_form is null)
    );

-- Existing supplements remain powder and retain their current mass stock unit.
alter table public.products drop constraint if exists products_stock_unit_check;
alter table public.products
    add constraint products_stock_unit_check
    check (
        (category = 'supplement' and (
            (supplement_form = 'powder' and stock_unit in ('gram', 'kilogram', 'ounce', 'pound'))
            or (supplement_form = 'drinkable' and stock_unit in ('milliliter', 'liter', 'fluid_ounce'))
            or (supplement_form in ('capsule', 'tablet', 'other') and stock_unit = 'item')
        ))
        or (category = 'merchandise' and stock_unit = 'item')
    );

alter table public.sale_items drop constraint if exists sale_items_unit_check;
alter table public.sale_items
    add constraint sale_items_unit_check
    check (unit in ('gram', 'milliliter', 'item', 'membership'));

create or replace function public.record_walk_in_sale(
    p_receipt_number text,
    p_customer_name text,
    p_product_id uuid,
    p_quantity numeric
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
    unit_name text;
    stock_deduction numeric(14, 6);
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

    if product_row.category = 'merchandise' then
        if product_row.stock_unit <> 'item' or p_quantity <> trunc(p_quantity) then
            raise exception 'Merchandise quantity must be a whole number of items';
        end if;
        unit_name := 'item';
        stock_deduction := p_quantity;
    elsif product_row.category = 'supplement' then
        case product_row.supplement_form
            when 'powder' then
                if product_row.unit <> 'gram' then raise exception 'Powder supplements must be priced by gram'; end if;
                unit_name := 'gram';
                stock_deduction := case product_row.stock_unit
                    when 'gram' then p_quantity
                    when 'kilogram' then p_quantity / 1000
                    when 'ounce' then p_quantity / 28.349523125
                    when 'pound' then p_quantity / 453.59237
                    else null
                end;
            when 'drinkable' then
                if product_row.unit <> 'milliliter' then raise exception 'Drinkable supplements must be priced by milliliter'; end if;
                unit_name := 'milliliter';
                stock_deduction := case product_row.stock_unit
                    when 'milliliter' then p_quantity
                    when 'liter' then p_quantity / 1000
                    when 'fluid_ounce' then p_quantity / 29.5735295625
                    else null
                end;
            when 'capsule', 'tablet', 'other' then
                if product_row.unit <> 'item' or product_row.stock_unit <> 'item' or p_quantity <> trunc(p_quantity) then
                    raise exception 'This supplement must be priced and stocked as whole items';
                end if;
                unit_name := 'item';
                stock_deduction := p_quantity;
            else
                raise exception 'Unsupported supplement form';
        end case;
        if stock_deduction is null then raise exception 'Unsupported supplement inventory unit'; end if;
    else
        raise exception 'Unsupported product category';
    end if;

    if product_row.stock < stock_deduction then raise exception 'Not enough stock available'; end if;
    sale_total := round(product_row.price_per_unit * p_quantity, 2);

    insert into public.sales (receipt_number, customer_type, customer_name, total, status, processed_by)
    values (btrim(p_receipt_number), 'walk_in', btrim(p_customer_name), sale_total, 'paid', (select auth.uid()))
    returning id into new_sale_id;

    insert into public.sale_items (sale_id, product_id, item_name, category, quantity, unit, unit_price, line_total)
    values (new_sale_id, product_row.id, product_row.name, product_row.category, p_quantity, unit_name, product_row.price_per_unit, sale_total);

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
        'unit', unit_name,
        'unit_price', product_row.price_per_unit,
        'line_total', sale_total,
        'stock', resulting_stock,
        'stock_unit', product_row.stock_unit
    );
end;
$$;

revoke all on function public.record_walk_in_sale(text, text, uuid, numeric) from public, anon;
grant execute on function public.record_walk_in_sale(text, text, uuid, numeric) to authenticated;
notify pgrst, 'reload schema';

commit;
