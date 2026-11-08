import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
try{
 await db.exec(`create role service_role bypassrls;create role authenticated;create role anon;
 create table public.profiles(id integer primary key,role text,is_active boolean);
 insert into profiles values(1,'staff',true),(2,'admin',true);
 alter table profiles enable row level security;
 set role service_role;`);
 await assert.rejects(db.query("select * from public.profiles where role='staff'"),/permission denied/);
 await db.exec('reset role');
 const migration=fs.readFileSync('supabase/migrations/20261108000010_restore_staff_service_profile_access.sql','utf8');
 await db.exec(migration);await db.exec(migration);
 await db.exec('set role service_role');
 assert.equal((await db.query("select id from public.profiles where role='staff'")).rows.length,1);
 await db.exec("update public.profiles set is_active=false where id=1 and role='staff'");
 assert.equal((await db.query('select is_active from profiles where id=1')).rows[0].is_active,false);
 await db.exec('reset role');
 for(const role of ['authenticated','anon']){
  await db.exec(`set role ${role}`);
  await assert.rejects(db.query('select * from profiles'),/permission denied/);
  await assert.rejects(db.exec('update profiles set is_active=true where id=1'),/permission denied/);
  await db.exec('reset role');
 }
 console.log('Passed: service role can list and update staff profiles; browser roles gain no read or write permissions.');
}finally{await db.close();}
