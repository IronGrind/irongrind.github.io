create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and is_active);
$$;

-- The current baseline uses numeric amounts for members.paid. Remove the
-- obsolete Boolean-schema branch, which is invalid against this database.
do $$
declare definition text; paid_type text;
begin
  select data_type into paid_type from information_schema.columns
    where table_schema='public' and table_name='members' and column_name='paid';
  if paid_type<>'numeric' then raise exception 'Expected numeric members.paid; review migration before applying'; end if;
  definition:=pg_get_functiondef('public.admin_record_membership_change(uuid,text,text,numeric,date,date,text,text,text)'::regprocedure);
  definition:=regexp_replace(definition,
    'select data_type into paid_type from information_schema.columns[\s\S]*?end if;',
    'update public.members set paid = p_new_price where id = member_row.id;');
  definition:=replace(definition,'    paid_type text;','');
  execute definition;
end;
$$;
notify pgrst,'reload schema';
