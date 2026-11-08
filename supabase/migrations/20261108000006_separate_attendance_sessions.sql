-- Keep one dashboard session and one attendance-scanner session per account.
alter table private.account_sessions add column if not exists session_scope text not null default 'dashboard';
alter table private.account_sessions drop constraint account_sessions_pkey;
alter table private.account_sessions add primary key(user_id,session_scope);
alter table private.account_sessions add constraint account_sessions_scope_check check(session_scope in ('dashboard','attendance'));

create or replace function private.account_session_is_current()
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from auth.sessions s
    where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
      and (s.not_after is null or s.not_after>now())
      and (not exists(select 1 from private.account_sessions a where a.user_id=s.user_id)
        or exists(select 1 from private.account_sessions a where a.user_id=s.user_id and a.session_id=s.id)));
$$;

do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.activate_account_session()'::regprocedure);
  definition:=replace(definition,'where user_id=session_row.user_id;', 'where user_id=session_row.user_id and session_scope=''dashboard'';');
  definition:=replace(definition,'on conflict(user_id)', 'on conflict(user_id,session_scope)');
  execute definition;
end;
$$;

create or replace function public.activate_attendance_session()
returns void language plpgsql security definer set search_path='' as $$
declare
  session_row auth.sessions%rowtype;
  active_row private.account_sessions%rowtype;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and is_active and role in ('staff','admin')) then
    raise exception 'Active staff or admin access required';
  end if;
  select * into session_row from auth.sessions
    where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
      and (not_after is null or not_after>now());
  if not found then raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(session_row.user_id::text,817));
  select * into active_row from private.account_sessions where user_id=session_row.user_id and session_scope='attendance';
  if found and active_row.session_id<>session_row.id and
    (active_row.session_created_at,active_row.session_id)>=(session_row.created_at,session_row.id) then
    raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED';
  end if;
  insert into private.account_sessions(user_id,session_id,session_created_at,session_scope)
    values(session_row.user_id,session_row.id,session_row.created_at,'attendance')
    on conflict(user_id,session_scope) do update set session_id=excluded.session_id,session_created_at=excluded.session_created_at;
end;
$$;
revoke all on function public.activate_attendance_session() from public,anon;
grant execute on function public.activate_attendance_session() to authenticated;

do $$
declare definition text;
begin
  definition:=pg_get_functiondef('public.enforce_account_session()'::regprocedure);
  definition:=replace(definition,'''/rpc/activate_account_session'',', '''/rpc/activate_account_session'',''/rpc/activate_attendance_session'',');
  execute definition;
end;
$$;
notify pgrst,'reload schema';
