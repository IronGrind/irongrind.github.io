-- Check registration usernames before creating an Auth user. The result is a
-- boolean only; the function does not expose profile rows or account details.

create or replace function public.is_registration_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
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
$$;

revoke all on function public.is_registration_username_available(text)
    from public, anon, authenticated;
grant execute on function public.is_registration_username_available(text)
    to anon, authenticated;

notify pgrst, 'reload schema';
