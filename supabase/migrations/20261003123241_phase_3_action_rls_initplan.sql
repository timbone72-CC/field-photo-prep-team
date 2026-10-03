-- Same ledger read authority, with the established scalar JWT initplan pattern.
alter policy field_actions_select_allowed on public.field_actions using (
 organization_id=nullif(((select auth.jwt())->'app_metadata'->>'organization_id'),'')::uuid
 and (actor_user_id=(select auth.uid()) or ((select auth.jwt())->'app_metadata'->>'role')='ADMIN')
);
