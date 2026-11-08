// Isolated migration checks. Pass the path to an installed @electric-sql/pglite/dist/index.js.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const admin = '11111111-1111-4111-8111-111111111111';
const member = '22222222-2222-4222-8222-222222222222';
try {
    await db.exec(`
        create role anon; create role authenticated; create role service_role;
        create schema auth; create schema private;
        create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
        create function auth.role() returns text language sql as $$select current_setting('request.jwt.claim.role', true)$$;
        grant usage on schema auth, private to authenticated, service_role;
        create table public.profiles (id uuid primary key, full_name text, username text, email text, role text);
        create table public.members (id uuid primary key default gen_random_uuid(), auth_user_id uuid, full_name text, plan text, plan_price numeric, paid boolean);
        create table public.membership_applications (id uuid primary key default gen_random_uuid(), full_name text, status text, reviewed_by uuid);
        create table public.attendance (id uuid primary key default gen_random_uuid(), member_id uuid, time_out timestamptz, recorded_by uuid);
        create table public.products (id uuid primary key default gen_random_uuid(), name text, is_active boolean, stock integer, updated_at timestamptz);
        create table public.sales (id uuid primary key default gen_random_uuid(), receipt_number text, customer_type text, customer_name text, member_id uuid, total numeric, status text, sold_at timestamptz, processed_by uuid);
        create table public.sale_items (id uuid primary key default gen_random_uuid(), sale_id uuid, item_name text, category text, quantity numeric, unit text, unit_price numeric, line_total numeric);
        create table public.membership_history (id uuid primary key default gen_random_uuid(), member_id uuid, event_type text, recorded_by uuid);
        create function private.is_admin() returns boolean language sql security definer set search_path = '' as $$select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin')$$;
        insert into profiles values ('${admin}', 'Staff One', 'staff1', 'staff1@example.test', 'admin'), ('${member}', 'Member One', 'member1', 'member1@example.test', 'member');
    `);
    const migration = await readFile(new URL('../migrations_archive/pre-baseline-20261105/20261103000000_activity_logs.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration); // Rerunning setup must not duplicate triggers.
    await db.query("select set_config('request.jwt.claim.sub', $1, false), set_config('request.jwt.claim.role', 'authenticated', false)", [admin]);
    await db.exec("insert into products(name, is_active, stock) values ('Shirt', true, 5); update products set stock = 4; update products set is_active = false;");
    let rows = (await db.query('select * from activity_logs order by id')).rows;
    assert.equal(rows.length, 3);
    assert.equal(rows[0].actor_id, admin);
    assert.equal(rows[0].actor_name, 'Staff One');
    assert.equal(rows[2].action, 'archived');
    assert.deepEqual(rows[1].changed_fields, ['stock']);
    await db.exec('update products set updated_at = now()');
    assert.equal((await db.query('select count(*)::int as n from activity_logs')).rows[0].n, 3);
    await db.exec('begin; update products set stock = 99; rollback;');
    assert.equal((await db.query('select count(*)::int as n from activity_logs')).rows[0].n, 3);
    await db.exec('set role authenticated');
    assert.equal((await db.query('select count(*)::int as n from activity_logs')).rows[0].n, 3);
    for (const sql of ["insert into activity_logs(actor_name,actor_role,action,entity_type) values ('fake','admin','fake','fake')", 'update activity_logs set actor_name = \'fake\'', 'delete from activity_logs', 'truncate activity_logs']) {
        await assert.rejects(db.exec(sql), /permission denied/);
    }
    await db.query("select public.admin_log_session_event('signed_in')");
    await assert.rejects(db.query("select public.admin_log_session_event('fake')"), /Unsupported session event/);
    await db.query("select set_config('request.jwt.claim.sub', $1, false)", [member]);
    assert.equal((await db.query('select count(*)::int as n from activity_logs')).rows[0].n, 0);
    await assert.rejects(db.query("select public.admin_log_session_event('signed_in')"), /Admin access required/);
    await assert.rejects(db.query('select public.admin_create_member_and_sale($1,$2,$3)', [admin, {}, 'fake']), /permission denied/);
    await db.exec('reset role');
    await db.query("select set_config('request.jwt.claim.sub', '', false), set_config('request.jwt.claim.role', 'service_role', false)");
    await db.exec('set role service_role');
    const result = await db.query('select public.admin_create_member_and_sale($1,$2::jsonb,$3) as result', [admin, JSON.stringify({ auth_user_id: member, full_name: 'New Member', plan: 'Monthly', plan_price: 800 }), 'TEST-RECEIPT']);
    assert.ok(result.rows[0].result.member_id);
    await db.exec('reset role');
    rows = (await db.query('select * from activity_logs order by id desc limit 3')).rows;
    assert.equal(rows.length, 3);
    assert.ok(rows.every(row => row.actor_id === admin));
    assert.deepEqual(rows.map(row => row.entity_type).sort(), ['members', 'sale_items', 'sales']);
    console.log('Passed: triggers, replay, actor attribution, rollback, field filtering, admin read-only access, member isolation, session validation, service-only registration attribution.');
} finally { await db.close(); }
