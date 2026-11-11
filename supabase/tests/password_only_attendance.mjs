import assert from 'node:assert/strict';
import fs from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
const db=new PGlite();
const admin='11111111-1111-4111-8111-111111111111',staff='22222222-2222-4222-8222-222222222222';
const web='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',phone='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',next='cccccccc-cccc-4ccc-8ccc-cccccccccccc',staffPhone='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
const device='11111111-aaaa-4aaa-8aaa-111111111111';
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create role authenticator;
 create schema auth;create schema private;grant usage on schema auth,private to authenticated;
 create function auth.jwt() returns jsonb language sql as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
 create function auth.uid() returns uuid language sql as $$select (auth.jwt()->>'sub')::uuid$$;
 create function auth.role() returns text language sql as $$select auth.jwt()->>'role'$$;
 create table auth.users(id uuid primary key);insert into auth.users values('${admin}'),('${staff}');
 create table auth.sessions(id uuid primary key,user_id uuid,created_at timestamptz,not_after timestamptz,aal text);
 insert into auth.sessions values('${web}','${admin}',now()-interval '5 minutes',null,'aal2'),('${phone}','${admin}',now()-interval '3 minutes',null,'aal1'),('${next}','${admin}',now(),null,'aal1'),('${staffPhone}','${staff}',now(),null,'aal1');
 create table public.profiles(id uuid primary key,role text,is_active boolean,full_name text);
 insert into profiles values('${admin}','admin',true,'Owner'),('${staff}','staff',true,'Staff');
 create table public.activity_logs(actor_id uuid,actor_name text,actor_role text,action text,entity_type text,entity_id text,details text);
 create table public.protected_records(id int);insert into protected_records values(1);
 alter table protected_records enable row level security;grant select on protected_records to authenticated;create policy allowed on protected_records to authenticated using(true);
 create function public.log_account_activity(text) returns void language sql as $$select$$;
 create function public.record_attendance_scan(text,uuid,uuid,text) returns jsonb language plpgsql as $$begin
 if $3 is distinct from '${device}'::uuid or $4 is distinct from 'valid-pairing' then raise exception 'Phone pairing is invalid or expired'; end if;
 return '{"action":"check_in"}'::jsonb;end$$;`);
 for(const file of ['20261108000003_single_account_session.sql','20261108000004_anonymous_session_guard.sql','20261108000006_separate_attendance_sessions.sql','20261110000002_admin_mfa.sql','20261110000003_admin_device_approval.sql','20261110000004_admin_trusted_device.sql','20261111000001_password_only_attendance_operator.sql'])await db.exec(fs.readFileSync('supabase/migrations/'+file,'utf8'));
 async function login(uid,sid,aal='aal1') {
  await db.exec('reset role');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:'authenticated',sub:uid,session_id:sid,aal})]);await db.exec('set role authenticated');
 }
 async function request(path,sql,args=[]) {await db.query("select set_config('request.path',$1,false)",[path]);await db.query('select enforce_account_session()');return db.query(sql,args);}
 await db.exec(`insert into private.admin_trusted_devices(user_id,device_id,public_key,device_label,expires_at) values('${admin}','${device}','{}','Website',now()+interval '30 days');
 insert into private.admin_device_sessions(session_id,user_id,device_id,session_scope,public_key,challenge,challenge_expires_at,authorized_until) values('${web}','${admin}','${device}','dashboard','{}','',now(),now()+interval '30 days');
 insert into private.account_sessions values('${admin}','${web}',now()-interval '5 minutes','dashboard');`);
 await login(admin,phone);
 await request('/rpc/activate_attendance_session','select activate_attendance_session()');
 assert.equal((await request('/rpc/get_attendance_operator','select get_attendance_operator() result')).rows[0].result.id,admin);
 assert.equal((await request('/rpc/current_attendance_session_is_active','select current_attendance_session_is_active() active')).rows[0].active,true);
 assert.equal((await db.query('select * from protected_records')).rows.length,0,'Scanner cannot read tables through RLS');
 for(const path of ['/profiles','/rpc/activate_account_session','/rpc/get_admin_trusted_device','/rpc/record_attendance_scan','/rpc/admin_mfa_required'])await assert.rejects(request(path,'select 1'),/SCANNER_ACCESS_ONLY/);
 await assert.rejects(db.query('select activate_account_session()'),/ADMIN_DEVICE_REQUIRED/);
 await assert.rejects(request('/rpc/record_scanner_attendance','select record_scanner_attendance($1,$2,$3,$4)',['member',phone,null,null]),/Phone pairing is required/);
 await assert.rejects(request('/rpc/record_scanner_attendance','select record_scanner_attendance($1,$2,$3,$4)',['member',phone,device,'invalid']),/invalid or expired/);
 assert.equal((await request('/rpc/record_scanner_attendance','select record_scanner_attendance($1,$2,$3,$4) result',['member',phone,device,'valid-pairing'])).rows[0].result.action,'check_in');
 await assert.rejects(request('/rpc/log_scanner_activity',"select log_scanner_activity('report_export_requested')"),/Unsupported scanner event/);
 await login(admin,web,'aal2');await request('/protected_records','select * from protected_records');
 assert.equal((await db.query('select private.is_admin() allowed')).rows[0].allowed,true);
 await assert.rejects(request('/rpc/activate_attendance_session','select activate_attendance_session()'),/separate sign-in/);
 await login(admin,next);await request('/rpc/activate_attendance_session','select activate_attendance_session()');
 await login(admin,phone);assert.equal((await request('/rpc/current_attendance_session_is_active','select current_attendance_session_is_active() active')).rows[0].active,false);
 await assert.rejects(request('/rpc/get_attendance_operator','select get_attendance_operator()'),/Active scanner session required/);
 await assert.rejects(request('/rpc/activate_attendance_session','select activate_attendance_session()'),/ACCOUNT_SESSION_REPLACED/);
 await login(staff,staffPhone);await request('/rpc/activate_attendance_session','select activate_attendance_session()');
 assert.equal((await db.query('select * from protected_records')).rows.length,0,'Staff scanner RLS also denies website records');
 await assert.rejects(request('/rpc/record_walk_in_sale','select 1'),/SCANNER_ACCESS_ONLY/);
 await login(admin,web,'aal2');await request('/rpc/forget_admin_trusted_device','select forget_admin_trusted_device()');
 await login(admin,next);assert.equal((await request('/rpc/current_attendance_session_is_active','select current_attendance_session_is_active() active')).rows[0].active,true,'Website forget preserves scanner');
 await db.exec('reset role');await db.exec(`update profiles set is_active=false where id='${admin}'`);
 await login(admin,next);assert.equal((await request('/rpc/current_attendance_session_is_active','select current_attendance_session_is_active() active')).rows[0].active,false);
 console.log('Passed: password-only admin/staff scanner, website coexistence, website MFA retained, RLS and RPC isolation, mandatory pairing, restricted audit, replacement, website forget isolation and inactive-account rejection.');
} finally {await db.close();}
