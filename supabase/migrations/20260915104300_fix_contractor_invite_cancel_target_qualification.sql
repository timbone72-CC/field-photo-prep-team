create or replace function private.admin_begin_contractor_invitation_cancel(
  p_invitation_id uuid
)
returns table (
  invitation_id uuid,
  email text,
  display_name text,
  status text,
  auth_user_id uuid,
  organization_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org uuid := nullif(auth.jwt() -> 'app_metadata' ->> 'organization_id', '')::uuid;
  v_role text := auth.jwt() -> 'app_metadata' ->> 'role';
  v_row public.contractor_invitations%rowtype;
  v_user auth.users%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_role <> 'ADMIN' or v_org is null then
    raise exception 'Admin permission required' using errcode = '42501';
  end if;

  select * into v_row
  from public.contractor_invitations ci
  where ci.id = p_invitation_id
  for update;

  if not found or v_row.organization_id is distinct from v_org then
    raise exception 'Invitation not available to this Admin' using errcode = '42501';
  end if;

  if v_row.status not in ('RESERVED', 'SENT', 'PROBLEM') then
    raise exception 'Only a pending unaccepted invitation can be cancelled' using errcode = '22023';
  end if;

  if v_row.auth_user_id is not null then
    select * into v_user
    from auth.users u
    where u.id = v_row.auth_user_id
      and u.deleted_at is null;

    if not found then
      raise exception 'Invitation Auth identity is missing and requires reconciliation' using errcode = '42501';
    end if;

    if lower(coalesce(v_user.email, '')) <> v_row.email
       or v_user.email_confirmed_at is not null
       or v_user.last_sign_in_at is not null
       or v_user.raw_app_meta_data ->> 'role' <> 'CONTRACTOR'
       or v_user.raw_app_meta_data ->> 'organization_id' <> v_org::text
       or v_user.raw_user_meta_data ->> 'team_invitation_id' <> v_row.id::text then
      raise exception 'This invitation can no longer be safely cancelled as an unused account' using errcode = '42501';
    end if;

    if exists (
      select 1
      from public.work_orders w
      where w.assigned_user_id = v_row.auth_user_id
         or w.pending_assignee_user_id = v_row.auth_user_id
    ) then
      raise exception 'This Contractor identity is referenced by a work order and cannot be deleted' using errcode = '42501';
    end if;
  end if;

  update public.contractor_invitations
     set status = 'CANCELLING',
         cancel_requested_by = v_uid,
         cancel_requested_at = now(),
         cancel_target_auth_user_id = v_row.auth_user_id,
         updated_at = now()
   where id = v_row.id
   returning * into v_row;

  return query
  select v_row.id, v_row.email, v_row.display_name, v_row.status, v_row.auth_user_id, v_row.organization_id;
end;
$$;