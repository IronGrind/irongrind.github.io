-- Keep the legacy boolean compatibility branch valid on numeric-paid databases.
-- Replaces function text only; no membership or payment rows are changed.
begin;
do $$
declare
    target regprocedure := to_regprocedure('public.admin_record_membership_change(uuid,text,text,numeric,date,date,text,text,text)');
    definition text;
begin
    if target is null then return; end if;
    select pg_get_functiondef(target) into definition;
    if position('update public.members set paid = true where id = member_row.id;' in definition) > 0 then
        execute replace(definition,
            'update public.members set paid = true where id = member_row.id;',
            'execute ''update public.members set paid = $1 where id = $2'' using true, member_row.id;');
    end if;
end;
$$;
notify pgrst, 'reload schema';
commit;
