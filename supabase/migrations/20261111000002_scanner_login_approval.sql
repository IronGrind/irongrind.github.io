-- Scanner-to-scanner handoff only; website trust/MFA is unchanged.
create table private.scanner_login_approvals (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 requesting_session_id uuid not null references auth.sessions(id) on delete cascade unique,
 approver_session_id uuid references auth.sessions(id) on delete set null,
 device_label text not null,
 status text not null default 'pending' check(status in ('pending','approved','denied','cancelled','consumed')),
 requested_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '2 minutes'
);
alter table private.scanner_login_approvals enable row level security;
revoke all on private.scanner_login_approvals from public,anon,authenticated;

create function public.request_scanner_login_approval(p_device_label text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare target auth.sessions%rowtype; approver uuid; request private.scanner_login_approvals%rowtype;
begin
 select * into target from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
   and (not_after is null or not_after>now());
 if not found or not exists(select 1 from public.profiles where id=auth.uid() and is_active and role in ('admin','staff')) then
   raise exception 'Active staff or admin sign-in required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.user_id::text,817));
 if exists(select 1 from private.account_sessions where session_id=target.id and session_scope='dashboard')
 or exists(select 1 from private.admin_device_sessions where session_id=target.id) then raise exception 'Use a separate scanner sign-in'; end if;
 select * into request from private.scanner_login_approvals where requesting_session_id=target.id;
 if found and (request.status in ('denied','cancelled','consumed') or request.expires_at<=now()) then
   return jsonb_build_object('status',case when request.expires_at<=now() then 'expired' else request.status end); end if;
 select a.session_id into approver from private.account_sessions a join auth.sessions s on s.id=a.session_id and s.user_id=a.user_id
 where a.user_id=target.user_id and a.session_scope='attendance' and a.session_id<>target.id
 and (s.not_after is null or s.not_after>now());
 if approver is null then return jsonb_build_object('status','ready'); end if;
 if request.id is not null then
   if request.approver_session_id is distinct from approver then return jsonb_build_object('status','expired'); end if;
   return jsonb_build_object('status',request.status,'expires_at',request.expires_at);
 end if;
 insert into private.scanner_login_approvals(user_id,requesting_session_id,approver_session_id,device_label)
 values(target.user_id,target.id,approver,left(coalesce(nullif(btrim(p_device_label),''),'Another scanner'),180)) returning * into request;
 return jsonb_build_object('status','pending','expires_at',request.expires_at);
end;
$$;

create function public.list_scanner_login_approvals()
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.attendance_operator_is_current() then raise exception 'Active scanner session required'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'device_label',device_label,'requested_at',requested_at,'expires_at',expires_at) order by requested_at),'[]'::jsonb)
 from private.scanner_login_approvals where user_id=auth.uid() and approver_session_id::text=auth.jwt()->>'session_id'
 and status='pending' and expires_at>now());
end;
$$;
create function public.decide_scanner_login_approval(p_request_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare request private.scanner_login_approvals%rowtype;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 if not private.attendance_operator_is_current() or p_approve is null then raise exception 'Active scanner decision required'; end if;
 select * into request from private.scanner_login_approvals where id=p_request_id and user_id=auth.uid()
 and approver_session_id::text=auth.jwt()->>'session_id' for update;
 if not found or request.status<>'pending' or request.expires_at<=now() then raise exception 'Scanner request expired or unavailable'; end if;
 update private.scanner_login_approvals set status=case when p_approve then 'approved' else 'denied' end where id=request.id;
end;
$$;
create function public.cancel_scanner_login_approval()
returns void language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 update private.scanner_login_approvals set status='cancelled' where user_id=auth.uid()
 and requesting_session_id::text=auth.jwt()->>'session_id' and status in ('pending','approved');
end;
$$;
create function public.end_attendance_session()
returns void language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 delete from private.account_sessions where user_id=auth.uid() and session_scope='attendance' and session_id::text=auth.jwt()->>'session_id';
end;
$$;

-- Keep the original activation identity, downgrade and newer-session checks.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.activate_attendance_session()'::regprocedure);
 if position('insert into private.attendance_operator_sessions' in definition)=0 then raise exception 'Unexpected scanner activation'; end if;
 definition:=replace(definition,'insert into private.attendance_operator_sessions',
   E'if exists(select 1 from private.scanner_login_approvals where requesting_session_id=target.id and (status in (''denied'',''cancelled'',''consumed'') or expires_at<=now())) then raise exception ''SCANNER_APPROVAL_EXPIRED''; end if;\n if active.session_id is not null and active.session_id<>target.id and exists(select 1 from auth.sessions where id=active.session_id and (not_after is null or not_after>now())) and not exists(select 1 from private.scanner_login_approvals where user_id=target.user_id and requesting_session_id=target.id and approver_session_id=active.session_id and status=''approved'' and expires_at>now()) then raise exception ''SCANNER_APPROVAL_REQUIRED''; end if;\n update private.scanner_login_approvals set status=''consumed'' where requesting_session_id=target.id and status=''approved'';\n insert into private.attendance_operator_sessions');
 execute definition;
 definition:=pg_get_functiondef('public.enforce_account_session()'::regprocedure);
 if position('''/rpc/log_scanner_activity''' in definition)=0 then raise exception 'Unexpected scanner pre-request guard'; end if;
 definition:=replace(definition,'''/rpc/log_scanner_activity''',
   '''/rpc/log_scanner_activity'',''/rpc/request_scanner_login_approval'',''/rpc/list_scanner_login_approvals'',''/rpc/decide_scanner_login_approval'',''/rpc/cancel_scanner_login_approval'',''/rpc/end_attendance_session''');
 execute definition;
end;
$$;
revoke all on function public.request_scanner_login_approval(text),public.list_scanner_login_approvals(),public.decide_scanner_login_approval(uuid,boolean),public.cancel_scanner_login_approval(),public.end_attendance_session() from public,anon;
grant execute on function public.request_scanner_login_approval(text),public.list_scanner_login_approvals(),public.decide_scanner_login_approval(uuid,boolean),public.cancel_scanner_login_approval(),public.end_attendance_session() to authenticated;
notify pgrst,'reload schema';
