-- Add human-readable descriptions for sales and their line items.
begin;

alter table public.activity_logs
    add column if not exists details text not null default '';

create or replace function private.describe_sale_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    sale_reference text;
    customer_name text;
    quantity_label text;
    description text;
    sale_action text;
begin
    select s.receipt_number, s.customer_name
    into sale_reference, customer_name
    from public.sales s
    where s.id = new.sale_id;

    quantity_label := case new.unit
        when 'gram' then trim(trailing '.' from trim(trailing '0' from to_char(new.quantity, 'FM999999999990.000000'))) || ' g'
        when 'item' then trim(trailing '.' from trim(trailing '0' from to_char(new.quantity, 'FM999999999990.000000'))) || case when new.quantity = 1 then ' item' else ' items' end
        else trim(trailing '.' from trim(trailing '0' from to_char(new.quantity, 'FM999999999990.000000'))) || ' ' || new.unit
    end;

    if new.category = 'membership' then
        description := 'Recorded payment for ' || new.item_name || ' for ' || coalesce(nullif(customer_name, ''), 'customer')
            || ' (PHP ' || to_char(new.line_total, 'FM999999999990.00') || ')';
        sale_action := 'payment_recorded';
    else
        description := 'Sold ' || quantity_label || ' of ' || new.item_name || ' to ' || coalesce(nullif(customer_name, ''), 'customer');
        sale_action := 'sold';
    end if;

    update public.activity_logs
    set action = sale_action,
        details = case when details = '' then description else details || '; ' || description end
    where entity_type = 'sales' and entity_id = new.sale_id::text;

    update public.activity_logs
    set action = sale_action,
        record_label = coalesce(nullif(sale_reference, ''), record_label),
        details = description
    where entity_type = 'sale_items' and entity_id = new.id::text;

    return new;
end;
$$;
revoke all on function private.describe_sale_activity() from public, anon, authenticated;

drop trigger if exists sale_item_activity_description on public.sale_items;
create trigger sale_item_activity_description
after insert on public.sale_items
for each row execute function private.describe_sale_activity();

-- Fill descriptions into sale activity entries that already exist. This does
-- not create new log rows or reconstruct actions from before logging began.
update public.activity_logs log
set action = case when item.category = 'membership' then 'payment_recorded' else 'sold' end,
    record_label = coalesce(nullif(sale.receipt_number, ''), log.record_label),
    details = case when item.category = 'membership' then
        'Recorded payment for ' || item.item_name || ' for ' || coalesce(nullif(sale.customer_name, ''), 'customer')
            || ' (PHP ' || to_char(item.line_total, 'FM999999999990.00') || ')'
    else
        'Sold ' || case item.unit
            when 'gram' then trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || ' g'
            when 'item' then trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || case when item.quantity = 1 then ' item' else ' items' end
            else trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || ' ' || item.unit
        end || ' of ' || item.item_name || ' to ' || coalesce(nullif(sale.customer_name, ''), 'customer')
    end
from public.sale_items item
join public.sales sale on sale.id = item.sale_id
where log.entity_type = 'sale_items' and log.entity_id = item.id::text;

with descriptions as (
    select item.sale_id,
        bool_and(item.category = 'membership') as membership_only,
        string_agg(
            case when item.category = 'membership' then
                'Recorded payment for ' || item.item_name || ' for ' || coalesce(nullif(sale.customer_name, ''), 'customer')
                    || ' (PHP ' || to_char(item.line_total, 'FM999999999990.00') || ')'
            else
                'Sold ' || case item.unit
                    when 'gram' then trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || ' g'
                    when 'item' then trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || case when item.quantity = 1 then ' item' else ' items' end
                    else trim(trailing '.' from trim(trailing '0' from to_char(item.quantity, 'FM999999999990.000000'))) || ' ' || item.unit
                end || ' of ' || item.item_name || ' to ' || coalesce(nullif(sale.customer_name, ''), 'customer')
            end,
            '; ' order by item.id
        ) as details
    from public.sale_items item
    join public.sales sale on sale.id = item.sale_id
    group by item.sale_id
)
update public.activity_logs log
set action = case when descriptions.membership_only then 'payment_recorded' else 'sold' end,
    details = descriptions.details
from descriptions
where log.entity_type = 'sales' and log.entity_id = descriptions.sale_id::text;

commit;
