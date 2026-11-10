-- One browser signing key per administrator. Private keys never leave the browser.
create table if not exists private.admin_trusted_devices (
 user_id uuid primary key references auth.users(id) on delete cascade,
 device_id uuid not null,
 public_key jsonb not null,
 device_label text not null,
 registered_at timestamptz not null default now(),
 expires_at timestamptz not null,
 last_seen_at timestamptz not null default now()
);
create table if not exists private.admin_device_sessions (
 session_id uuid primary key references auth.sessions(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 device_id uuid not null,
 session_scope text not null check(session_scope in ('dashboard','attendance')),
 public_key jsonb not null,
 challenge text not null,
 challenge_expires_at timestamptz not null,
 authorized_until timestamptz
);
alter table private.admin_login_approvals add column if not exists trusted_device_id uuid;
alter table private.admin_trusted_devices enable row level security;
alter table private.admin_device_sessions enable row level security;
revoke all on private.admin_trusted_devices,private.admin_device_sessions from public,anon,authenticated;

create or replace function private.admin_mfa_satisfied()
returns boolean language sql stable security definer set search_path='' as $$
 select not public.admin_mfa_required() or exists(
   select 1 from private.admin_device_sessions ds join private.admin_trusted_devices d
     on d.user_id=ds.user_id and d.device_id=ds.device_id and d.public_key=ds.public_key
   join auth.sessions s on s.id=ds.session_id and s.user_id=ds.user_id
   where ds.user_id=auth.uid() and ds.session_id::text=auth.jwt()->>'session_id'
     and ds.authorized_until>now() and d.expires_at>now() and (s.not_after is null or s.not_after>now()));
$$;
create or replace function private.require_admin_login_scope(p_scope text)
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if public.admin_mfa_required() and (not private.admin_mfa_satisfied() or not exists(
   select 1 from private.admin_device_sessions where user_id=auth.uid() and session_id::text=auth.jwt()->>'session_id' and session_scope=p_scope)) then
   raise sqlstate 'PT403' using message='ADMIN_DEVICE_REQUIRED';
 end if;
end;
$$;

-- Service-only functions: the Edge Function validates Auth and the ECDSA proof.
create or replace function public.create_admin_device_challenge(p_user uuid,p_session uuid,p_device uuid,p_scope text,p_key jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare message text; reusable boolean;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 if p_scope is null or p_scope not in ('dashboard','attendance') or p_device is null
   or p_key is null or p_key->>'kty' is distinct from 'EC' or p_key->>'crv' is distinct from 'P-256'
   or p_key ? 'd' or length(coalesce(p_key->>'x',''))<>43 or length(coalesce(p_key->>'y',''))<>43 then raise exception 'Invalid device key'; end if;
 if not exists(select 1 from public.profiles where id=p_user and role='admin' and is_active)
   or not exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now())) then raise exception 'Active administrator session required'; end if;
 message:='IronGrind device proof:'||p_session::text||':'||gen_random_uuid()::text||gen_random_uuid()::text;
 insert into private.admin_device_sessions(session_id,user_id,device_id,session_scope,public_key,challenge,challenge_expires_at)
 values(p_session,p_user,p_device,p_scope,p_key,message,now()+interval '10 minutes')
 on conflict(session_id) do update set device_id=excluded.device_id,session_scope=excluded.session_scope,
   public_key=excluded.public_key,challenge=excluded.challenge,challenge_expires_at=excluded.challenge_expires_at,authorized_until=null;
 select exists(select 1 from private.admin_trusted_devices where user_id=p_user and device_id=p_device and public_key=p_key and expires_at>now()) into reusable;
 return jsonb_build_object('message',message,'reusable',reusable);
end;
$$;
create or replace function public.get_admin_device_challenge(p_user uuid,p_session uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 return (select jsonb_build_object('message',challenge,'public_key',public_key,'issued_at',extract(epoch from (challenge_expires_at-interval '10 minutes'))) from private.admin_device_sessions
   where user_id=p_user and session_id=p_session and challenge_expires_at>now());
end;
$$;

create or replace function public.finish_admin_device_login(p_user uuid,p_session uuid,p_challenge text,p_mfa boolean,p_label text)
returns void language plpgsql security definer set search_path='' as $$
declare candidate private.admin_device_sessions%rowtype; current_device private.admin_trusted_devices%rowtype;
 target auth.sessions%rowtype; reusable boolean; active_other boolean; approved boolean; display text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user::text,817));
 select * into target from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now());
 if not found or not exists(select 1 from public.profiles where id=p_user and role='admin' and is_active) then raise exception 'Active administrator session required'; end if;
 select * into candidate from private.admin_device_sessions where session_id=p_session and user_id=p_user for update;
 if not found or candidate.challenge is distinct from p_challenge or candidate.challenge_expires_at<=now() then raise exception 'Device challenge expired or consumed'; end if;
 select * into current_device from private.admin_trusted_devices where user_id=p_user for update;
 reusable:=found and current_device.device_id=candidate.device_id and current_device.public_key=candidate.public_key and current_device.expires_at>now();
 if not reusable then
   if p_mfa is distinct from true or coalesce(target.aal::text,'aal1')<>'aal2' then raise exception 'ADMIN_MFA_REQUIRED'; end if;
   if exists(select 1 from private.admin_login_approvals where user_id=p_user and requesting_session_id=p_session
     and session_scope=candidate.session_scope and status='denied') then raise exception 'ADMIN_APPROVAL_REQUIRED'; end if;
   select exists(select 1 from private.account_sessions a join auth.sessions s on s.id=a.session_id
     join private.admin_device_sessions ds on ds.session_id=s.id and ds.device_id=current_device.device_id
     where a.user_id=p_user and s.user_id=p_user and s.id<>p_session and ds.authorized_until>now()
       and (s.not_after is null or s.not_after>now()) and current_device.expires_at>now()
       and current_device.last_seen_at>now()-interval '2 minutes') into active_other;
   select exists(select 1 from private.admin_login_approvals where user_id=p_user and requesting_session_id=p_session
     and session_scope=candidate.session_scope and trusted_device_id=current_device.device_id
     and status='approved' and approval_expires_at>now()) into approved;
   if active_other and not approved then raise exception 'ADMIN_APPROVAL_REQUIRED'; end if;
   -- A transfer retires both old dashboard/scanner scopes. Reuse keeps the other scope.
   delete from private.account_sessions where user_id=p_user;
   insert into private.admin_trusted_devices(user_id,device_id,public_key,device_label,expires_at)
   values(p_user,candidate.device_id,candidate.public_key,left(coalesce(nullif(btrim(p_label),''),'Browser'),180),now()+interval '30 days')
   on conflict(user_id) do update set device_id=excluded.device_id,public_key=excluded.public_key,device_label=excluded.device_label,
     registered_at=now(),expires_at=excluded.expires_at,last_seen_at=now();
   select * into current_device from private.admin_trusted_devices where user_id=p_user;
   select full_name into display from public.profiles where id=p_user;
   insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
   values(p_user,coalesce(display,'Administrator'),'admin','admin_device_registered','security',candidate.device_id::text,
     case when approved then 'Transferred device trust after current-device approval and authenticator verification.' else 'Registered device after authenticator verification; no recently active trusted approver was available.' end);
 end if;
 if exists(select 1 from private.account_sessions where user_id=p_user and session_scope=candidate.session_scope
   and session_id<>p_session and (session_created_at,session_id)>=(target.created_at,target.id)) then raise exception 'ACCOUNT_SESSION_REPLACED'; end if;
 update private.admin_device_sessions set authorized_until=current_device.expires_at,challenge='',challenge_expires_at=now() where session_id=p_session;
 update private.admin_trusted_devices set last_seen_at=now() where user_id=p_user;
 insert into private.account_sessions(user_id,session_id,session_created_at,session_scope)
 values(p_user,p_session,target.created_at,candidate.session_scope)
 on conflict(user_id,session_scope) do update set session_id=excluded.session_id,session_created_at=excluded.session_created_at;
end;
$$;

-- Retain the existing approval logic, narrowing eligible approvers to trusted sessions
-- and binding each request to the trusted device which is being replaced.
do $$
declare definition text;
begin
 definition:=pg_get_functiondef('public.request_admin_login_approval(text,text)'::regprocedure);
 if position('TRUSTED_DEVICE_APPROVAL' in definition)=0 then
   definition:=replace(definition,'and (s.aal::text=''aal2'' or exists',
     'and (exists(select 1 from private.admin_device_sessions trusted join private.admin_trusted_devices d on d.user_id=trusted.user_id and d.device_id=trusted.device_id and d.public_key=trusted.public_key where trusted.session_id=s.id and trusted.user_id=target.user_id and trusted.authorized_until>now() and d.expires_at>now()) or s.aal::text=''aal2'' or exists');
   definition:=replace(definition,'order by case a.session_scope',
     'and exists(select 1 from private.admin_device_sessions trusted join private.admin_trusted_devices d on d.user_id=trusted.user_id and d.device_id=trusted.device_id and d.public_key=trusted.public_key where trusted.session_id=s.id and trusted.user_id=target.user_id and trusted.authorized_until>now() and d.expires_at>now() and d.last_seen_at>now()-interval ''2 minutes'') order by case a.session_scope');
   definition:=replace(definition,'if approver is null then',
     E'-- TRUSTED_DEVICE_APPROVAL\n if approver is not null and not exists(select 1 from private.admin_device_sessions ds join private.admin_trusted_devices d on d.user_id=ds.user_id and d.device_id=ds.device_id and d.public_key=ds.public_key where ds.session_id=approver and ds.user_id=target.user_id and ds.authorized_until>now() and d.expires_at>now() and d.last_seen_at>now()-interval ''2 minutes'') then approver:=null; end if;\n if approver is null then');
   definition:=replace(definition,'return jsonb_build_object(''status'',''pending'',''request_id'',request.id,',
     E'update private.admin_login_approvals set trusted_device_id=(select device_id from private.admin_trusted_devices where user_id=target.user_id) where id=request.id;\n return jsonb_build_object(''status'',''pending'',''request_id'',request.id,');
   execute definition;
 end if;
 definition:=pg_get_functiondef('public.list_admin_login_approvals()'::regprocedure);
 if position('last_seen_at' in definition)=0 then
   definition:=replace(definition,'return (select',E'update private.admin_trusted_devices set last_seen_at=now() where user_id=auth.uid();\n return (select');
   execute definition;
 end if;
end;
$$;

create or replace function public.forget_admin_trusted_device()
returns void language plpgsql security definer set search_path='' as $$
declare device uuid; display text;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 if not private.is_admin() or not private.account_session_is_current() then raise exception 'Trusted active administrator required'; end if;
 select device_id into device from private.admin_trusted_devices where user_id=auth.uid();
 select full_name into display from public.profiles where id=auth.uid();
 delete from private.admin_trusted_devices where user_id=auth.uid();
 delete from private.account_sessions where user_id=auth.uid();
 insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
 values(auth.uid(),coalesce(display,'Administrator'),'admin','admin_device_forgotten','security',device::text,'Revoked the trusted device and its application sessions.');
end;
$$;
revoke all on function public.create_admin_device_challenge(uuid,uuid,uuid,text,jsonb),public.get_admin_device_challenge(uuid,uuid),
 public.finish_admin_device_login(uuid,uuid,text,boolean,text) from public,anon,authenticated;
grant execute on function public.create_admin_device_challenge(uuid,uuid,uuid,text,jsonb),public.get_admin_device_challenge(uuid,uuid),
 public.finish_admin_device_login(uuid,uuid,text,boolean,text) to service_role;
revoke all on function public.forget_admin_trusted_device() from public,anon;
grant execute on function public.forget_admin_trusted_device() to authenticated;
notify pgrst,'reload schema';
