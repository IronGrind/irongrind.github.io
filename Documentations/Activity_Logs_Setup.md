# Activity logs

## Enable logging

Apply `supabase/migrations/20261103000000_activity_logs.sql` in the intended Supabase project's SQL Editor after the existing schema and membership migrations. Then apply `supabase/migrations/20261104000002_activity_log_sale_descriptions.sql` to add readable sale descriptions. Serve the updated website and refresh the login and admin pages. No Edge Function redeployment is required.

Open **Activity Logs** using the history icon beside the admin's name in the header. Filters support account name, area, and inclusive Manila dates. Results show 50 events per page, with Refresh and pagination controls.

The feature records successful database inserts, updates, and deletes for accounts, members, applications, attendance, products, sales, sale items, and membership history. Application decisions, attendance check-in/check-out, product archives, and membership history events receive specific action labels. Sale entries describe the product, quantity, and customer (for example, “Sold 10 g of Creatine to Maria”). One operation can produce several related events, such as a sale and its item lines.

Database triggers save the authenticated account ID and a snapshot of its name and role. The service-only member creation function supplies its verified administrator for the same transaction. Service operations without a known initiating account appear as **System / service**; an old staff reference is not reused as the actor of an unrelated update. Member changes are labeled with the member's account role.

Only administrators can read the log through the website. Authenticated users cannot directly insert, update, or delete log rows. The log stores record labels, IDs, and changed field names, without copying passwords, signatures, health declarations, or full row contents. Changes are recorded in the same transaction as the original operation.

## Identify individual staff

Each staff member needs their own Supabase Auth account and administrator profile. Sharing an email/password produces the same actor ID for everyone and cannot prove which person used it. A name typed into a shared session is not a verified identity.

The project owner can create each account in Supabase Authentication > Users, following the existing account setup, then update that account's profile in the SQL Editor:

```sql
update public.profiles
set role = 'admin', full_name = 'Actual staff name'
where id = 'THE-STAFF-AUTH-USER-UUID';
```

Confirm the profile exists and exactly the intended account was updated. Use a separate email and password for each staff member. This gives each person full existing admin access; there is no separate restricted staff role in this feature. Staff should log out when handing the PC to another person, and the next staff member should sign in with their own account.

## Check after applying

1. Sign in with a named admin account and confirm its sign-in event appears.
2. Change a product or review an application; refresh Activity Logs and check actor, action, record, and Manila time.
3. Make a change through a second admin account and confirm its different account ID and name.
4. Confirm members cannot select activity_logs and authenticated admins cannot directly insert/update/delete its rows.
5. Filter by an account, area, and date; check pagination and empty results.

## Limits

Logging starts after the migration; it does not reconstruct past actions. Sign-in and sign-out entries are app-reported events attributed by the database to the current authenticated account. A sign-out request is logged before sign-out, and closing a browser does not create one. Use Supabase Auth logs for authentication failures and security investigations. Direct privileged database maintenance may show System / service. There is no IP/device tracking or automatic retention cleanup in this feature. Logs refresh on opening the screen or clicking Refresh.

The migration requires deployment and live verification. Local JavaScript checks do not prove the migration was applied to the hosted database.

## Isolated database checks

`supabase/tests/activity_logs.mjs` runs the migration against a disposable PGlite PostgreSQL database with minimal existing-table fixtures. Pass the absolute path to an installed `@electric-sql/pglite/dist/index.js` when running it with Node. It checks trigger creation and reruns, actor attribution, transaction rollback, ignored timestamp-only updates, admin read-only access, member read isolation, session-event validation, and service-only member creation. It does not connect to Supabase or change production records.
