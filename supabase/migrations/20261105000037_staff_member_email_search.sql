-- Search staff member transactions by name or email only. The mobile number
-- remains in the RPC response for the server-side renewal integrity check.
begin;

create or replace function public.staff_search_members(p_query text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
revoke all on function public.staff_search_members(text) from public, anon;
grant execute on function public.staff_search_members(text) to authenticated;

notify pgrst, 'reload schema';
commit;
