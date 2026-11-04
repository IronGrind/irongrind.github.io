-- Preserve the selected merchandise variant on the sale item and audit row.
begin;

create or replace function private.attach_merchandise_size_to_sale_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    merchandise_size text;
begin
    if new.category = 'merchandise' and new.product_id is not null then
        select nullif(btrim(size), '') into merchandise_size
        from public.products
        where id = new.product_id;

        if merchandise_size is not null
            and position(lower(merchandise_size) in lower(new.item_name)) = 0 then
            new.item_name := left(new.item_name, 150 - char_length(merchandise_size) - 3)
                || ' - ' || merchandise_size;
        end if;
    end if;
    return new;
end;
$$;
revoke all on function private.attach_merchandise_size_to_sale_item() from public, anon, authenticated;

drop trigger if exists attach_merchandise_size_to_sale_item on public.sale_items;
create trigger attach_merchandise_size_to_sale_item
    before insert on public.sale_items
    for each row execute function private.attach_merchandise_size_to_sale_item();

notify pgrst, 'reload schema';
commit;
