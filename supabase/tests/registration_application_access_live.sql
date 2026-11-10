-- Terminal verification only: no real account, email or applicant is used.
-- Both the application and its activity-log trigger effects are rolled back.
begin;
set local role service_role;
insert into public.membership_applications (
  full_name, plan, plan_price, application_type, status,
  emergency_contact_data, start_date, end_date
)
values (
  'Registration Permission Verification Fixture', 'Monthly', 800,
  'registration', 'pending', '{"name":"Verification Guardian"}'::jsonb,
  (now() at time zone 'Asia/Manila')::date,
  (now() at time zone 'Asia/Manila')::date + 30
)
returning id, status;
rollback;

select
  has_table_privilege('service_role','public.membership_applications','INSERT') as service_insert,
  has_table_privilege('service_role','public.membership_applications','SELECT') as service_select,
  has_table_privilege('anon','public.membership_applications','INSERT') as anonymous_insert,
  (select prosecdef from pg_proc where oid='private.validate_person_name_record()'::regprocedure) as trigger_security_definer,
  not exists (
    select 1 from public.membership_applications
    where full_name='Registration Permission Verification Fixture'
  ) as fixture_rolled_back;
