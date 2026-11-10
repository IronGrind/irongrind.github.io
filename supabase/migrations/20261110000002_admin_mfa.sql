-- Admin MFA is enforced on the server, including session activation and RLS.
-- Bootstrap exposes only whether the caller's own active account is an admin.
create or replace function public.admin_mfa_required()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and is_active);
$$;
revoke all on function public.admin_mfa_required() from public,anon;
grant execute on function public.admin_mfa_required() to authenticated;

create or replace function private.admin_mfa_satisfied()
returns boolean language sql stable security definer set search_path='' as $$
 select not public.admin_mfa_required() or coalesce(auth.jwt()->>'aal','aal1')='aal2';
$$;
revoke all on function private.admin_mfa_satisfied() from public,anon;
grant execute on function private.admin_mfa_satisfied() to authenticated;

create or replace function private.require_admin_mfa()
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if not private.admin_mfa_satisfied() then
   raise sqlstate 'PT403' using message='ADMIN_MFA_REQUIRED';
 end if;
end;
$$;
revoke all on function private.require_admin_mfa() from public,anon;
grant execute on function private.require_admin_mfa() to authenticated;

do $$
declare definition text; name text;
begin
 definition:=replace(pg_get_functiondef('private.account_session_is_current()'::regprocedure),chr(13),'');
 if position('private.admin_mfa_satisfied()' in definition)=0 then
   if position('select exists' in definition)=0 then raise exception 'Unexpected session guard definition'; end if;
   definition:=replace(definition,'select exists','select private.admin_mfa_satisfied() and exists');
   execute definition;
 end if;
 foreach name in array array['activate_account_session','activate_attendance_session'] loop
   definition:=replace(pg_get_functiondef(('public.'||name||'()')::regprocedure),chr(13),'');
   if position('private.require_admin_mfa()' in definition)=0 then
     if position(E'begin\n' in definition)=0 then raise exception 'Unexpected activation definition'; end if;
     definition:=replace(definition,E'begin\n',E'begin\n  perform private.require_admin_mfa();\n');
     execute definition;
   end if;
 end loop;
 definition:=replace(pg_get_functiondef('public.enforce_account_session()'::regprocedure),chr(13),'');
 if position('ADMIN_MFA_BOOTSTRAP' in definition)=0 then
   if position(E'begin\n' in definition)=0 then raise exception 'Unexpected pre-request definition'; end if;
   definition:=replace(definition,E'begin\n',E'begin\n  -- ADMIN_MFA_BOOTSTRAP\n  if auth.role()=''authenticated'' then\n    if coalesce(current_setting(''request.path'',true),'''')=''/rpc/admin_mfa_required'' then return; end if;\n    perform private.require_admin_mfa();\n  end if;\n');
   execute definition;
 end if;
end;
$$;
notify pgrst,'reload schema';
