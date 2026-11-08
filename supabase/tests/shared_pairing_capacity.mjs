import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
const actor='11111111-1111-4111-8111-111111111111';
try{
 await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
 create function auth.uid() returns uuid language sql as $$select '${actor}'::uuid$$;
 create function private.is_admin() returns boolean language sql as $$select true$$;
 create function private.require_pairing_password(text) returns void language sql as $$select$$;
 create function private.require_attendance_removal_pin(text) returns void language sql as $$select$$;
 create table profiles(id uuid,full_name text,username text,email text,role text);
 create table mobile_attendance_pairing_policy(singleton boolean,max_pairs integer,pairing_password_hash text,updated_at timestamptz,updated_by uuid);
 insert into mobile_attendance_pairing_policy values(true,2,'configured',now(),null);
 create table mobile_attendance_scan_sessions(id uuid primary key default gen_random_uuid(),token_hash text,created_by uuid,created_at timestamptz default now(),expires_at timestamptz,paired_at timestamptz,paired_device text,remember_phone boolean);
 create table activity_logs(actor_id uuid,actor_name text,actor_role text,action text,entity_type text,entity_id text,record_label text,details text,changed_fields text[]);
 insert into mobile_attendance_scan_sessions(token_hash,expires_at,paired_at,paired_device) values(md5('paired'),now()+interval '30 days',now(),'Phone 1');`);
 const baseline=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
 for(const name of ['create_mobile_attendance_scan_session','get_mobile_attendance_pairing_settings','register_mobile_attendance_device','set_mobile_attendance_pairing_limit']){
  const start=baseline.indexOf(`CREATE OR REPLACE FUNCTION "public"."${name}"`);assert.ok(start>=0);
  await db.exec(baseline.slice(start,baseline.indexOf('ALTER FUNCTION',start)));
 }
 const create=async()=>(await db.query("select create_mobile_attendance_scan_session(true,'password') as result")).rows[0].result;
 const first=await create();const newest=await create();
 await db.query("update mobile_attendance_scan_sessions set created_at=now()-interval '1 minute' where id=$1",[first.session_id]);
 await db.exec(fs.readFileSync('supabase/migrations/20261108000009_shared_pairing_capacity.sql','utf8'));
 const settings=async()=>(await db.query('select get_mobile_attendance_pairing_settings() as result')).rows[0].result;
 const initial=await settings();assert.equal(initial.paired_count,1);assert.equal(initial.pending_count,1);assert.equal(initial.active_count,2);
 await assert.rejects(create(),/pairing limit reached/);
 await db.query('select register_mobile_attendance_device($1,$2,$3)',[newest.session_id,newest.token,'Phone 2']);
 let state=await settings();assert.equal(state.paired_count,2);assert.equal(state.pending_count,0);assert.equal(state.active_count,2);
 await assert.rejects(create(),/pairing limit reached/);
 await db.exec("update mobile_attendance_scan_sessions set expires_at=now() where paired_device='Phone 1'");
 await create();state=await settings();assert.equal(state.paired_count,1);assert.equal(state.pending_count,1);assert.equal(state.active_count,2);
 await db.exec("select set_mobile_attendance_pairing_limit(3,'pin')");await create();
 await db.exec("select set_mobile_attendance_pairing_limit(2,'pin')");state=await settings();assert.equal(state.active_count,2);assert.equal(state.pending_count,1);
 console.log('Passed: paired plus pending shares the limit, overflow pending QR expires without disconnecting paired phones, pairing a reserved slot stays within capacity, and reducing the limit trims pending reservations.');
}finally{await db.close();}
