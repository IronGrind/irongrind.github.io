import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
try {
    await db.exec(`
        create role anon; create role authenticated; create schema private;
        create table mobile_attendance_scan_sessions(id uuid primary key, token_hash text, created_by uuid, expires_at timestamptz, paired_at timestamptz, paired_device text, remember_phone boolean);
        create table mobile_attendance_pairing_policy(max_pairs integer, singleton boolean, pairing_password_hash text);
        create table profiles(id uuid, full_name text, username text, email text, role text);
        create table activity_logs(actor_id uuid, actor_name text, actor_role text, action text, entity_type text, entity_id text, record_label text, details text, changed_fields text[]);
        insert into mobile_attendance_pairing_policy values (2,true,'unchanged-hash');
        create function private.require_pairing_password(p_password text) returns void language plpgsql as $$
        begin
            if p_password = 'service-error' then raise exception 'Pairing configuration unavailable'; end if;
            if p_password <> 'correct' or p_password is null then raise exception 'Incorrect phone pairing password'; end if;
        end;
        $$;
        insert into mobile_attendance_scan_sessions values ('11111111-1111-4111-8111-111111111111',md5('token'),null,now()+interval '10 minutes',null,null,true);
    `);
    const migration = await readFile(new URL('../migrations/20261104000028_repair_phone_pairing_verification.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    await db.exec('set role authenticated');
    assert.equal((await db.query("select verify_mobile_attendance_pairing_password('correct') as valid")).rows[0].valid, true);
    await assert.rejects(db.query("select verify_mobile_attendance_pairing_password('wrong')"), /Incorrect phone pairing password/);
    await assert.rejects(db.query("select verify_mobile_attendance_pairing_password('service-error')"), /Pairing configuration unavailable/);
    await db.exec('reset role; set role anon');
    await assert.rejects(db.query("select verify_mobile_attendance_pairing_password('correct')"), /permission denied/);
    await db.query("select register_mobile_attendance_device('11111111-1111-4111-8111-111111111111','token','Test Phone')");
    await db.exec('reset role');
    let row = (await db.query('select * from mobile_attendance_scan_sessions')).rows[0];
    assert.ok(new Date(row.expires_at) - Date.now() > 29 * 86400000, 'Remembered first pairing gets 30 days');
    const originalTime = row.paired_at;
    await db.exec('set role anon');
    await db.query("select register_mobile_attendance_device('11111111-1111-4111-8111-111111111111','token','Test Phone')");
    await db.exec('reset role');
    row = (await db.query('select * from mobile_attendance_scan_sessions')).rows[0];
    assert.equal(String(row.paired_at), String(originalTime), 'Reopen preserves original pairing time');
    assert.equal((await db.query('select pairing_password_hash from mobile_attendance_pairing_policy')).rows[0].pairing_password_hash, 'unchanged-hash');
    console.log('Passed: repair rerun, verifier error distinction, anonymous isolation, remembered pairing duration, reopen stability, configured hash preserved.');
} finally { await db.close(); }
