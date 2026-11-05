-- After five Manila business dates without a pending renewal request, mark
-- the member inactive and save the expired membership to membership_history.
begin;

create or replace function public.admin_capture_expired_memberships()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
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

revoke all on function public.admin_capture_expired_memberships() from public, anon;
grant execute on function public.admin_capture_expired_memberships() to authenticated;
drop function if exists public.admin_mark_members_inactive();

commit;

notify pgrst, 'reload schema';
