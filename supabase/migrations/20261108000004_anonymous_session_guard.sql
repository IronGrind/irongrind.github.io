-- Keep the private permission check inside an authenticated-only PL/pgSQL block.
-- A single SQL AND expression can check function privileges for anon too.
do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.enforce_account_session()'::regprocedure);
  if position('and not private.account_session_is_current() then' in definition)>0 then
    definition:=replace(definition,'and not private.account_session_is_current() then',
      E'then\n        if not private.account_session_is_current() then');
    definition:=replace(definition,'message=''ACCOUNT_SESSION_REPLACED'';',
      E'message=''ACCOUNT_SESSION_REPLACED'';\n        end if;');
    execute definition;
  end if;
end;
$$;
notify pgrst,'reload schema';
