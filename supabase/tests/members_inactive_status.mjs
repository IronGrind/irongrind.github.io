import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const names = ['Ana Jean Seripa', 'Jamaica Bongcao', 'Jecil', 'Main Test Account', 'roshe', 'roshe', 'Roshe Mae I. Gomez', 'Seripa, Ana Jean D.', 'TestAccount2'];
try {
    await db.exec(`create table public.members (
        id uuid primary key default gen_random_uuid(), full_name text, auth_user_id uuid,
        status text check (status in ('active','expired','suspended')), updated_at timestamptz default now()
    ); create table public.sales(member_id uuid references public.members(id));
    create table public.attendance(member_id uuid references public.members(id));`);
    for (const name of names) await db.query('insert into members(full_name,status) values($1,\'active\')', [name]);
    await db.exec("insert into members(full_name,status) values('Retained suspended member','suspended'); insert into sales select id from members; insert into attendance select id from members;");
    const cleanup = await readFile(new URL('../maintenance/mark_approved_old_members_inactive.sql', import.meta.url), 'utf8');
    await assert.rejects(db.exec(cleanup), /members_status_check/);
    await db.exec('rollback');
    assert.equal((await db.query("select count(*)::int n from members where status='active'")).rows[0].n, 9);
    const migration = await readFile(new URL('../migrations_archive/pre-baseline-20261105/20261104000001_members_inactive_status.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    await db.exec(cleanup);
    assert.equal((await db.query("select count(*)::int n from members where status='inactive'")).rows[0].n, 9);
    assert.equal((await db.query("select count(*)::int n from members where status='suspended'")).rows[0].n, 1);
    assert.equal((await db.query('select count(*)::int n from sales')).rows[0].n, 10);
    assert.equal((await db.query('select count(*)::int n from attendance')).rows[0].n, 10);
    await assert.rejects(db.exec("update members set status='invalid'"), /members_status_check/);
    await db.exec(cleanup); // Repeating the approved cleanup is harmless.
    await db.exec("insert into members(full_name,status) values('Jecil','active')");
    await assert.rejects(db.exec(cleanup), /nine approved memberships no longer match/);
    await db.exec('rollback');
    assert.equal((await db.query("select count(*)::int n from members where full_name='Jecil' and status='active'")).rows[0].n, 1);
    console.log('Passed: reproduced legacy constraint failure and rollback; repair archives the nine records, preserves suspended and related records, rejects invalid statuses, and aborts changed record matches.');
} finally { await db.close(); }
