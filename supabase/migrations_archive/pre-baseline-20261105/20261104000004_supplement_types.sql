-- Add a type within the existing supplement category. Existing rows are
-- classified from their names when possible, otherwise left as Other.
begin;

alter table public.products
    add column if not exists supplement_type text;

update public.products
set supplement_type = case
    when lower(name) like '%protein%' then 'protein'
    when lower(name) like '%creatine%' then 'creatine'
    when lower(name) like '%pre-workout%' or lower(name) like '%pre workout%' or lower(name) like '%preworkout%' then 'pre_workout'
    when lower(name) like '%vitamin%' then 'vitamins'
    when lower(name) like '%amino%' or lower(name) like '%bcaa%' then 'amino_acids'
    else 'other'
end
where category = 'supplement' and supplement_type is null;

update public.products
set supplement_type = null
where category = 'merchandise' and supplement_type is not null;

alter table public.products drop constraint if exists products_supplement_type_check;
alter table public.products
    add constraint products_supplement_type_check
    check (
        (category = 'supplement' and supplement_type in ('protein', 'creatine', 'pre_workout', 'vitamins', 'amino_acids', 'other'))
        or (category = 'merchandise' and supplement_type is null)
    );

commit;
