-- Member browser registration and approval. A newly seen browser is approved
-- by the member's currently signed-in, previously registered browser.
create table if not exists private.member_trusted_devices (
 user_id uuid primary key references auth.users(id) on delete cascade,
 device_id uuid not null,
 public_key jsonb not null,
 device_label text not null,
 registered_at timestamptz not null default now(),
 last_seen_at timestamptz not null default now()
);
create table if not exists private.member_device_sessions (
 session_id uuid primary key references auth.sessions(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 device_id uuid not null,
 public_key jsonb not null,
 challenge text not null,
 challenge_expires_at timestamptz not null,
 authorized_until timestamptz
);
create table if not exists private.member_device_approvals (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 requesting_session_id uuid not null references auth.sessions(id) on delete cascade,
 approver_session_id uuid references auth.sessions(id) on delete set null,
 device_id uuid not null,
 device_label text not null,
 status text not null default 'pending' check(status in ('pending','approved','denied','consumed')),
 requested_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '2 minutes',
 decided_at timestamptz,
 unique(requesting_session_id)
);
alter table private.member_trusted_devices enable row level security;
alter table private.member_device_sessions enable row level security;
alter table private.member_device_approvals enable row level security;
revoke all on private.member_trusted_devices,private.member_device_sessions,private.member_device_approvals from public,anon,authenticated;

create or replace function private.member_device_session_is_trusted(p_user uuid,p_session uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.member_device_sessions s join private.member_trusted_devices d
   on d.user_id=s.user_id and d.device_id=s.device_id and d.public_key=s.public_key
   join auth.sessions a on a.id=s.session_id and a.user_id=s.user_id
   where s.user_id=p_user and s.session_id=p_session and s.authorized_until>now()
     and a.id::text=auth.jwt()->>'session_id' and (a.not_after is null or a.not_after>now()))
$$;
create or replace function private.require_member_device_session()
returns void language plpgsql stable security definer set search_path='' as $$
begin
 if exists(select 1 from public.profiles p join public.members m on m.auth_user_id=p.id
   where p.id=auth.uid() and p.role='member')
   and not private.member_device_session_is_trusted(auth.uid(),(auth.jwt()->>'session_id')::uuid) then
   raise sqlstate 'PT403' using message='MEMBER_DEVICE_REQUIRED';
 end if;
end
$$;

-- Bind member activation to a proven, registered browser. Existing sessions
-- remain usable until replaced, allowing a first post-migration enrollment.
do $$
declare definition text;
begin
 definition:=replace(pg_get_functiondef('public.activate_account_session()'::regprocedure),chr(13),'');
 if position('private.require_member_device_session()' in definition)=0 then
   definition:=replace(definition,'perform private.require_admin_mfa();',
     'perform private.require_admin_mfa(); perform private.require_member_device_session();');
   execute definition;
 end if;
end
$$;

-- Service-only RPCs are called by the member-device-trust Edge Function after
-- Auth validation and ECDSA proof verification.
create or replace function public.create_member_device_challenge(p_user uuid,p_session uuid,p_device uuid,p_key jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare message text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 if p_device is null or p_key is null or p_key->>'kty' is distinct from 'EC' or p_key->>'crv' is distinct from 'P-256'
   or p_key ? 'd' or length(coalesce(p_key->>'x',''))<>43 or length(coalesce(p_key->>'y',''))<>43 then raise exception 'Invalid device key'; end if;
 if not exists(select 1 from public.profiles p where p.id=p_user and p.role='member' and p.is_active)
   or not exists(select 1 from auth.sessions s where s.id=p_session and s.user_id=p_user and (s.not_after is null or s.not_after>now())) then
   raise exception 'Active member session required';
 end if;
 if not exists(select 1 from public.members m where m.auth_user_id=p_user) then
   return jsonb_build_object('skip',true);
 end if;
 message:='IronGrind member device proof:'||p_session::text||':'||gen_random_uuid()::text||gen_random_uuid()::text;
 insert into private.member_device_sessions(session_id,user_id,device_id,public_key,challenge,challenge_expires_at)
 values(p_session,p_user,p_device,p_key,message,now()+interval '10 minutes')
 on conflict(session_id) do update set device_id=excluded.device_id,public_key=excluded.public_key,
   challenge=excluded.challenge,challenge_expires_at=excluded.challenge_expires_at,authorized_until=null;
 return jsonb_build_object('message',message);
end
$$;
create or replace function public.get_member_device_challenge(p_user uuid,p_session uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 return (select jsonb_build_object('message',challenge,'public_key',public_key)
   from private.member_device_sessions where user_id=p_user and session_id=p_session and challenge_expires_at>now());
end
$$;
create or replace function public.get_member_device_approval_status(p_user uuid,p_session uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare request private.member_device_approvals%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 select * into request from private.member_device_approvals where user_id=p_user and requesting_session_id=p_session;
 if not found then return jsonb_build_object('status','none'); end if;
 if request.status='pending' and request.expires_at<=now() then return jsonb_build_object('status','expired'); end if;
 return jsonb_build_object('status',request.status,'expires_at',request.expires_at);
end
$$;

create or replace function public.finish_member_device_login(p_user uuid,p_session uuid,p_challenge text,p_label text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare candidate private.member_device_sessions%rowtype; target auth.sessions%rowtype; trusted private.member_trusted_devices%rowtype;
 active_session uuid; approval private.member_device_approvals%rowtype; reusable boolean:=false; display text; label text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'Service access required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_user::text,817));
 select * into target from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now());
 if not found or not exists(select 1 from public.profiles p join public.members m on m.auth_user_id=p.id where p.id=p_user and p.role='member' and p.is_active) then
   raise exception 'Active member session required';
 end if;
 select * into candidate from private.member_device_sessions where session_id=p_session and user_id=p_user for update;
 if not found or candidate.challenge is distinct from p_challenge or candidate.challenge_expires_at<=now() then raise exception 'Device challenge expired or consumed'; end if;
 select * into trusted from private.member_trusted_devices where user_id=p_user for update;
 reusable:=found and trusted.device_id=candidate.device_id and trusted.public_key=candidate.public_key;
 if not reusable then
   select a.session_id into active_session from private.account_sessions a join auth.sessions s on s.id=a.session_id and s.user_id=a.user_id
     join private.member_device_sessions ds on ds.session_id=s.id and ds.user_id=s.user_id
     join private.member_trusted_devices d on d.user_id=ds.user_id and d.device_id=ds.device_id and d.public_key=ds.public_key
     where a.user_id=p_user and a.session_scope='dashboard' and s.id<>p_session
       and (s.not_after is null or s.not_after>now()) and ds.authorized_until>now()
       and d.last_seen_at>now()-interval '2 minutes' limit 1;
   select * into approval from private.member_device_approvals where requesting_session_id=p_session for update;
   if active_session is not null then
     if not found then
       label:=left(coalesce(nullif(btrim(p_label),''),'Browser'),180);
       insert into private.member_device_approvals(user_id,requesting_session_id,approver_session_id,device_id,device_label)
       values(p_user,p_session,active_session,candidate.device_id,label) returning * into approval;
       insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
       values(p_user,'Member','member','member_device_approval_requested','security',approval.id::text,'Requested approval to register a new member browser.');
     end if;
     if approval.status='denied' then return jsonb_build_object('status','denied'); end if;
     if approval.status='pending' and approval.expires_at>now() then return jsonb_build_object('status','pending','expires_at',approval.expires_at); end if;
     if approval.status<>'approved' or approval.expires_at<=now() or approval.approver_session_id is distinct from active_session then
       return jsonb_build_object('status','expired');
     end if;
   end if;
   delete from private.account_sessions where user_id=p_user and session_scope='dashboard';
   label:=left(coalesce(nullif(btrim(p_label),''),'Browser'),180);
   insert into private.member_trusted_devices(user_id,device_id,public_key,device_label,registered_at,last_seen_at)
   values(p_user,candidate.device_id,candidate.public_key,label,now(),now())
   on conflict(user_id) do update set device_id=excluded.device_id,public_key=excluded.public_key,device_label=excluded.device_label,registered_at=now(),last_seen_at=now();
   select * into trusted from private.member_trusted_devices where user_id=p_user;
   if approval.id is not null and approval.status='approved' then update private.member_device_approvals set status='consumed' where id=approval.id; end if;
   select full_name into display from public.profiles where id=p_user;
   insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
   values(p_user,coalesce(display,'Member'),'member','member_device_registered','security',candidate.device_id::text,
     case when approval.id is not null then 'Registered a browser after approval from the currently trusted member device.' else 'Registered the initial active member browser.' end);
 end if;
 update private.member_device_sessions set authorized_until=now()+interval '90 days',challenge='',challenge_expires_at=now() where session_id=p_session;
 update private.member_trusted_devices set last_seen_at=now() where user_id=p_user;
 insert into private.account_sessions(user_id,session_id,session_created_at,session_scope)
 values(p_user,p_session,target.created_at,'dashboard')
 on conflict(user_id,session_scope) do update set session_id=excluded.session_id,session_created_at=excluded.session_created_at;
 return jsonb_build_object('status','authorized');
end
$$;

create or replace function public.list_member_device_approvals()
returns table(id uuid,device_label text,requested_at timestamptz,expires_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.profiles p join public.members m on m.auth_user_id=p.id
   where p.id=auth.uid() and p.role='member' and p.is_active)
   or not private.account_session_is_current()
   or not private.member_device_session_is_trusted(auth.uid(),(auth.jwt()->>'session_id')::uuid) then raise exception 'Active trusted member device required'; end if;
 update private.member_trusted_devices set last_seen_at=now() where user_id=auth.uid();
 return query select a.id,a.device_label,a.requested_at,a.expires_at from private.member_device_approvals a
   where a.user_id=auth.uid() and a.approver_session_id::text=auth.jwt()->>'session_id'
     and a.status='pending' and a.expires_at>now() order by a.requested_at limit 1;
end
$$;
create or replace function public.decide_member_device_approval(p_request_id uuid,p_approve boolean)
returns void language plpgsql security definer set search_path='' as $$
declare request private.member_device_approvals%rowtype; display text;
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text,817));
 if not exists(select 1 from public.profiles p join public.members m on m.auth_user_id=p.id
   where p.id=auth.uid() and p.role='member' and p.is_active)
   or not private.account_session_is_current()
   or not private.member_device_session_is_trusted(auth.uid(),(auth.jwt()->>'session_id')::uuid) then raise exception 'Active trusted member device required'; end if;
 select * into request from private.member_device_approvals where id=p_request_id and user_id=auth.uid()
   and approver_session_id::text=auth.jwt()->>'session_id' and status='pending' for update;
 if not found or request.expires_at<=now() then raise exception 'Approval request is unavailable or expired'; end if;
 update private.member_device_approvals set status=case when p_approve then 'approved' else 'denied' end,decided_at=now() where id=request.id;
 update private.member_trusted_devices set last_seen_at=now() where user_id=auth.uid();
 select full_name into display from public.profiles where id=auth.uid();
 insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
 values(auth.uid(),coalesce(display,'Member'),'member',case when p_approve then 'member_device_approved' else 'member_device_denied' end,
   'security',request.id::text,case when p_approve then 'Approved a new member browser.' else 'Denied a new member browser.' end);
end
$$;

revoke all on function public.member_device_session_is_trusted(uuid,uuid),public.require_member_device_session() from public,anon,authenticated;
revoke all on function public.create_member_device_challenge(uuid,uuid,uuid,jsonb),public.get_member_device_challenge(uuid,uuid),
 public.get_member_device_approval_status(uuid,uuid),public.finish_member_device_login(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.create_member_device_challenge(uuid,uuid,uuid,jsonb),public.get_member_device_challenge(uuid,uuid),
 public.get_member_device_approval_status(uuid,uuid),public.finish_member_device_login(uuid,uuid,text,text) to service_role;
revoke all on function public.list_member_device_approvals(),public.decide_member_device_approval(uuid,boolean) from public,anon;
grant execute on function public.list_member_device_approvals(),public.decide_member_device_approval(uuid,boolean) to authenticated;
notify pgrst,'reload schema';
