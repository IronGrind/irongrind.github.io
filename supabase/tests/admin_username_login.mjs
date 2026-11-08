// Run with the absolute path to an installed @electric-sql/pglite/dist/index.js.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
try {
    await db.exec('create role anon; create role authenticated; create role service_role;');
    const migration = await readFile(new URL('../migrations_archive/pre-baseline-20261105/20261103000001_admin_username_login.sql', import.meta.url), 'utf8');
    await db.exec(migration);
    await db.exec(migration);
    const bucket = `user:${'a'.repeat(64)}`;
    await db.exec('set role service_role');
    for (let i = 0; i < 10; i++) {
        assert.equal((await db.query('select public.consume_admin_login_attempt($1, 10) as allowed', [bucket])).rows[0].allowed, true);
    }
    assert.equal((await db.query('select public.consume_admin_login_attempt($1, 10) as allowed', [bucket])).rows[0].allowed, false);
    await assert.rejects(db.query('select public.consume_admin_login_attempt($1, 10)', ['raw-username']), /Invalid login bucket/);
    await assert.rejects(db.query('select public.consume_admin_login_attempt($1, null)', [bucket]), /Invalid login bucket/);
    await db.exec('reset role');
    await db.exec("update private.admin_login_attempts set window_start = now() - interval '6 minutes'");
    await db.exec('set role service_role');
    assert.equal((await db.query('select public.consume_admin_login_attempt($1, 10) as allowed', [bucket])).rows[0].allowed, true);
    await db.exec('reset role');
    for (const role of ['anon', 'authenticated']) {
        await db.exec(`set role ${role}`);
        await assert.rejects(db.query('select public.consume_admin_login_attempt($1, 10)', [bucket]), /permission denied/);
        await assert.rejects(db.exec('select * from private.admin_login_attempts'), /permission denied/);
        await db.exec('reset role');
    }
    console.log('Passed: throttling, five-minute reset, invalid input, migration rerun, anonymous/authenticated isolation.');
} finally { await db.close(); }
