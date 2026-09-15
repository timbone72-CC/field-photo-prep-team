create or replace function private.admin_list_assignable_users()
returns table (
  user_id uuid,
  email text,
  role text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  return query
  select
    u.id,
    u.email::text,
    u.raw_app_meta_data ->> 'role'
  from auth.users u
  where u.deleted_at is null
    and u.email is not null
    and u.raw_app_meta_data ->> 'organization_id' = v_org::text
    and u.raw_app_meta_data ->> 'role' = 'CONTRACTOR'
  order by lower(u.email);
end;
$$;

create or replace function private.admin_create_work_order(
  p_generate_wo_number boolean,
  p_wo_number text,
  p_property_address text,
  p_work_type text,
  p_instructions text,
  p_due_date date,
  p_assigned_user_id uuid
)
returns table (
  work_order_id uuid,
  organization_id uuid,
  assigned_user_id uuid,
  wo_number text,
  property_address text,
  work_type text,
  instructions text,
  due_date date,
  field_status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_row public.work_orders%rowtype;
  v_wo_number text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  if btrim(coalesce(p_property_address, '')) = '' then
    raise exception 'Property address is required' using errcode = '22023';
  end if;

  if btrim(coalesce(p_work_type, '')) = '' then
    raise exception 'Work type is required' using errcode = '22023';
  end if;

  if p_due_date is null then
    raise exception 'Due date is required' using errcode = '22023';
  end if;

  if p_assigned_user_id is null then
    raise exception 'Assignee is required' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = p_assigned_user_id
      and u.deleted_at is null
      and u.raw_app_meta_data ->> 'organization_id' = v_org::text
      and u.raw_app_meta_data ->> 'role' = 'CONTRACTOR'
  ) then
    raise exception 'Assignee is not an active Contractor in this organization' using errcode = '42501';
  end if;

  if coalesce(p_generate_wo_number, true) then
    v_wo_number := 'FPP-' || lpad(nextval('public.work_order_number_seq')::text, 6, '0');
  else
    v_wo_number := btrim(coalesce(p_wo_number, ''));
    if v_wo_number = '' then
      raise exception 'Work-order number is required when using a custom number' using errcode = '22023';
    end if;
  end if;

  insert into public.work_orders (
    organization_id,
    assigned_user_id,
    wo_number,
    property_address,
    work_type,
    instructions,
    due_date,
    field_status
  ) values (
    v_org,
    p_assigned_user_id,
    v_wo_number,
    btrim(p_property_address),
    btrim(p_work_type),
    nullif(btrim(coalesce(p_instructions, '')), ''),
    p_due_date,
    'ASSIGNED'
  )
  returning * into v_row;

  return query
  select
    v_row.id,
    v_row.organization_id,
    v_row.assigned_user_id,
    v_row.wo_number,
    v_row.property_address,
    v_row.work_type,
    v_row.instructions,
    v_row.due_date,
    v_row.field_status,
    v_row.created_at;
exception
  when unique_violation then
    raise exception 'That work-order number already exists in this organization' using errcode = '23505';
end;
$$;

create or replace function private.admin_update_work_order(
  p_work_order_id uuid,
  p_wo_number text,
  p_property_address text,
  p_work_type text,
  p_instructions text,
  p_due_date date,
  p_assigned_user_id uuid
)
returns table (
  work_order_id uuid,
  organization_id uuid,
  assigned_user_id uuid,
  pending_assignee_user_id uuid,
  reassignment_requested_at timestamptz,
  wo_number text,
  property_address text,
  work_type text,
  instructions text,
  due_date date,
  field_status text,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_row public.work_orders%rowtype;
  v_assignment_changed boolean;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  select * into v_row
  from public.work_orders
  where id = p_work_order_id;

  if not found or v_row.organization_id is distinct from v_org then
    raise exception 'Work order not available to this Admin' using errcode = '42501';
  end if;

  if btrim(coalesce(p_wo_number, '')) = ''
     or btrim(coalesce(p_property_address, '')) = ''
     or btrim(coalesce(p_work_type, '')) = ''
     or p_due_date is null
     or p_assigned_user_id is null then
    raise exception 'Required work-order field is missing' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = p_assigned_user_id
      and u.deleted_at is null
      and u.raw_app_meta_data ->> 'organization_id' = v_org::text
      and u.raw_app_meta_data ->> 'role' = 'CONTRACTOR'
  ) then
    raise exception 'Assignee is not an active Contractor in this organization' using errcode = '42501';
  end if;

  v_assignment_changed := p_assigned_user_id is distinct from v_row.assigned_user_id;

  if v_row.field_status = 'ASSIGNED' then
    update public.work_orders
       set wo_number = btrim(p_wo_number),
           property_address = btrim(p_property_address),
           work_type = btrim(p_work_type),
           instructions = nullif(btrim(coalesce(p_instructions, '')), ''),
           due_date = p_due_date,
           assigned_user_id = p_assigned_user_id,
           assignment_received_at = case when v_assignment_changed then null else assignment_received_at end,
           pending_assignee_user_id = null,
           reassignment_requested_at = null
     where id = p_work_order_id
     returning * into v_row;
  elsif v_row.field_status = 'IN_PROGRESS' then
    update public.work_orders
       set wo_number = btrim(p_wo_number),
           property_address = btrim(p_property_address),
           work_type = btrim(p_work_type),
           instructions = nullif(btrim(coalesce(p_instructions, '')), ''),
           due_date = p_due_date,
           pending_assignee_user_id = case when v_assignment_changed then p_assigned_user_id else null end,
           reassignment_requested_at = case when v_assignment_changed then now() else null end
     where id = p_work_order_id
     returning * into v_row;
  elsif v_row.field_status in ('FIELD_COMPLETE', 'CANCELLED') then
    if v_assignment_changed then
      raise exception 'Completed or cancelled work cannot be reassigned' using errcode = '22023';
    end if;

    update public.work_orders
       set wo_number = btrim(p_wo_number),
           property_address = btrim(p_property_address),
           work_type = btrim(p_work_type),
           instructions = nullif(btrim(coalesce(p_instructions, '')), ''),
           due_date = p_due_date,
           pending_assignee_user_id = null,
           reassignment_requested_at = null
     where id = p_work_order_id
     returning * into v_row;
  else
    raise exception 'Invalid work order state' using errcode = '22023';
  end if;

  return query
  select
    v_row.id,
    v_row.organization_id,
    v_row.assigned_user_id,
    v_row.pending_assignee_user_id,
    v_row.reassignment_requested_at,
    v_row.wo_number,
    v_row.property_address,
    v_row.work_type,
    v_row.instructions,
    v_row.due_date,
    v_row.field_status,
    v_row.updated_at;
end;
$$;

create or replace function private.respond_reassignment(
  p_work_order_id uuid,
  p_accept boolean
)
returns table (
  work_order_id uuid,
  accepted boolean,
  assigned_user_id uuid,
  field_status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_row public.work_orders%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role not in ('ADMIN', 'CONTRACTOR') or v_org is null then
    raise exception 'Not permitted' using errcode = '42501';
  end if;

  select * into v_row
  from public.work_orders
  where id = p_work_order_id;

  if not found
     or v_row.organization_id is distinct from v_org
     or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;

  if v_row.field_status <> 'IN_PROGRESS' then
    raise exception 'Reassignment consent is only available while work is in progress' using errcode = '22023';
  end if;

  if v_row.pending_assignee_user_id is null then
    raise exception 'No reassignment request is pending' using errcode = '22023';
  end if;

  if p_accept then
    if not exists (
      select 1
      from auth.users u
      where u.id = v_row.pending_assignee_user_id
        and u.deleted_at is null
        and u.raw_app_meta_data ->> 'organization_id' = v_org::text
        and u.raw_app_meta_data ->> 'role' = 'CONTRACTOR'
    ) then
      raise exception 'Proposed assignee is no longer an active Contractor' using errcode = '42501';
    end if;

    update public.work_orders
       set assigned_user_id = pending_assignee_user_id,
           assignment_received_at = null,
           pending_assignee_user_id = null,
           reassignment_requested_at = null
     where id = p_work_order_id
     returning * into v_row;
  else
    update public.work_orders
       set pending_assignee_user_id = null,
           reassignment_requested_at = null
     where id = p_work_order_id
     returning * into v_row;
  end if;

  return query
  select v_row.id, p_accept, v_row.assigned_user_id, v_row.field_status;
end;
$$;
