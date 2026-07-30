begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(169);

select has_table('public', relation_name, relation_name || ' exists')
from (
  values ('branches'), ('warehouses'), ('registers'), ('devices_v2'), ('devices')
) as relations(relation_name);

select has_column('public', relation_name, column_name, relation_name || '.' || column_name || ' exists')
from (
  values
    ('branches','id'), ('branches','organization_id'), ('branches','code'),
    ('branches','name'), ('branches','address'), ('branches','phone'),
    ('branches','timezone'), ('branches','status'), ('branches','legacy_store_id'),
    ('branches','created_at'), ('branches','updated_at'), ('branches','archived_at'),
    ('warehouses','id'), ('warehouses','organization_id'), ('warehouses','branch_id'),
    ('warehouses','code'), ('warehouses','name'), ('warehouses','is_primary'),
    ('warehouses','allow_negative_stock'), ('warehouses','status'),
    ('warehouses','created_at'), ('warehouses','updated_at'), ('warehouses','archived_at'),
    ('registers','id'), ('registers','organization_id'), ('registers','branch_id'),
    ('registers','default_warehouse_id'), ('registers','code'), ('registers','name'),
    ('registers','settings'), ('registers','status'), ('registers','created_at'),
    ('registers','updated_at'), ('registers','archived_at'),
    ('devices_v2','id'), ('devices_v2','organization_id'), ('devices_v2','branch_id'),
    ('devices_v2','register_id'), ('devices_v2','legacy_device_id'), ('devices_v2','name'),
    ('devices_v2','device_type'), ('devices_v2','fingerprint_hash'),
    ('devices_v2','status'), ('devices_v2','last_sync_cursor'),
    ('devices_v2','last_seen_at'), ('devices_v2','revoked_at'),
    ('devices_v2','created_at'), ('devices_v2','updated_at')
) as columns(relation_name, column_name);

select ok(
  (select relrowsecurity from pg_catalog.pg_class where oid = format('public.%I', relation_name)::regclass),
  relation_name || ' has RLS enabled'
)
from (values ('branches'), ('warehouses'), ('registers'), ('devices_v2')) as relations(relation_name);

select ok(
  not has_table_privilege('anon', format('public.%I', relation_name), 'SELECT, INSERT, UPDATE, DELETE'),
  'anon has no privileges on ' || relation_name
)
from (values ('branches'), ('warehouses'), ('registers'), ('devices_v2')) as relations(relation_name);

select ok(
  not has_table_privilege('authenticated', format('public.%I', relation_name), 'INSERT, UPDATE, DELETE'),
  'authenticated cannot write ' || relation_name
)
from (values ('branches'), ('warehouses'), ('registers'), ('devices_v2')) as relations(relation_name);

select ok(
  has_table_privilege('authenticated', format('public.%I', relation_name), 'SELECT'),
  'authenticated can select ' || relation_name || ' through RLS'
)
from (values ('branches'), ('warehouses'), ('registers'), ('devices_v2')) as relations(relation_name);

select ok(
  exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = format('public.%I', relation_name)::regclass
      and conname = constraint_name and contype = 'f'
  ),
  constraint_name || ' exists'
)
from (
  values
    ('branches','branches_organization_id_fkey'),
    ('branches','branches_legacy_store_id_fkey'),
    ('warehouses','warehouses_organization_id_fkey'),
    ('warehouses','warehouses_branch_id_fkey'),
    ('registers','registers_organization_id_fkey'),
    ('registers','registers_branch_id_fkey'),
    ('registers','registers_default_warehouse_id_fkey'),
    ('devices_v2','devices_v2_organization_id_fkey'),
    ('devices_v2','devices_v2_branch_id_fkey'),
    ('devices_v2','devices_v2_register_id_fkey'),
    ('devices_v2','devices_v2_legacy_device_id_fkey'),
    ('branch_access','branch_access_branch_id_fkey'),
    ('approval_requests','approval_requests_branch_id_fkey'),
    ('command_log','command_log_branch_id_fkey'),
    ('command_log','command_log_device_id_fkey'),
    ('audit_events','audit_events_branch_id_fkey'),
    ('audit_events','audit_events_register_id_fkey'),
    ('audit_events','audit_events_device_id_fkey'),
    ('sync_operations','sync_operations_device_id_fkey')
) as fks(relation_name, constraint_name);

select has_index('public', relation_name, index_name, index_name || ' exists')
from (
  values
    ('branches','branches_organization_status_name_idx'),
    ('branches','branches_active_code_key'),
    ('branches','branches_active_name_key'),
    ('branches','branches_legacy_store_id_key'),
    ('warehouses','warehouses_organization_code_key'),
    ('warehouses','warehouses_one_primary_per_branch_key'),
    ('warehouses','warehouses_branch_status_idx'),
    ('warehouses','warehouses_organization_status_idx'),
    ('registers','registers_branch_code_key'),
    ('registers','registers_organization_branch_status_idx'),
    ('devices_v2','devices_v2_fingerprint_key'),
    ('devices_v2','devices_v2_legacy_device_id_key'),
    ('devices_v2','devices_v2_organization_branch_status_idx'),
    ('devices_v2','devices_v2_last_seen_at_idx')
) as indexes(relation_name, index_name);

select has_function('public', function_name, array[]::text[], function_name || ' exists')
from (
  values
    ('v2_prevent_location_delete'),
    ('v2_guard_branch_update'),
    ('v2_guard_warehouse'),
    ('v2_guard_register'),
    ('v2_guard_device')
) as functions(function_name);
select has_function('public', 'v2_can_access_branch', array['uuid','uuid'], 'branch access helper exists');

select has_table('public', 'devices', 'legacy V1 devices table remains');
select has_column('public', 'devices', 'store_id', 'legacy devices.store_id remains');
select has_column('public', 'devices', 'last_sync_at', 'legacy devices.last_sync_at remains');
select is(
  (select count(*) from supabase_migrations.schema_migrations where version between '0001' and '0009'),
  9::bigint,
  'migrations 0001 through 0009 are recorded'
);

-- Transaction-scoped tenant, identity, and location fixtures.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000009001','authenticated','authenticated','owner-a-9@test.local','',now(),now(),now()),
  ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000009002','authenticated','authenticated','seller-a-9@test.local','',now(),now(),now()),
  ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000009003','authenticated','authenticated','owner-b-9@test.local','',now(),now(),now()),
  ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000009004','authenticated','authenticated','support-9@test.local','',now(),now(),now());

insert into public.organizations (id, name)
values
  ('00000000-0000-0000-0000-000000009101','Location tenant A'),
  ('00000000-0000-0000-0000-000000009102','Location tenant B');
insert into public.stores (id, organization_id, name)
values
  ('00000000-0000-0000-0000-000000009111','00000000-0000-0000-0000-000000009101','Legacy A'),
  ('00000000-0000-0000-0000-000000009112','00000000-0000-0000-0000-000000009102','Legacy B');
insert into public.devices (id, store_id, name, device_type)
values
  ('00000000-0000-0000-0000-000000009121','00000000-0000-0000-0000-000000009111','Legacy device A','desktop'),
  ('00000000-0000-0000-0000-000000009122','00000000-0000-0000-0000-000000009112','Legacy device B','desktop');

insert into public.user_profiles (id, auth_user_id, full_name)
values
  ('00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','Owner A'),
  ('00000000-0000-0000-0000-000000009202','00000000-0000-0000-0000-000000009002','Seller A'),
  ('00000000-0000-0000-0000-000000009203','00000000-0000-0000-0000-000000009003','Owner B'),
  ('00000000-0000-0000-0000-000000009204','00000000-0000-0000-0000-000000009004','Support');
insert into public.organization_memberships (
  id, organization_id, user_profile_id, system_role, status, joined_at
)
values
  ('00000000-0000-0000-0000-000000009301','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009201','owner','active',now()),
  ('00000000-0000-0000-0000-000000009302','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009202','seller','active',now()),
  ('00000000-0000-0000-0000-000000009303','00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009203','owner','active',now()),
  ('00000000-0000-0000-0000-000000009304','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009204','service_admin','active',now());

insert into public.branches (id, organization_id, code, name, legacy_store_id)
values
  ('00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009101','A1','Branch A1','00000000-0000-0000-0000-000000009111'),
  ('00000000-0000-0000-0000-000000009402','00000000-0000-0000-0000-000000009101','A2','Branch A2',null),
  ('00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009102','B1','Branch B1','00000000-0000-0000-0000-000000009112');
insert into public.warehouses (id, organization_id, branch_id, code, name, is_primary)
values
  ('00000000-0000-0000-0000-000000009501','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','WA1','Warehouse A1',true),
  ('00000000-0000-0000-0000-000000009502','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009402','WA2','Warehouse A2',true),
  ('00000000-0000-0000-0000-000000009503','00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009403','WB1','Warehouse B1',true);
insert into public.registers (id, organization_id, branch_id, default_warehouse_id, code, name)
values
  ('00000000-0000-0000-0000-000000009601','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009501','RA1','Register A1'),
  ('00000000-0000-0000-0000-000000009602','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009402','00000000-0000-0000-0000-000000009502','RA2','Register A2'),
  ('00000000-0000-0000-0000-000000009603','00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009503','RB1','Register B1');
insert into public.devices_v2 (
  id, organization_id, branch_id, register_id, legacy_device_id,
  name, device_type, fingerprint_hash, status
)
values
  ('00000000-0000-0000-0000-000000009701','00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009601','00000000-0000-0000-0000-000000009121','Device A1','desktop','fingerprint-a','pending'),
  ('00000000-0000-0000-0000-000000009703','00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009603','00000000-0000-0000-0000-000000009122','Device B1','desktop','fingerprint-b','pending');

-- Branch checks.
select throws_ok($$insert into public.branches (organization_id,code,name) values ('00000000-0000-0000-0000-000000009101','','Bad')$$,'23514',null,'blank branch code rejected');
select throws_ok($$insert into public.branches (organization_id,code,name) values ('00000000-0000-0000-0000-000000009101','BAD',' ')$$,'23514',null,'blank branch name rejected');
select throws_ok($$insert into public.branches (organization_id,code,name,status) values ('00000000-0000-0000-0000-000000009101','BAD','Bad','archived')$$,'23514',null,'branch lifecycle enforced');
select throws_ok($$insert into public.branches (organization_id,code,name) values ('00000000-0000-0000-0000-000000009101','a1','Other')$$,'23505',null,'active branch code is case-insensitively unique');
select throws_ok($$insert into public.branches (organization_id,code,name) values ('00000000-0000-0000-0000-000000009101','OTHER','branch a1')$$,'23505',null,'active branch name is case-insensitively unique');
select throws_ok($$insert into public.branches (organization_id,code,name,legacy_store_id) values ('00000000-0000-0000-0000-000000009101','OTHER','Other','00000000-0000-0000-0000-000000009111')$$,'23505',null,'legacy store mapping is unique');
select throws_ok($$update public.branches set code='CHANGED' where id='00000000-0000-0000-0000-000000009401'$$,'P0001','V2_BRANCH_IDENTITY_MUTATION_FORBIDDEN','branch stable identity is immutable');
select throws_ok($$delete from public.branches where id='00000000-0000-0000-0000-000000009402'$$,'P0001','V2_LOCATION_HARD_DELETE_FORBIDDEN','branch hard delete rejected');

-- Warehouse checks.
select throws_ok($$insert into public.warehouses (organization_id,branch_id,code,name) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009403','BAD','Bad')$$,'P0001','V2_WAREHOUSE_BRANCH_TENANT_MISMATCH','warehouse cross-tenant branch rejected');
select throws_ok($$insert into public.warehouses (organization_id,branch_id,code,name) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','wa1','Other')$$,'23505',null,'warehouse code unique per tenant');
select throws_ok($$insert into public.warehouses (organization_id,branch_id,code,name,is_primary) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','OTHER','Other',true)$$,'23505',null,'one primary warehouse per branch');
select throws_ok($$insert into public.warehouses (organization_id,branch_id,code,name,is_primary,status,archived_at) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','ARCH','Archived',true,'archived',now())$$,'23514',null,'archived warehouse cannot be primary');
select throws_ok($$update public.warehouses set branch_id='00000000-0000-0000-0000-000000009402' where id='00000000-0000-0000-0000-000000009501'$$,'P0001','V2_WAREHOUSE_IDENTITY_MUTATION_FORBIDDEN','warehouse identity immutable');
select throws_ok($$delete from public.warehouses where id='00000000-0000-0000-0000-000000009502'$$,'P0001','V2_LOCATION_HARD_DELETE_FORBIDDEN','warehouse hard delete rejected');

-- Register checks.
select throws_ok($$insert into public.registers (organization_id,branch_id,default_warehouse_id,code,name) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009503','BAD','Bad')$$,'P0001','V2_REGISTER_BRANCH_TENANT_MISMATCH','register cross-tenant branch rejected');
select throws_ok($$insert into public.registers (organization_id,branch_id,default_warehouse_id,code,name) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009502','BAD','Bad')$$,'P0001','V2_REGISTER_WAREHOUSE_LOCATION_MISMATCH','register warehouse branch mismatch rejected');
select throws_ok($$insert into public.registers (organization_id,branch_id,default_warehouse_id,code,name,settings) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009501','BAD','Bad','[]')$$,'23514',null,'register settings must be object');
select throws_ok($$insert into public.registers (organization_id,branch_id,default_warehouse_id,code,name) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009501','ra1','Other')$$,'23505',null,'register code unique in branch');
select throws_ok($$update public.registers set branch_id='00000000-0000-0000-0000-000000009402' where id='00000000-0000-0000-0000-000000009601'$$,'P0001','V2_REGISTER_WAREHOUSE_LOCATION_MISMATCH','register identity mutation rejected');
select throws_ok($$delete from public.registers where id='00000000-0000-0000-0000-000000009602'$$,'P0001','V2_LOCATION_HARD_DELETE_FORBIDDEN','register hard delete rejected');

-- V1/V2 device coexistence and V2 lifecycle.
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009403','Bad','desktop','bad-cross')$$,'P0001','V2_DEVICE_BRANCH_TENANT_MISMATCH','device cross-tenant branch rejected');
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,register_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009602','Bad','desktop','bad-register-branch')$$,'P0001','V2_DEVICE_REGISTER_LOCATION_MISMATCH','device register from another branch rejected');
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,register_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009603','Bad','desktop','bad-register-tenant')$$,'P0001','V2_DEVICE_REGISTER_LOCATION_MISMATCH','device register from another tenant rejected');
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','Duplicate','tablet','fingerprint-a')$$,'23505',null,'device fingerprint unique per tenant');
select lives_ok($$insert into public.devices_v2 (organization_id,branch_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009403','Same fingerprint other tenant','tablet','fingerprint-a')$$,'same fingerprint allowed in another tenant');
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,legacy_device_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009121','Duplicate legacy','mobile','legacy-duplicate')$$,'23505',null,'legacy device mapping is unique');
select lives_ok($$insert into public.devices_v2 (organization_id,branch_id,name,device_type,fingerprint_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','Null legacy one','mobile','null-legacy-1'),('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','Null legacy two','mobile','null-legacy-2')$$,'multiple null legacy mappings allowed');
select throws_ok($$insert into public.devices_v2 (organization_id,branch_id,name,device_type,fingerprint_hash,status) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','Bad lifecycle','desktop','bad-lifecycle','revoked')$$,'23514',null,'device revoked lifecycle requires timestamp');
select lives_ok($$update public.devices_v2 set status='trusted',last_sync_cursor=5,last_seen_at=now() where id='00000000-0000-0000-0000-000000009701'$$,'pending device can become trusted');
select throws_ok($$update public.devices_v2 set last_sync_cursor=4 where id='00000000-0000-0000-0000-000000009701'$$,'P0001','V2_DEVICE_CURSOR_DECREASE_FORBIDDEN','device cursor cannot decrease');
select throws_ok($$update public.devices_v2 set last_seen_at=last_seen_at - interval '1 minute' where id='00000000-0000-0000-0000-000000009701'$$,'P0001','V2_DEVICE_LAST_SEEN_DECREASE_FORBIDDEN','device last_seen cannot decrease');
select throws_ok($$update public.devices_v2 set last_seen_at=null where id='00000000-0000-0000-0000-000000009701'$$,'P0001','V2_DEVICE_LAST_SEEN_DECREASE_FORBIDDEN','device last_seen cannot be cleared');
select throws_ok($$update public.devices_v2 set status='pending' where id='00000000-0000-0000-0000-000000009701'$$,'P0001','V2_DEVICE_STATUS_TRANSITION_INVALID','trusted device cannot return pending');
update public.devices_v2 set status='revoked',revoked_at=now() where id='00000000-0000-0000-0000-000000009701';
select throws_ok($$update public.devices_v2 set name='Reopened' where id='00000000-0000-0000-0000-000000009701'$$,'P0001','V2_REVOKED_DEVICE_MUTATION_FORBIDDEN','revoked device is terminal');
select throws_ok($$update public.devices_v2 set fingerprint_hash='changed' where id='00000000-0000-0000-0000-000000009703'$$,'P0001','V2_DEVICE_IDENTITY_MUTATION_FORBIDDEN','device identity is immutable');
select throws_ok($$update public.devices_v2 set name='Changed' where id='00000000-0000-0000-0000-000000009703'$$,'P0001','V2_DEVICE_IDENTITY_MUTATION_FORBIDDEN','device registered name is immutable');
select throws_ok($$delete from public.devices_v2 where id='00000000-0000-0000-0000-000000009703'$$,'P0001','V2_LOCATION_HARD_DELETE_FORBIDDEN','V2 device hard delete rejected');
select throws_ok($$
  insert into public.command_log (organization_id,branch_id,device_id,local_operation_id,command_type,payload_hash)
  values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009121','00000000-0000-0000-0000-000000009801','legacy-device-command','hash');
  set constraints command_log_device_id_fkey immediate
$$,'23503',null,'V1 device cannot be used by V2 command_log FK');

-- Foundation location tenant consistency.
select throws_ok($$insert into public.branch_access (organization_id,membership_id,branch_id) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009302','00000000-0000-0000-0000-000000009403')$$,'P0001','V2_BRANCH_ACCESS_BRANCH_TENANT_MISMATCH','branch access cross-tenant branch rejected');
insert into public.command_log (id,organization_id,branch_id,device_id,local_operation_id,command_type,payload_hash)
values ('00000000-0000-0000-0000-000000009811','00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009703','00000000-0000-0000-0000-000000009812','foundation-b','hash-b');
select throws_ok($$insert into public.approval_requests (organization_id,branch_id,command_id,permission_code,requested_by,reason,payload_hash,expires_at) values ('00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009811','sales.reverse','00000000-0000-0000-0000-000000009303','Bad branch','hash',now()+interval '1 hour')$$,'P0001','V2_APPROVAL_BRANCH_TENANT_MISMATCH','approval branch tenant guard enforced');
select throws_ok($$insert into public.command_log (organization_id,branch_id,local_operation_id,command_type,payload_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009813','bad-branch','hash')$$,'P0001','V2_COMMAND_BRANCH_TENANT_MISMATCH','command branch tenant guard enforced');
select throws_ok($$insert into public.command_log (organization_id,branch_id,device_id,local_operation_id,command_type,payload_hash) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009703','00000000-0000-0000-0000-000000009814','bad-device-tenant','hash')$$,'P0001','V2_COMMAND_DEVICE_TENANT_MISMATCH','command device tenant guard enforced');
select throws_ok($$insert into public.command_log (organization_id,branch_id,device_id,local_operation_id,command_type,payload_hash) values ('00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009703','00000000-0000-0000-0000-000000009815','bad-device-branch','hash')$$,'P0001','V2_COMMAND_BRANCH_TENANT_MISMATCH','command location mismatch rejected');
select throws_ok($$insert into public.audit_events (organization_id,branch_id,correlation_id,action,entity_type) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009403','00000000-0000-0000-0000-000000009821','bad-branch','test')$$,'P0001','V2_AUDIT_BRANCH_TENANT_MISMATCH','audit branch tenant guard enforced');
select throws_ok($$insert into public.audit_events (organization_id,branch_id,register_id,correlation_id,action,entity_type) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009602','00000000-0000-0000-0000-000000009822','bad-register','test')$$,'P0001','V2_AUDIT_LOCATION_MISMATCH','audit register branch mismatch rejected');
select throws_ok($$insert into public.audit_events (organization_id,branch_id,device_id,correlation_id,action,entity_type) values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401','00000000-0000-0000-0000-000000009703','00000000-0000-0000-0000-000000009823','bad-device','test')$$,'P0001','V2_AUDIT_DEVICE_TENANT_MISMATCH','audit device tenant guard enforced');

-- Branch helper and RLS isolation.
insert into public.branch_access (organization_id,membership_id,branch_id)
values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009302','00000000-0000-0000-0000-000000009401');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
select ok(public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009402'),'owner can access every own branch');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009002',true);
select ok(public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401'),'seller can access assigned branch');
select ok(not public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009402'),'seller denied outside assigned branch');
update public.user_profiles set status='blocked' where id='00000000-0000-0000-0000-000000009202';
select ok(not public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401'),'blocked profile denied branch access');
update public.user_profiles set status='active' where id='00000000-0000-0000-0000-000000009202';
update public.organization_memberships set status='blocked' where id='00000000-0000-0000-0000-000000009302';
select ok(not public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401'),'blocked membership denied branch access');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009004',true);
select ok(not public.v2_can_access_branch('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009401'),'service admin membership alone denied');
insert into public.support_access_grants (organization_id,service_admin_profile_id,scopes,reason,status,approved_by_membership_id,starts_at,expires_at)
values ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009204',array['branches.manage'],'Location support','active','00000000-0000-0000-0000-000000009301',now()-interval '1 minute',now()+interval '1 hour');
select ok(public.v2_has_support_grant('00000000-0000-0000-0000-000000009101','branches.manage'),'support exact location scope works');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009001',true);
set local role authenticated;
select is((select count(*) from public.branches where organization_id='00000000-0000-0000-0000-000000009102'),0::bigint,'branches RLS isolates tenant');
select is((select count(*) from public.warehouses where organization_id='00000000-0000-0000-0000-000000009102'),0::bigint,'warehouses RLS isolates tenant');
select is((select count(*) from public.registers where organization_id='00000000-0000-0000-0000-000000009102'),0::bigint,'registers RLS isolates tenant');
select is((select count(*) from public.devices_v2 where organization_id='00000000-0000-0000-0000-000000009102'),0::bigint,'devices_v2 RLS isolates tenant');
reset role;

select * from finish();
rollback;
