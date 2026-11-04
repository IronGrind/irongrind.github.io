-- Add named staff accounts with attendance-only data access. Staff identities
-- are individual Auth users; admins retain control over all other operations.
begin;

alter table public.profiles
    add column if not exists is_active boolean not null default true;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
    add constraint profiles_role_check check (role in ('admin', 'staff', 'member'));

create or replace function private.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from public.profiles
        where id = (select auth.uid()) and role = 'staff' and is_active
    );
$$;
revoke all on function private.is_staff() from public, anon;
grant execute on function private.is_staff() to authenticated;

drop policy if exists staff_read_attendance on public.attendance;
create policy staff_read_attendance on public.attendance
    for select to authenticated
    using ((select private.is_staff()));

drop policy if exists staff_insert_attendance on public.attendance;
create policy staff_insert_attendance on public.attendance
    for insert to authenticated
    with check ((select private.is_staff()) and recorded_by = (select auth.uid()));

drop policy if exists staff_update_attendance on public.attendance;
create policy staff_update_attendance on public.attendance
    for update to authenticated
    using ((select private.is_staff()))
    with check ((select private.is_staff()));

create or replace function public.staff_resolve_attendance_member(p_identifier text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

create or replace function public.staff_list_attendance()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke all on function public.staff_resolve_attendance_member(text) from public, anon;
grant execute on function public.staff_resolve_attendance_member(text) to authenticated;
revoke all on function public.staff_list_attendance() from public, anon;
grant execute on function public.staff_list_attendance() to authenticated;

notify pgrst, 'reload schema';
commit;
