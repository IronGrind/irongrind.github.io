import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
try {
    await db.exec(`
        create role anon;
        create role authenticated;
        create role service_role bypassrls;
        create table public.profiles(id uuid, username text, role text, full_name text, email text);
        alter table public.profiles enable row level security;
        insert into public.profiles values ('11111111-1111-4111-8111-111111111111', 'JARAPAN', 'admin', 'JARAPAN', 'private@example.test');
        set role service_role;
    `);
    await assert.rejects(db.query("select id from public.profiles where username ilike 'jarapan' and role = 'admin'"), /permission denied/);
    await db.exec('reset role');
    const migration = await readFile(new URL('../migrations_archive/pre-baseline-20261105/20261103000002_admin_login_profile_read_access.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    await db.exec('set role service_role');
    assert.equal((await db.query("select id from public.profiles where username ilike 'jarapan' and role = 'admin'")).rows.length, 1);
    assert.equal((await db.query('select id, full_name, username, role from public.profiles')).rows.length, 1);
    await assert.rejects(db.exec('select email from public.profiles'), /permission denied/);
    await assert.rejects(db.exec("update public.profiles set role = 'member'"), /permission denied/);
    await db.exec('reset role; set role anon');
    await assert.rejects(db.exec('select id, username from public.profiles'), /permission denied/);
    await db.exec('reset role; set role authenticated');
    await assert.rejects(db.exec('select id, username from public.profiles'), /permission denied/);
    console.log('Passed: reproduced BYPASSRLS permission failure; repair enables exact case-insensitive username lookup and reset-script reads without granting browser, email, or write access.');
} finally { await db.close(); }
