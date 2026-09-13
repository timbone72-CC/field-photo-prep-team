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
           started_at = coalesce(wo.started_at, now())
     where wo.id = p_work_order_id
     returning wo.* into v_row;
  elsif v_row.field_status in ('IN_PROGRESS', 'FIELD_COMPLETE') then
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

create or replace function private.complete_field_work(p_work_order_id uuid)
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

  if v_row.field_status = 'IN_PROGRESS' then
    update public.work_orders as wo
       set field_status = 'FIELD_COMPLETE',
           field_completed_at = coalesce(wo.field_completed_at, now())
     where wo.id = p_work_order_id
     returning wo.* into v_row;
  elsif v_row.field_status = 'FIELD_COMPLETE' then
    null;
  elsif v_row.field_status = 'ASSIGNED' then
    raise exception 'Work order must be started before field completion' using errcode = '22023';
  elsif v_row.field_status = 'CANCELLED' then
    raise exception 'Cancelled work order cannot be completed' using errcode = '22023';
  else
    raise exception 'Invalid work order state' using errcode = '22023';
  end if;

  return query
  select v_row.id, v_row.field_status, v_row.started_at, v_row.field_completed_at;
end;
$$;
