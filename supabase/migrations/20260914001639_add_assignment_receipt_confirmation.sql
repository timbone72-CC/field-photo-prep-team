alter table public.work_orders
  add column if not exists assignment_received_at timestamptz;

-- Reconciliation replay: this migration records the live Supabase history entry created while
-- reconciling an interrupted receipt deployment. The durable receipt behavior is defined by
-- the earlier receipt migration; this replay is intentionally idempotent and keeps the live
-- migration ledger and repository history aligned.

create or replace function private.acknowledge_assignment_received(p_work_order_id uuid)
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
  select * into v_row from public.work_orders where id = p_work_order_id;
  if not found or v_row.organization_id is distinct from v_org or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;
  if v_row.field_status = 'CANCELLED' then
    raise exception 'Cancelled work order cannot be acknowledged' using errcode = '22023';
  end if;
  if v_row.assignment_received_at is null then
    update public.work_orders set assignment_received_at = now() where id = p_work_order_id returning * into v_row;
  end if;
  return query select v_row.id, v_row.assignment_received_at;
end;
$$;

create or replace function public.acknowledge_assignment_received(p_work_order_id uuid)
returns table (work_order_id uuid, assignment_received_at timestamptz)
language sql
security invoker
set search_path = ''
as $$ select * from private.acknowledge_assignment_received(p_work_order_id); $$;

revoke all on function private.acknowledge_assignment_received(uuid) from public, anon;
revoke all on function public.acknowledge_assignment_received(uuid) from public, anon;
grant execute on function private.acknowledge_assignment_received(uuid) to authenticated, service_role;
grant execute on function public.acknowledge_assignment_received(uuid) to authenticated, service_role;

-- Remaining edit/reassignment definitions were replayed unchanged by the live reconciliation.
-- Their authoritative definitions remain in 20260914000713_add_assignment_receipt_confirmation.sql.
