import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite }=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;
 create table auth.users(email text);create table profiles(email text);
 insert into auth.users values('unconfirmed@gmail.com');insert into profiles values('Member@gmail.com');`);
 const sql=fs.readFileSync('supabase/migrations/20261108000005_unique_registration_emails.sql','utf8');
 await db.exec(sql);await db.exec(sql);
 for(const role of ['anon','authenticated','service_role']){
  await db.exec(`set role ${role}`);
  const available=async email=>(await db.query('select is_registration_email_available($1) as available',[email])).rows[0].available;
  for(const email of ['member@gmail.com',' MEMBER@GMAIL.COM ','unconfirmed@gmail.com','not-an-email',''])assert.equal(await available(email),false);
  assert.equal(await available('new@gmail.com'),true);
  await db.exec('reset role');
 }
 await assert.rejects(db.exec("insert into profiles values(' member@GMAIL.com ')"),/duplicate key/);
 console.log('Passed: duplicate Gmail checks across roles, case/spacing variations, unconfirmed Auth accounts, invalid input, and database uniqueness.');
}finally{await db.close();}
