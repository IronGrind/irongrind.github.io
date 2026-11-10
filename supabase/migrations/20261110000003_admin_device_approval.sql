create table if not exists private.admin_login_approvals (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 requesting_session_id uuid not null references auth.sessions(id) on delete cascade,
 approver_session_id uuid references auth.sessions(id) on delete set null,
 session_scope text not null check(session_scope in ('dashboard','attendance')),
 device_label text not null,
 status text not null default 'pending' check(status in ('pending','approved','denied','cancelled')),
 requested_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '2 minutes',
 decided_at timestamptz,
 approval_expires_at timestamptz,
 unique(requesting_session_id,session_scope)
);
alter table private.admin_login_approvals enable row level security;
revoke all on private.admin_login_approvals from public,anon,authenticated;

create or replace function private.admin_mfa_satisfied()
returns boolean language sql stable security definer set search_path='' as $$
 select not public.admin_mfa_required() or coalesce(auth.jwt()->>'aal','aal1')='aal2'
 or exists(select 1 from private.admin_login_approvals a join auth.sessions s on s.id=a.requesting_session_id
   where a.user_id=auth.uid() and s.user_id=auth.uid() and s.id::text=auth.jwt()->>'session_id'
     and a.status='approved' and a.approval_expires_at>now() and (s.not_after is null or s.not_after>now()));
$$;
create or replace function private.is_admin()
returns boolean language sql stable security definer set search_path='' as $$
 select public.admin_mfa_required() and private.admin_mfa_satisfied();
$$;

create or replace function public.request_admin_login_approval(p_scope text,p_device_label text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare target auth.sessions%rowtype; approver uuid; request private.admin_login_approvals%rowtype;
begin
 if not public.admin_mfa_required() then raise exception 'Active administrator required'; end if;
 if p_scope is null or p_scope not in ('dashboard','attendance') then raise exception 'Invalid session scope'; end if;
 select * into target from auth.sessions where user_id=auth.uid() and id::text=auth.jwt()->>'session_id'
   and (not_after is null or not_after>now());
 if not found then raise exception 'Valid sign-in session required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(target.user_id::text,817));
 select * into request from private.admin_login_approvals where requesting_session_id=target.id and session_scope=p_scope;
 if found then
   return jsonb_build_object('status',case when request.status='approved' and request.approval_expires_at<=now() then 'expired'
     when request.status='pending' and request.expires_at<=now() then 'expired' else request.status end,
     'request_id',request.id,'expires_at',request.expires_at);
 end if;
 -- Only an already active application session may approve. Prefer the dashboard.
 select s.id into approver from private.account_sessions a join auth.sessions s on s.id=a.session_id
 where a.user_id=target.user_id and s.user_id=target.user_id and s.id<>target.id
   and (s.not_after is null or s.not_after>now())
   and (s.aal::text='aal2' or exists(select 1 from private.admin_login_approvals prior
     where prior.requesting_session_id=s.id and prior.user_id=target.user_id and prior.status='approved' and prior.approval_expires_at>now()))
 order by case a.session_scope when 'dashboard' then 0 else 1 end limit 1;
 if approver is null then return jsonb_build_object('status','mfa_required'); end if;
 insert into private.admin_login_approvals(user_id,requesting_session_id,approver_session_id,session_scope,device_label)
 values(target.user_id,target.id,approver,p_scope,left(coalesce(nullif(btrim(p_device_label),''),'Unspecified browser'),180)) returning * into request;
 insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
 values(null,'Unverified sign-in','unverified','admin_login_approval_requested','security',request.id::text,
   'Requested approval from an active administrator session.');
 return jsonb_build_object('status','pending','request_id',request.id,'expires_at',request.expires_at);
end;
$$;

create or replace function public.list_admin_login_approvals()
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not private.is_admin() or not private.account_session_is_current() then raise exception 'Verified active administrator required'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',id,'device_label',device_label,'session_scope',session_scope,
   'requested_at',requested_at,'expires_at',expires_at) order by requested_at),'[]'::jsonb)
   from private.admin_login_approvals where user_id=auth.uid() and approver_session_id::text=auth.jwt()->>'session_id'
     and status='pending' and expires_at>now());
end;
$$;

create or replace function public.decide_admin_login_approval(p_request_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare request private.admin_login_approvals%rowtype; display text;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 if not private.is_admin() or not private.account_session_is_current() then raise exception 'Verified active administrator required'; end if;
 if p_approve is null then raise exception 'Decision required'; end if;
 select * into request from private.admin_login_approvals where id=p_request_id and user_id=auth.uid()
   and approver_session_id::text=auth.jwt()->>'session_id' for update;
 if not found or request.status<>'pending' or request.expires_at<=now() then raise exception 'Request unavailable or expired'; end if;
 if not exists(select 1 from auth.sessions where id=request.requesting_session_id and user_id=request.user_id
   and (not_after is null or not_after>now())) then raise exception 'Requesting session ended'; end if;
 update private.admin_login_approvals set status=case when p_approve then 'approved' else 'denied' end,decided_at=now(),
   approval_expires_at=case when p_approve then now()+interval '8 hours' else null end where id=request.id;
 select full_name into display from public.profiles where id=auth.uid();
 insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
 values(auth.uid(),coalesce(display,'Administrator'),'admin',case when p_approve then 'admin_login_approved' else 'admin_login_denied' end,
 'security',request.id::text,'Decided a session-bound administrator login request.');
end;
$$;

create or replace function public.cancel_admin_login_approval(p_scope text)
returns void language plpgsql security definer set search_path='' as $$
begin
 update private.admin_login_approvals set status='cancelled',decided_at=now()
 where user_id=auth.uid() and requesting_session_id::text=auth.jwt()->>'session_id' and session_scope=p_scope and status in ('pending','approved')
   and not exists(select 1 from private.account_sessions active where active.user_id=auth.uid()
     and active.session_id::text=auth.jwt()->>'session_id' and active.session_scope=p_scope);
end;
$$;

create or replace function private.require_admin_login_scope(p_scope text)
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if public.admin_mfa_required() and coalesce(auth.jwt()->>'aal','aal1')<>'aal2' and not exists(
   select 1 from private.admin_login_approvals where user_id=auth.uid() and requesting_session_id::text=auth.jwt()->>'session_id'
   and session_scope=p_scope and status='approved' and approval_expires_at>now()) then
   raise sqlstate 'PT403' using message='ADMIN_APPROVAL_REQUIRED';
 end if;
end;
$$;

do $$
declare definition text; name text; scope text;
begin
 foreach name in array array['activate_account_session','activate_attendance_session'] loop
   scope:=case name when 'activate_account_session' then 'dashboard' else 'attendance' end;
   definition:=replace(pg_get_functiondef(('public.'||name||'()')::regprocedure),chr(13),'');
   if position('private.require_admin_login_scope' in definition)=0 then
     definition:=replace(definition,E'begin\n',E'begin\n  perform private.require_admin_login_scope('''||scope||E''');\n');
     execute definition;
   end if;
 end loop;
 definition:=pg_get_functiondef('public.enforce_account_session()'::regprocedure);
 -- Preserve existing checks; extend only the exact own-session bootstrap exception.
 definition:=replace(definition,'=''/rpc/admin_mfa_required''',
   'in (''/rpc/admin_mfa_required'',''/rpc/request_admin_login_approval'',''/rpc/cancel_admin_login_approval'')');
 execute definition;
end;
$$;
revoke all on function public.request_admin_login_approval(text,text),public.list_admin_login_approvals(),
 public.decide_admin_login_approval(uuid,boolean),public.cancel_admin_login_approval(text) from public,anon;
grant execute on function public.request_admin_login_approval(text,text),public.list_admin_login_approvals(),
 public.decide_admin_login_approval(uuid,boolean),public.cancel_admin_login_approval(text) to authenticated;
revoke all on function private.require_admin_login_scope(text) from public,anon;
grant execute on function private.require_admin_login_scope(text) to authenticated;
notify pgrst,'reload schema';
