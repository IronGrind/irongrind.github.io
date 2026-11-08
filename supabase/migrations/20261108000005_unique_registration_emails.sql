create unique index if not exists profiles_email_normalized_unique
on public.profiles(lower(btrim(email))) where nullif(btrim(email),'') is not null;

create or replace function public.is_registration_email_available(p_email text)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(length(btrim(p_email)) between 3 and 254
    and btrim(p_email) ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    and not exists(select 1 from auth.users where lower(btrim(email))=lower(btrim(p_email)))
    and not exists(select 1 from public.profiles where lower(btrim(email))=lower(btrim(p_email))),false);
$$;
revoke all on function public.is_registration_email_available(text) from public;
grant execute on function public.is_registration_email_available(text) to anon,authenticated,service_role;
