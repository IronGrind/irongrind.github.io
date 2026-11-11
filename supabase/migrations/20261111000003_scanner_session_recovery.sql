-- A visible scanner proves liveness through its existing status checks.
alter table private.attendance_operator_sessions add column last_seen_at timestamptz not null default now();
create or replace function public.current_attendance_session_is_active()
returns boolean language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 if not private.attendance_operator_is_current() then return false; end if;
 update private.attendance_operator_sessions set last_seen_at=now()
 where user_id=auth.uid() and session_id::text=auth.jwt()->>'session_id';
 return true;
end;
$$;

-- Explicit recovery, never an automatic approval on request timeout.
-- A recently live scanner still requires its own Approve/Deny decision.
create function public.recover_inactive_attendance_session()
returns void language plpgsql security definer set search_path='' as $$
declare target auth.sessions%rowtype; active uuid; seen timestamptz;
begin
 select * into target from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
 and (not_after is null or not_after>now());
 if not found or not exists(select 1 from public.profiles where id=auth.uid() and is_active and role in ('admin','staff')) then
   raise exception 'Active staff or admin sign-in required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.user_id::text,817));
 select a.session_id,coalesce(o.last_seen_at,a.session_created_at) into active,seen
 from private.account_sessions a left join private.attendance_operator_sessions o on o.session_id=a.session_id
 where a.user_id=target.user_id and a.session_scope='attendance';
 if active=target.id then perform public.activate_attendance_session(); return; end if;
 if active is not null and seen>now()-interval '2 minutes' then raise exception 'SCANNER_STILL_ACTIVE'; end if;
 if exists(select 1 from private.scanner_login_approvals where requesting_session_id=target.id and status in ('denied','cancelled','consumed')) then
   raise exception 'Scanner request ended. Sign in again'; end if;
 if active is not null then
   insert into private.scanner_login_approvals(user_id,requesting_session_id,approver_session_id,device_label,status,expires_at)
   values(target.user_id,target.id,active,'Explicit inactive scanner recovery','approved',now()+interval '2 minutes')
   on conflict(requesting_session_id) do update set approver_session_id=excluded.approver_session_id,status='approved',expires_at=excluded.expires_at;
 end if;
 perform public.activate_attendance_session();
 insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
 select id,coalesce(full_name,'Operator'),role,'scanner_session_recovered','session',target.id::text,
 'Explicitly recovered an attendance session after the previous scanner stopped reporting activity for at least two minutes.'
 from public.profiles where id=target.user_id;
end;
$$;
revoke all on function public.recover_inactive_attendance_session() from public,anon;
grant execute on function public.recover_inactive_attendance_session() to authenticated;
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.enforce_account_session()'::regprocedure);
 if position('''/rpc/end_attendance_session''' in definition)=0 then raise exception 'Unexpected scanner request guard'; end if;
 execute replace(definition,'''/rpc/end_attendance_session''','''/rpc/end_attendance_session'',''/rpc/recover_inactive_attendance_session''');
end;
$$;
notify pgrst,'reload schema';
