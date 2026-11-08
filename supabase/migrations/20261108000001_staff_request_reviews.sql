-- Narrow RPC access: staff do not gain SELECT/UPDATE access to member profiles.
create or replace function public.staff_pending_membership_requests()
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not coalesce(private.is_staff(), false) and not coalesce(private.is_admin(), false) then
    raise exception 'Active staff or admin access required';
  end if;
  return coalesce((select jsonb_agg(q order by q.submitted_at) from (
    select id, full_name, application_type, plan, plan_price, submitted_at
    from public.membership_applications where status = 'pending'
  ) q), '[]'::jsonb);
end;
$$;

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
begin
  select role into operator_role from public.profiles where id = auth.uid() and is_active;
  if operator_role is null or operator_role not in ('admin','staff') then
    raise exception 'Active staff or admin access required';
  end if;
  if p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'Invalid review decision';
  end if;
  -- Lock before checking status; competing approvals cannot charge or extend twice.
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
    -- Serialize distinct registrations for the same account as well.
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
  else
    select * into m from public.members where id = a.member_id for update;
    if not found or m.auth_user_id is distinct from a.auth_user_id then raise exception 'Invalid renewal member link'; end if;
    expiry := greatest(business_date, coalesce(m.expiry_date,m.end_date,business_date)) + days;
    insert into public.membership_history(member_id,event_type,previous_plan,new_plan,previous_price,new_price,
      previous_start_date,previous_expiry_date,new_start_date,new_expiry_date,notes,recorded_by)
    values(m.id,'renewal',m.plan,a.plan,m.plan_price,a.plan_price,m.start_date,coalesce(m.expiry_date,m.end_date),
      business_date,expiry,'Member portal renewal application ' || a.id::text,auth.uid());
    update public.members set plan=a.plan,plan_price=a.plan_price,start_date=business_date,
      end_date=expiry,expiry_date=expiry,status='active',paid=a.plan_price,updated_at=now() where id=m.id;
    reference := 'IG-R-' || a.id::text;
  end if;
  insert into public.sales(receipt_number,customer_type,customer_name,member_id,total,status,sold_at,processed_by)
    values(reference,'member',m.full_name,m.id,a.plan_price,'paid',now(),auth.uid()) returning id into sale_id;
  insert into public.sale_items(sale_id,item_name,category,quantity,unit,unit_price,line_total)
    values(sale_id,a.plan || case when a.application_type='renewal' then ' Membership Renewal' else ' Membership' end,
      'membership',1,'membership',a.plan_price,a.plan_price);
  update public.membership_applications set status='approved', reviewed_at=now(), reviewed_by=auth.uid() where id=a.id;
  return jsonb_build_object('status','approved','member_id',m.id,'expiry_date',expiry);
end;
$$;
revoke all on function public.staff_pending_membership_requests() from public, anon;
revoke all on function public.review_membership_request(uuid,text) from public, anon;
grant execute on function public.staff_pending_membership_requests() to authenticated;
grant execute on function public.review_membership_request(uuid,text) to authenticated;
