-- Allow restocks in any compatible unit and convert into the product's stock unit.
begin;

drop function if exists public.restock_product(uuid, numeric);

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

    if product_row.stock_unit = 'item' then
        if p_quantity_unit is distinct from 'item' or p_quantity <> trunc(p_quantity) then
            raise exception 'Item stock must be added as a whole number of items';
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
        if quantity_factor is null or stock_factor is null then
            raise exception 'Unsupported restock unit';
        end if;

        -- Weight and volume units have separate dimensions and cannot mix.
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

revoke all on function public.restock_product(uuid, numeric, text) from public, anon;
grant execute on function public.restock_product(uuid, numeric, text) to authenticated;
notify pgrst, 'reload schema';

commit;
