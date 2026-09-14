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

  select * into v_row
  from public.work_orders
  where id = p_work_order_id;

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

  if p_assigned_user_id is distinct from v_row.assigned_user_id
     and v_row.field_status <> 'ASSIGNED' then
    raise exception 'Cannot reassign after field work has started' using errcode = '22023';
  end if;

  update public.work_orders
     set wo_number = btrim(p_wo_number),
         property_address = btrim(p_property_address),
         work_type = btrim(p_work_type),
         instructions = nullif(btrim(coalesce(p_instructions, '')), ''),
         due_date = p_due_date,
         assigned_user_id = p_assigned_user_id
   where id = p_work_order_id
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
    v_row.updated_at;
end;
$$;

revoke all on function private.admin_update_work_order(uuid, text, text, text, text, date, uuid) from public, anon;
grant execute on function private.admin_update_work_order(uuid, text, text, text, text, date, uuid) to authenticated, service_role;

create or replace function public.admin_update_work_order(
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
  wo_number text,
  property_address text,
  work_type text,
  instructions text,
  due_date date,
  field_status text,
  updated_at timestamptz
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_update_work_order(
    p_work_order_id,
    p_wo_number,
    p_property_address,
    p_work_type,
    p_instructions,
    p_due_date,
    p_assigned_user_id
  );
$$;

revoke all on function public.admin_update_work_order(uuid, text, text, text, text, date, uuid) from public, anon;
grant execute on function public.admin_update_work_order(uuid, text, text, text, text, date, uuid) to authenticated, service_role;

revoke update on public.work_orders from authenticated;
drop policy if exists work_orders_admin_update on public.work_orders;
