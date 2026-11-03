-- Add stock to an existing product quantity without replacing its current stock.
begin;

create or replace function public.restock_product(
    p_product_id uuid,
    p_quantity numeric
)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
    resulting_stock numeric(14, 6);
    stock_unit_name text;
begin
    if not private.is_admin() then
        raise exception 'Admin access required';
    end if;
    if p_quantity is null or p_quantity <= 0 then
        raise exception 'Restock quantity must be greater than zero';
    end if;

    update public.products
    set stock = stock + p_quantity,
        updated_at = now()
    where id = p_product_id and is_active = true
    returning stock, stock_unit into resulting_stock, stock_unit_name;

    if not found then
        raise exception 'Product is unavailable';
    end if;
    if stock_unit_name = 'item' and p_quantity <> trunc(p_quantity) then
        raise exception 'Item stock must be a whole number';
    end if;

    return resulting_stock;
end;
$$;

revoke all on function public.restock_product(uuid, numeric) from public, anon;
grant execute on function public.restock_product(uuid, numeric) to authenticated;
notify pgrst, 'reload schema';

commit;
