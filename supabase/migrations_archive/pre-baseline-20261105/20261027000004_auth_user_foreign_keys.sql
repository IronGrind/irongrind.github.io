-- Add the Auth foreign keys that were not created when the legacy columns
-- already existed. Before applying this migration, the live data was checked
-- for orphan UUIDs; all six checks returned zero.
--
-- This migration only adds constraints. It does not delete or rewrite rows.

begin;

do $$
begin
    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.profiles'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.profiles'::regclass and attname = 'id')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.profiles
            add constraint profiles_id_auth_users_fkey
            foreign key (id) references auth.users (id) on delete cascade;
    end if;

    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.members'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.members'::regclass and attname = 'auth_user_id')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.members
            add constraint members_auth_user_id_auth_users_fkey
            foreign key (auth_user_id) references auth.users (id) on delete set null;
    end if;

    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.membership_applications'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.membership_applications'::regclass and attname = 'auth_user_id')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.membership_applications
            add constraint membership_applications_auth_user_id_auth_users_fkey
            foreign key (auth_user_id) references auth.users (id) on delete cascade;
    end if;

    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.attendance'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.attendance'::regclass and attname = 'recorded_by')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.attendance
            add constraint attendance_recorded_by_auth_users_fkey
            foreign key (recorded_by) references auth.users (id) on delete set null;
    end if;

    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.sales'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.sales'::regclass and attname = 'processed_by')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.sales
            add constraint sales_processed_by_auth_users_fkey
            foreign key (processed_by) references auth.users (id) on delete set null;
    end if;

    if not exists (
        select 1 from pg_catalog.pg_constraint c
        where c.conrelid = 'public.membership_history'::regclass
          and c.confrelid = 'auth.users'::regclass
          and c.contype = 'f'
          and c.conkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'public.membership_history'::regclass and attname = 'recorded_by')]::smallint[]
          and c.confkey = array[(select attnum from pg_catalog.pg_attribute where attrelid = 'auth.users'::regclass and attname = 'id')]::smallint[]
    ) then
        alter table public.membership_history
            add constraint membership_history_recorded_by_auth_users_fkey
            foreign key (recorded_by) references auth.users (id) on delete set null;
    end if;
end;
$$;

commit;

notify pgrst, 'reload schema';
