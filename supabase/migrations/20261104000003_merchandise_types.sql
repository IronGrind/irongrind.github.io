-- Categorize merchandise separately from supplements. Existing items with a
-- size are treated as apparel; other merchandise starts as Other.
begin;

alter table public.products
    add column if not exists merch_type text;

update public.products
set merch_type = case
    when category = 'merchandise' and nullif(btrim(size), '') is not null then 'apparel'
    when category = 'merchandise' then 'other'
    else null
end
where merch_type is null;

alter table public.products drop constraint if exists products_merch_type_check;
alter table public.products
    add constraint products_merch_type_check
    check (
        (category = 'merchandise' and merch_type in ('apparel', 'accessories', 'drinkware', 'gym_gear', 'other'))
        or (category = 'supplement' and merch_type is null)
    );

commit;
