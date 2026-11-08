import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const staff='11111111-1111-4111-8111-111111111111', member='22222222-2222-4222-8222-222222222222';
try {
    await db.exec(`create role anon; create role authenticated; create schema auth; create schema private;
        create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
        create table profiles(id uuid primary key,role text,is_active boolean);
        insert into profiles values('${staff}','staff',true),('${member}','member',true);
        create function private.is_staff() returns boolean language sql as $$select exists(select 1 from public.profiles where id=auth.uid() and role='staff' and is_active)$$;
        create function private.is_admin() returns boolean language sql as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and is_active)$$;`);
    const baseline=fs.readFileSync('supabase/migrations/20261105043517_remote_schema.sql','utf8');
    for(const table of ['members','membership_applications','membership_history','sales','sale_items']) {
        const sql=baseline.match(new RegExp(`CREATE TABLE IF NOT EXISTS "public"\."${table}" \\([\\s\\S]*?\\n\\);`))[0];
        await db.exec(sql);
    }
    await db.exec('alter table members enable row level security; grant select on members to authenticated;');
    const migration=fs.readFileSync('supabase/migrations/20261108000001_staff_request_reviews.sql','utf8');
    await db.exec(migration); await db.exec(migration);
    const login=async id=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated');};
    const seed=async(type='registration',price=800)=>{
        await db.exec('reset role');
        return (await db.query(`insert into membership_applications(id,auth_user_id,member_id,full_name,plan,plan_price,application_type)
          values(gen_random_uuid(),$1,(select id from members limit 1), 'Test Member','Monthly',$2,$3) returning id`,[member,price,type])).rows[0].id;
    };
    const review=async(id,decision='approved')=>(await db.query('select review_membership_request($1,$2) as result',[id,decision])).rows[0].result;
    const id=await seed(); await login(member);
    await assert.rejects(review(id),/access required/);
    await login(staff);
    const pending=(await db.query('select staff_pending_membership_requests() as result')).rows[0].result;
    assert.equal(pending.length,1); assert.equal('health_conditions' in pending[0],false);
    assert.equal((await review(id)).status,'approved');
    await assert.rejects(review(id),/already been reviewed/);
    assert.equal((await db.query('select * from members')).rows.length,0,'Staff cannot view member profiles');
    await db.exec('reset role');
    assert.equal(Number((await db.query('select count(*) as n from sales')).rows[0].n),1);
    assert.equal((await db.query('select processed_by from sales')).rows[0].processed_by,staff);
    const renewal=await seed('renewal'); await login(staff);
    await review(renewal);
    await db.exec('reset role');
    assert.equal(Number((await db.query('select count(*) as n from membership_history')).rows[0].n),1);
    assert.equal(Number((await db.query('select expiry_date-start_date as days from members')).rows[0].days),60,'Renewal extends existing unexpired subscription');
    const rejected=await seed('renewal'); await login(staff); await review(rejected,'rejected');
    const invalid=await seed('renewal',5); await login(staff); await assert.rejects(review(invalid),/nonstandard price/);
    await db.exec('reset role');
    assert.equal(Number((await db.query('select count(*) as n from sales')).rows[0].n),2,'Rejected and invalid requests record no sale');
    const failed=await seed('renewal');
    await db.exec(`create function fail_review_sale() returns trigger language plpgsql as $$begin raise exception 'Simulated payment write failure'; end$$;
        create trigger fail_review_sale before insert on sales for each row execute function fail_review_sale();`);
    await login(staff); await assert.rejects(review(failed),/Simulated payment/); await db.exec('reset role');
    assert.equal((await db.query('select status from membership_applications where id=$1',[failed])).rows[0].status,'pending');
    assert.equal(Number((await db.query('select count(*) as n from membership_history')).rows[0].n),1,'Payment failure rolls back renewal history');
    assert.equal(Number((await db.query('select expiry_date-start_date as days from members')).rows[0].days),60,'Payment failure rolls back subscription changes');
    await db.exec('drop trigger fail_review_sale on sales');
    await db.exec(`update profiles set is_active=false where id='${staff}'`); await login(staff);
    await assert.rejects(review(invalid),/access required/);
    await db.exec('reset role; set role anon'); await assert.rejects(review(invalid),/permission denied/);
    console.log('Passed: staff review, renewal extension, duplicate prevention, rejection, invalid prices, inactive/member/anonymous denial, and profile isolation.');
} finally { await db.close(); }

