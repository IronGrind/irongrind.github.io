-- Apply after the existing membership and sales migrations.
-- Logs begin when this migration is applied; old actions are not reconstructed.
-- Discard any SET ROLE left by SQL Editor permission tests. This restores only
-- the connected session user's own privileges; run setup as the project owner.
reset role;
begin;

create schema if not exists private;
create table if not exists public.activity_logs (
    id bigint generated always as identity primary key,
    occurred_at timestamptz not null default clock_timestamp(),
    actor_id uuid,
    actor_name text not null,
    actor_role text not null,
    action text not null,
    entity_type text not null,
    entity_id text,
    record_label text not null default '',
    changed_fields text[] not null default '{}'
);
create index if not exists activity_logs_time_idx on public.activity_logs (occurred_at desc, id desc);
create index if not exists activity_logs_actor_idx on public.activity_logs (actor_id, occurred_at desc);
alter table public.activity_logs enable row level security;
revoke all on public.activity_logs from public, anon, authenticated;
grant select on public.activity_logs to authenticated;
drop policy if exists activity_logs_admin_read on public.activity_logs;
create policy activity_logs_admin_read on public.activity_logs
    for select to authenticated using ((select private.is_admin()));

-- Only database triggers and the restricted session-event function write logs.
create or replace function private.capture_activity()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
    before_data jsonb := '{}'::jsonb;
    after_data jsonb := '{}'::jsonb;
    record_data jsonb;
    actor uuid := auth.uid();
    actor_display text;
    actor_kind text;
    changed text[];
    label text;
    event_name text;
begin
    if tg_op <> 'INSERT' then before_data := to_jsonb(old); end if;
    if tg_op <> 'DELETE' then after_data := to_jsonb(new); end if;
    record_data := case when tg_op = 'DELETE' then before_data else after_data end;
    select coalesce(array_agg(k order by k), '{}'::text[]) into changed
    from jsonb_object_keys(before_data || after_data) as fields(k)
    where (before_data -> k) is distinct from (after_data -> k)
      and k not in ('updated_at', 'created_at');
    if tg_op = 'UPDATE' and cardinality(changed) = 0 then return new; end if;

    -- This context is set only inside the service-only member creation RPC.
    if actor is null and auth.role() = 'service_role' then
        actor := nullif(current_setting('irongrind.activity_actor', true), '')::uuid;
        if actor is null and tg_op = 'INSERT' then
            actor := nullif(coalesce(record_data ->> 'processed_by', record_data ->> 'recorded_by', record_data ->> 'reviewed_by'), '')::uuid;
        end if;
    end if;
    select coalesce(nullif(p.full_name, ''), p.username, p.email, p.id::text), p.role
    into actor_display, actor_kind from public.profiles p where p.id = actor;
    actor_display := coalesce(actor_display, case when actor is null then 'System / service' else actor::text end);
    actor_kind := coalesce(actor_kind, case when actor is null then 'system' else 'account' end);
    label := coalesce(record_data ->> 'receipt_number', record_data ->> 'full_name', record_data ->> 'name', record_data ->> 'item_name', '');
    if label = '' and record_data ->> 'member_id' is not null then
        select m.full_name into label from public.members m where m.id::text = record_data ->> 'member_id';
    end if;
    event_name := lower(tg_op);
    if tg_table_name = 'membership_applications' and tg_op = 'UPDATE' and 'status' = any(changed) then
        event_name := case record_data ->> 'status' when 'approved' then 'approved' when 'rejected' then 'rejected' else 'update' end;
    elsif tg_table_name = 'attendance' then
        if tg_op = 'INSERT' then event_name := 'check_in';
        elsif tg_op = 'UPDATE' and 'time_out' = any(changed) and record_data ->> 'time_out' is not null then event_name := 'check_out'; end if;
    elsif tg_table_name = 'products' and tg_op = 'UPDATE' and 'is_active' = any(changed) then
        event_name := case when (record_data ->> 'is_active')::boolean then 'restored' else 'archived' end;
    elsif tg_table_name = 'membership_history' and tg_op = 'INSERT' then
        event_name := coalesce(record_data ->> 'event_type', 'insert');
    end if;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, changed_fields)
    values (actor, actor_display, actor_kind, event_name, tg_table_name, record_data ->> 'id', coalesce(label, ''), changed);
    if tg_op = 'DELETE' then return old; end if;
    return new;
end;
$$;
revoke all on function private.capture_activity() from public, anon, authenticated;

do $$
declare table_name text;
begin
    foreach table_name in array array['profiles', 'members', 'membership_applications', 'attendance', 'products', 'sales', 'sale_items', 'membership_history'] loop
        execute format('drop trigger if exists capture_activity on public.%I', table_name);
        execute format('create trigger capture_activity after insert or update or delete on public.%I for each row execute function private.capture_activity()', table_name);
    end loop;
end;
$$;

-- These are application session events, not a replacement for Supabase Auth logs.
create or replace function public.admin_log_session_event(p_event text)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_display text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    if p_event not in ('signed_in', 'sign_out_requested') then raise exception 'Unsupported session event'; end if;
    select coalesce(nullif(full_name, ''), username, email, id::text) into actor_display
    from public.profiles where id = auth.uid();
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id)
    values (auth.uid(), actor_display, 'admin', p_event, 'session', auth.uid()::text);
end;
$$;
revoke all on function public.admin_log_session_event(text) from public, anon;
grant execute on function public.admin_log_session_event(text) to authenticated;

-- Preserve the existing service-only registration behavior and attach its
-- verified administrator to all writes in the same transaction.
create or replace function public.admin_create_member_and_sale(p_admin_id uuid, p_member jsonb, p_receipt_number text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    member_data jsonb := p_member;
    member_row public.members%rowtype;
    sale_id uuid;
    paid_type text;
begin
    if not exists (select 1 from public.profiles where id = p_admin_id and role = 'admin') then raise exception 'Admin access required'; end if;
    if jsonb_typeof(member_data) is distinct from 'object' or nullif(member_data ->> 'auth_user_id', '') is null then raise exception 'Member details and Auth user link are required'; end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Receipt number is required'; end if;
    perform set_config('irongrind.activity_actor', p_admin_id::text, true);
    select data_type into paid_type from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    member_data := jsonb_set(member_data, '{id}', to_jsonb(gen_random_uuid()), true);
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        member_data := jsonb_set(member_data, '{paid}', member_data -> 'plan_price', true);
    else member_data := jsonb_set(member_data, '{paid}', 'true'::jsonb, true); end if;
    insert into public.members select (jsonb_populate_record(null::public.members, member_data)).* returning * into member_row;
    insert into public.sales (receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by)
    values (btrim(p_receipt_number), 'member', member_row.full_name, member_row.id, coalesce(member_row.plan_price, 0), 'paid', now(), p_admin_id)
    returning id into sale_id;
    insert into public.sale_items (sale_id, item_name, category, quantity, unit, unit_price, line_total)
    values (sale_id, coalesce(member_row.plan, 'Membership') || ' Membership', 'membership', 1, 'membership', coalesce(member_row.plan_price, 0), coalesce(member_row.plan_price, 0));
    return jsonb_build_object('member_id', member_row.id, 'sale_id', sale_id, 'receipt_number', btrim(p_receipt_number));
end;
$$;
revoke all on function public.admin_create_member_and_sale(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.admin_create_member_and_sale(uuid, jsonb, text) to service_role;
commit;
notify pgrst, 'reload schema';
