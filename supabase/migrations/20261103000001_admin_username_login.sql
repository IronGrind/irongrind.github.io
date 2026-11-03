-- Private username login throttling. No username/email lookup is exposed to clients.
begin;
create schema if not exists private;
create table if not exists private.admin_login_attempts (
    bucket text primary key,
    window_start timestamptz not null,
    attempts integer not null
);
revoke all on private.admin_login_attempts from public, anon, authenticated;

create or replace function public.consume_admin_login_attempt(p_bucket text, p_limit integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare attempt_count integer;
begin
    if p_bucket is null or p_bucket !~ '^(user|ip):[0-9a-f]{64}$'
        or p_limit is null or p_limit not in (10, 50) then raise exception 'Invalid login bucket'; end if;
    -- Only hashes are stored. Opportunistic cleanup bounds old bucket retention.
    delete from private.admin_login_attempts where window_start < now() - interval '1 day';
    insert into private.admin_login_attempts as a (bucket, window_start, attempts)
    values (p_bucket, now(), 1)
    on conflict (bucket) do update set
        attempts = case when a.window_start <= now() - interval '5 minutes' then 1 else least(a.attempts + 1, 1000) end,
        window_start = case when a.window_start <= now() - interval '5 minutes' then now() else a.window_start end
    returning attempts into attempt_count;
    return attempt_count <= p_limit;
end;
$$;
revoke all on function public.consume_admin_login_attempt(text, integer) from public, anon, authenticated;
grant execute on function public.consume_admin_login_attempt(text, integer) to service_role;
commit;
notify pgrst, 'reload schema';
