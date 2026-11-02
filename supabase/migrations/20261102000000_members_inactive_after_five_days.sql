-- Mark memberships inactive once they have been expired for five full
-- Manila business dates. The admin dashboard invokes this when it loads.
begin;

create or replace function public.admin_mark_members_inactive()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    updated_count integer;
    business_date date := (now() at time zone 'Asia/Manila')::date;
begin
    if not (select private.is_admin()) then
        raise exception 'Admin access required';
    end if;

    update public.members
    set status = 'inactive', updated_at = now()
    where status in ('active', 'expired')
      and expiry_date <= business_date - 5;

    get diagnostics updated_count = row_count;
    return updated_count;
end;
$$;

revoke all on function public.admin_mark_members_inactive() from public, anon;
grant execute on function public.admin_mark_members_inactive() to authenticated;

commit;

notify pgrst, 'reload schema';
