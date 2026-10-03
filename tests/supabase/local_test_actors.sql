-- Synthetic accepted actors in the disposable CI database only; no real PII.
insert into public.organizations(id,name) values ('00000000-0000-0000-0000-000000000001','FWH CI TEST');
insert into auth.users(id,email,raw_app_meta_data,email_confirmed_at) values
 ('00000000-0000-0000-0000-000000000010','admin@example.invalid','{"role":"ADMIN","organization_id":"00000000-0000-0000-0000-000000000001"}',now()),
 ('00000000-0000-0000-0000-000000000011','a@example.invalid','{"role":"CONTRACTOR","organization_id":"00000000-0000-0000-0000-000000000001"}',now()),
 ('00000000-0000-0000-0000-000000000012','b@example.invalid','{"role":"CONTRACTOR","organization_id":"00000000-0000-0000-0000-000000000001"}',now());
