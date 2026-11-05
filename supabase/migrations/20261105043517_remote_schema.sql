


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "private";


ALTER SCHEMA "private" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "private"."capture_activity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."capture_activity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."describe_sale_activity"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "private"."describe_sale_activity"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1
        from public.profiles
        where id = (select auth.uid())
          and role = 'admin'
    );
$$;


ALTER FUNCTION "private"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."is_staff"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select exists (
        select 1 from public.profiles
        where id = (select auth.uid()) and role = 'staff' and is_active
    );
$$;


ALTER FUNCTION "private"."is_staff"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."require_attendance_removal_pin"("p_pin" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare stored_hash text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    if p_pin is null or p_pin !~ '^[0-9]{4}$' then raise exception 'Enter the four-digit pairing removal PIN'; end if;
    select pairing_removal_pin_hash into stored_hash
    from public.mobile_attendance_pairing_policy where singleton;
    if stored_hash is null then raise exception 'Set the four-digit removal PIN in the database first'; end if;
    if extensions.crypt(p_pin, stored_hash) <> stored_hash then raise exception 'Incorrect four-digit pairing removal PIN'; end if;
end;
$_$;


ALTER FUNCTION "private"."require_attendance_removal_pin"("p_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."require_pairing_password"("p_password" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare stored_hash text;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select pairing_password_hash into stored_hash
    from public.mobile_attendance_pairing_policy where singleton;
    if stored_hash is null then raise exception 'Set the admin phone pairing password first'; end if;
    if p_password is null or octet_length(p_password) > 72 or extensions.crypt(p_password, stored_hash) <> stored_hash then
        raise exception 'Incorrect phone pairing password';
    end if;
end;
$$;


ALTER FUNCTION "private"."require_pairing_password"("p_password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "private"."require_recent_admin_auth"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    authenticated_at bigint;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;
    authenticated_at := nullif((select auth.jwt())->>'auth_time', '')::bigint;
    if authenticated_at is null or extract(epoch from now())::bigint - authenticated_at > 300 then
        raise exception 'Re-enter the admin password to authorize this action';
    end if;
end;
$$;


ALTER FUNCTION "private"."require_recent_admin_auth"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_capture_expired_memberships"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    inserted_count integer;
    business_date date := (now() at time zone 'Asia/Manila')::date;
begin
    if not (select private.is_admin()) then
        raise exception 'Admin access required';
    end if;

    update public.members m
    set status = 'expired', updated_at = now()
    where m.status = 'inactive'
      and coalesce(m.expiry_date, m.end_date) < business_date
      and exists (
          select 1 from public.membership_applications a
          where a.member_id = m.id
            and a.application_type = 'renewal'
            and a.status = 'pending'
      );

    insert into public.membership_history (
        member_id, event_type, previous_plan, previous_price,
        previous_start_date, previous_expiry_date, notes
    )
    select m.id, 'expired', m.plan, coalesce(m.plan_price, 0), m.start_date,
        coalesce(m.expiry_date, m.end_date), 'Marked inactive and archived after five-day expiry period without a pending renewal'
    from public.members m
    where coalesce(m.expiry_date, m.end_date) <= business_date - 5
      and not exists (
          select 1 from public.membership_applications a
          where a.member_id = m.id
            and a.application_type = 'renewal'
            and a.status = 'pending'
      )
      and not exists (
          select 1 from public.membership_history h
          where h.member_id = m.id
            and h.event_type = 'expired'
            and h.previous_expiry_date = coalesce(m.expiry_date, m.end_date)
            and h.previous_plan is not distinct from m.plan
      );

    get diagnostics inserted_count = row_count;

    update public.members m
    set status = 'inactive', updated_at = now()
    where m.status in ('active', 'expired')
      and coalesce(m.expiry_date, m.end_date) <= business_date - 5
      and not exists (
          select 1 from public.membership_applications a
          where a.member_id = m.id
            and a.application_type = 'renewal'
            and a.status = 'pending'
      );

    return inserted_count;
end;
$$;


ALTER FUNCTION "public"."admin_capture_expired_memberships"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_create_member_and_sale"("p_admin_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    member_data jsonb := p_member;
    member_row public.members%rowtype;
    sale_id uuid;
    paid_type text;
    caller_role text;
    caller_active boolean;
begin
    if jsonb_typeof(member_data) is distinct from 'object'
        or nullif(member_data ->> 'auth_user_id', '') is null then
        raise exception 'Member details and Auth user link are required';
    end if;
    select role, is_active into caller_role, caller_active from public.profiles where id = p_admin_id;
    if caller_role not in ('admin', 'staff') or caller_active is distinct from true then
        raise exception 'Active admin or staff access required';
    end if;
    if caller_role = 'staff' and not (
        (member_data ->> 'plan' = 'Monthly' and member_data ->> 'plan_price' = '800')
        or (member_data ->> 'plan' = 'Half Month' and member_data ->> 'plan_price' = '400')
        or (member_data ->> 'plan' = 'Walk-in' and member_data ->> 'plan_price' = '80')
    ) then
        raise exception 'Staff may register only the standard membership plans';
    end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Receipt number is required'; end if;

    select data_type into paid_type from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    member_data := jsonb_set(member_data, '{id}', to_jsonb(gen_random_uuid()), true);
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        member_data := jsonb_set(member_data, '{paid}', member_data -> 'plan_price', true);
    else
        member_data := jsonb_set(member_data, '{paid}', 'true'::jsonb, true);
    end if;
    insert into public.members select (jsonb_populate_record(null::public.members, member_data)).* returning * into member_row;

    insert into public.sales (receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by)
    values (btrim(p_receipt_number), 'member', member_row.full_name, member_row.id,
        coalesce(member_row.plan_price, 0), 'paid', now(), p_admin_id) returning id into sale_id;
    insert into public.sale_items (sale_id, item_name, category, quantity, unit, unit_price, line_total)
    values (sale_id, coalesce(member_row.plan, 'Membership') || ' Membership', 'membership', 1,
        'membership', coalesce(member_row.plan_price, 0), coalesce(member_row.plan_price, 0));
    return jsonb_build_object('member_id', member_row.id, 'sale_id', sale_id, 'receipt_number', btrim(p_receipt_number));
end;
$$;


ALTER FUNCTION "public"."admin_create_member_and_sale"("p_admin_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_log_session_event"("p_event" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    actor_display text;
    actor_role text;
begin
    if p_event not in ('signed_in', 'sign_out_requested') then
        raise exception 'Unsupported session event';
    end if;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles
    where id = (select auth.uid())
      and role in ('admin', 'staff')
      and is_active;
    if not found then raise exception 'Active staff or admin sign-in required'; end if;

    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id)
    values ((select auth.uid()), actor_display, actor_role, p_event, 'session', (select auth.uid())::text);
end;
$$;


ALTER FUNCTION "public"."admin_log_session_event"("p_event" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_record_membership_change"("p_member_id" "uuid", "p_event_type" "text", "p_new_plan" "text", "p_new_price" numeric, "p_new_start_date" "date", "p_new_expiry_date" "date", "p_customer_name" "text", "p_mobile" "text", "p_receipt_number" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
    member_row public.members%rowtype;
    new_sale_id uuid;
    item_label text;
    paid_type text;
    operator_role text;
    business_date date := (now() at time zone 'Asia/Manila')::date;
begin
    select role into operator_role
    from public.profiles
    where id = (select auth.uid()) and is_active;
    if operator_role is distinct from 'admin' and operator_role is distinct from 'staff' then
        raise exception 'Active staff or admin access required';
    end if;
    if p_event_type is null or p_event_type not in ('renewal', 'plan_change') then raise exception 'Unsupported membership event'; end if;
    if p_new_price is null or p_new_price <= 0 then raise exception 'Membership price must be greater than zero'; end if;
    if nullif(btrim(p_new_plan), '') is null or nullif(btrim(p_customer_name), '') is null
       or nullif(btrim(p_receipt_number), '') is null then
        raise exception 'Plan, customer name, and receipt number are required';
    end if;
    if p_new_start_date is null or p_new_expiry_date is null or p_new_expiry_date < p_new_start_date then
        raise exception 'Valid membership start and expiry dates are required';
    end if;

    if operator_role = 'staff' then
        if not (
            (p_new_plan = 'Monthly' and p_new_price = 800)
            or (p_new_plan = 'Half Month' and p_new_price = 400)
            or (p_new_plan = 'Walk-in' and p_new_price = 80)
        ) then raise exception 'Staff may use only standard membership plans and prices'; end if;
        if p_new_start_date <> business_date then raise exception 'Membership changes must start today'; end if;
        if p_new_expiry_date <> p_new_start_date + (case p_new_plan when 'Monthly' then 30 when 'Half Month' then 15 else 1 end) then
            raise exception 'Membership expiry does not match the selected plan';
        end if;
    end if;

    select * into member_row from public.members where id = p_member_id for update;
    if not found then raise exception 'Member not found'; end if;
    if operator_role = 'staff' and (
        btrim(p_customer_name) is distinct from member_row.full_name
        or nullif(btrim(p_mobile), '') is distinct from member_row.mobile
    ) then
        raise exception 'Staff membership transactions must use the member name and mobile on file';
    end if;
    if p_event_type = 'plan_change' and member_row.plan is not distinct from p_new_plan
       and member_row.plan_price = p_new_price then
        raise exception 'The member already has this plan and price';
    end if;

    select id into new_sale_id from public.sales where receipt_number = btrim(p_receipt_number);
    if found then
        return jsonb_build_object('receipt_number', btrim(p_receipt_number), 'sale_id', new_sale_id,
            'start_date', p_new_start_date, 'expiry_date', p_new_expiry_date);
    end if;

    if coalesce(member_row.expiry_date, member_row.end_date) < business_date
       and not exists (
           select 1 from public.membership_history h
           where h.member_id = member_row.id and h.event_type = 'expired'
             and h.previous_expiry_date = coalesce(member_row.expiry_date, member_row.end_date)
             and h.previous_plan is not distinct from member_row.plan
       ) then
        insert into public.membership_history (
            member_id, event_type, previous_plan, previous_price,
            previous_start_date, previous_expiry_date, notes, recorded_by
        ) values (
            member_row.id, 'expired', member_row.plan, coalesce(member_row.plan_price, 0),
            member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
            'Archived when renewed; receipt ' || btrim(p_receipt_number), (select auth.uid())
        );
    end if;

    insert into public.membership_history (
        member_id, event_type, previous_plan, new_plan, previous_price, new_price,
        previous_start_date, previous_expiry_date, new_start_date, new_expiry_date, notes, recorded_by
    ) values (
        member_row.id, p_event_type, member_row.plan, p_new_plan,
        coalesce(member_row.plan_price, 0), p_new_price,
        member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
        p_new_start_date, p_new_expiry_date, 'Receipt ' || btrim(p_receipt_number), (select auth.uid())
    );

    if p_event_type = 'renewal' and member_row.plan is distinct from p_new_plan then
        insert into public.membership_history (
            member_id, event_type, previous_plan, new_plan, previous_price, new_price,
            previous_start_date, previous_expiry_date, new_start_date, new_expiry_date, notes, recorded_by
        ) values (
            member_row.id, 'plan_change', member_row.plan, p_new_plan,
            coalesce(member_row.plan_price, 0), p_new_price,
            member_row.start_date, coalesce(member_row.expiry_date, member_row.end_date),
            p_new_start_date, p_new_expiry_date,
            'Plan changed during counter renewal; receipt ' || btrim(p_receipt_number), (select auth.uid())
        );
    end if;

    update public.members set plan = p_new_plan, plan_price = p_new_price,
        start_date = p_new_start_date, end_date = p_new_expiry_date,
        expiry_date = p_new_expiry_date, status = 'active',
        mobile = coalesce(nullif(btrim(p_mobile), ''), mobile), updated_at = now()
    where id = member_row.id;

    select data_type into paid_type from information_schema.columns
    where table_schema = 'public' and table_name = 'members' and column_name = 'paid';
    if paid_type in ('numeric', 'integer', 'bigint', 'real', 'double precision') then
        execute 'update public.members set paid = $1 where id = $2' using p_new_price, member_row.id;
    elsif paid_type = 'boolean' then
        execute 'update public.members set paid = $1 where id = $2' using true, member_row.id;
    end if;

    item_label := p_new_plan || case when p_event_type = 'renewal'
        then ' Membership Renewal' else ' Membership Plan Change' end;
    insert into public.sales (
        receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by
    ) values (
        btrim(p_receipt_number), 'member', btrim(p_customer_name), member_row.id,
        p_new_price, 'paid', now(), (select auth.uid())
    ) returning id into new_sale_id;
    insert into public.sale_items (sale_id, item_name, category, quantity, unit, unit_price, line_total)
    values (new_sale_id, item_label, 'membership', 1, 'membership', p_new_price, p_new_price);
    return jsonb_build_object('receipt_number', btrim(p_receipt_number), 'sale_id', new_sale_id,
        'start_date', p_new_start_date, 'expiry_date', p_new_expiry_date);
end;
$_$;


ALTER FUNCTION "public"."admin_record_membership_change"("p_member_id" "uuid", "p_event_type" "text", "p_new_plan" "text", "p_new_price" numeric, "p_new_start_date" "date", "p_new_expiry_date" "date", "p_customer_name" "text", "p_mobile" "text", "p_receipt_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admin_record_registration_sale"("p_member_id" "uuid", "p_receipt_number" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    member_row public.members%rowtype;
    sale_id uuid;
begin
    if not (select private.is_admin()) then
        raise exception 'Admin access required';
    end if;
    select * into member_row from public.members where id = p_member_id for update;
    if not found then
        raise exception 'Member not found';
    end if;
    select id into sale_id from public.sales where receipt_number = btrim(p_receipt_number);
    if found then return sale_id; end if;

    insert into public.sales (
        receipt_number, customer_type, customer_name, member_id, total, status, sold_at, processed_by
    ) values (
        btrim(p_receipt_number), 'member', member_row.full_name, member_row.id,
        coalesce(member_row.plan_price, 0), 'paid', now(), (select auth.uid())
    ) returning id into sale_id;

    insert into public.sale_items (
        sale_id, item_name, category, quantity, unit, unit_price, line_total
    ) values (
        sale_id, coalesce(member_row.plan, 'Membership') || ' Membership Registration',
        'membership', 1, 'membership', coalesce(member_row.plan_price, 0),
        coalesce(member_row.plan_price, 0)
    );
    return sale_id;
end;
$$;


ALTER FUNCTION "public"."admin_record_registration_sale"("p_member_id" "uuid", "p_receipt_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."close_mobile_attendance_scan_session"("p_session_id" "uuid", "p_pairing_pin" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    actor_id uuid := auth.uid(); actor_display text; actor_role text;
begin
    perform private.require_attendance_removal_pin(p_pairing_pin);
    select * into session_row from public.mobile_attendance_scan_sessions
    where id = p_session_id for update;
    if not found then return; end if;
    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role from public.profiles where id = actor_id;
    insert into public.activity_logs (actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details)
    values (actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        case when session_row.paired_at is null then 'phone_pairing_ended' else 'phone_unpaired' end,
        'mobile_attendance_scan_sessions', session_row.id::text,
        coalesce(nullif(session_row.paired_device, ''), 'Pending phone pairing'),
        case when session_row.paired_at is null then 'Ended a pending attendance phone pairing QR.'
             else 'Ended the attendance phone pairing for ' || session_row.paired_device || '.' end);
    delete from public.mobile_attendance_scan_sessions where id = p_session_id;
end;
$$;


ALTER FUNCTION "public"."close_mobile_attendance_scan_session"("p_session_id" "uuid", "p_pairing_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."consume_admin_login_attempt"("p_bucket" "text", "p_limit" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare attempt_count integer;
begin
    if p_bucket is null or p_bucket !~ '^(user|ip):[0-9a-f]{64}$'
        or p_limit is null or p_limit not in (10, 50) then raise exception 'Invalid login bucket'; end if;
    -- Only hashes are stored. Opportunistic cleanup bounds old bucket retention.
    delete from private.admin_login_attempts where window_start < now() - interval '1 day';
    insert into private.admin_login_attempts as a (bucket, window_start, attempts)
    values (p_bucket, now(), 1)
    on conflict (bucket) do update set
        attempts = case when a.window_start <= now() - interval '5 minutes' then 1 else least(a.attempts + 1, 1000) end,
        window_start = case when a.window_start <= now() - interval '5 minutes' then now() else a.window_start end
    returning attempts into attempt_count;
    return attempt_count <= p_limit;
end;
$_$;


ALTER FUNCTION "public"."consume_admin_login_attempt"("p_bucket" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_member_and_sale_with_actor"("p_actor_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if not exists (
        select 1 from public.profiles
        where id = p_actor_id and role in ('admin', 'staff') and is_active
    ) then
        raise exception 'Active staff or admin access required';
    end if;

    perform set_config('irongrind.activity_actor', p_actor_id::text, true);
    return public.admin_create_member_and_sale(p_actor_id, p_member, p_receipt_number);
end;
$$;


ALTER FUNCTION "public"."create_member_and_sale_with_actor"("p_actor_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_mobile_attendance_scan_session"("p_remember_phone" boolean, "p_pairing_password" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz := now() + interval '10 minutes';
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
    remember_requested boolean := coalesce(p_remember_phone, false);
    pairing_limit integer;
    paired_devices integer;
begin
    perform private.require_pairing_password(p_pairing_password);
    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into pairing_limit
    from public.mobile_attendance_pairing_policy where singleton;
    delete from public.mobile_attendance_scan_sessions where expires_at <= now();
    select count(*)::integer into paired_devices
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    if paired_devices >= pairing_limit then
        raise exception 'Phone pairing limit reached (% of %). End an existing pairing or increase the limit.', paired_devices, pairing_limit;
    end if;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.mobile_attendance_scan_sessions (
        id, token_hash, created_by, expires_at, remember_phone
    ) values (
        session_id, md5(session_token), actor_id, session_expiry, remember_requested
    );
    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id, record_label, details
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pair_qr_created', 'mobile_attendance_scan_sessions', session_id::text,
        'Attendance phone pairing',
        case when remember_requested
            then 'Created a 10-minute attendance phone pairing QR. A successful pairing will remain active for 30 days.'
            else 'Created a one-time 10-minute attendance phone pairing QR.' end
    );

    return jsonb_build_object(
        'session_id', session_id,
        'token', session_token,
        'expires_at', session_expiry,
        'remember_phone', remember_requested
    );
end;
$$;


ALTER FUNCTION "public"."create_mobile_attendance_scan_session"("p_remember_phone" boolean, "p_pairing_password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_profile_for_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.profiles (id, username, full_name)
  values (
    new.id,
    nullif(lower(trim(new.raw_user_meta_data ->> 'username')), ''),
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), '')
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."create_profile_for_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_member_renewal_window"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    membership_expiry date;
begin
    if new.application_type <> 'renewal' then
        return new;
    end if;

    select coalesce(m.expiry_date, m.end_date)
    into membership_expiry
    from public.members m
    where m.id = new.member_id
      and m.auth_user_id = new.auth_user_id;

    if not found or membership_expiry is null then
        raise exception 'A linked membership with an expiry date is required for renewal.';
    end if;

    return new;
end;
$$;


ALTER FUNCTION "public"."enforce_member_renewal_window"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_admin_mobile_attendance_device"("p_session_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id
      and created_by = (select auth.uid())
      and expires_at > now();

    if not found then raise exception 'Phone scanner session is inactive or expired'; end if;

    return jsonb_build_object(
        'paired', session_row.paired_at is not null,
        'device', session_row.paired_device,
        'paired_at', session_row.paired_at,
        'expires_at', session_row.expires_at
    );
end;
$$;


ALTER FUNCTION "public"."get_admin_mobile_attendance_device"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_mobile_attendance_pairing_settings"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    configured_limit integer;
    paired_devices integer;
    pending_qrs integer;
    configured boolean;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;

    select max_pairs, pairing_password_hash is not null
    into configured_limit, configured
    from public.mobile_attendance_pairing_policy where singleton;
    select count(*)::integer into paired_devices
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    select count(*)::integer into pending_qrs
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is null;

    return jsonb_build_object(
        'max_pairs', configured_limit,
        'active_count', paired_devices,
        'paired_count', paired_devices,
        'pending_count', pending_qrs,
        'session_count', paired_devices + pending_qrs,
        'password_configured', configured
    );
end;
$$;


ALTER FUNCTION "public"."get_mobile_attendance_pairing_settings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    insert into public.profiles (id, email, username, full_name)
    values (
        new.id,
        new.email,
        nullif(lower(new.raw_user_meta_data ->> 'username'), ''),
        coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''), '')
    );
    return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
      and p.account_status = 'active'
  );
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin_mobile_attendance_scan_session_active"("p_session_id" "uuid") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select (select private.is_admin()) is true and exists (
        select 1
        from public.mobile_attendance_scan_sessions
        where id = p_session_id
          and created_by = (select auth.uid())
          and expires_at > now()
    );
$$;


ALTER FUNCTION "public"."is_admin_mobile_attendance_scan_session_active"("p_session_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_registration_username_available"("p_username" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
    select coalesce(
        nullif(btrim(p_username), '') is not null
        and btrim(p_username) ~ '^[A-Za-z0-9_.]{4,}$'
        and not exists (
            select 1
            from public.profiles p
            where lower(p.username) = lower(btrim(p_username))
        ),
        false
    );
$_$;


ALTER FUNCTION "public"."is_registration_username_available"("p_username" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_admin_mobile_attendance_devices"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result jsonb;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select coalesce(jsonb_agg(jsonb_build_object(
        'session_id', id,
        'device', paired_device,
        'paired', true,
        'paired_at', paired_at,
        'created_at', created_at,
        'expires_at', expires_at
    ) order by paired_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is not null;
    return result;
end;
$$;


ALTER FUNCTION "public"."list_admin_mobile_attendance_devices"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_admin_mobile_attendance_pending_sessions"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result jsonb;
begin
    if (select private.is_admin()) is distinct from true then
        raise exception 'Admin access required';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'session_id', id,
        'created_at', created_at,
        'expires_at', expires_at
    ) order by created_at desc), '[]'::jsonb)
    into result
    from public.mobile_attendance_scan_sessions
    where expires_at > now() and paired_at is null;

    return result;
end;
$$;


ALTER FUNCTION "public"."list_admin_mobile_attendance_pending_sessions"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_attendance_scan"("p_identifier" "text", "p_request_id" "uuid", "p_session_id" "uuid" DEFAULT NULL::"uuid", "p_token" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    operator_id uuid := auth.uid();
    member_row public.members%rowtype;
    visit public.attendance%rowtype;
    saved_request private.attendance_scan_requests%rowtype;
    result jsonb;
    identifier text := btrim(p_identifier);
    expiry date;
begin
    if not exists (select 1 from public.profiles where id = operator_id
        and role in ('admin', 'staff') and is_active) then
        raise exception 'Active staff or admin sign-in required';
    end if;
    if p_request_id is null or identifier is null or length(identifier) not between 1 and 500 then
        raise exception 'Invalid attendance scan';
    end if;
    if p_session_id is not null or p_token is not null then
        perform 1 from public.mobile_attendance_scan_sessions
        where id = p_session_id and token_hash = md5(p_token)
            and expires_at > now() and paired_at is not null for update;
        if not found then raise exception 'Phone pairing is invalid or expired'; end if;
    end if;
    perform pg_advisory_xact_lock(hashtext(p_request_id::text));
    select * into saved_request from private.attendance_scan_requests where request_id = p_request_id;
    if found then
        if saved_request.operator_id <> operator_id then raise exception 'Scan belongs to another operator'; end if;
        return saved_request.result;
    end if;
    if upper(left(identifier, 10)) = 'IRONGRIND|' then identifier := substr(identifier, 11); end if;
    select * into member_row from public.members
    where id::text = lower(identifier) or auth_user_id::text = lower(identifier)
        or lower(username) = lower(identifier) limit 1;
    if not found then raise exception 'Member QR was not recognized'; end if;
    perform pg_advisory_xact_lock(hashtext(member_row.id::text));
    select * into visit from public.attendance where member_id = member_row.id
        order by time_in desc limit 1 for update;
    -- Repeated camera callbacks or two phones scanning together must not toggle a visit.
    if found and greatest(visit.time_in, visit.time_out) > now() - interval '8 seconds' then
        result := jsonb_build_object('action', 'duplicate', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    elsif visit.id is not null and visit.time_out is null then
        update public.attendance set time_out = now(), checked_out_by = operator_id where id = visit.id;
        result := jsonb_build_object('action', 'check_out', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    else
        expiry := coalesce(member_row.expiry_date, member_row.end_date);
        if expiry is not null and expiry < (now() at time zone 'Asia/Manila')::date then
            raise exception 'Membership is expired. Ask the admin to check renewal status';
        end if;
        insert into public.attendance(member_id, time_in, recorded_by)
        values (member_row.id, now(), operator_id) returning * into visit;
        result := jsonb_build_object('action', 'check_in', 'member_name', member_row.full_name, 'attendance_id', visit.id);
    end if;
    insert into private.attendance_scan_requests(request_id, operator_id, member_id, result)
    values (p_request_id, operator_id, member_row.id, result);
    return result;
end;
$$;


ALTER FUNCTION "public"."record_attendance_scan"("p_identifier" "text", "p_request_id" "uuid", "p_session_id" "uuid", "p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_walk_in_sale"("p_receipt_number" "text", "p_customer_name" "text", "p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    product_row public.products%rowtype;
    new_sale_id uuid;
    sale_total numeric(12, 2);
    resulting_stock numeric(14, 6);
    quantity_factor numeric;
    stock_factor numeric;
    quantity_in_base_unit numeric(14, 6);
    stock_deduction numeric(14, 6);
    sale_unit_price numeric(12, 2);
begin
    if not private.is_admin() and not private.is_staff() then
        raise exception 'Staff sales access required';
    end if;
    if nullif(btrim(p_customer_name), '') is null then raise exception 'Customer name is required'; end if;
    if nullif(btrim(p_receipt_number), '') is null then raise exception 'Transaction reference is required'; end if;
    if p_quantity is null or p_quantity <= 0 then raise exception 'Quantity must be greater than zero'; end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;
    if not found then raise exception 'Product is unavailable'; end if;
    if product_row.stock is null then raise exception 'Product inventory is not configured'; end if;

    quantity_factor := case p_quantity_unit
        when 'gram' then 1 when 'kilogram' then 1000 when 'ounce' then 28.349523125
        when 'pound' then 453.59237 when 'milliliter' then 1 when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625 when 'item' then 1 when 'piece' then 1
        when 'box' then 1 else null
    end;
    if quantity_factor is null then raise exception 'Unsupported sale unit'; end if;

    if product_row.unit = 'gram' and p_quantity_unit not in ('gram', 'kilogram', 'ounce', 'pound') then
        raise exception 'Powder supplements must be sold by weight';
    elsif product_row.unit = 'milliliter' and p_quantity_unit not in ('milliliter', 'liter', 'fluid_ounce') then
        raise exception 'Drinkable supplements must be sold by volume';
    elsif product_row.unit in ('item', 'piece', 'box')
        and (p_quantity_unit is distinct from product_row.unit or p_quantity <> trunc(p_quantity)) then
        raise exception 'Discrete products must use their configured unit and a whole-number quantity';
    end if;

    stock_factor := case product_row.stock_unit
        when 'gram' then 1 when 'kilogram' then 1000 when 'ounce' then 28.349523125
        when 'pound' then 453.59237 when 'milliliter' then 1 when 'liter' then 1000
        when 'fluid_ounce' then 29.5735295625 when 'item' then 1 when 'piece' then 1
        when 'box' then 1 else null
    end;
    if stock_factor is null then raise exception 'Unsupported inventory unit'; end if;
    if product_row.unit = 'gram' and product_row.stock_unit not in ('gram', 'kilogram', 'ounce', 'pound') then
        raise exception 'Weight sale unit does not match inventory unit';
    elsif product_row.unit = 'milliliter' and product_row.stock_unit not in ('milliliter', 'liter', 'fluid_ounce') then
        raise exception 'Volume sale unit does not match inventory unit';
    elsif product_row.unit in ('item', 'piece', 'box') and product_row.stock_unit <> product_row.unit then
        raise exception 'Discrete sale unit does not match inventory unit';
    end if;

    quantity_in_base_unit := p_quantity * quantity_factor;
    stock_deduction := quantity_in_base_unit / stock_factor;
    if product_row.stock < stock_deduction then raise exception 'Not enough stock available'; end if;
    sale_unit_price := round(product_row.price_per_unit * quantity_factor, 2);
    sale_total := round(product_row.price_per_unit * quantity_in_base_unit, 2);

    insert into public.sales (receipt_number, customer_type, customer_name, total, status, processed_by)
    values (btrim(p_receipt_number), 'walk_in', btrim(p_customer_name), sale_total, 'paid', (select auth.uid()))
    returning id into new_sale_id;
    insert into public.sale_items (sale_id, product_id, item_name, category, quantity, unit, unit_price, line_total)
    values (new_sale_id, product_row.id, product_row.name, product_row.category, p_quantity, p_quantity_unit, sale_unit_price, sale_total);
    update public.products
    set stock = round(stock - stock_deduction, 6), updated_at = now()
    where id = product_row.id
    returning stock into resulting_stock;

    return jsonb_build_object(
        'id', new_sale_id, 'receipt_number', btrim(p_receipt_number),
        'customer_name', btrim(p_customer_name), 'total', sale_total, 'sold_at', now(),
        'product_id', product_row.id, 'item_name', product_row.name, 'category', product_row.category,
        'quantity', p_quantity, 'unit', p_quantity_unit, 'unit_price', sale_unit_price,
        'line_total', sale_total, 'stock', resulting_stock, 'stock_unit', product_row.stock_unit
    );
end;
$$;


ALTER FUNCTION "public"."record_walk_in_sale"("p_receipt_number" "text", "p_customer_name" "text", "p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_mobile_attendance_device"("p_session_id" "uuid", "p_token" "text", "p_device_label" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    device_label text := left(btrim(p_device_label), 100);
    pairing_limit integer;
    paired_devices integer;
    actor_display text;
    actor_role text;
    log_action text;
    log_details text;
    changed text[];
begin
    if p_token is null or nullif(device_label, '') is null then
        raise exception 'Invalid phone pairing details';
    end if;

    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id
      and token_hash = md5(p_token)
      and expires_at > now()
    for update;
    if not found then
        raise exception 'Phone scanner session is invalid or expired';
    end if;

    if session_row.paired_at is null then
        select max_pairs into pairing_limit
        from public.mobile_attendance_pairing_policy where singleton;
        select count(*)::integer into paired_devices
        from public.mobile_attendance_scan_sessions
        where expires_at > now() and paired_at is not null;
        if paired_devices >= pairing_limit then
            raise exception 'Phone pairing limit reached. Ask the admin to free a paired-phone slot.';
        end if;
    end if;

    update public.mobile_attendance_scan_sessions
    set paired_device = device_label,
        paired_at = coalesce(paired_at, now()),
        expires_at = case when paired_at is null
            then now() + case when remember_phone then interval '30 days' else interval '10 minutes' end
            else expires_at end
    where id = p_session_id;

    if session_row.paired_at is null then
        log_action := 'phone_paired';
        log_details := 'Paired ' || device_label || ' with the attendance pairing QR.';
        changed := array['paired_device', 'paired_at'];
    elsif session_row.paired_device is distinct from device_label then
        log_action := 'phone_device_updated';
        log_details := 'Updated the paired attendance phone label to ' || device_label || '.';
        changed := array['paired_device'];
    end if;

    if log_action is not null then
        select coalesce(nullif(full_name, ''), username, email, id::text), role
        into actor_display, actor_role
        from public.profiles where id = session_row.created_by;
        insert into public.activity_logs (
            actor_id, actor_name, actor_role, action, entity_type, entity_id,
            record_label, details, changed_fields
        ) values (
            session_row.created_by, coalesce(actor_display, session_row.created_by::text), coalesce(actor_role, 'admin'),
            log_action, 'mobile_attendance_scan_sessions', p_session_id::text,
            device_label, log_details, changed
        );
    end if;
end;
$$;


ALTER FUNCTION "public"."register_mobile_attendance_device"("p_session_id" "uuid", "p_token" "text", "p_device_label" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restock_product"("p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    product_row public.products%rowtype;
    stock_increment numeric(14, 6);
    quantity_factor numeric;
    stock_factor numeric;
    resulting_stock numeric(14, 6);
begin
    if not private.is_admin() then raise exception 'Admin access required'; end if;
    if p_quantity is null or p_quantity <= 0 then raise exception 'Restock quantity must be greater than zero'; end if;

    select * into product_row
    from public.products
    where id = p_product_id and is_active = true
    for update;
    if not found then raise exception 'Product is unavailable'; end if;

    if product_row.stock_unit in ('item', 'piece', 'box') then
        if p_quantity_unit is distinct from product_row.stock_unit or p_quantity <> trunc(p_quantity) then
            raise exception 'Discrete stock must use the product unit and a whole-number quantity';
        end if;
        stock_increment := p_quantity;
    else
        quantity_factor := case p_quantity_unit
            when 'gram' then 1
            when 'kilogram' then 1000
            when 'ounce' then 28.349523125
            when 'pound' then 453.59237
            when 'milliliter' then 1
            when 'liter' then 1000
            when 'fluid_ounce' then 29.5735295625
            else null
        end;
        stock_factor := case product_row.stock_unit
            when 'gram' then 1
            when 'kilogram' then 1000
            when 'ounce' then 28.349523125
            when 'pound' then 453.59237
            when 'milliliter' then 1
            when 'liter' then 1000
            when 'fluid_ounce' then 29.5735295625
            else null
        end;
        if quantity_factor is null or stock_factor is null then raise exception 'Unsupported restock unit'; end if;
        if (p_quantity_unit in ('gram', 'kilogram', 'ounce', 'pound'))
            <> (product_row.stock_unit in ('gram', 'kilogram', 'ounce', 'pound')) then
            raise exception 'Restock unit does not match the product stock type';
        end if;
        stock_increment := p_quantity * quantity_factor / stock_factor;
    end if;

    update public.products
    set stock = round(stock + stock_increment, 6), updated_at = now()
    where id = product_row.id
    returning stock into resulting_stock;
    return resulting_stock;
end;
$$;


ALTER FUNCTION "public"."restock_product"("p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_mobile_attendance_pairing_limit"("p_max_pairs" integer, "p_removal_pin" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    previous_limit integer;
    actor_id uuid := auth.uid();
    actor_display text;
    actor_role text;
begin
    perform private.require_attendance_removal_pin(p_removal_pin);
    if p_max_pairs is null or p_max_pairs not between 2 and 50 then
        raise exception 'Phone pairing limit must be between 2 and 50';
    end if;

    perform pg_advisory_xact_lock(hashtext('mobile_attendance_pairing_limit'));
    select max_pairs into previous_limit
    from public.mobile_attendance_pairing_policy where singleton for update;
    update public.mobile_attendance_pairing_policy
    set max_pairs = p_max_pairs, updated_at = now(), updated_by = actor_id
    where singleton;

    select coalesce(nullif(full_name, ''), username, email, id::text), role
    into actor_display, actor_role
    from public.profiles where id = actor_id;
    insert into public.activity_logs (
        actor_id, actor_name, actor_role, action, entity_type, entity_id,
        record_label, details, changed_fields
    ) values (
        actor_id, coalesce(actor_display, actor_id::text), coalesce(actor_role, 'admin'),
        'phone_pairing_limit_changed', 'mobile_attendance_pairing_policy', 'true',
        'Attendance phone pairing limit',
        'Changed the active phone pairing limit from ' || previous_limit || ' to ' || p_max_pairs || '.',
        array['max_pairs']
    );
    return jsonb_build_object('previous_limit', previous_limit, 'max_pairs', p_max_pairs);
end;
$$;


ALTER FUNCTION "public"."set_mobile_attendance_pairing_limit"("p_max_pairs" integer, "p_removal_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_mobile_attendance_pairing_password"("p_password" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    if p_password is null or length(p_password) < 8 or octet_length(p_password) > 72 then
        raise exception 'Pairing password must be at least 8 characters and no more than 72 bytes';
    end if;
    update public.mobile_attendance_pairing_policy
    set pairing_password_hash = extensions.crypt(p_password, extensions.gen_salt('bf')),
        updated_at = now(), updated_by = auth.uid()
    where singleton;
end;
$$;


ALTER FUNCTION "public"."set_mobile_attendance_pairing_password"("p_password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_list_attendance"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result jsonb;
begin
    if (select private.is_staff()) is not true
        and (select private.is_admin()) is not true then
        raise exception 'Staff access required';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'id', a.id,
        'member_id', a.member_id,
        'member_name', m.full_name,
        'time_in', a.time_in,
        'time_out', a.time_out,
        'recorded_by', a.recorded_by
    ) order by a.time_in desc), '[]'::jsonb)
    into result
    from public.attendance a
    join public.members m on m.id = a.member_id;
    return result;
end;
$$;


ALTER FUNCTION "public"."staff_list_attendance"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_list_own_product_sales"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare result jsonb;
begin
    if not private.is_staff() then raise exception 'Staff access required'; end if;
    select coalesce(jsonb_agg(jsonb_build_object(
        'receipt_number', s.receipt_number,
        'customer_name', s.customer_name,
        'total', s.total,
        'sold_at', s.sold_at,
        'items', (select coalesce(jsonb_agg(jsonb_build_object(
            'item_name', si.item_name, 'quantity', si.quantity, 'unit', si.unit,
            'line_total', si.line_total, 'category', si.category
        )), '[]'::jsonb) from public.sale_items si
          where si.sale_id = s.id and si.category in ('supplement', 'merchandise'))
    ) order by s.sold_at desc), '[]'::jsonb)
    into result
    from (
        select distinct s.id, s.receipt_number, s.customer_name, s.total, s.sold_at
        from public.sales s
        join public.sale_items si on si.sale_id = s.id
        where s.processed_by = (select auth.uid())
          and s.customer_type = 'walk_in'
          and s.status = 'paid'
          and si.category in ('supplement', 'merchandise')
        order by s.sold_at desc
        limit 50
    ) s;
    return result;
end;
$$;


ALTER FUNCTION "public"."staff_list_own_product_sales"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_resolve_attendance_member"("p_identifier" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare result jsonb;
begin
    if (select private.is_staff()) is not true
        and (select private.is_admin()) is not true then
        raise exception 'Staff access required';
    end if;
    if nullif(btrim(p_identifier), '') is null then
        raise exception 'Member QR identifier is required';
    end if;

    if btrim(p_identifier) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select jsonb_build_object(
            'id', id,
            'full_name', full_name,
            'expiry_date', coalesce(expiry_date, end_date)
        ) into result
        from public.members
        where id = btrim(p_identifier)::uuid or auth_user_id = btrim(p_identifier)::uuid
        limit 1;
    else
        select jsonb_build_object(
            'id', id,
            'full_name', full_name,
            'expiry_date', coalesce(expiry_date, end_date)
        ) into result
        from public.members
        where lower(username) = lower(btrim(p_identifier))
        limit 1;
    end if;

    return result;
end;
$_$;


ALTER FUNCTION "public"."staff_resolve_attendance_member"("p_identifier" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_search_members"("p_query" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    search_text text := btrim(coalesce(p_query, ''));
    result jsonb;
begin
    if not private.is_staff() then raise exception 'Staff access required'; end if;
    if length(search_text) < 2 or length(search_text) > 80 then
        raise exception 'Enter between 2 and 80 characters to search';
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
        'id', member_row.id,
        'full_name', member_row.full_name,
        'email', member_row.email,
        'mobile', member_row.mobile,
        'plan', member_row.plan,
        'plan_price', member_row.plan_price,
        'status', member_row.status,
        'start_date', member_row.start_date,
        'expiry_date', coalesce(member_row.expiry_date, member_row.end_date)
    ) order by member_row.full_name), '[]'::jsonb)
    into result
    from (
        select id, full_name, email, mobile, plan, plan_price, status, start_date, expiry_date, end_date
        from public.members
        where full_name ilike '%' || search_text || '%'
           or email ilike '%' || search_text || '%'
        order by full_name
        limit 25
    ) member_row;

    return result;
end;
$$;


ALTER FUNCTION "public"."staff_search_members"("p_query" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."submit_mobile_attendance_scan"("p_session_id" "uuid", "p_token" "text", "p_qr_payload" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    raise exception 'Update the attendance app and sign in before scanning';
end;
$$;


ALTER FUNCTION "public"."submit_mobile_attendance_scan"("p_session_id" "uuid", "p_token" "text", "p_qr_payload" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_auth_user_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if new.email is distinct from old.email then
        update public.profiles set email = new.email where id = new.id;
        update public.members set email = new.email where auth_user_id = new.id;
    end if;
    return new;
end;
$$;


ALTER FUNCTION "public"."sync_auth_user_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_legacy_product_price"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
    product_record jsonb;
begin
    product_record := to_jsonb(new);
    if product_record ? 'price' then
        product_record := jsonb_set(product_record, '{price}', to_jsonb(new.price_per_unit), true);
        new := jsonb_populate_record(new, product_record);
    end if;
    return new;
end;
$$;


ALTER FUNCTION "public"."sync_legacy_product_price"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_own_member_personal_info"("p_profile" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
    v_member_id uuid;
    v_full_name text;
    v_mobile text;
    v_dob date;
    v_sex text;
    v_height numeric;
    v_height_unit text;
    v_weight numeric;
    v_emergency_contact jsonb;
    v_fitness_goals text[];
    v_health_conditions text[];
    v_other_medical_conditions text;
begin
    if (select auth.uid()) is null then
        raise exception 'Authentication required';
    end if;
    if jsonb_typeof(p_profile) is distinct from 'object' then
        raise exception 'Profile information must be an object';
    end if;

    v_full_name := nullif(btrim(p_profile ->> 'full_name'), '');
    v_mobile := nullif(btrim(p_profile ->> 'mobile'), '');
    v_dob := nullif(p_profile ->> 'date_of_birth', '')::date;
    v_sex := nullif(btrim(p_profile ->> 'sex'), '');
    v_height := nullif(p_profile ->> 'height', '')::numeric;
    v_height_unit := nullif(p_profile ->> 'height_unit', '');
    v_weight := nullif(p_profile ->> 'weight_kg', '')::numeric;
    v_emergency_contact := case
        when jsonb_typeof(p_profile -> 'emergency_contact') = 'object' then p_profile -> 'emergency_contact'
        else '{}'::jsonb
    end;
    v_other_medical_conditions := coalesce(p_profile ->> 'other_medical_conditions', '');

    if v_full_name is null then
        raise exception 'Full name is required';
    end if;
    if v_dob is null or v_dob > current_date then
        raise exception 'Enter a valid date of birth';
    end if;
    if v_mobile is not null and v_mobile !~ '^09[0-9]{9}$' then
        raise exception 'Enter a valid PH mobile number';
    end if;
    if nullif(btrim(v_emergency_contact ->> 'contact'), '') is not null
        and btrim(v_emergency_contact ->> 'contact') !~ '^09[0-9]{9}$' then
        raise exception 'Enter a valid emergency contact number';
    end if;
    if v_height is not null and v_height <= 0 then
        raise exception 'Height must be greater than zero';
    end if;
    if v_weight is not null and v_weight <= 0 then
        raise exception 'Weight must be greater than zero';
    end if;
    if v_height is not null and (v_height_unit is null or v_height_unit not in ('cm', 'in', 'ft')) then
        raise exception 'Choose a valid height unit';
    end if;

    select coalesce(array_agg(value), '{}'::text[])
    into v_fitness_goals
    from jsonb_array_elements_text(
        case when jsonb_typeof(p_profile -> 'fitness_goals') = 'array'
            then p_profile -> 'fitness_goals' else '[]'::jsonb end
    ) as goals(value);

    select coalesce(array_agg(value), '{}'::text[])
    into v_health_conditions
    from jsonb_array_elements_text(
        case when jsonb_typeof(p_profile -> 'health_conditions') = 'array'
            then p_profile -> 'health_conditions' else '[]'::jsonb end
    ) as conditions(value);

    update public.members
    set full_name = v_full_name,
        mobile = v_mobile,
        date_of_birth = v_dob,
        age = extract(year from age(current_date, v_dob))::smallint,
        sex = v_sex,
        height = v_height,
        height_unit = case when v_height is null then null else v_height_unit end,
        weight_kg = v_weight,
        emergency_contact = v_emergency_contact,
        fitness_goals = v_fitness_goals,
        health_conditions = v_health_conditions,
        other_medical_conditions = v_other_medical_conditions,
        updated_at = now()
    where auth_user_id = (select auth.uid())
    returning id into v_member_id;

    if v_member_id is null then
        raise exception 'No member record is linked to this account';
    end if;

    update public.profiles
    set full_name = v_full_name
    where id = (select auth.uid());
end;
$_$;


ALTER FUNCTION "public"."update_own_member_personal_info"("p_profile" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_mobile_attendance_scan_session"("p_session_id" "uuid", "p_token" "text") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    select p_token is not null and exists (
        select 1
        from public.mobile_attendance_scan_sessions
        where id = p_session_id
          and token_hash = md5(p_token)
          and expires_at > now()
    );
$$;


ALTER FUNCTION "public"."validate_mobile_attendance_scan_session"("p_session_id" "uuid", "p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_mobile_attendance_pairing_password"("p_password" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    perform private.require_pairing_password(p_password);
    return true;
end;
$$;


ALTER FUNCTION "public"."verify_mobile_attendance_pairing_password"("p_password" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verify_mobile_attendance_removal_pin"("p_pin" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare configured boolean;
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    select pairing_removal_pin_hash is not null into configured
    from public.mobile_attendance_pairing_policy where singleton;
    if not configured then return jsonb_build_object('configured', false, 'valid', false); end if;
    if p_pin is null or p_pin !~ '^[0-9]{4}$' then return jsonb_build_object('configured', true, 'valid', false); end if;
    if exists (select 1 from public.mobile_attendance_pairing_policy
        where singleton and extensions.crypt(p_pin, pairing_removal_pin_hash) = pairing_removal_pin_hash) then
        return jsonb_build_object('configured', true, 'valid', true);
    end if;
    return jsonb_build_object('configured', true, 'valid', false);
end;
$_$;


ALTER FUNCTION "public"."verify_mobile_attendance_removal_pin"("p_pin" "text") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "private"."admin_login_attempts" (
    "bucket" "text" NOT NULL,
    "window_start" timestamp with time zone NOT NULL,
    "attempts" integer NOT NULL
);


ALTER TABLE "private"."admin_login_attempts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "private"."attendance_scan_requests" (
    "request_id" "uuid" NOT NULL,
    "operator_id" "uuid" NOT NULL,
    "member_id" "uuid" NOT NULL,
    "result" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "private"."attendance_scan_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" bigint NOT NULL,
    "occurred_at" timestamp with time zone DEFAULT "clock_timestamp"() NOT NULL,
    "actor_id" "uuid",
    "actor_name" "text" NOT NULL,
    "actor_role" "text" NOT NULL,
    "action" "text" NOT NULL,
    "entity_type" "text" NOT NULL,
    "entity_id" "text",
    "record_label" "text" DEFAULT ''::"text" NOT NULL,
    "changed_fields" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "details" "text" DEFAULT ''::"text" NOT NULL
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


ALTER TABLE "public"."activity_logs" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."activity_logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."attendance" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "member_id" "uuid" NOT NULL,
    "date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "time_in" timestamp with time zone DEFAULT "now"() NOT NULL,
    "time_out" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "recorded_by" "uuid",
    "checked_out_by" "uuid"
);


ALTER TABLE "public"."attendance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "application_id" "uuid",
    "full_name" character varying(150) NOT NULL,
    "mobile" character varying(11),
    "plan" character varying(30) NOT NULL,
    "start_date" "date",
    "end_date" "date",
    "status" character varying(20) DEFAULT 'active'::"text" NOT NULL,
    "paid" numeric(10,2) DEFAULT 0 NOT NULL,
    "fitness_goals" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "height" numeric(6,2),
    "height_unit" character varying(3),
    "weight" numeric(6,2),
    "health_conditions" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "other_medical_conditions" "text",
    "signature_data" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "auth_user_id" "uuid",
    "email" character varying(254),
    "username" character varying(30),
    "date_of_birth" "date",
    "age" smallint,
    "sex" character varying(30),
    "weight_kg" numeric(7,2),
    "emergency_contact" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "plan_price" numeric(12,2) DEFAULT 0 NOT NULL,
    "expiry_date" "date",
    "registration_source" character varying(40) DEFAULT 'Online application'::"text" NOT NULL,
    "signature_path" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "members_height_unit_check" CHECK ((("height_unit" IS NULL) OR (("height_unit")::"text" = ANY (ARRAY['cm'::"text", 'in'::"text", 'ft'::"text"])))),
    CONSTRAINT "members_paid_check" CHECK (("paid" >= (0)::numeric)),
    CONSTRAINT "members_status_check" CHECK ((("status")::"text" = ANY ((ARRAY['active'::character varying, 'expired'::character varying, 'suspended'::character varying, 'inactive'::character varying])::"text"[])))
);


ALTER TABLE "public"."members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."membership_applications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "full_name" character varying(150) NOT NULL,
    "date_of_birth" "date",
    "age" integer,
    "sex" character varying(30),
    "mobile" character varying(11),
    "height" numeric(6,2),
    "height_unit" character varying(3),
    "weight" numeric(6,2),
    "emergency_name" "text",
    "emergency_relationship" "text",
    "emergency_contact" "text",
    "plan" character varying(30) NOT NULL,
    "plan_price" numeric(10,2) DEFAULT 0 NOT NULL,
    "start_date" "date",
    "end_date" "date",
    "health_conditions" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "other_medical_conditions" "text",
    "fitness_goals" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "signature_data" "text",
    "status" character varying(20) DEFAULT 'pending'::"text" NOT NULL,
    "reviewed_by" "uuid",
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "auth_user_id" "uuid",
    "member_id" "uuid",
    "application_type" character varying(20) DEFAULT 'registration'::"text" NOT NULL,
    "submitted_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" character varying(254),
    "username" character varying(30),
    "emergency_contact_data" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "weight_kg" numeric(7,2),
    "signature_path" "text",
    CONSTRAINT "membership_applications_age_check" CHECK ((("age" IS NULL) OR (("age" >= 1) AND ("age" <= 120)))),
    CONSTRAINT "membership_applications_application_type_check" CHECK ((("application_type")::"text" = ANY (ARRAY['registration'::"text", 'renewal'::"text"]))),
    CONSTRAINT "membership_applications_height_unit_check" CHECK ((("height_unit" IS NULL) OR (("height_unit")::"text" = ANY (ARRAY['cm'::"text", 'in'::"text", 'ft'::"text"])))),
    CONSTRAINT "membership_applications_plan_price_check" CHECK (("plan_price" >= (0)::numeric)),
    CONSTRAINT "membership_applications_status_check" CHECK ((("status")::"text" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."membership_applications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."membership_history" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "member_id" "uuid" NOT NULL,
    "event_type" character varying(30) NOT NULL,
    "previous_plan" character varying(30),
    "new_plan" character varying(30),
    "previous_price" numeric(12,2),
    "new_price" numeric(12,2),
    "previous_start_date" "date",
    "previous_expiry_date" "date",
    "new_start_date" "date",
    "new_expiry_date" "date",
    "notes" "text" DEFAULT ''::"text" NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "recorded_by" "uuid",
    CONSTRAINT "membership_history_event_type_check" CHECK ((("event_type")::"text" = ANY (ARRAY['expired'::"text", 'renewal'::"text", 'plan_change'::"text"]))),
    CONSTRAINT "membership_history_new_price_check" CHECK ((("new_price" IS NULL) OR ("new_price" >= (0)::numeric))),
    CONSTRAINT "membership_history_previous_price_check" CHECK ((("previous_price" IS NULL) OR ("previous_price" >= (0)::numeric)))
);


ALTER TABLE "public"."membership_history" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mobile_attendance_pairing_policy" (
    "singleton" boolean DEFAULT true NOT NULL,
    "max_pairs" integer DEFAULT 2 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_by" "uuid",
    "pairing_password_hash" "text",
    "pairing_removal_pin_hash" "text",
    CONSTRAINT "mobile_attendance_pairing_policy_max_pairs_check" CHECK ((("max_pairs" >= 2) AND ("max_pairs" <= 50))),
    CONSTRAINT "mobile_attendance_pairing_policy_singleton_check" CHECK ("singleton")
);


ALTER TABLE "public"."mobile_attendance_pairing_policy" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mobile_attendance_scan_events" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "qr_payload" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "mobile_attendance_scan_events_qr_payload_check" CHECK ((("length"("qr_payload") >= 1) AND ("length"("qr_payload") <= 500)))
);


ALTER TABLE "public"."mobile_attendance_scan_events" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mobile_attendance_scan_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "token_hash" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone NOT NULL,
    "paired_device" "text",
    "paired_at" timestamp with time zone,
    "remember_phone" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."mobile_attendance_scan_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" character varying(120) NOT NULL,
    "category" character varying(20) NOT NULL,
    "price" numeric(10,2) NOT NULL,
    "stock" numeric(14,6) DEFAULT 0 NOT NULL,
    "size" character varying(30),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "archived_at" timestamp with time zone,
    "image_path" "text",
    "price_per_unit" numeric(12,2) DEFAULT 0 NOT NULL,
    "unit" character varying(12) DEFAULT 'item'::"text" NOT NULL,
    "stock_unit" "text" DEFAULT 'item'::"text" NOT NULL,
    "merch_type" "text",
    "supplement_form" "text",
    "supplement_type" "text",
    CONSTRAINT "products_category_check" CHECK ((("category")::"text" = ANY (ARRAY['supplement'::"text", 'merchandise'::"text"]))),
    CONSTRAINT "products_category_unit_check" CHECK ((((("category")::"text" = 'supplement'::"text") AND ((("supplement_form" = 'powder'::"text") AND (("unit")::"text" = 'gram'::"text")) OR (("supplement_form" = 'drinkable'::"text") AND (("unit")::"text" = 'milliliter'::"text")) OR (("supplement_form" = ANY (ARRAY['capsule'::"text", 'tablet'::"text"])) AND (("unit")::"text" = ANY ((ARRAY['piece'::character varying, 'box'::character varying])::"text"[])) AND (("unit")::"text" = "stock_unit")) OR (("supplement_form" = 'other'::"text") AND (("unit")::"text" = 'item'::"text")))) OR ((("category")::"text" = 'merchandise'::"text") AND (("unit")::"text" = 'item'::"text")))),
    CONSTRAINT "products_merch_type_check" CHECK ((((("category")::"text" = 'merchandise'::"text") AND ("merch_type" = ANY (ARRAY['apparel'::"text", 'accessories'::"text", 'drinkware'::"text", 'gym_gear'::"text", 'other'::"text"]))) OR ((("category")::"text" = 'supplement'::"text") AND ("merch_type" IS NULL)))),
    CONSTRAINT "products_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "products_stock_check" CHECK (("stock" >= (0)::numeric)),
    CONSTRAINT "products_stock_unit_check" CHECK ((((("category")::"text" = 'supplement'::"text") AND ((("supplement_form" = 'powder'::"text") AND ("stock_unit" = ANY (ARRAY['gram'::"text", 'kilogram'::"text", 'ounce'::"text", 'pound'::"text"]))) OR (("supplement_form" = 'drinkable'::"text") AND ("stock_unit" = ANY (ARRAY['milliliter'::"text", 'liter'::"text", 'fluid_ounce'::"text"]))) OR (("supplement_form" = ANY (ARRAY['capsule'::"text", 'tablet'::"text"])) AND ("stock_unit" = ANY (ARRAY['piece'::"text", 'box'::"text"]))) OR (("supplement_form" = 'other'::"text") AND ("stock_unit" = 'item'::"text")))) OR ((("category")::"text" = 'merchandise'::"text") AND ("stock_unit" = 'item'::"text")))),
    CONSTRAINT "products_supplement_form_check" CHECK ((((("category")::"text" = 'supplement'::"text") AND ("supplement_form" IS NOT NULL) AND ("supplement_form" = ANY (ARRAY['powder'::"text", 'drinkable'::"text", 'capsule'::"text", 'tablet'::"text", 'other'::"text"]))) OR ((("category")::"text" = 'merchandise'::"text") AND ("supplement_form" IS NULL)))),
    CONSTRAINT "products_supplement_type_check" CHECK ((((("category")::"text" = 'supplement'::"text") AND ("supplement_type" = ANY (ARRAY['protein'::"text", 'creatine'::"text", 'pre_workout'::"text", 'vitamins'::"text", 'amino_acids'::"text", 'other'::"text"]))) OR ((("category")::"text" <> 'supplement'::"text") AND ("supplement_type" IS NULL))))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "username" character varying(30),
    "full_name" character varying(150) DEFAULT ''::"text" NOT NULL,
    "role" character varying(20) DEFAULT 'member'::"text" NOT NULL,
    "account_status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "email" character varying(254),
    "is_active" boolean DEFAULT true NOT NULL,
    "phone_number" "text",
    "gender" "text",
    CONSTRAINT "profiles_account_status_check" CHECK (("account_status" = ANY (ARRAY['pending'::"text", 'active'::"text", 'disabled'::"text"]))),
    CONSTRAINT "profiles_role_check" CHECK ((("role")::"text" = ANY ((ARRAY['admin'::character varying, 'staff'::character varying, 'member'::character varying])::"text"[])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sale_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "product_id" "uuid",
    "item_name" character varying(150) NOT NULL,
    "category" character varying(20) NOT NULL,
    "quantity" numeric(12,3) NOT NULL,
    "unit" character varying(12) NOT NULL,
    "unit_price" numeric(12,2) NOT NULL,
    "line_total" numeric(12,2) NOT NULL,
    CONSTRAINT "sale_items_category_check" CHECK ((("category")::"text" = ANY (ARRAY['supplement'::"text", 'merchandise'::"text", 'membership'::"text"]))),
    CONSTRAINT "sale_items_line_total_check" CHECK (("line_total" >= (0)::numeric)),
    CONSTRAINT "sale_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "sale_items_unit_check" CHECK ((("unit")::"text" = ANY ((ARRAY['gram'::character varying, 'kilogram'::character varying, 'ounce'::character varying, 'pound'::character varying, 'milliliter'::character varying, 'liter'::character varying, 'fluid_ounce'::character varying, 'item'::character varying, 'piece'::character varying, 'box'::character varying, 'membership'::character varying])::"text"[]))),
    CONSTRAINT "sale_items_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."sale_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "member_id" "uuid",
    "customer_name" character varying(150) NOT NULL,
    "items" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "total" numeric(10,2) NOT NULL,
    "status" character varying(12) DEFAULT 'completed'::"text" NOT NULL,
    "sold_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "receipt_number" character varying(64) NOT NULL,
    "customer_type" character varying(15) DEFAULT 'member'::"text" NOT NULL,
    "processed_by" "uuid",
    CONSTRAINT "sales_status_check" CHECK (((("status")::"text" <> ''::"text") AND (("status")::"text" = "lower"("btrim"(("status")::"text"))))),
    CONSTRAINT "sales_total_check" CHECK (("total" >= (0)::numeric))
);


ALTER TABLE "public"."sales" OWNER TO "postgres";


ALTER TABLE ONLY "private"."admin_login_attempts"
    ADD CONSTRAINT "admin_login_attempts_pkey" PRIMARY KEY ("bucket");



ALTER TABLE ONLY "private"."attendance_scan_requests"
    ADD CONSTRAINT "attendance_scan_requests_pkey" PRIMARY KEY ("request_id");



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_application_id_key" UNIQUE ("application_id");



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."membership_applications"
    ADD CONSTRAINT "membership_applications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."membership_history"
    ADD CONSTRAINT "membership_history_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mobile_attendance_pairing_policy"
    ADD CONSTRAINT "mobile_attendance_pairing_policy_pkey" PRIMARY KEY ("singleton");



ALTER TABLE ONLY "public"."mobile_attendance_scan_events"
    ADD CONSTRAINT "mobile_attendance_scan_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mobile_attendance_scan_sessions"
    ADD CONSTRAINT "mobile_attendance_scan_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



CREATE INDEX "activity_logs_actor_idx" ON "public"."activity_logs" USING "btree" ("actor_id", "occurred_at" DESC);



CREATE INDEX "activity_logs_time_idx" ON "public"."activity_logs" USING "btree" ("occurred_at" DESC, "id" DESC);



CREATE INDEX "applications_auth_user_id_idx" ON "public"."membership_applications" USING "btree" ("auth_user_id");



CREATE INDEX "applications_status_submitted_idx" ON "public"."membership_applications" USING "btree" ("status", "submitted_at" DESC);



CREATE INDEX "attendance_member_date_idx" ON "public"."attendance" USING "btree" ("member_id", "date" DESC);



CREATE INDEX "attendance_member_time_idx" ON "public"."attendance" USING "btree" ("member_id", "time_in" DESC);



CREATE UNIQUE INDEX "members_auth_user_id_uidx" ON "public"."members" USING "btree" ("auth_user_id") WHERE ("auth_user_id" IS NOT NULL);



CREATE INDEX "membership_history_member_date_idx" ON "public"."membership_history" USING "btree" ("member_id", "recorded_at" DESC);



CREATE INDEX "mobile_attendance_scan_events_session_created_idx" ON "public"."mobile_attendance_scan_events" USING "btree" ("session_id", "created_at");



CREATE UNIQUE INDEX "profiles_email_unique_idx" ON "public"."profiles" USING "btree" ("email") WHERE ("email" IS NOT NULL);



CREATE UNIQUE INDEX "profiles_username_unique_idx" ON "public"."profiles" USING "btree" ("username") WHERE ("username" IS NOT NULL);



CREATE INDEX "sale_items_sale_id_idx" ON "public"."sale_items" USING "btree" ("sale_id");



CREATE UNIQUE INDEX "sales_receipt_number_unique_idx" ON "public"."sales" USING "btree" ("receipt_number");



CREATE INDEX "sales_sold_at_idx" ON "public"."sales" USING "btree" ("sold_at" DESC);



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."attendance" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."members" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."membership_applications" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."membership_history" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."sale_items" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "capture_activity" AFTER INSERT OR DELETE OR UPDATE ON "public"."sales" FOR EACH ROW EXECUTE FUNCTION "private"."capture_activity"();



CREATE OR REPLACE TRIGGER "membership_application_renewal_window" BEFORE INSERT ON "public"."membership_applications" FOR EACH ROW EXECUTE FUNCTION "public"."enforce_member_renewal_window"();



CREATE OR REPLACE TRIGGER "products_sync_legacy_price" BEFORE INSERT OR UPDATE OF "price_per_unit" ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."sync_legacy_product_price"();



CREATE OR REPLACE TRIGGER "sale_item_activity_description" AFTER INSERT ON "public"."sale_items" FOR EACH ROW EXECUTE FUNCTION "private"."describe_sale_activity"();



ALTER TABLE ONLY "private"."attendance_scan_requests"
    ADD CONSTRAINT "attendance_scan_requests_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "private"."attendance_scan_requests"
    ADD CONSTRAINT "attendance_scan_requests_operator_id_fkey" FOREIGN KEY ("operator_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_checked_out_by_fkey" FOREIGN KEY ("checked_out_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attendance"
    ADD CONSTRAINT "attendance_recorded_by_fkey" FOREIGN KEY ("recorded_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_application_id_fkey" FOREIGN KEY ("application_id") REFERENCES "public"."membership_applications"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."members"
    ADD CONSTRAINT "members_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."membership_applications"
    ADD CONSTRAINT "membership_applications_auth_user_id_fkey" FOREIGN KEY ("auth_user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."membership_applications"
    ADD CONSTRAINT "membership_applications_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."membership_applications"
    ADD CONSTRAINT "membership_applications_reviewed_by_fkey" FOREIGN KEY ("reviewed_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."membership_history"
    ADD CONSTRAINT "membership_history_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."membership_history"
    ADD CONSTRAINT "membership_history_recorded_by_fkey" FOREIGN KEY ("recorded_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."mobile_attendance_pairing_policy"
    ADD CONSTRAINT "mobile_attendance_pairing_policy_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."mobile_attendance_scan_events"
    ADD CONSTRAINT "mobile_attendance_scan_events_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."mobile_attendance_scan_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mobile_attendance_scan_sessions"
    ADD CONSTRAINT "mobile_attendance_scan_sessions_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "public"."members"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_processed_by_fkey" FOREIGN KEY ("processed_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE "private"."admin_login_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "private"."attendance_scan_requests" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Admins clear paired attendance scans" ON "public"."mobile_attendance_scan_events" FOR DELETE TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "Admins read paired attendance scans" ON "public"."mobile_attendance_scan_events" FOR SELECT TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin"));



ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_logs_admin_read" ON "public"."activity_logs" FOR SELECT TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "applications_admin_manage" ON "public"."membership_applications" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "applications_read_self_or_admin" ON "public"."membership_applications" FOR SELECT TO "authenticated" USING ((("auth_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "private"."is_admin"() AS "is_admin")));



CREATE POLICY "applications_submit_own_pending" ON "public"."membership_applications" FOR INSERT TO "authenticated" WITH CHECK ((("auth_user_id" = ( SELECT "auth"."uid"() AS "uid")) AND (("status")::"text" = 'pending'::"text") AND ("reviewed_at" IS NULL) AND ("reviewed_by" IS NULL) AND (((("application_type")::"text" = 'registration'::"text") AND ("member_id" IS NULL)) OR ((("application_type")::"text" = 'renewal'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."id" = "membership_applications"."member_id") AND ("m"."auth_user_id" = ( SELECT "auth"."uid"() AS "uid")))))))));



ALTER TABLE "public"."attendance" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "attendance_admin_manage" ON "public"."attendance" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "attendance_read_member_or_admin" ON "public"."attendance" FOR SELECT TO "authenticated" USING ((( SELECT "private"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."id" = "attendance"."member_id") AND ("m"."auth_user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



ALTER TABLE "public"."members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "members_admin_manage" ON "public"."members" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "members_read_self_or_admin" ON "public"."members" FOR SELECT TO "authenticated" USING ((("auth_user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "private"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."membership_applications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."membership_history" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "membership_history_admin_manage" ON "public"."membership_history" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "membership_history_read_member_or_admin" ON "public"."membership_history" FOR SELECT TO "authenticated" USING ((( SELECT "private"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."id" = "membership_history"."member_id") AND ("m"."auth_user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



ALTER TABLE "public"."mobile_attendance_pairing_policy" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mobile_attendance_scan_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mobile_attendance_scan_sessions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_admin_manage" ON "public"."products" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "products_read_active_or_admin" ON "public"."products" FOR SELECT TO "authenticated" USING (("is_active" OR ( SELECT "private"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_read_self_or_admin" ON "public"."profiles" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "private"."is_admin"() AS "is_admin")));



CREATE POLICY "profiles_update_self_or_admin" ON "public"."profiles" FOR UPDATE TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "private"."is_admin"() AS "is_admin"))) WITH CHECK ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "private"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."sale_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_items_admin_manage" ON "public"."sale_items" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "sale_items_read_member_or_admin" ON "public"."sale_items" FOR SELECT TO "authenticated" USING ((( SELECT "private"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM ("public"."sales" "s"
     JOIN "public"."members" "m" ON (("m"."id" = "s"."member_id")))
  WHERE (("s"."id" = "sale_items"."sale_id") AND ("m"."auth_user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sales_admin_manage" ON "public"."sales" TO "authenticated" USING (( SELECT "private"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "private"."is_admin"() AS "is_admin"));



CREATE POLICY "sales_read_member_or_admin" ON "public"."sales" FOR SELECT TO "authenticated" USING ((( SELECT "private"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."members" "m"
  WHERE (("m"."id" = "sales"."member_id") AND ("m"."auth_user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "staff_read_attendance" ON "public"."attendance" FOR SELECT TO "authenticated" USING (( SELECT "private"."is_staff"() AS "is_staff"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."attendance";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."membership_applications";



GRANT USAGE ON SCHEMA "private" TO "authenticated";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































REVOKE ALL ON FUNCTION "private"."capture_activity"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."describe_sale_activity"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."is_admin"() FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."is_admin"() TO "authenticated";



REVOKE ALL ON FUNCTION "private"."is_staff"() FROM PUBLIC;
GRANT ALL ON FUNCTION "private"."is_staff"() TO "authenticated";



REVOKE ALL ON FUNCTION "private"."require_attendance_removal_pin"("p_pin" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."require_pairing_password"("p_password" "text") FROM PUBLIC;



REVOKE ALL ON FUNCTION "private"."require_recent_admin_auth"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."admin_capture_expired_memberships"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_capture_expired_memberships"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_create_member_and_sale"("p_admin_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_create_member_and_sale"("p_admin_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admin_log_session_event"("p_event" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_log_session_event"("p_event" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_record_membership_change"("p_member_id" "uuid", "p_event_type" "text", "p_new_plan" "text", "p_new_price" numeric, "p_new_start_date" "date", "p_new_expiry_date" "date", "p_customer_name" "text", "p_mobile" "text", "p_receipt_number" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_record_membership_change"("p_member_id" "uuid", "p_event_type" "text", "p_new_plan" "text", "p_new_price" numeric, "p_new_start_date" "date", "p_new_expiry_date" "date", "p_customer_name" "text", "p_mobile" "text", "p_receipt_number" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."admin_record_registration_sale"("p_member_id" "uuid", "p_receipt_number" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admin_record_registration_sale"("p_member_id" "uuid", "p_receipt_number" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."close_mobile_attendance_scan_session"("p_session_id" "uuid", "p_pairing_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."close_mobile_attendance_scan_session"("p_session_id" "uuid", "p_pairing_pin" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."consume_admin_login_attempt"("p_bucket" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."consume_admin_login_attempt"("p_bucket" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_member_and_sale_with_actor"("p_actor_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_member_and_sale_with_actor"("p_actor_id" "uuid", "p_member" "jsonb", "p_receipt_number" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_mobile_attendance_scan_session"("p_remember_phone" boolean, "p_pairing_password" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_mobile_attendance_scan_session"("p_remember_phone" boolean, "p_pairing_password" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_admin_mobile_attendance_device"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_admin_mobile_attendance_device"("p_session_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."get_mobile_attendance_pairing_settings"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_mobile_attendance_pairing_settings"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."is_admin_mobile_attendance_scan_session_active"("p_session_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_admin_mobile_attendance_scan_session_active"("p_session_id" "uuid") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."is_registration_username_available"("p_username" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_registration_username_available"("p_username" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_registration_username_available"("p_username" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."list_admin_mobile_attendance_devices"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_admin_mobile_attendance_devices"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."list_admin_mobile_attendance_pending_sessions"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_admin_mobile_attendance_pending_sessions"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."record_attendance_scan"("p_identifier" "text", "p_request_id" "uuid", "p_session_id" "uuid", "p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."record_attendance_scan"("p_identifier" "text", "p_request_id" "uuid", "p_session_id" "uuid", "p_token" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."record_walk_in_sale"("p_receipt_number" "text", "p_customer_name" "text", "p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."record_walk_in_sale"("p_receipt_number" "text", "p_customer_name" "text", "p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."register_mobile_attendance_device"("p_session_id" "uuid", "p_token" "text", "p_device_label" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."register_mobile_attendance_device"("p_session_id" "uuid", "p_token" "text", "p_device_label" "text") TO "anon";



REVOKE ALL ON FUNCTION "public"."restock_product"("p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restock_product"("p_product_id" "uuid", "p_quantity" numeric, "p_quantity_unit" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."set_mobile_attendance_pairing_limit"("p_max_pairs" integer, "p_removal_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_mobile_attendance_pairing_limit"("p_max_pairs" integer, "p_removal_pin" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."set_mobile_attendance_pairing_password"("p_password" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_mobile_attendance_pairing_password"("p_password" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."staff_list_attendance"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_list_attendance"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."staff_list_own_product_sales"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_list_own_product_sales"() TO "authenticated";



REVOKE ALL ON FUNCTION "public"."staff_resolve_attendance_member"("p_identifier" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_resolve_attendance_member"("p_identifier" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."staff_search_members"("p_query" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_search_members"("p_query" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."submit_mobile_attendance_scan"("p_session_id" "uuid", "p_token" "text", "p_qr_payload" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."submit_mobile_attendance_scan"("p_session_id" "uuid", "p_token" "text", "p_qr_payload" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."submit_mobile_attendance_scan"("p_session_id" "uuid", "p_token" "text", "p_qr_payload" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."sync_auth_user_email"() FROM PUBLIC;



REVOKE ALL ON FUNCTION "public"."update_own_member_personal_info"("p_profile" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_own_member_personal_info"("p_profile" "jsonb") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."validate_mobile_attendance_scan_session"("p_session_id" "uuid", "p_token" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."validate_mobile_attendance_scan_session"("p_session_id" "uuid", "p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."validate_mobile_attendance_scan_session"("p_session_id" "uuid", "p_token" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."verify_mobile_attendance_pairing_password"("p_password" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verify_mobile_attendance_pairing_password"("p_password" "text") TO "authenticated";



REVOKE ALL ON FUNCTION "public"."verify_mobile_attendance_removal_pin"("p_pin" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."verify_mobile_attendance_removal_pin"("p_pin" "text") TO "authenticated";


















GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."activity_logs" TO "service_role";
GRANT SELECT ON TABLE "public"."activity_logs" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."attendance" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."attendance" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."members" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."members" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."membership_applications" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."membership_applications" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."membership_history" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."membership_history" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mobile_attendance_pairing_policy" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mobile_attendance_scan_events" TO "service_role";
GRANT SELECT,DELETE ON TABLE "public"."mobile_attendance_scan_events" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."mobile_attendance_scan_sessions" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."products" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."products" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."profiles" TO "service_role";
GRANT SELECT ON TABLE "public"."profiles" TO "authenticated";



GRANT SELECT("id") ON TABLE "public"."profiles" TO "service_role";



GRANT UPDATE("username") ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT("username"),UPDATE("username") ON TABLE "public"."profiles" TO "service_role";



GRANT UPDATE("full_name") ON TABLE "public"."profiles" TO "authenticated";
GRANT SELECT("full_name"),UPDATE("full_name") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("role"),UPDATE("role") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("created_at") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("email") ON TABLE "public"."profiles" TO "service_role";



GRANT SELECT("is_active"),UPDATE("is_active") ON TABLE "public"."profiles" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sale_items" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."sale_items" TO "authenticated";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales" TO "service_role";
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE "public"."sales" TO "authenticated";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";































drop extension if exists "pg_net";

revoke delete on table "public"."activity_logs" from "anon";

revoke insert on table "public"."activity_logs" from "anon";

revoke references on table "public"."activity_logs" from "anon";

revoke select on table "public"."activity_logs" from "anon";

revoke trigger on table "public"."activity_logs" from "anon";

revoke truncate on table "public"."activity_logs" from "anon";

revoke update on table "public"."activity_logs" from "anon";

revoke delete on table "public"."activity_logs" from "authenticated";

revoke insert on table "public"."activity_logs" from "authenticated";

revoke references on table "public"."activity_logs" from "authenticated";

revoke trigger on table "public"."activity_logs" from "authenticated";

revoke truncate on table "public"."activity_logs" from "authenticated";

revoke update on table "public"."activity_logs" from "authenticated";

revoke delete on table "public"."activity_logs" from "service_role";

revoke insert on table "public"."activity_logs" from "service_role";

revoke select on table "public"."activity_logs" from "service_role";

revoke update on table "public"."activity_logs" from "service_role";

revoke delete on table "public"."attendance" from "anon";

revoke insert on table "public"."attendance" from "anon";

revoke references on table "public"."attendance" from "anon";

revoke select on table "public"."attendance" from "anon";

revoke trigger on table "public"."attendance" from "anon";

revoke truncate on table "public"."attendance" from "anon";

revoke update on table "public"."attendance" from "anon";

revoke references on table "public"."attendance" from "authenticated";

revoke trigger on table "public"."attendance" from "authenticated";

revoke truncate on table "public"."attendance" from "authenticated";

revoke delete on table "public"."attendance" from "service_role";

revoke insert on table "public"."attendance" from "service_role";

revoke select on table "public"."attendance" from "service_role";

revoke update on table "public"."attendance" from "service_role";

revoke delete on table "public"."members" from "anon";

revoke insert on table "public"."members" from "anon";

revoke references on table "public"."members" from "anon";

revoke select on table "public"."members" from "anon";

revoke trigger on table "public"."members" from "anon";

revoke truncate on table "public"."members" from "anon";

revoke update on table "public"."members" from "anon";

revoke references on table "public"."members" from "authenticated";

revoke trigger on table "public"."members" from "authenticated";

revoke truncate on table "public"."members" from "authenticated";

revoke delete on table "public"."members" from "service_role";

revoke insert on table "public"."members" from "service_role";

revoke select on table "public"."members" from "service_role";

revoke update on table "public"."members" from "service_role";

revoke delete on table "public"."membership_applications" from "anon";

revoke insert on table "public"."membership_applications" from "anon";

revoke references on table "public"."membership_applications" from "anon";

revoke select on table "public"."membership_applications" from "anon";

revoke trigger on table "public"."membership_applications" from "anon";

revoke truncate on table "public"."membership_applications" from "anon";

revoke update on table "public"."membership_applications" from "anon";

revoke references on table "public"."membership_applications" from "authenticated";

revoke trigger on table "public"."membership_applications" from "authenticated";

revoke truncate on table "public"."membership_applications" from "authenticated";

revoke delete on table "public"."membership_applications" from "service_role";

revoke insert on table "public"."membership_applications" from "service_role";

revoke select on table "public"."membership_applications" from "service_role";

revoke update on table "public"."membership_applications" from "service_role";

revoke delete on table "public"."membership_history" from "anon";

revoke insert on table "public"."membership_history" from "anon";

revoke references on table "public"."membership_history" from "anon";

revoke select on table "public"."membership_history" from "anon";

revoke trigger on table "public"."membership_history" from "anon";

revoke truncate on table "public"."membership_history" from "anon";

revoke update on table "public"."membership_history" from "anon";

revoke references on table "public"."membership_history" from "authenticated";

revoke trigger on table "public"."membership_history" from "authenticated";

revoke truncate on table "public"."membership_history" from "authenticated";

revoke delete on table "public"."membership_history" from "service_role";

revoke insert on table "public"."membership_history" from "service_role";

revoke select on table "public"."membership_history" from "service_role";

revoke update on table "public"."membership_history" from "service_role";

revoke delete on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke insert on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke references on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke select on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke trigger on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke truncate on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke update on table "public"."mobile_attendance_pairing_policy" from "anon";

revoke delete on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke insert on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke references on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke select on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke trigger on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke truncate on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke update on table "public"."mobile_attendance_pairing_policy" from "authenticated";

revoke delete on table "public"."mobile_attendance_pairing_policy" from "service_role";

revoke insert on table "public"."mobile_attendance_pairing_policy" from "service_role";

revoke select on table "public"."mobile_attendance_pairing_policy" from "service_role";

revoke update on table "public"."mobile_attendance_pairing_policy" from "service_role";

revoke delete on table "public"."mobile_attendance_scan_events" from "anon";

revoke insert on table "public"."mobile_attendance_scan_events" from "anon";

revoke references on table "public"."mobile_attendance_scan_events" from "anon";

revoke select on table "public"."mobile_attendance_scan_events" from "anon";

revoke trigger on table "public"."mobile_attendance_scan_events" from "anon";

revoke truncate on table "public"."mobile_attendance_scan_events" from "anon";

revoke update on table "public"."mobile_attendance_scan_events" from "anon";

revoke insert on table "public"."mobile_attendance_scan_events" from "authenticated";

revoke references on table "public"."mobile_attendance_scan_events" from "authenticated";

revoke trigger on table "public"."mobile_attendance_scan_events" from "authenticated";

revoke truncate on table "public"."mobile_attendance_scan_events" from "authenticated";

revoke update on table "public"."mobile_attendance_scan_events" from "authenticated";

revoke delete on table "public"."mobile_attendance_scan_events" from "service_role";

revoke insert on table "public"."mobile_attendance_scan_events" from "service_role";

revoke select on table "public"."mobile_attendance_scan_events" from "service_role";

revoke update on table "public"."mobile_attendance_scan_events" from "service_role";

revoke delete on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke insert on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke references on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke select on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke trigger on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke truncate on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke update on table "public"."mobile_attendance_scan_sessions" from "anon";

revoke delete on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke insert on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke references on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke select on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke trigger on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke truncate on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke update on table "public"."mobile_attendance_scan_sessions" from "authenticated";

revoke delete on table "public"."mobile_attendance_scan_sessions" from "service_role";

revoke insert on table "public"."mobile_attendance_scan_sessions" from "service_role";

revoke select on table "public"."mobile_attendance_scan_sessions" from "service_role";

revoke update on table "public"."mobile_attendance_scan_sessions" from "service_role";

revoke delete on table "public"."products" from "anon";

revoke insert on table "public"."products" from "anon";

revoke references on table "public"."products" from "anon";

revoke select on table "public"."products" from "anon";

revoke trigger on table "public"."products" from "anon";

revoke truncate on table "public"."products" from "anon";

revoke update on table "public"."products" from "anon";

revoke references on table "public"."products" from "authenticated";

revoke trigger on table "public"."products" from "authenticated";

revoke truncate on table "public"."products" from "authenticated";

revoke delete on table "public"."products" from "service_role";

revoke insert on table "public"."products" from "service_role";

revoke select on table "public"."products" from "service_role";

revoke update on table "public"."products" from "service_role";

revoke delete on table "public"."profiles" from "anon";

revoke insert on table "public"."profiles" from "anon";

revoke references on table "public"."profiles" from "anon";

revoke select on table "public"."profiles" from "anon";

revoke trigger on table "public"."profiles" from "anon";

revoke truncate on table "public"."profiles" from "anon";

revoke update on table "public"."profiles" from "anon";

revoke delete on table "public"."profiles" from "authenticated";

revoke insert on table "public"."profiles" from "authenticated";

revoke references on table "public"."profiles" from "authenticated";

revoke trigger on table "public"."profiles" from "authenticated";

revoke truncate on table "public"."profiles" from "authenticated";

revoke update on table "public"."profiles" from "authenticated";

revoke delete on table "public"."profiles" from "service_role";

revoke insert on table "public"."profiles" from "service_role";

revoke select on table "public"."profiles" from "service_role";

revoke update on table "public"."profiles" from "service_role";

revoke delete on table "public"."sale_items" from "anon";

revoke insert on table "public"."sale_items" from "anon";

revoke references on table "public"."sale_items" from "anon";

revoke select on table "public"."sale_items" from "anon";

revoke trigger on table "public"."sale_items" from "anon";

revoke truncate on table "public"."sale_items" from "anon";

revoke update on table "public"."sale_items" from "anon";

revoke references on table "public"."sale_items" from "authenticated";

revoke trigger on table "public"."sale_items" from "authenticated";

revoke truncate on table "public"."sale_items" from "authenticated";

revoke delete on table "public"."sale_items" from "service_role";

revoke insert on table "public"."sale_items" from "service_role";

revoke select on table "public"."sale_items" from "service_role";

revoke update on table "public"."sale_items" from "service_role";

revoke delete on table "public"."sales" from "anon";

revoke insert on table "public"."sales" from "anon";

revoke references on table "public"."sales" from "anon";

revoke select on table "public"."sales" from "anon";

revoke trigger on table "public"."sales" from "anon";

revoke truncate on table "public"."sales" from "anon";

revoke update on table "public"."sales" from "anon";

revoke references on table "public"."sales" from "authenticated";

revoke trigger on table "public"."sales" from "authenticated";

revoke truncate on table "public"."sales" from "authenticated";

revoke delete on table "public"."sales" from "service_role";

revoke insert on table "public"."sales" from "service_role";

revoke select on table "public"."sales" from "service_role";

revoke update on table "public"."sales" from "service_role";

alter table "public"."members" drop constraint "members_status_check";

alter table "public"."products" drop constraint "products_category_unit_check";

alter table "public"."profiles" drop constraint "profiles_role_check";

alter table "public"."sale_items" drop constraint "sale_items_unit_check";

alter table "public"."members" add constraint "members_status_check" CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'expired'::character varying, 'suspended'::character varying, 'inactive'::character varying])::text[]))) not valid;

alter table "public"."members" validate constraint "members_status_check";

alter table "public"."products" add constraint "products_category_unit_check" CHECK (((((category)::text = 'supplement'::text) AND (((supplement_form = 'powder'::text) AND ((unit)::text = 'gram'::text)) OR ((supplement_form = 'drinkable'::text) AND ((unit)::text = 'milliliter'::text)) OR ((supplement_form = ANY (ARRAY['capsule'::text, 'tablet'::text])) AND ((unit)::text = ANY ((ARRAY['piece'::character varying, 'box'::character varying])::text[])) AND ((unit)::text = stock_unit)) OR ((supplement_form = 'other'::text) AND ((unit)::text = 'item'::text)))) OR (((category)::text = 'merchandise'::text) AND ((unit)::text = 'item'::text)))) not valid;

alter table "public"."products" validate constraint "products_category_unit_check";

alter table "public"."profiles" add constraint "profiles_role_check" CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'staff'::character varying, 'member'::character varying])::text[]))) not valid;

alter table "public"."profiles" validate constraint "profiles_role_check";

alter table "public"."sale_items" add constraint "sale_items_unit_check" CHECK (((unit)::text = ANY ((ARRAY['gram'::character varying, 'kilogram'::character varying, 'ounce'::character varying, 'pound'::character varying, 'milliliter'::character varying, 'liter'::character varying, 'fluid_ounce'::character varying, 'item'::character varying, 'piece'::character varying, 'box'::character varying, 'membership'::character varying])::text[]))) not valid;

alter table "public"."sale_items" validate constraint "sale_items_unit_check";

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

CREATE TRIGGER on_auth_user_email_updated AFTER UPDATE OF email ON auth.users FOR EACH ROW WHEN (((old.email)::text IS DISTINCT FROM (new.email)::text)) EXECUTE FUNCTION public.sync_auth_user_email();


