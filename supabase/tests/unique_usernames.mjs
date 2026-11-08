import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
try {
    await db.exec('create role anon; create role authenticated; create role service_role; create schema private; create table profiles(id uuid default gen_random_uuid(),username text);');
    const sql=fs.readFileSync('supabase/migrations/20261108000002_unique_account_usernames.sql','utf8');
    await db.exec(sql); await db.exec(sql);
    await db.query('insert into profiles(username) values($1)',[' Member_One ']);
    assert.equal((await db.query('select username from profiles')).rows[0].username,'member_one');
    for(const name of ['member_one','MEMBER_ONE',' member_one ']) await assert.rejects(db.query('insert into profiles(username) values($1)',[name]),/duplicate key/);
    await db.exec("insert into profiles(username) values('other_member')");
    await assert.rejects(db.exec("update profiles set username='Member_One' where username='other_member'"),/duplicate key/);
    for(const role of ['anon','authenticated','service_role']) {
        await db.exec(`set role ${role}`);
        const available=async name=>(await db.query('select is_registration_username_available($1) as available',[name])).rows[0].available;
        assert.equal(await available(' MEMBER_ONE '),false);
        assert.equal(await available('new_member'),true);
        assert.equal(await available('a'.repeat(31)),false);
        assert.equal(await available(''),false);
        assert.equal(await available('staff_123'),true);
        await db.exec('reset role');
    }
    console.log('Passed: case/space duplicate insertion, duplicate update, normalization, availability checks, and all registration roles.');
} finally { await db.close(); }
