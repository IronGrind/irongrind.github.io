// Execute the checked-in sales function against isolated PostgreSQL tables.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
const {PGlite}=await import(pathToFileURL(process.argv[2]).href);
const db=new PGlite();const checks=[];
try{
 await db.exec(`create schema auth; create schema private;
 create function auth.uid() returns uuid language sql as $$select '11111111-1111-4111-8111-111111111111'::uuid$$;
 create function private.is_admin() returns boolean language sql as $$select current_setting('test.actor',true)='admin'$$;
 create function private.is_staff() returns boolean language sql as $$select current_setting('test.actor',true)='staff'$$;`);
 const base=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
 for(const table of ['products','sales','sale_items']){
  const sql=base.match(new RegExp(`CREATE TABLE IF NOT EXISTS "public"\\."${table}" \\([\\s\\S]*?\\n\\);`));
  assert.ok(sql,`Missing actual ${table} definition`);await db.exec(sql[0]);
 }
 const start=base.indexOf('CREATE OR REPLACE FUNCTION "public"."record_walk_in_sale"');
 assert.ok(start>=0);await db.exec(base.slice(start,base.indexOf('ALTER FUNCTION',start)));
 await db.query("select set_config('test.actor','staff',false)");
 const powder=(await db.query("insert into products(name,category,price,stock,price_per_unit,unit,stock_unit,supplement_form,supplement_type) values('Fixture powder','supplement',2,1,2,'gram','kilogram','powder','protein') returning id")).rows[0].id;
 const merch=(await db.query("insert into products(name,category,price,stock,price_per_unit,unit,stock_unit,merch_type) values('Fixture shirt','merchandise',300,3,300,'item','item','apparel') returning id")).rows[0].id;
 let sequence=0;
 const sell=async(id,quantity,unit)=>(await db.query("select record_walk_in_sale($1,'Fixture customer',$2,$3,$4) as result",[`fixture-${++sequence}`,id,quantity,unit])).rows[0].result;
 const stock=async id=>Number((await db.query('select stock from products where id=$1',[id])).rows[0].stock);
 const counts=async()=>(await db.query('select (select count(*)::int from sales) as sales,(select count(*)::int from sale_items) as lines')).rows[0];
 const first=await sell(powder,250,'gram');assert.equal(Number(first.total),500);assert.equal(await stock(powder),0.75);assert.deepEqual(await counts(),{sales:1,lines:1});checks.push('Gram sale deducts kilogram stock and saves correct total/header/line.');
 await assert.rejects(sell(powder,1000,'gram'),/Not enough stock/);assert.equal(await stock(powder),0.75);assert.deepEqual(await counts(),{sales:1,lines:1});checks.push('Insufficient stock rejects sale without partial stock/header/line writes.');
 await assert.rejects(sell(powder,1,'liter'),/sold by weight/);await assert.rejects(sell(merch,0.5,'item'),/whole-number quantity/);await assert.rejects(sell(merch,1,'box'),/configured unit/);checks.push('Weight/volume mismatch and fractional or mismatched discrete units are denied.');
 await assert.rejects(sell(powder,0,'gram'),/greater than zero/);await assert.rejects(sell(powder,-1,'gram'),/greater than zero/);checks.push('Zero and negative quantities are denied.');
 const pounds=await sell(powder,1,'pound');assert.equal(Number(pounds.total),907.18);assert.ok(Math.abs(await stock(powder)-0.296408)<0.000001);checks.push('Pounds convert to grams for pricing and kilograms for stock deduction.');
 await db.query('update products set is_active=false where id=$1',[merch]);await assert.rejects(sell(merch,1,'item'),/unavailable/);await db.query('update products set is_active=true where id=$1',[merch]);checks.push('Archived products cannot be sold.');
 await db.query("select set_config('test.actor','member',false)");await assert.rejects(sell(merch,1,'item'),/Staff sales access required/);assert.equal(await stock(merch),3);checks.push('Member role cannot record counter sales.');
 await db.query("select set_config('test.actor','admin',false)");const shirt=await sell(merch,2,'item');assert.equal(Number(shirt.total),600);assert.equal(await stock(merch),1);assert.deepEqual(await counts(),{sales:3,lines:3});checks.push('Administrator merchandise sale saves total and deducts whole items.');
 fs.writeFileSync('Documentations/Review Evidence/Sales Inventory Results.json',JSON.stringify({completedAt:new Date().toISOString(),passed:checks.length,failed:0,scope:'Isolated database, checked-in table definitions and sales function. No live transactions; concurrency and full hosted role integration are not tested.',checks},null,2)+'\n');
 console.log(`${checks.length} sales/inventory scenarios passed. No live data changed.`);
}finally{await db.close();}

