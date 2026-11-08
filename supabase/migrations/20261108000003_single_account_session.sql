create table if not exists private.account_sessions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  session_id uuid not null,
  session_created_at timestamptz not null
);
alter table private.account_sessions enable row level security;
revoke all on private.account_sessions from public, anon, authenticated;

create or replace function private.account_session_is_current()
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from auth.sessions s
    where s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
      and (s.not_after is null or s.not_after>now())
      and not exists(select 1 from private.account_sessions a
        where a.user_id=s.user_id and a.session_id<>s.id)
  );
$$;
revoke all on function private.account_session_is_current() from public, anon;
grant execute on function private.account_session_is_current() to authenticated;

create or replace function public.current_account_session_is_active()
returns boolean language sql stable security definer set search_path='' as $$
  select private.account_session_is_current();
$$;

create or replace function public.activate_account_session()
returns void language plpgsql security definer set search_path='' as $$
declare
  session_row auth.sessions%rowtype;
  active_row private.account_sessions%rowtype;
begin
  select * into session_row from auth.sessions
    where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
      and (not_after is null or not_after>now());
  if not found then raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(session_row.user_id::text, 817));
  select * into active_row from private.account_sessions where user_id=session_row.user_id;
  if found and active_row.session_id<>session_row.id and
    (active_row.session_created_at,active_row.session_id)>=(session_row.created_at,session_row.id) then
    raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED';
  end if;
  insert into private.account_sessions(user_id,session_id,session_created_at)
    values(session_row.user_id,session_row.id,session_row.created_at)
    on conflict(user_id) do update set session_id=excluded.session_id,session_created_at=excluded.session_created_at;
end;
$$;
revoke all on function public.activate_account_session() from public, anon;
revoke all on function public.current_account_session_is_active() from public, anon;
grant execute on function public.activate_account_session(), public.current_account_session_is_active() to authenticated;

-- RLS covers table reads, writes and Realtime authorization.
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname='public' loop
    execute format('drop policy if exists account_session_required on public.%I',t.tablename);
    execute format('create policy account_session_required on public.%I as restrictive for all to authenticated using ((select private.account_session_is_current())) with check ((select private.account_session_is_current()))',t.tablename);
  end loop;
end;
$$;

-- Pre-request validation also covers SECURITY DEFINER RPCs, which bypass RLS.
-- Preserve a previously configured hook rather than silently replacing it.
do $install$
declare old_hook text; old_call text := '';
begin
  select substr(setting,length('pgrst.db_pre_request=')+1) into old_hook
    from pg_db_role_setting s, unnest(s.setconfig) setting
    where s.setrole=(select oid from pg_roles where rolname='authenticator')
      and s.setdatabase=0 and setting like 'pgrst.db_pre_request=%';
  if old_hook='public.enforce_account_session' then return; end if;
  if nullif(old_hook,'') is not null then old_call:=format('perform %s();',old_hook::regproc); end if;
  execute format($function$
    create or replace function public.enforce_account_session() returns void
    language plpgsql set search_path='' as $body$
    begin
      %s
      if auth.role()='authenticated'
        and coalesce(current_setting('request.path',true),'') not in
          ('/rpc/activate_account_session','/rpc/current_account_session_is_active')
        and not private.account_session_is_current() then
        raise sqlstate 'PT401' using message='ACCOUNT_SESSION_REPLACED';
      end if;
    end;
    $body$;
  $function$,old_call);
end;
$install$;
grant execute on function public.enforce_account_session() to anon, authenticated, service_role;
alter role authenticator set pgrst.db_pre_request='public.enforce_account_session';
notify pgrst,'reload config';
