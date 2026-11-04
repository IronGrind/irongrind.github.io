-- Include staff application sessions in the admin activity log and preserve
-- the authenticated operator identity across service-role walk-in creation.
begin;

create or replace function public.admin_log_session_event(p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
revoke all on function public.admin_log_session_event(text) from public, anon;
grant execute on function public.admin_log_session_event(text) to authenticated;

-- Edge calls this only after authenticating the user. The service-role-only
-- wrapper verifies an active operator, tags the transaction, then runs the
-- existing restricted member and payment writer.
create or replace function public.create_member_and_sale_with_actor(
    p_actor_id uuid,
    p_member jsonb,
    p_receipt_number text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
revoke all on function public.create_member_and_sale_with_actor(uuid, jsonb, text) from public, anon, authenticated;
grant execute on function public.create_member_and_sale_with_actor(uuid, jsonb, text) to service_role;

notify pgrst, 'reload schema';
commit;
