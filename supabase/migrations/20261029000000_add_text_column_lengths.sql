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

-- Policies can depend on columns whose types are changing. Save policies on
-- the affected tables, remove them for the type changes, and restore them
-- exactly within this transaction. If a later statement fails, rollback
-- restores the original policies along with the original column types.
create temporary table _text_length_policy_backup (
    policy_sql text not null
) on commit drop;
alter table _text_length_policy_backup enable row level security;

insert into _text_length_policy_backup (policy_sql)
select format(
    'create policy %I on %I.%I as %s for %s to %s%s%s',
    p.polname,
    n.nspname,
    t.relname,
    case when p.polpermissive then 'permissive' else 'restrictive' end,
    case p.polcmd
        when 'r' then 'select'
        when 'a' then 'insert'
        when 'w' then 'update'
        when 'd' then 'delete'
        else 'all'
    end,
    roles.role_list,
    case when p.polqual is not null
        then format(' using (%s)', pg_catalog.pg_get_expr(p.polqual, p.polrelid))
        else ''
    end,
    case when p.polwithcheck is not null
        then format(' with check (%s)', pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid))
        else ''
    end
)
from pg_catalog.pg_policy p
join pg_catalog.pg_class t on t.oid = p.polrelid
join pg_catalog.pg_namespace n on n.oid = t.relnamespace
cross join lateral (
    select string_agg(
        case when role_id = 0 then 'public' else pg_catalog.quote_ident(r.rolname) end,
        ', ' order by role_id
    ) as role_list
    from unnest(p.polroles) as policy_role(role_id)
    left join pg_catalog.pg_roles r on r.oid = role_id
) roles
where n.nspname = 'public'
  and t.relname in (
      'profiles', 'members', 'membership_applications', 'products',
      'sales', 'sale_items', 'membership_history'
  );

do $$
declare
    policy record;
begin
    for policy in
        select n.nspname as schema_name, t.relname as table_name, p.polname as policy_name
        from pg_catalog.pg_policy p
        join pg_catalog.pg_class t on t.oid = p.polrelid
        join pg_catalog.pg_namespace n on n.oid = t.relnamespace
        where n.nspname = 'public'
          and t.relname in (
              'profiles', 'members', 'membership_applications', 'products',
              'sales', 'sale_items', 'membership_history'
          )
    loop
        execute format(
            'drop policy %I on %I.%I',
            policy.policy_name, policy.schema_name, policy.table_name
        );
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

do $$
declare
    policy record;
begin
    for policy in select policy_sql from _text_length_policy_backup
    loop
        execute policy.policy_sql;
    end loop;
end;
$$;

commit;

notify pgrst, 'reload schema';
