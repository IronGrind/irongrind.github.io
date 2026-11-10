create or replace function public.get_admin_trusted_device()
returns table(device_label text, registered_at timestamptz, expires_at timestamptz)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
 if not private.is_admin() or not private.account_session_is_current() then
   raise exception 'Trusted active administrator required';
 end if;
 return query
   select d.device_label, d.registered_at, d.expires_at
   from private.admin_trusted_devices d
   where d.user_id=auth.uid() and d.expires_at>now();
end;
$$;
revoke all on function public.get_admin_trusted_device() from public,anon;
grant execute on function public.get_admin_trusted_device() to authenticated;
notify pgrst,'reload schema';
