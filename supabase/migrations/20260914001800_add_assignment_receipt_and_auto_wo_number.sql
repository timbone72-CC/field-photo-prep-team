alter table public.work_orders
  add column assignment_received_at timestamptz;

create sequence public.team_wo_number_seq as bigint start with 1 increment by 1 no cycle;
revoke all on sequence public.team_wo_number_seq from public, anon, authenticated;
grant usage, select on sequence public.team_wo_number_seq to service_role;

create unique index work_orders_org_wo_number_uidx
  on public.work_orders(organization_id, wo_number);

create or replace function private.admin_create_work_order(
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
      and u.raw_app_meta_data ->> 'role' in ('ADMIN', 'CONTRACTOR')
  ) then
    raise exception 'Assignee is not an active Team user in this organization' using errcode = '42501';
  end if;

  if btrim(coalesce(p_wo_number, '')) = '' then
    v_wo_number := 'TEAM-' || lpad(nextval('public.team_wo_number_seq')::text, 6, '0');
  else
    v_wo_number := btrim(p_wo_number);
    if upper(v_wo_number) like 'TEAM-%' then
      raise exception 'TEAM- numbers are reserved for automatic work-order numbering' using errcode = '22023';
    end if;
  end if;

  begin
    insert into public.work_orders (
      organization_id,
      assigned_user_id,
      wo_number,
      property_address,
      work_type,
      instructions,
      due_date,
      field_status,
      assignment_received_at
    ) values (
      v_org,
      p_assigned_user_id,
      v_wo_number,
      btrim(p_property_address),
      btrim(p_work_type),
      nullif(btrim(coalesce(p_instructions, '')), ''),
      p_due_date,
      'ASSIGNED',
      null
    )
    returning * into v_row;
  exception
    when unique_violation then
      raise exception 'Work-order number already exists in this organization' using errcode = '23505';
  end;

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
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  if p_work_order_id is null then
    raise exception 'Work order is required' using errcode = '22023';
  end if;

  if btrim(coalesce(p_wo_number, '')) = '' then
    raise exception 'Work-order number is required' using errcode = '22023';
  end if;

  if upper(btrim(p_wo_number)) like 'TEAM-%' then
    select * into v_row from public.work_orders where id = p_work_order_id;
    if not found or v_row.organization_id is distinct from v_org then
      raise exception 'Work order not available to this Admin' using errcode = '42501';
    end if;
    if btrim(p_wo_number) is distinct from v_row.wo_number then
      raise exception 'TEAM- numbers are reserved for automatic work-order numbering' using errcode = '22023';
    end if;
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

  if v_row.id is null then
    select * into v_row
    from public.work_orders
    where id = p_work_order_id;
  end if;

  if not found or v_row.organization_id is distinct from v_org then
    raise exception 'Work order not available to this Admin' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from auth.users u
    where u.id = p_assigned_user_id
      and u.deleted_at is null
      and u.raw_app_meta_data ->> 'organization_id' = v_org::text
      and u.raw_app_meta_data ->> 'role' in ('ADMIN', 'CONTRACTOR')
  ) then
    raise exception 'Assignee is not an active Team user in this organization' using errcode = '42501';
  end if;

  begin
    if v_row.field_status = 'ASSIGNED' then
      update public.work_orders
         set wo_number = btrim(p_wo_number),
             property_address = btrim(p_property_address),
             work_type = btrim(p_work_type),
             instructions = nullif(btrim(coalesce(p_instructions, '')), ''),
             due_date = p_due_date,
             assigned_user_id = p_assigned_user_id,
             assignment_received_at = case
               when p_assigned_user_id is distinct from v_row.assigned_user_id then null
               else v_row.assignment_received_at
             end,
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
             pending_assignee_user_id = case
               when p_assigned_user_id is distinct from v_row.assigned_user_id then p_assigned_user_id
               else null
             end,
             reassignment_requested_at = case
               when p_assigned_user_id is distinct from v_row.assigned_user_id then now()
               else null
             end
       where id = p_work_order_id
       returning * into v_row;
    elsif v_row.field_status in ('FIELD_COMPLETE', 'CANCELLED') then
      if p_assigned_user_id is distinct from v_row.assigned_user_id then
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
  exception
    when unique_violation then
      raise exception 'Work-order number already exists in this organization' using errcode = '23505';
  end;

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

create or replace function private.acknowledge_work_order(p_work_order_id uuid)
returns table (
  work_order_id uuid,
  assignment_received_at timestamptz
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

  select wo.* into v_row
  from public.work_orders wo
  where wo.id = p_work_order_id;

  if not found
     or v_row.organization_id is distinct from v_org
     or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;

  if v_row.field_status = 'CANCELLED' then
    raise exception 'Cancelled work order cannot be acknowledged' using errcode = '22023';
  end if;

  if v_row.assignment_received_at is null then
    update public.work_orders wo
       set assignment_received_at = now()
     where wo.id = p_work_order_id
     returning wo.* into v_row;
  end if;

  return query select v_row.id, v_row.assignment_received_at;
end;
$$;

create or replace function public.acknowledge_work_order(p_work_order_id uuid)
returns table (
  work_order_id uuid,
  assignment_received_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.acknowledge_work_order(p_work_order_id);
$$;

revoke all on function private.acknowledge_work_order(uuid) from public, anon;
revoke all on function public.acknowledge_work_order(uuid) from public, anon;
grant execute on function private.acknowledge_work_order(uuid) to authenticated, service_role;
grant execute on function public.acknowledge_work_order(uuid) to authenticated, service_role;

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
        and u.raw_app_meta_data ->> 'role' in ('ADMIN', 'CONTRACTOR')
    ) then
      raise exception 'Proposed assignee is no longer an active Team user' using errcode = '42501';
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

create or replace function private.start_work(p_work_order_id uuid)
returns table (
  work_order_id uuid,
  field_status text,
  started_at timestamptz,
  field_completed_at timestamptz
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

  if v_role not in ('ADMIN', 'CONTRACTOR') then
    raise exception 'Not permitted' using errcode = '42501';
  end if;

  select wo.* into v_row
  from public.work_orders as wo
  where wo.id = p_work_order_id;

  if not found
     or v_row.organization_id is distinct from v_org
     or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;

  if v_row.field_status = 'ASSIGNED' then
    update public.work_orders as wo
       set field_status = 'IN_PROGRESS',
           started_at = coalesce(wo.started_at, now()),
           assignment_received_at = coalesce(wo.assignment_received_at, now())
     where wo.id = p_work_order_id
     returning wo.* into v_row;
  elsif v_row.field_status = 'IN_PROGRESS' then
    if v_row.assignment_received_at is null then
      update public.work_orders as wo
         set assignment_received_at = now()
       where wo.id = p_work_order_id
       returning wo.* into v_row;
    end if;
  elsif v_row.field_status = 'FIELD_COMPLETE' then
    null;
  elsif v_row.field_status = 'CANCELLED' then
    raise exception 'Cancelled work order cannot be started' using errcode = '22023';
  else
    raise exception 'Invalid work order state' using errcode = '22023';
  end if;

  return query
  select v_row.id, v_row.field_status, v_row.started_at, v_row.field_completed_at;
end;
$$;
