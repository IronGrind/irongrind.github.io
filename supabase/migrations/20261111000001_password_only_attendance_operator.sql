-- Password-only scanner sessions are deliberately not trusted website sessions.
create table private.attendance_operator_sessions (
 session_id uuid primary key references auth.sessions(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade
);
alter table private.attendance_operator_sessions enable row level security;
revoke all on private.attendance_operator_sessions from public,anon,authenticated;

create function private.is_attendance_operator_session()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.attendance_operator_sessions where user_id=auth.uid() and session_id::text=auth.jwt()->>'session_id');
$$;
revoke all on function private.is_attendance_operator_session() from public,anon;
grant execute on function private.is_attendance_operator_session() to authenticated;

create or replace function private.attendance_operator_is_current()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.attendance_operator_sessions o
 join private.account_sessions a on a.session_id=o.session_id and a.user_id=o.user_id and a.session_scope='attendance'
 join auth.sessions s on s.id=o.session_id and s.user_id=o.user_id
 join public.profiles p on p.id=o.user_id
 where o.user_id=auth.uid() and o.session_id::text=auth.jwt()->>'session_id'
 and (s.not_after is null or s.not_after>now()) and p.is_active and p.role in ('admin','staff'));
$$;
revoke all on function private.attendance_operator_is_current() from public,anon;
grant execute on function private.attendance_operator_is_current() to authenticated;

create or replace function public.activate_attendance_session()
returns void language plpgsql security definer set search_path='' as $$
declare target auth.sessions%rowtype; active private.account_sessions%rowtype;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and is_active and role in ('admin','staff')) then
   raise exception 'Active staff or admin access required'; end if;
 select * into target from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
   and (not_after is null or not_after>now());
 if not found then raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.user_id::text,817));
 -- Never downgrade a website session or turn a device challenge into scanner access.
 if exists(select 1 from private.account_sessions where session_id=target.id and session_scope='dashboard')
 or exists(select 1 from private.admin_device_sessions where session_id=target.id) then
   raise exception 'Use a separate sign-in for the attendance scanner'; end if;
 select * into active from private.account_sessions where user_id=target.user_id and session_scope='attendance';
 if found and active.session_id<>target.id and (active.session_created_at,active.session_id)>=(target.created_at,target.id) then
   raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED'; end if;
 insert into private.attendance_operator_sessions values(target.id,target.user_id) on conflict do nothing;
 insert into private.account_sessions(user_id,session_id,session_created_at,session_scope)
 values(target.user_id,target.id,target.created_at,'attendance')
 on conflict(user_id,session_scope) do update set session_id=excluded.session_id,session_created_at=excluded.session_created_at;
end;
$$;

create function public.current_attendance_session_is_active()
returns boolean language sql stable security definer set search_path='' as $$
 select private.attendance_operator_is_current();
$$;
create function public.get_attendance_operator()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.attendance_operator_is_current() then raise exception 'Active scanner session required'; end if;
 return (select jsonb_build_object('id',id,'full_name',full_name) from public.profiles where id=auth.uid());
end;
$$;
create function public.record_scanner_attendance(p_identifier text,p_request_id uuid,p_session_id uuid,p_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.attendance_operator_is_current() then raise exception 'Active scanner session required'; end if;
 if p_session_id is null or nullif(p_token,'') is null then raise exception 'Phone pairing is required'; end if;
 return public.record_attendance_scan(p_identifier,p_request_id,p_session_id,p_token);
end;
$$;
create function public.log_scanner_activity(p_event text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not private.attendance_operator_is_current() then raise exception 'Active scanner session required'; end if;
 if p_event not in ('scanner_signed_in','scanner_sign_out_requested') or p_event is null then raise exception 'Unsupported scanner event'; end if;
 perform public.log_account_activity(p_event);
end;
$$;
revoke all on function public.current_attendance_session_is_active(),public.get_attendance_operator(),public.record_scanner_attendance(text,uuid,uuid,text),public.log_scanner_activity(text) from public,anon;
grant execute on function public.current_attendance_session_is_active(),public.get_attendance_operator(),public.record_scanner_attendance(text,uuid,uuid,text),public.log_scanner_activity(text) to authenticated;

-- Scanner credentials cannot read protected tables (including Realtime RLS).
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('private.account_session_is_current()'::regprocedure);
 if position('select private.admin_mfa_satisfied()' in definition)=0 then raise exception 'Unexpected session guard'; end if;
 definition:=replace(definition,'select private.admin_mfa_satisfied()',
   'select not exists(select 1 from private.attendance_operator_sessions where user_id=auth.uid() and session_id::text=auth.jwt()->>''session_id'') and private.admin_mfa_satisfied()');
 execute definition;
 -- Preserve earlier pre-request hooks; bypass website security only for these
 -- narrow scanner RPCs, whose bodies validate identity and scanner scope.
 definition:=replace(pg_get_functiondef('public.enforce_account_session()'::regprocedure),chr(13),'');
 definition:=replace(definition,E'begin\n',E'begin\n  if auth.role()=''authenticated'' then\n    if coalesce(current_setting(''request.path'',true),'''') in (''/rpc/activate_attendance_session'',''/rpc/current_attendance_session_is_active'',''/rpc/get_attendance_operator'',''/rpc/record_scanner_attendance'',''/rpc/log_scanner_activity'') then return; end if;\n    if private.is_attendance_operator_session() then raise sqlstate ''PT403'' using message=''SCANNER_ACCESS_ONLY''; end if;\n  end if;\n');
 execute definition;
 -- Website enrollment/forget must not retire independent scanner access.
 definition:=pg_get_functiondef('public.finish_admin_device_login(uuid,uuid,text,boolean,text)'::regprocedure);
 definition:=replace(definition,'delete from private.account_sessions where user_id=p_user;',
   'delete from private.account_sessions where user_id=p_user and session_scope=''dashboard'';');
 execute definition;
 definition:=pg_get_functiondef('public.forget_admin_trusted_device()'::regprocedure);
 definition:=replace(definition,'delete from private.account_sessions where user_id=auth.uid();',
   'delete from private.account_sessions where user_id=auth.uid() and session_scope=''dashboard'';');
 execute definition;
end;
$$;
notify pgrst,'reload schema';
