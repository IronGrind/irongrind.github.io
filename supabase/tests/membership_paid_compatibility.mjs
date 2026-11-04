import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const migration = await readFile(new URL('../migrations/20261104000029_membership_paid_type_compatibility.sql', import.meta.url), 'utf8');
for (const type of ['boolean', 'numeric']) {
    const db = new PGlite();
    try {
        await db.exec(`
            create table members(id uuid primary key, paid ${type});
            insert into members values ('11111111-1111-4111-8111-111111111111', null);
            create function public.admin_record_membership_change(uuid,text,text,numeric,date,date,text,text,text)
            returns jsonb language plpgsql as $$
            declare member_row public.members%rowtype;
            begin
                select * into member_row from public.members where id=$1;
                if pg_typeof(member_row.paid)::text='boolean' then
                    update public.members set paid = true where id = member_row.id;
                else
                    execute 'update public.members set paid = $1 where id = $2' using $4, member_row.id;
                end if;
                return '{}'::jsonb;
            end;
            $$;
        `);
        await db.exec(migration);
        await db.exec(migration);
        assert.equal((await db.query('select paid from members')).rows[0].paid, null, 'Migration changes no payment values');
        await db.query("select admin_record_membership_change('11111111-1111-4111-8111-111111111111','renewal','Monthly',500,current_date,current_date,'Name','Phone','Reference')");
        const paid = (await db.query('select paid from members')).rows[0].paid;
        assert.equal(type === 'boolean' ? paid : Number(paid), type === 'boolean' ? true : 500);
    } finally { await db.close(); }
}
console.log('Passed: boolean/numeric payment schemas, migration rerun, existing values unchanged.');
