-- Allow members to request a paid plan change for staff or administrator review.
alter table public.membership_applications
  drop constraint if exists membership_applications_application_type_check;

alter table public.membership_applications
  add constraint membership_applications_application_type_check
  check (application_type in ('registration', 'renewal', 'plan_change'));

drop policy if exists applications_submit_own_pending on public.membership_applications;
create policy applications_submit_own_pending on public.membership_applications
  for insert to authenticated
  with check (
    auth_user_id = (select auth.uid())
    and status = 'pending'
    and reviewed_at is null
    and reviewed_by is null
    and (
      (application_type = 'registration' and member_id is null)
      or (application_type in ('renewal', 'plan_change') and exists (
        select 1 from public.members m
        where m.id = membership_applications.member_id
          and m.auth_user_id = (select auth.uid())
      ))
    )
  );

create or replace function public.review_membership_request(p_application_id uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  a public.membership_applications%rowtype;
  m public.members%rowtype;
  operator_role text;
  business_date date := (now() at time zone 'Asia/Manila')::date;
  expiry date;
  days integer;
  sale_id uuid;
  reference text;
  item_label text;
begin
  select role into operator_role from public.profiles where id = auth.uid() and is_active;
  if operator_role is null or operator_role not in ('admin', 'staff') then
    raise exception 'Active staff or admin access required';
  end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Invalid review decision';
  end if;

  select * into a from public.membership_applications where id = p_application_id for update;
  if not found then raise exception 'Request not found'; end if;
  if a.status <> 'pending' then raise exception 'This request has already been reviewed'; end if;
  if p_decision = 'rejected' then
    update public.membership_applications set status = 'rejected', reviewed_at = now(), reviewed_by = auth.uid() where id = a.id;
    return jsonb_build_object('status','rejected');
  end if;

  days := case a.plan when 'Monthly' then 30 when 'Half Month' then 15 when 'Walk-in' then 1 else null end;
  if days is null or a.plan_price <= 0 then raise exception 'Unsupported membership plan or price'; end if;
  if operator_role = 'staff' and not (
    (a.plan = 'Monthly' and a.plan_price = 800) or
    (a.plan = 'Half Month' and a.plan_price = 400) or
    (a.plan = 'Walk-in' and a.plan_price = 80)
  ) then raise exception 'Only an administrator can review a nonstandard price'; end if;

  if a.application_type = 'registration' then
    if a.auth_user_id is null then raise exception 'Application has no linked account'; end if;
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(a.auth_user_id::text, 0));
    if exists(select 1 from public.members where auth_user_id = a.auth_user_id) then
      raise exception 'An existing member is linked to this account; administrator reconciliation is required';
    end if;
    expiry := business_date + days;
    insert into public.members(application_id, auth_user_id, full_name, email, username,
      mobile, date_of_birth, age, sex, height, height_unit, weight_kg, emergency_contact,
      plan, plan_price, start_date, end_date, expiry_date, status, paid, fitness_goals,
      health_conditions, other_medical_conditions, signature_path, registration_source)
    values(a.id, a.auth_user_id, a.full_name, a.email, a.username, a.mobile,
      a.date_of_birth, a.age, a.sex, a.height, a.height_unit, coalesce(a.weight_kg,a.weight),
      case when a.emergency_contact_data <> '{}'::jsonb then a.emergency_contact_data else
        jsonb_build_object('name',a.emergency_name,'relationship',a.emergency_relationship,'contact',a.emergency_contact) end,
      a.plan,a.plan_price,business_date,expiry,expiry,'active',a.plan_price,a.fitness_goals,
      a.health_conditions,a.other_medical_conditions,coalesce(a.signature_path,a.signature_data),'Online application') returning * into m;
    reference := 'IG-REG-' || a.id::text;
    item_label := a.plan || ' Membership';
  else
    select * into m from public.members where id = a.member_id for update;
    if not found or m.auth_user_id is distinct from a.auth_user_id then raise exception 'Invalid member request link'; end if;
    if a.application_type = 'plan_change' then
      if m.status is distinct from 'active' then raise exception 'This member must renew before changing plans'; end if;
      if m.plan is not distinct from a.plan and m.plan_price = a.plan_price then
        raise exception 'The member already has this plan and price';
      end if;
      expiry := business_date + days;
      reference := 'IG-PC-' || a.id::text;
      item_label := a.plan || ' Membership Plan Change';
    elsif a.application_type = 'renewal' then
      expiry := greatest(business_date, coalesce(m.expiry_date,m.end_date,business_date)) + days;
      reference := 'IG-R-' || a.id::text;
      item_label := a.plan || ' Membership Renewal';
    else
      raise exception 'Unsupported membership request type';
    end if;

    insert into public.membership_history(member_id,event_type,previous_plan,new_plan,previous_price,new_price,
      previous_start_date,previous_expiry_date,new_start_date,new_expiry_date,notes,recorded_by)
    values(m.id,a.application_type,m.plan,a.plan,m.plan_price,a.plan_price,m.start_date,coalesce(m.expiry_date,m.end_date),
      business_date,expiry,'Member portal ' || replace(a.application_type, '_', ' ') || ' request ' || a.id::text,auth.uid());
    update public.members set plan=a.plan,plan_price=a.plan_price,start_date=business_date,
      end_date=expiry,expiry_date=expiry,status='active',paid=a.plan_price,updated_at=now() where id=m.id;
  end if;

  insert into public.sales(receipt_number,customer_type,customer_name,member_id,total,status,sold_at,processed_by)
    values(reference,'member',m.full_name,m.id,a.plan_price,'paid',now(),auth.uid()) returning id into sale_id;
  insert into public.sale_items(sale_id,item_name,category,quantity,unit,unit_price,line_total)
    values(sale_id,item_label,'membership',1,'membership',a.plan_price,a.plan_price);
  update public.membership_applications set status='approved', reviewed_at=now(), reviewed_by=auth.uid() where id=a.id;
  return jsonb_build_object('status','approved','member_id',m.id,'expiry_date',expiry);
end;
$$;

revoke all on function public.review_membership_request(uuid,text) from public, anon;
grant execute on function public.review_membership_request(uuid,text) to authenticated;
