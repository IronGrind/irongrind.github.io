import fs from 'node:fs';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite(),admin='11111111-1111-4111-8111-111111111111',staff='22222222-2222-4222-8222-222222222222';
try{
 await db.exec(`create schema auth;create schema private;
 create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 create table profiles(id uuid primary key,role text,is_active boolean);
 insert into profiles values('${admin}','admin',true),('${staff}','staff',true);`);
 const base=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
 for(const table of ['members','membership_history','sales','sale_items'])await db.exec(base.match(new RegExp(`CREATE TABLE IF NOT EXISTS "public"\."${table}" \\([\\s\\S]*?\\n\\);`))[0]);
 const start=base.indexOf('CREATE OR REPLACE FUNCTION "public"."admin_record_membership_change"');
 await db.exec(base.slice(start,base.indexOf('ALTER FUNCTION',start)));
 await db.exec(fs.readFileSync('supabase/migrations/20261108000011_admin_and_membership_checks.sql','utf8'));
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[admin]);
 assert.equal((await db.query('select private.is_admin() as allowed')).rows[0].allowed,true);
 await db.query('update profiles set is_active=false where id=$1',[admin]);
 assert.equal((await db.query('select private.is_admin() as allowed')).rows[0].allowed,false);
 await db.query('update profiles set is_active=true where id=$1',[admin]);
 const member=(await db.query("insert into members(full_name,mobile,plan,plan_price) values('Test Member','09123456789','Monthly',800) returning id")).rows[0].id;
 const change=async(type,plan,price,reference)=>db.query(`select admin_record_membership_change($1,$2,$3,$4,
   (now() at time zone 'Asia/Manila')::date,(now() at time zone 'Asia/Manila')::date + case $3 when 'Monthly' then 30 else 15 end,
   'Test Member','09123456789',$5)`,[member,type,plan,price,reference]);
 await change('renewal','Monthly',800,'audit-renewal');
 assert.equal(Number((await db.query('select paid from members where id=$1',[member])).rows[0].paid),800);
 await db.query("select set_config('request.jwt.claim.sub',$1,false)",[staff]);
 await change('plan_change','Half Month',400,'audit-plan-change');
 const row=(await db.query('select paid,plan from members where id=$1',[member])).rows[0];assert.equal(Number(row.paid),400);assert.equal(row.plan,'Half Month');
 await db.query('update profiles set is_active=false where id=$1',[staff]);
 await assert.rejects(change('renewal','Monthly',800,'audit-denied'),/Active staff or admin/);
 assert.equal(Number((await db.query('select count(*) as n from sales')).rows[0].n),2);
 console.log('Passed: active-admin authorization, inactive-admin denial, numeric renewal and plan-change payments, and inactive-staff denial.');
}finally{await db.close();}
