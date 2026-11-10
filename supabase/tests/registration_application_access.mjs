import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
try{
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create schema private; create schema auth;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('test.user',true),'')::uuid$$;`);
 const base=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
 for(const table of ['profiles','members','membership_applications']){
  const definition=base.match(new RegExp(`CREATE TABLE IF NOT EXISTS "public"\\."${table}" \\([\\s\\S]*?\\n\\);`));assert.ok(definition);await db.exec(definition[0]);
 }
 await db.exec(`alter table membership_applications enable row level security;
 grant usage on schema auth,private to authenticated;
 grant select,insert on membership_applications to authenticated;
 create policy own_application on membership_applications to authenticated using(auth_user_id=auth.uid()) with check(auth_user_id=auth.uid());
 grant select,insert,update on profiles,members to authenticated;`);
 await db.exec(fs.readFileSync('supabase/migrations/20261108000012_validate_person_names.sql','utf8'));
 const user='11111111-1111-4111-8111-111111111111';
 const insert=()=>db.query("insert into membership_applications(full_name,plan,auth_user_id,emergency_contact_data) values('Fixture Applicant','Monthly',$1,'{\"name\":\"Fixture Guardian\"}') returning id,status",[user]);
 await db.exec('set role service_role');
 await assert.rejects(insert(),e=>e.code==='42501'&&/membership_applications/.test(e.message));
 await db.exec('reset role;grant select,insert on membership_applications to service_role;set role service_role');
 await assert.rejects(insert(),e=>e.code==='42501'&&/private/.test(e.message));
 await db.exec('reset role;revoke select,insert on membership_applications from service_role');
 const migration=fs.readFileSync('supabase/migrations/20261110000007_restore_registration_application_access.sql','utf8');
 await db.exec(migration);await db.exec(migration);
 await db.exec('set role service_role');
 const saved=(await insert()).rows[0];assert.ok(saved.id);assert.equal(saved.status,'pending');
 await assert.rejects(db.query("insert into membership_applications(full_name,plan) values('Invalid 123','Monthly')"),/Name must contain/);
 await assert.rejects(db.query("insert into membership_applications(full_name,plan,emergency_contact_data) values('Valid Applicant','Monthly','{\"name\":\"Invalid 123\"}')"),/Emergency contact name/);
 assert.equal((await db.query('select count(*)::int as count from membership_applications')).rows[0].count,1);
 await db.exec('reset role;set role authenticated');
 await db.query("select set_config('test.user',$1,false)",[user]);
 assert.equal((await db.query('select id from membership_applications')).rows.length,1);
 assert.ok((await insert()).rows[0].id,'Existing own-account application path still validates and saves.');
 await db.query("select set_config('test.user','22222222-2222-4222-8222-222222222222',false)");
 assert.equal((await db.query('select id from membership_applications')).rows.length,0);
 await assert.rejects(insert(),/row-level security/);
 await db.query("insert into profiles(id,full_name) values($1,'Fixture Profile')",[user]);
 await assert.rejects(db.query("update profiles set full_name='Invalid 123' where id=$1",[user]),/Name must contain/);
 await db.query("insert into members(full_name,plan,emergency_contact) values('Fixture Member','Monthly','{\"name\":\"Fixture Guardian\"}')");
 await assert.rejects(db.query("insert into members(full_name,plan) values('Invalid 123','Monthly')"),/Name must contain/);
 for(const role of ['authenticated','anon']){
  await db.exec(`reset role;set role ${role}`);
  await assert.rejects(db.query("select private.is_valid_person_name('Fixture')"),e=>e.code==='42501');
 }
 await assert.rejects(insert(),e=>e.code==='42501');
 await db.exec('reset role');
 assert.equal((await db.query("select has_table_privilege('service_role','membership_applications','UPDATE') as allowed")).rows[0].allowed,false);
 assert.equal((await db.query("select has_table_privilege('service_role','membership_applications','DELETE') as allowed")).rows[0].allowed,false);
 console.log('Passed: reproduced missing service table grants and private-trigger access failures; fixed pending insert/select, name/emergency validation, own-account RLS, foreign-account denial, profile/member triggers, private helper isolation, narrow grants and migration rerun.');
}finally{await db.close();}
