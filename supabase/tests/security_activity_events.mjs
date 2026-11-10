import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
try {
    await db.exec(`create role anon; create role authenticated; create role service_role;
      create schema auth; create schema private;
      create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
      create function auth.role() returns text language sql as $$select current_user::text$$;
      create table public.profiles(id uuid primary key, full_name text, username text, email text, role text, is_active boolean);
      create table public.activity_logs(id bigint generated always as identity, actor_id uuid, actor_name text,actor_role text,action text,entity_type text,entity_id text,details text);
      create table auth.users(id uuid primary key,encrypted_password text);
      create table auth.audit_log_entries(payload jsonb);
      insert into public.profiles values('00000000-0000-0000-0000-000000000001','Admin',null,null,'admin',true),
      ('00000000-0000-0000-0000-000000000002','Member',null,null,'member',true);`);
    const migration = await readFile(new URL('../migrations/20261110000001_security_activity_events.sql', import.meta.url), 'utf8');
    await db.exec(migration); await db.exec(migration);
    await db.exec(`set role anon`);
    await assert.rejects(db.exec("select public.record_security_failure('member_sign_in_failed')"), /permission denied/);
    await assert.rejects(db.exec("select public.log_account_activity('member_signed_in')"), /permission denied/);
    await db.exec('reset role; set role service_role');
    // auth.role() resolves the invoker JWT role in production, independent of SECURITY DEFINER.
    await db.exec('reset role');
    await db.exec("create or replace function auth.role() returns text language sql as $$select 'service_role'::text$$");
    await db.exec("set role service_role; select public.record_security_failure('member_sign_in_failed'); reset role;");
    await db.exec("set test.uid='00000000-0000-0000-0000-000000000002'; set role authenticated");
    await db.exec("select public.log_account_activity('member_signed_in')");
    await assert.rejects(db.exec("select public.log_account_activity('report_export_requested')"), /Admin access required/);
    await assert.rejects(db.exec("select public.log_account_activity('scanner_signed_in')"), /Operator access required/);
    await assert.rejects(db.exec("select public.log_account_activity('invented')"), /Unsupported/);
    await db.exec("reset role; set test.uid='00000000-0000-0000-0000-000000000001'; set role authenticated; select public.log_account_activity('report_export_requested'); reset role;");
    await db.exec(`insert into auth.users values('00000000-0000-0000-0000-000000000002','old-secret-hash');
      update auth.users set encrypted_password='new-secret-hash';
      update auth.users set encrypted_password='new-secret-hash';
      insert into auth.audit_log_entries values('{"action":"user_recovery_requested","token":"secret-token"}');`);
    const rows = (await db.query('select * from public.activity_logs')).rows;
    assert.equal(rows.filter(row => row.action === 'password_updated').length, 1);
    assert.ok(rows.some(row => row.action === 'password_reset_requested'));
    assert.ok(rows.some(row => row.action === 'member_signed_in' && row.actor_name === 'Member'));
    assert.doesNotMatch(JSON.stringify(rows), /secret-hash|secret-token/);
    console.log('Passed: security activity migration, repeat application, role restrictions, password/recovery triggers, and secret exclusion.');
} finally { await db.close(); }
