import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const admin='11111111-1111-4111-8111-111111111111', staff='22222222-2222-4222-8222-222222222222';
const session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', next='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
try {
 await db.exec(`create role anon; create role authenticated; create role service_role; create role authenticator;
 create schema auth; create schema private; grant usage on schema auth,private to authenticated;
 create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
 create function auth.uid() returns uuid language sql as $$select (auth.jwt()->>'sub')::uuid$$;
 create function auth.role() returns text language sql as $$select auth.jwt()->>'role'$$;
 create table auth.users(id uuid primary key);insert into auth.users values('${admin}'),('${staff}');
 create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz,not_after timestamptz);
 insert into auth.sessions values('${session}','${admin}',now()-interval '2 minutes',null),('${next}','${staff}',now(),null);
 create table public.profiles(id uuid primary key,role text,is_active boolean);
 insert into profiles values('${admin}','admin',true),('${staff}','staff',true);
 create table public.protected_records(id integer);insert into protected_records values(1);
 alter table protected_records enable row level security;grant select on protected_records to authenticated;
 create policy permitted on protected_records to authenticated using(true);`);
 for(const file of ['20261108000003_single_account_session.sql','20261108000004_anonymous_session_guard.sql','20261108000006_separate_attendance_sessions.sql','20261110000002_admin_mfa.sql']) {
   await db.exec(fs.readFileSync('supabase/migrations/'+file,'utf8'));
 }
 await db.exec(fs.readFileSync('supabase/migrations/20261110000002_admin_mfa.sql','utf8'));
 async function login(uid,sid,aal) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:uid,session_id:sid,aal,role:'authenticated'})]);
  await db.exec('set role authenticated');
 }
 await login(admin,session,'aal1');
 assert.equal((await db.query('select public.admin_mfa_required() required')).rows[0].required,true);
 assert.equal((await db.query('select * from protected_records')).rows.length,0);
 await assert.rejects(db.exec('select activate_account_session()'),/ADMIN_MFA_REQUIRED/);
 await assert.rejects(db.exec('select activate_attendance_session()'),/ADMIN_MFA_REQUIRED/);
 await db.exec("select set_config('request.path','/rpc/admin_mfa_required',false); select enforce_account_session()");
 await db.exec("select set_config('request.path','/profiles',false)");
 await assert.rejects(db.exec('select enforce_account_session()'),/ADMIN_MFA_REQUIRED/);
 await login(admin,session,'aal2'); await db.exec('select activate_account_session(); select enforce_account_session()');
 assert.equal((await db.query('select * from protected_records')).rows.length,1);
 await login(staff,next,'aal1'); await db.exec('select activate_account_session()');
 assert.equal((await db.query('select * from protected_records')).rows.length,1);
 await db.exec('reset role; set role anon');
 await assert.rejects(db.exec('select public.admin_mfa_required()'),/permission denied/);
 console.log('Passed: admin MFA blocks direct RLS reads, dashboard/scanner activation and protected RPC requests at AAL1; bootstrap limited to own boolean; AAL2 and staff access preserved; migration rerun passes.');
}finally {await db.close();}
