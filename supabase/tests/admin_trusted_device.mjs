import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite }=await import(pathToFileURL(process.argv[2]).href);const db=new PGlite();
const user='11111111-1111-4111-8111-111111111111';
const a='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',a2='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',b='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',c='cccccccc-cccc-4ccc-8ccc-cccccccccccc',d='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const deviceA='11111111-aaaa-4aaa-8aaa-111111111111',deviceB='22222222-bbbb-4bbb-8bbb-222222222222',deviceC='33333333-cccc-4ccc-8ccc-333333333333';
const keyA={kty:'EC',crv:'P-256',x:'a'.repeat(43),y:'b'.repeat(43)},keyB={...keyA,x:'c'.repeat(43)},keyC={...keyA,x:'d'.repeat(43)};
try{
 await db.exec(`create role anon;create role authenticated;create role service_role;create role authenticator;create schema auth;create schema private;grant usage on schema auth,private to authenticated;
 create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
 create function auth.uid() returns uuid language sql as $$select (auth.jwt()->>'sub')::uuid$$;
 create function auth.role() returns text language sql as $$select auth.jwt()->>'role'$$;
 create table auth.users(id uuid primary key);insert into auth.users values('${user}');
 create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz,not_after timestamptz,aal text);
 insert into auth.sessions values('${a}','${user}',now()-interval '5 minutes',null,'aal2'),('${a2}','${user}',now()-interval '4 minutes',null,'aal1'),('${b}','${user}',now()-interval '3 minutes',null,'aal2'),('${c}','${user}',now()-interval '2 minutes',null,'aal2'),('${d}','${user}',now()-interval '1 minute',null,'aal2');
 create table public.profiles(id uuid primary key,role text,is_active boolean,full_name text);insert into profiles values('${user}','admin',true,'Owner');
 create table public.activity_logs(actor_id uuid,actor_name text,actor_role text,action text,entity_type text,entity_id text,details text);
 create table public.protected_records(id int);insert into protected_records values(1);alter table protected_records enable row level security;grant select on protected_records to authenticated;create policy allowed on protected_records to authenticated using(true);`);
 for(const file of ['20261108000003_single_account_session.sql','20261108000004_anonymous_session_guard.sql','20261108000006_separate_attendance_sessions.sql','20261110000002_admin_mfa.sql','20261110000003_admin_device_approval.sql','20261110000004_admin_trusted_device.sql'])await db.exec(fs.readFileSync('supabase/migrations/'+file,'utf8'));
 await db.exec(fs.readFileSync('supabase/migrations/20261110000004_admin_trusted_device.sql','utf8'));
 async function role(name,sid,aal='aal1'){
  await db.exec('reset role');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify(name==='service_role'?{role:name}:{role:name,sub:user,session_id:sid,aal})]);await db.exec('set role '+name);
 }
 async function challenge(sid,device,key){await role('service_role');return (await db.query("select create_admin_device_challenge($1,$2,$3,'dashboard',$4) result",[user,sid,device,key])).rows[0].result;}
 async function finish(sid,message,mfa){await role('service_role');return db.query('select finish_admin_device_login($1,$2,$3,$4,$5)',[user,sid,message,mfa,'Test browser']);}
 const initial=await challenge(a,deviceA,keyA);assert.equal(initial.reusable,false);
 await assert.rejects(finish(a,initial.message,false),/ADMIN_MFA_REQUIRED/);await finish(a,initial.message,true);
 await role('authenticated',a,'aal2');assert.equal((await db.query('select * from protected_records')).rows.length,1);
 await assert.rejects(db.query("select create_admin_device_challenge($1,$2,$3,'dashboard',$4)",[user,a,deviceA,keyA]),/permission denied/);
 await db.exec('reset role');await db.query('delete from auth.sessions where id=$1',[a]);
 const reused=await challenge(a2,deviceA,keyA);assert.equal(reused.reusable,true);await finish(a2,reused.message,false);
 await role('authenticated',a2);assert.equal((await db.query('select * from protected_records')).rows.length,1,'Password login reuses actual key trust');
 await assert.rejects(finish(a2,reused.message,false),/expired or consumed/);
 const transfer=await challenge(b,deviceB,keyB);await role('authenticated',b,'aal2');
 assert.equal((await db.query('select * from protected_records')).rows.length,0,'AAL2 alone no longer bypasses registration');
 const request=(await db.query("select request_admin_login_approval('dashboard','Device B') result")).rows[0].result;
 assert.equal(request.status,'pending','Trusted AAL1 session can approve a transfer');
 await assert.rejects(finish(b,transfer.message,true),/ADMIN_APPROVAL_REQUIRED/);
 await role('authenticated',a2);await db.query('select decide_admin_login_approval($1,true)',[request.request_id]);
 await assert.rejects(finish(b,transfer.message,false),/ADMIN_MFA_REQUIRED/);
 await role('authenticated',a2);assert.equal((await db.query('select * from protected_records')).rows.length,1,'Approval alone leaves A trusted');
 await finish(b,transfer.message,true);await role('authenticated',b,'aal2');assert.equal((await db.query('select * from protected_records')).rows.length,1);
 await role('authenticated',a2);assert.equal((await db.query('select * from protected_records')).rows.length,0,'Transfer revokes old device sessions');
 await db.exec('reset role');assert.equal((await db.query('select count(*)::int count from private.admin_trusted_devices')).rows[0].count,1);
 const denied=await challenge(c,deviceC,keyC);await role('authenticated',c,'aal2');const req=(await db.query("select request_admin_login_approval('dashboard','C') result")).rows[0].result;
 await role('authenticated',b,'aal2');await db.query('select decide_admin_login_approval($1,false)',[req.request_id]);await assert.rejects(finish(c,denied.message,true),/ADMIN_APPROVAL_REQUIRED/);
 const recovered=await challenge(d,deviceC,keyC);await db.exec('reset role');await db.exec("update private.admin_trusted_devices set last_seen_at=now()-interval '3 minutes'");
 await finish(d,recovered.message,true);await role('authenticated',d,'aal2');await db.exec('select forget_admin_trusted_device()');
 assert.equal((await db.query('select * from protected_records')).rows.length,0,'Forget revokes current access even for AAL2');
 await db.exec('reset role');assert.equal((await db.query('select count(*)::int count from private.admin_trusted_devices')).rows[0].count,0);
 console.log('Passed: first enrollment MFA, password-only key reuse after logout, service-only challenge APIs, consumed proof rejection, trusted AAL1 approver, approval plus MFA transfer, atomic old-device revocation, denied transfer isolation, offline MFA recovery, forget-device revocation and migration rerun.');
}finally{await db.close();}
