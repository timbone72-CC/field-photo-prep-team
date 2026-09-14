create sequence if not exists public.work_order_number_seq;

create unique index if not exists work_orders_org_wo_number_uidx
  on public.work_orders(organization_id, wo_number);

drop function if exists public.admin_create_work_order(text, text, text, text, date, uuid);
drop function if exists private.admin_create_work_order(text, text, text, text, date, uuid);

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
      and u.raw_app_meta_data ->> 'role' in ('ADMIN', 'CONTRACTOR')
  ) then
    raise exception 'Assignee is not an active Team user in this organization' using errcode = '42501';
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

create or replace function public.admin_create_work_order(
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
language sql
security invoker
set search_path = ''
as $$
  select * from private.admin_create_work_order(
    p_generate_wo_number,
    p_wo_number,
    p_property_address,
    p_work_type,
    p_instructions,
    p_due_date,
    p_assigned_user_id
  );
$$;

revoke all on sequence public.work_order_number_seq from public, anon, authenticated;
grant usage, select on sequence public.work_order_number_seq to service_role;

revoke all on function private.admin_create_work_order(boolean, text, text, text, text, date, uuid) from public, anon;
revoke all on function public.admin_create_work_order(boolean, text, text, text, text, date, uuid) from public, anon;
grant execute on function private.admin_create_work_order(boolean, text, text, text, text, date, uuid) to authenticated, service_role;
grant execute on function public.admin_create_work_order(boolean, text, text, text, text, date, uuid) to authenticated, service_role;
