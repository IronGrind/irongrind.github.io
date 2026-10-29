-- Apply explicit maximum lengths to bounded user-facing text fields.
-- Free-form notes, medical declarations, and storage paths remain TEXT.
-- This migration aborts before changing any columns if existing values exceed
-- the selected limits; it never truncates stored data.

begin;

do $$
declare
    field record;
    over_limit_count bigint;
    observed_max integer;
begin
    for field in
        select * from (values
            ('profiles', 'email', 254),
            ('profiles', 'username', 30),
            ('profiles', 'full_name', 150),
            ('profiles', 'role', 20),
            ('members', 'full_name', 150),
            ('members', 'email', 254),
            ('members', 'username', 30),
            ('members', 'mobile', 11),
            ('members', 'sex', 30),
            ('members', 'height_unit', 3),
            ('members', 'plan', 30),
            ('members', 'status', 20),
            ('members', 'registration_source', 40),
            ('membership_applications', 'application_type', 20),
            ('membership_applications', 'full_name', 150),
            ('membership_applications', 'email', 254),
            ('membership_applications', 'username', 30),
            ('membership_applications', 'mobile', 11),
            ('membership_applications', 'sex', 30),
            ('membership_applications', 'height_unit', 3),
            ('membership_applications', 'plan', 30),
            ('membership_applications', 'status', 20),
            ('products', 'name', 120),
            ('products', 'category', 20),
            ('products', 'unit', 12),
            ('products', 'size', 30),
            ('sales', 'receipt_number', 64),
            ('sales', 'customer_type', 15),
            ('sales', 'customer_name', 150),
            ('sales', 'status', 12),
            ('sale_items', 'item_name', 150),
            ('sale_items', 'category', 20),
            ('sale_items', 'unit', 12),
            ('membership_history', 'event_type', 30),
            ('membership_history', 'previous_plan', 30),
            ('membership_history', 'new_plan', 30)
        ) as limits(table_name, column_name, max_length)
    loop
        execute format(
            'select count(*), max(length(%I)) from public.%I where length(%I) > $1',
            field.column_name, field.table_name, field.column_name
        ) into over_limit_count, observed_max using field.max_length;

        if over_limit_count > 0 then
            raise exception 'Cannot set public.%.% to VARCHAR(%): % existing row(s) exceed the limit (maximum found: %). Review those values before retrying.',
                field.table_name, field.column_name, field.max_length,
                over_limit_count, observed_max;
        end if;
    end loop;
end;
$$;

alter table public.profiles
    alter column email type varchar(254),
    alter column username type varchar(30),
    alter column full_name type varchar(150),
    alter column role type varchar(20);

alter table public.members
    alter column full_name type varchar(150),
    alter column email type varchar(254),
    alter column username type varchar(30),
    alter column mobile type varchar(11),
    alter column sex type varchar(30),
    alter column height_unit type varchar(3),
    alter column plan type varchar(30),
    alter column status type varchar(20),
    alter column registration_source type varchar(40);

alter table public.membership_applications
    alter column application_type type varchar(20),
    alter column full_name type varchar(150),
    alter column email type varchar(254),
    alter column username type varchar(30),
    alter column mobile type varchar(11),
    alter column sex type varchar(30),
    alter column height_unit type varchar(3),
    alter column plan type varchar(30),
    alter column status type varchar(20);

alter table public.products
    alter column name type varchar(120),
    alter column category type varchar(20),
    alter column unit type varchar(12),
    alter column size type varchar(30);

alter table public.sales
    alter column receipt_number type varchar(64),
    alter column customer_type type varchar(15),
    alter column customer_name type varchar(150),
    alter column status type varchar(12);

alter table public.sale_items
    alter column item_name type varchar(150),
    alter column category type varchar(20),
    alter column unit type varchar(12);

alter table public.membership_history
    alter column event_type type varchar(30),
    alter column previous_plan type varchar(30),
    alter column new_plan type varchar(30);

commit;

notify pgrst, 'reload schema';
