-- Allow authenticated users to select membership history rows permitted by
-- the RLS policy. Admins can read all rows; members can read their own.

begin;

alter table public.membership_history enable row level security;

revoke all on table public.membership_history from public, anon;
grant select on table public.membership_history to authenticated;

grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

drop policy if exists "membership_history_read_member_or_admin"
    on public.membership_history;
create policy "membership_history_read_member_or_admin"
    on public.membership_history
    for select
    to authenticated
    using (
        (select private.is_admin())
        or exists (
            select 1
            from public.members m
            where m.id = membership_history.member_id
              and m.auth_user_id = (select auth.uid())
        )
    );

commit;

notify pgrst, 'reload schema';
