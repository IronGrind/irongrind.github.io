-- Preserve existing names; fail safely if legacy case/space collisions need review.
create unique index if not exists profiles_username_normalized_unique
on public.profiles (lower(btrim(username))) where nullif(btrim(username),'') is not null;

create or replace function private.normalize_profile_username()
returns trigger language plpgsql set search_path='' as $$
begin
  new.username := nullif(lower(btrim(new.username)), '');
  return new;
end;
$$;
drop trigger if exists normalize_profile_username on public.profiles;
create trigger normalize_profile_username before insert or update of username on public.profiles
for each row execute function private.normalize_profile_username();

create or replace function public.is_registration_username_available(p_username text)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(btrim(p_username) ~ '^[A-Za-z0-9_.]{3,30}$'
    and not exists(select 1 from public.profiles where lower(btrim(username))=lower(btrim(p_username))),false);
$$;
revoke all on function public.is_registration_username_available(text) from public;
grant execute on function public.is_registration_username_available(text) to anon, authenticated, service_role;
