-- Event metadata only: never copy passwords, tokens, or Auth payloads.
create or replace function public.record_security_failure(p_event text)
returns void language plpgsql security definer set search_path='' as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Service access required'; end if;
  if p_event not in ('username_sign_in_failed','member_sign_in_failed','sign_in_throttled') then
    raise exception 'Unsupported security event';
  end if;
  insert into public.activity_logs(actor_name,actor_role,action,entity_type,details)
  values('Unverified visitor','unverified',p_event,'security','Sign-in rejected by the authentication service.');
end;
$$;
revoke all on function public.record_security_failure(text) from public,anon,authenticated;
grant execute on function public.record_security_failure(text) to service_role;

create or replace function public.log_account_activity(p_event text)
returns void language plpgsql security definer set search_path='' as $$
declare account public.profiles%rowtype;
begin
  select * into account from public.profiles where id=auth.uid();
  if not found or account.is_active is not true then raise exception 'Active account required'; end if;
  if p_event not in ('member_signed_in','member_sign_out_requested','scanner_signed_in','scanner_sign_out_requested','report_export_requested') then
    raise exception 'Unsupported activity event';
  end if;
  if p_event='report_export_requested' and account.role<>'admin' then raise exception 'Admin access required'; end if;
  if p_event like 'scanner_%' and account.role not in ('staff','admin') then raise exception 'Operator access required'; end if;
  if p_event like 'member_%' and account.role not in ('member','customer') then raise exception 'Member access required'; end if;
  insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id,details)
  values(account.id,coalesce(nullif(account.full_name,''),account.username,account.email,account.id::text),account.role,
    p_event,case when p_event='report_export_requested' then 'reports' else 'session' end,account.id::text,
    case when p_event='report_export_requested' then 'Requested report export; browser download completion is not verified.' else '' end);
end;
$$;
revoke all on function public.log_account_activity(text) from public,anon;
grant execute on function public.log_account_activity(text) to authenticated;

create or replace function private.capture_password_change()
returns trigger language plpgsql security definer set search_path='' as $$
declare account public.profiles%rowtype;
begin
  if old.encrypted_password is not distinct from new.encrypted_password then return new; end if;
  select * into account from public.profiles where id=new.id;
  insert into public.activity_logs(actor_id,actor_name,actor_role,action,entity_type,entity_id)
  values(new.id,coalesce(account.full_name,'Account holder'),coalesce(account.role,'account'),'password_updated','security',new.id::text);
  return new;
end;
$$;
revoke all on function private.capture_password_change() from public,anon,authenticated;
drop trigger if exists capture_password_change on auth.users;
create trigger capture_password_change after update of encrypted_password on auth.users
for each row execute function private.capture_password_change();

-- Supabase records recovery requests in its Auth audit table when DB audit storage is enabled.
create or replace function private.capture_recovery_request()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.payload->>'action'='user_recovery_requested' then
    insert into public.activity_logs(actor_name,actor_role,action,entity_type,details)
    values('Unverified visitor','unverified','password_reset_requested','security','Password recovery requested; account ownership is not yet verified.');
  end if;
  return new;
end;
$$;
revoke all on function private.capture_recovery_request() from public,anon,authenticated;
drop trigger if exists capture_recovery_request on auth.audit_log_entries;
create trigger capture_recovery_request after insert on auth.audit_log_entries
for each row execute function private.capture_recovery_request();
notify pgrst,'reload schema';
