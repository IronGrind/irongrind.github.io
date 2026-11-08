import fs from 'node:fs';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
const id='11111111-1111-4111-8111-111111111111';
try{
 await db.exec(`create table mobile_attendance_scan_sessions(id uuid primary key,token_hash text,created_by uuid,expires_at timestamptz,paired_at timestamptz,paired_device text,remember_phone boolean);
 create table mobile_attendance_pairing_policy(max_pairs integer,singleton boolean); insert into mobile_attendance_pairing_policy values(2,true);
 create table profiles(id uuid,full_name text,username text,email text,role text);
 create table activity_logs(actor_id uuid,actor_name text,actor_role text,action text,entity_type text,entity_id text,record_label text,details text,changed_fields text[]);
 insert into mobile_attendance_scan_sessions values('${id}',md5('token'),null,now()+interval '10 minutes',null,null,false);`);
 const baseline=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
 const start=baseline.indexOf('CREATE OR REPLACE FUNCTION "public"."register_mobile_attendance_device"');
 await db.exec(baseline.slice(start,baseline.indexOf('ALTER FUNCTION',start)));
 const migration=fs.readFileSync('supabase/migrations/20261108000007_monthly_phone_pairing.sql','utf8');
 await db.exec(migration);
 assert.ok(Number((await db.query('select extract(epoch from expires_at-now()) as seconds from mobile_attendance_scan_sessions')).rows[0].seconds)<601,'Unpaired QR still expires after 10 minutes');
 await db.query('select register_mobile_attendance_device($1,$2,$3)',[id,'token','Phone']);
 const visit=(await db.query('select *,extract(epoch from expires_at-paired_at)/86400 as days from mobile_attendance_scan_sessions')).rows[0];
 assert.equal(Number(visit.days),30,'Even a legacy temporary option pairs for 30 days');
 await db.query('select register_mobile_attendance_device($1,$2,$3)',[id,'token','Phone']);
 assert.equal((await db.query('select expires_at from mobile_attendance_scan_sessions')).rows[0].expires_at.toISOString(),visit.expires_at.toISOString(),'Reopening does not reset the 30-day expiry');
 console.log('Passed: 10-minute QR window, 30-day paired-phone duration, and no extension when reopening.');
}finally{await db.close();}
