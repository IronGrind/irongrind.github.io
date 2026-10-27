-- Consolidate legacy public.user_id references onto auth_user_id.
-- Run only after deploying app/Edge Function code that uses auth_user_id.
-- This migration preserves rows. It aborts if the two columns disagree or if
-- multiple member rows would violate the intended one-member-per-auth-user rule.

begin;

do $$
declare
    mismatch_count bigint;
begin
    select count(*) into mismatch_count
    from public.members
    where user_id is not null
      and auth_user_id is not null
      and user_id <> auth_user_id;

    if mismatch_count > 0 then
        raise exception 'Cannot remove public.members.user_id: % rows disagree with auth_user_id. Review and reconcile those rows first.', mismatch_count;
    end if;

    select count(*) into mismatch_count
    from public.membership_applications
    where user_id is not null
      and auth_user_id is not null
      and user_id <> auth_user_id;

    if mismatch_count > 0 then
        raise exception 'Cannot remove public.membership_applications.user_id: % rows disagree with auth_user_id. Review and reconcile those rows first.', mismatch_count;
    end if;
end;
$$;

update public.members
set auth_user_id = user_id
where auth_user_id is null and user_id is not null;

update public.membership_applications
set auth_user_id = user_id
where auth_user_id is null and user_id is not null;

do $$
declare
    duplicate_count bigint;
begin
    select count(*) into duplicate_count
    from (
        select auth_user_id
        from public.members
        where auth_user_id is not null
        group by auth_user_id
        having count(*) > 1
    ) duplicates;

    if duplicate_count > 0 then
        raise exception 'Cannot enforce one member per Auth user: % auth_user_id values occur in multiple member rows. Review those rows first.', duplicate_count;
    end if;
end;
$$;

-- Use a new index name because the existing *_unique_idx may be a non-unique
-- index; CREATE UNIQUE INDEX IF NOT EXISTS would otherwise leave it unchanged.
create unique index if not exists members_auth_user_id_uidx
    on public.members (auth_user_id);

-- The new unique index above replaces this older, non-unique compatibility index.
drop index if exists public.members_auth_user_id_unique_idx;

-- Replace the registration RPC so it no longer populates the legacy user_id field.
create or replace function public.admin_create_member_and_sale(
    p_admin_id uuid,
    p_member jsonb,
    p_receipt_number text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    member_data jsonb := p_member;
    member_row public.members%rowtype;
    sale_id uuid;
    paid_type text;
begin
    if not exists (select 1 from public.profiles where id = p_admin_id and role = 'admin') then
        raise exception 'Admin access required';
    end if;
    if jsonb_typeof(member_data) is distinct from 'object'
        or nullif(member_data ->> 'auth_user_id', '') is null then
        raise exception 'Member details and Auth user link are required';
    end if;
    if nullif(btrim(p_receipt_number), '') is null then
        raise exception 'Receipt number is required';
    end if;

    select data_type into paid_type
    from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    member_data := jsonb_set(member_data, '{id}', to_jsonb(gen_random_uuid()), true);
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        member_data := jsonb_set(member_data, '{paid}', member_data -> 'plan_price', true);
    else
        member_data := jsonb_set(member_data, '{paid}', 'true'::jsonb, true);
    end if;

    insert into public.members
    select (jsonb_populate_record(null::public.members, member_data)).*
    returning * into member_row;

    insert into public.sales (
        receipt_number, customer_type, customer_name, member_id, total, status,
        sold_at, processed_by
    ) values (
        btrim(p_receipt_number), 'member', member_row.full_name, member_row.id,
        coalesce(member_row.plan_price, 0), 'paid', now(), p_admin_id
    ) returning id into sale_id;

    insert into public.sale_items (
        sale_id, item_name, category, quantity, unit, unit_price, line_total
    ) values (
        sale_id, coalesce(member_row.plan, 'Membership') || ' Membership',
        'membership', 1, 'membership', coalesce(member_row.plan_price, 0),
        coalesce(member_row.plan_price, 0)
    );

    return jsonb_build_object('member_id', member_row.id, 'sale_id', sale_id,
        'receipt_number', btrim(p_receipt_number));
end;
$$;

revoke all on function public.admin_create_member_and_sale(uuid, jsonb, text)
    from public, anon, authenticated;
grant execute on function public.admin_create_member_and_sale(uuid, jsonb, text)
    to service_role;

-- Drop only the redundant legacy Auth reference columns. Their FKs and indexes
-- are removed with the columns. No CASCADE is used; unexpected dependencies abort.
alter table public.members drop column if exists user_id;
alter table public.membership_applications drop column if exists user_id;

commit;

notify pgrst, 'reload schema';
