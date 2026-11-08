-- Reject new person-name values containing digits while preserving existing
-- legacy records for review or correction. Names may contain Unicode letters,
-- spaces, and ordinary punctuation.
create or replace function private.is_valid_person_name(value text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select value is not null
    and pg_catalog.char_length(pg_catalog.btrim(value)) between 1 and 150
    and value ~ '[[:alpha:]]'
    and value !~ '[0-9]';
$$;

create or replace function private.validate_person_name_record()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  row_data jsonb := pg_catalog.to_jsonb(new);
  full_name text := row_data ->> 'full_name';
  emergency_data jsonb;
  emergency_name text;
begin
  if not private.is_valid_person_name(full_name) then
    raise exception 'Name must contain letters, must not contain numbers, and must be at most 150 characters.';
  end if;

  if tg_table_name = 'membership_applications' then
    emergency_data := row_data -> 'emergency_contact_data';
  elsif tg_table_name = 'members' then
    emergency_data := row_data -> 'emergency_contact';
  end if;

  emergency_name := emergency_data ->> 'name';
  if nullif(pg_catalog.btrim(emergency_name), '') is not null
     and not private.is_valid_person_name(emergency_name) then
    raise exception 'Emergency contact name must contain letters and must not contain numbers.';
  end if;

  return new;
end;
$$;

drop trigger if exists profiles_validate_person_name on public.profiles;
create trigger profiles_validate_person_name
before insert or update of full_name on public.profiles
for each row execute function private.validate_person_name_record();

drop trigger if exists members_validate_person_name on public.members;
create trigger members_validate_person_name
before insert or update of full_name, emergency_contact on public.members
for each row execute function private.validate_person_name_record();

drop trigger if exists membership_applications_validate_person_name on public.membership_applications;
create trigger membership_applications_validate_person_name
before insert or update of full_name, emergency_contact_data on public.membership_applications
for each row execute function private.validate_person_name_record();

revoke all on function private.is_valid_person_name(text) from public, anon, authenticated;
revoke all on function private.validate_person_name_record() from public, anon, authenticated;
