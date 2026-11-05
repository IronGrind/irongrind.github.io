-- Pair an HTTPS phone camera with a signed-in admin attendance page.
begin;

create table if not exists public.mobile_attendance_scan_sessions (
    id uuid primary key default gen_random_uuid(),
    token_hash text not null,
    created_by uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    expires_at timestamptz not null
);

create table if not exists public.mobile_attendance_scan_events (
    id uuid primary key default gen_random_uuid(),
    session_id uuid not null references public.mobile_attendance_scan_sessions (id) on delete cascade,
    qr_payload text not null check (length(qr_payload) between 1 and 500),
    created_at timestamptz not null default now()
);

create index if not exists mobile_attendance_scan_events_session_created_idx
    on public.mobile_attendance_scan_events (session_id, created_at);

alter table public.mobile_attendance_scan_sessions enable row level security;
alter table public.mobile_attendance_scan_events enable row level security;
revoke all on public.mobile_attendance_scan_sessions from public, anon, authenticated;
revoke all on public.mobile_attendance_scan_events from public, anon, authenticated;

drop policy if exists "Admins read paired attendance scans" on public.mobile_attendance_scan_events;
create policy "Admins read paired attendance scans"
    on public.mobile_attendance_scan_events for select to authenticated
    using ((select private.is_admin()));

drop policy if exists "Admins clear paired attendance scans" on public.mobile_attendance_scan_events;
create policy "Admins clear paired attendance scans"
    on public.mobile_attendance_scan_events for delete to authenticated
    using ((select private.is_admin()));

grant select, delete on public.mobile_attendance_scan_events to authenticated;

create or replace function public.create_mobile_attendance_scan_session()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_id uuid := gen_random_uuid();
    session_token text := gen_random_uuid()::text || gen_random_uuid()::text;
    session_expiry timestamptz := now() + interval '10 minutes';
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;

    delete from public.mobile_attendance_scan_sessions where expires_at <= now();

    insert into public.mobile_attendance_scan_sessions (id, token_hash, created_by, expires_at)
    values (session_id, md5(session_token), (select auth.uid()), session_expiry);

    return jsonb_build_object(
        'session_id', session_id,
        'token', session_token,
        'expires_at', session_expiry
    );
end;
$$;

create or replace function public.submit_mobile_attendance_scan(
    p_session_id uuid,
    p_token text,
    p_qr_payload text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    session_row public.mobile_attendance_scan_sessions%rowtype;
    queued_count integer;
begin
    if p_token is null or p_qr_payload is null or length(btrim(p_qr_payload)) not between 1 and 500 then
        raise exception 'Invalid scan request';
    end if;

    select * into session_row
    from public.mobile_attendance_scan_sessions
    where id = p_session_id and token_hash = md5(p_token) and expires_at > now()
    for update;
    if not found then raise exception 'Phone scanner session is invalid or expired'; end if;

    select count(*) into queued_count
    from public.mobile_attendance_scan_events
    where session_id = p_session_id;
    if queued_count >= 100 then raise exception 'Attendance scan queue is full'; end if;

    insert into public.mobile_attendance_scan_events (session_id, qr_payload)
    values (p_session_id, btrim(p_qr_payload));
end;
$$;

create or replace function public.validate_mobile_attendance_scan_session(
    p_session_id uuid,
    p_token text
)
returns boolean
language sql
security definer
set search_path = ''
as $$
    select p_token is not null and exists (
        select 1
        from public.mobile_attendance_scan_sessions
        where id = p_session_id
          and token_hash = md5(p_token)
          and expires_at > now()
    );
$$;

create or replace function public.close_mobile_attendance_scan_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    if (select private.is_admin()) is distinct from true then raise exception 'Admin access required'; end if;
    delete from public.mobile_attendance_scan_sessions where id = p_session_id;
end;
$$;

revoke all on function public.create_mobile_attendance_scan_session() from public, anon;
grant execute on function public.create_mobile_attendance_scan_session() to authenticated;
revoke all on function public.submit_mobile_attendance_scan(uuid, text, text) from public;
grant execute on function public.submit_mobile_attendance_scan(uuid, text, text) to anon, authenticated;
revoke all on function public.validate_mobile_attendance_scan_session(uuid, text) from public;
grant execute on function public.validate_mobile_attendance_scan_session(uuid, text) to anon, authenticated;
revoke all on function public.close_mobile_attendance_scan_session(uuid) from public, anon;
grant execute on function public.close_mobile_attendance_scan_session(uuid) to authenticated;

commit;
