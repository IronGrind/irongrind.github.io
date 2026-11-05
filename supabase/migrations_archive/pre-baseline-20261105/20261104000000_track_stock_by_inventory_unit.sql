-- Track supplement stock in its selected inventory unit (for example kg),
-- while the POS continues to record supplement sales in grams.
alter table public.products
    alter column stock type numeric(14, 6) using stock::numeric(14, 6),
    add column if not exists stock_unit text not null default 'item';

update public.products
set stock_unit = case when category = 'supplement' then 'gram' else 'item' end;

-- Older supplements had no tracked quantity. Treat that unknown amount as
-- zero so they cannot be sold until staff enter the actual stock on hand.
update public.products
set stock = 0
where category = 'supplement' and stock is null;

alter table public.products alter column stock set not null;
alter table public.products alter column stock set default 0;
alter table public.products drop constraint if exists products_stock_unit_check;
alter table public.products
    add constraint products_stock_unit_check
    check (
        (category = 'supplement' and stock_unit in ('gram', 'kilogram', 'ounce', 'pound'))
        or (category = 'merchandise' and stock_unit = 'item')
    );

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
    if not private.is_admin() then
        raise exception 'Admin access required';
    end if;
    if nullif(btrim(p_customer_name), '') is null then
        raise exception 'Customer name is required';
    end if;
    if nullif(btrim(p_receipt_number), '') is null then
        raise exception 'Transaction reference is required';
    end if;
    if p_quantity is null or p_quantity <= 0 then
        raise exception 'Quantity must be greater than zero';
    end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;

    if not found then
        raise exception 'Product is unavailable';
    end if;
    if product_row.category = 'merchandise' then
        if product_row.stock_unit <> 'item' or p_quantity <> trunc(p_quantity) then
            raise exception 'Merchandise quantity must be a whole number of items';
        end if;
        unit_name := 'item';
        stock_deduction := p_quantity;
    elsif product_row.category = 'supplement' then
        unit_name := 'gram';
        stock_deduction := case product_row.stock_unit
            when 'gram' then p_quantity
            when 'kilogram' then p_quantity / 1000
            when 'ounce' then p_quantity / 28.349523125
            when 'pound' then p_quantity / 453.59237
            else null
        end;
        if stock_deduction is null then
            raise exception 'Unsupported supplement inventory unit';
        end if;
    else
        raise exception 'Unsupported product category';
    end if;

    if product_row.stock < stock_deduction then
        raise exception 'Not enough stock available';
    end if;

    sale_total := round(product_row.price_per_unit * p_quantity, 2);
    insert into public.sales (
        receipt_number, customer_type, customer_name, total, status, processed_by
    ) values (
        btrim(p_receipt_number), 'walk_in', btrim(p_customer_name), sale_total,
        'paid', (select auth.uid())
    ) returning id into new_sale_id;

    insert into public.sale_items (
        sale_id, product_id, item_name, category, quantity, unit, unit_price, line_total
    ) values (
        new_sale_id, product_row.id, product_row.name, product_row.category,
        p_quantity, unit_name, product_row.price_per_unit, sale_total
    );

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
