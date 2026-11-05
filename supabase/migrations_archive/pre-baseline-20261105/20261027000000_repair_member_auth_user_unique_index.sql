-- Ensure each Supabase Auth user can be linked to at most one member.
-- The prior cleanup migration may encounter a regular index with the same
-- name; replace it only after checking that existing rows satisfy uniqueness.

begin;

do $$
begin
    if exists (
        select 1
        from public.members
        where auth_user_id is not null
        group by auth_user_id
        having count(*) > 1
    ) then
        raise exception 'Cannot enforce one member per Auth user: duplicate auth_user_id values exist in public.members.';
    end if;
end;
$$;

drop index if exists public.members_auth_user_id_uidx;

create unique index members_auth_user_id_uidx
    on public.members (auth_user_id)
    where auth_user_id is not null;

commit;

-- Refresh PostgREST's view of the existing sale_items_sale_id_fkey relation.
notify pgrst, 'reload schema';
