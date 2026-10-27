-- Allow authenticated users to select membership history rows permitted by
-- the RLS policy. Admins can read all rows; members can read their own.

begin;

create schema if not exists private;

-- Ensure the policy helper exists even if the earlier base-schema migration
-- was only partially applied to this Supabase project.
create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.profiles
        where id = (select auth.uid())
          and role = 'admin'
    );
$$;

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
