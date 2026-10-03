-- FWH Phase 3 immutable field action acceptance. Additive; no business backfill.
alter table public.work_order_assignments add constraint work_order_assignments_id_run_unique unique(id,run_id);
create table public.field_actions (
 action_id uuid primary key,
 actor_user_id uuid not null references auth.users(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 work_order_id uuid not null references public.work_orders(id) on delete restrict,
 run_id uuid not null,
 assignment_instance_id uuid not null,
 action_kind text not null check(action_kind in ('START','COMPLETE')),
 event_time_text text not null,
 event_at timestamptz not null,
 accepted_at timestamptz not null default now(),
 result jsonb not null check(jsonb_typeof(result)='object'),
 foreign key(run_id,work_order_id) references public.work_order_runs(id,work_order_id) on delete restrict,
 foreign key(assignment_instance_id,run_id) references public.work_order_assignments(id,run_id) on delete restrict
);
create index field_actions_actor_org_idx on public.field_actions(actor_user_id,organization_id);
create index field_actions_org_idx on public.field_actions(organization_id);
create index field_actions_wo_idx on public.field_actions(work_order_id);
create index field_actions_run_wo_idx on public.field_actions(run_id,work_order_id);
create index field_actions_assignment_run_idx on public.field_actions(assignment_instance_id,run_id);
alter table public.field_actions enable row level security;
revoke all on public.field_actions from public, anon, authenticated;
grant select on public.field_actions to authenticated;
grant all on public.field_actions to service_role;
create policy field_actions_select_allowed on public.field_actions for select to authenticated using (
 organization_id=nullif((select auth.jwt()->'app_metadata'->>'organization_id'),'')::uuid
 and (actor_user_id=(select auth.uid()) or (select auth.jwt()->'app_metadata'->>'role')='ADMIN')
);

create or replace function private.field_assignments()
returns setof jsonb language plpgsql security definer set search_path='' as $$
declare
 v_uid uuid:=auth.uid();
 v_org uuid:=nullif(auth.jwt()->'app_metadata'->>'organization_id','')::uuid;
 v_role text:=auth.jwt()->'app_metadata'->>'role';
begin
 if v_uid is null or v_org is null or v_role is null or v_role not in ('CONTRACTOR','ADMIN') or not exists(
 select 1 from auth.users u where u.id=v_uid and u.deleted_at is null
 and (u.banned_until is null or u.banned_until<=now())
 and u.raw_app_meta_data->>'organization_id'=v_org::text and u.raw_app_meta_data->>'role'=v_role
 ) then raise exception 'Authentication required' using errcode='42501'; end if;
 if v_role='CONTRACTOR' and not private.is_assignable_contractor(v_uid,v_org) then
 raise exception 'Contractor authorization required' using errcode='42501'; end if;
 return query select to_jsonb(w)||jsonb_build_object('assignment_instance_id',a.id)
 from public.work_orders w left join lateral (
 select h.id from public.work_order_assignments h
 where h.run_id=w.current_run_id and h.assigned_user_id=w.assigned_user_id
 and (h.assignment_ended_at is null or (w.field_status='FIELD_COMPLETE' and h.end_reason='FIELD_COMPLETE'))
 order by h.assignment_started_at desc,h.created_at desc limit 1
 ) a on true
 where w.organization_id=v_org and (v_role='ADMIN' or w.assigned_user_id=v_uid)
 order by w.due_date,w.wo_number;
end; $$;
create or replace function public.field_assignments()
returns setof jsonb language sql security invoker set search_path='' as $$select * from private.field_assignments();$$;
revoke all on function private.field_assignments() from public,anon;
revoke all on function public.field_assignments() from public,anon;
grant execute on function private.field_assignments() to authenticated,service_role;
grant execute on function public.field_assignments() to authenticated,service_role;

create or replace function private.accept_field_action(
 p_action_id uuid,p_work_order_id uuid,p_run_id uuid,p_assignment_instance_id uuid,p_action_kind text,p_event_time text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_uid uuid:=auth.uid();
 v_org uuid:=nullif(auth.jwt()->'app_metadata'->>'organization_id','')::uuid;
 v_role text:=auth.jwt()->'app_metadata'->>'role';
 v_old public.field_actions%rowtype;
 v_wo public.work_orders%rowtype;
 v_assignment public.work_order_assignments%rowtype;
 v_event timestamptz;
 v_reason text;
 v_result jsonb;
 v_outcome text:='APPLIED';
begin
 -- Current server-controlled membership gates both replay and new transitions.
 if v_uid is null or v_org is null or v_role is distinct from 'CONTRACTOR'
 or not private.is_assignable_contractor(v_uid,v_org) then
 raise exception 'Contractor authorization required' using errcode='42501'; end if;
 if p_action_id is null then return jsonb_build_object('outcome','CONFLICT','reason','INVALID_ACTION'); end if;
 perform pg_advisory_xact_lock(hashtextextended('fwh.action.'||p_action_id::text,0));
 select * into v_old from public.field_actions where action_id=p_action_id;
 if found then
 if v_old.actor_user_id is distinct from v_uid or v_old.organization_id is distinct from v_org
 or v_old.work_order_id is distinct from p_work_order_id or v_old.run_id is distinct from p_run_id
 or v_old.assignment_instance_id is distinct from p_assignment_instance_id
 or v_old.action_kind is distinct from p_action_kind or v_old.event_time_text is distinct from p_event_time then
 return jsonb_build_object('action_id',p_action_id,'outcome','CONFLICT','reason','ACTION_PAYLOAD_MISMATCH');
 end if;
 return v_old.result;
 end if;
 -- The same WO row is the serialization point for all old and new mutations.
 select * into v_wo from public.work_orders where id=p_work_order_id for update;
 if not found or v_wo.organization_id is distinct from v_org or v_wo.assigned_user_id is distinct from v_uid then
 v_reason:='ASSIGNMENT_UNAVAILABLE';
 elsif v_wo.current_run_id is distinct from p_run_id then v_reason:='RUN_CHANGED';
 elsif v_wo.field_status='CANCELLED' then v_reason:='CANCELLED';
 else
 select * into v_assignment from public.work_order_assignments a
 where a.id=p_assignment_instance_id and a.run_id=p_run_id and a.organization_id=v_org and a.assigned_user_id=v_uid
 and (a.assignment_ended_at is null or (v_wo.field_status='FIELD_COMPLETE' and a.end_reason='FIELD_COMPLETE'));
 if not found then v_reason:='ASSIGNMENT_CHANGED'; end if;
 end if;
 if v_reason is null then
 if p_action_kind is null or p_action_kind not in ('START','COMPLETE') then v_reason:='INVALID_ACTION';
 else
 begin
 if p_event_time is null or length(p_event_time)>64 or p_event_time !~ '^\d{4}-\d{2}-\d{2}T.*(Z|\+00:00)$' then
 v_reason:='INVALID_TIME';
 else v_event:=p_event_time::timestamptz; end if;
 exception when invalid_datetime_format or datetime_field_overflow then v_reason:='INVALID_TIME';
 end;
 if v_reason is null and (not isfinite(v_event) or v_event>now()+interval '5 minutes'
 or v_event<v_assignment.assignment_started_at-interval '5 minutes') then v_reason:='CLOCK_REVIEW'; end if;
 end if;
 end if;
 if v_reason is null then
 if p_action_kind='START' then
 if v_wo.field_status='ASSIGNED' then
 update public.work_orders set field_status='IN_PROGRESS',started_at=v_event where id=v_wo.id returning * into v_wo;
 elsif v_wo.field_status='IN_PROGRESS' and v_wo.started_at is not null then v_outcome:='ALREADY_APPLIED';
 else v_reason:='STATE_CHANGED'; end if;
 else
 if v_wo.started_at is null or v_event<v_wo.started_at then v_reason:='FINISH_BEFORE_START';
 elsif v_wo.field_status='IN_PROGRESS' then
 update public.work_orders set field_status='FIELD_COMPLETE',field_completed_at=v_event,
 pending_assignee_user_id=null,reassignment_requested_at=null where id=v_wo.id returning * into v_wo;
 elsif v_wo.field_status='FIELD_COMPLETE' then v_outcome:='ALREADY_APPLIED';
 else v_reason:='STATE_CHANGED'; end if;
 end if;
 end if;
 if v_reason is not null then
 return jsonb_build_object('action_id',p_action_id,'outcome','CONFLICT','reason',v_reason);
 end if;
 v_result:=jsonb_build_object('action_id',p_action_id,'outcome',v_outcome,'reason','',
 'field_status',v_wo.field_status,'started_at',v_wo.started_at,'field_completed_at',v_wo.field_completed_at,
 'server_updated_at',v_wo.updated_at,'accepted_at',now());
 insert into public.field_actions(action_id,actor_user_id,organization_id,work_order_id,run_id,assignment_instance_id,action_kind,event_time_text,event_at,result)
 values(p_action_id,v_uid,v_org,p_work_order_id,p_run_id,p_assignment_instance_id,p_action_kind,p_event_time,v_event,v_result);
 return v_result;
end; $$;
create or replace function public.accept_field_action(
 p_action_id uuid,p_work_order_id uuid,p_run_id uuid,p_assignment_instance_id uuid,p_action_kind text,p_event_time text
) returns jsonb language sql security invoker set search_path='' as $$
 select private.accept_field_action(p_action_id,p_work_order_id,p_run_id,p_assignment_instance_id,p_action_kind,p_event_time);
$$;
revoke all on function private.accept_field_action(uuid,uuid,uuid,uuid,text,text) from public,anon;
revoke all on function public.accept_field_action(uuid,uuid,uuid,uuid,text,text) from public,anon;
grant execute on function private.accept_field_action(uuid,uuid,uuid,uuid,text,text) to authenticated,service_role;
grant execute on function public.accept_field_action(uuid,uuid,uuid,uuid,text,text) to authenticated,service_role;

DO $parity$ BEGIN IF md5((SELECT prosrc FROM pg_proc WHERE oid='private.acknowledge_assignment_received(uuid)'::regprocedure)) <> '6be0db63c3cba21fbcb4c0c1cbdb4b23' THEN RAISE EXCEPTION 'Mutation source drift: acknowledge_assignment_received'; END IF; END $parity$;
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

  select * into v_row
  from public.work_orders
  where id = p_work_order_id for update;

  if not found
     or v_row.organization_id is distinct from v_org
     or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;

  if v_row.field_status = 'CANCELLED' then
    raise exception 'Cancelled work order cannot be acknowledged' using errcode = '22023';
  end if;

  if v_row.assignment_received_at is null then
    update public.work_orders
       set assignment_received_at = now()
     where id = p_work_order_id
     returning * into v_row;
  end if;

  return query
  select v_row.id, v_row.assignment_received_at;
end;
$$;

DO $parity$ BEGIN IF md5((SELECT prosrc FROM pg_proc WHERE oid='private.admin_update_work_order(uuid,text,text,text,text,date,uuid)'::regprocedure)) <> '6d83ce67366d05bc3674e30945bcb1bb' THEN RAISE EXCEPTION 'Mutation source drift: admin_update_work_order'; END IF; END $parity$;
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
  where id = p_work_order_id for update;

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

DO $parity$ BEGIN IF md5((SELECT prosrc FROM pg_proc WHERE oid='private.complete_field_work(uuid)'::regprocedure)) <> '9a925c9c9e79e0aefb793f62b724f91d' THEN RAISE EXCEPTION 'Mutation source drift: complete_field_work'; END IF; END $parity$;
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
  where wo.id = p_work_order_id for update;

  if not found
     or v_row.organization_id is distinct from v_org
     or v_row.assigned_user_id is distinct from v_uid then
    raise exception 'Work order not available to this user' using errcode = '42501';
  end if;

  if v_row.field_status = 'IN_PROGRESS' then
    update public.work_orders as wo
       set field_status = 'FIELD_COMPLETE',
           field_completed_at = coalesce(wo.field_completed_at, now()),
           pending_assignee_user_id = null,
           reassignment_requested_at = null
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

DO $parity$ BEGIN IF md5((SELECT prosrc FROM pg_proc WHERE oid='private.respond_reassignment(uuid,boolean)'::regprocedure)) <> '89b33a46c81b05ad7c833f8b666af67d' THEN RAISE EXCEPTION 'Mutation source drift: respond_reassignment'; END IF; END $parity$;
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
  where id = p_work_order_id for update;

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

DO $parity$ BEGIN IF md5((SELECT prosrc FROM pg_proc WHERE oid='private.start_work(uuid)'::regprocedure)) <> '70a159a31e5ab3bb66f72dec9c012e54' THEN RAISE EXCEPTION 'Mutation source drift: start_work'; END IF; END $parity$;
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
  where wo.id = p_work_order_id for update;

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
