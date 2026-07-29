begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(149);

-- Nine identity and access relations.
select has_table('public', relation_name, relation_name || ' exists')
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

-- Every browser-visible relation is protected by RLS.
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = format('public.%I', relation_name)::regclass
  ),
  relation_name || ' has RLS enabled'
)
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

-- Five contract-bearing columns per relation.
select has_column('public', relation_name, column_name, relation_name || '.' || column_name || ' exists')
from (
  values
    ('user_profiles', 'id'),
    ('user_profiles', 'auth_user_id'),
    ('user_profiles', 'status'),
    ('user_profiles', 'preferred_locale'),
    ('user_profiles', 'updated_at'),
    ('organization_memberships', 'organization_id'),
    ('organization_memberships', 'user_profile_id'),
    ('organization_memberships', 'system_role'),
    ('organization_memberships', 'permission_version'),
    ('organization_memberships', 'invited_by'),
    ('permissions', 'code'),
    ('permissions', 'module'),
    ('permissions', 'description'),
    ('permissions', 'critical'),
    ('permissions', 'created_at'),
    ('permission_profiles', 'organization_id'),
    ('permission_profiles', 'code'),
    ('permission_profiles', 'is_system'),
    ('permission_profiles', 'archived_at'),
    ('permission_profiles', 'updated_at'),
    ('permission_profile_permissions', 'permission_profile_id'),
    ('permission_profile_permissions', 'permission_id'),
    ('permission_profile_permissions', 'constraints'),
    ('permission_profile_permissions', 'created_at'),
    ('permission_profile_permissions', 'id'),
    ('membership_permission_profiles', 'membership_id'),
    ('membership_permission_profiles', 'permission_profile_id'),
    ('membership_permission_profiles', 'assigned_by'),
    ('membership_permission_profiles', 'created_at'),
    ('membership_permission_profiles', 'id'),
    ('branch_access', 'organization_id'),
    ('branch_access', 'membership_id'),
    ('branch_access', 'branch_id'),
    ('branch_access', 'is_primary'),
    ('branch_access', 'created_at'),
    ('approval_requests', 'command_id'),
    ('approval_requests', 'permission_code'),
    ('approval_requests', 'requested_by'),
    ('approval_requests', 'payload_hash'),
    ('approval_requests', 'expires_at'),
    ('support_access_grants', 'service_admin_profile_id'),
    ('support_access_grants', 'scopes'),
    ('support_access_grants', 'approved_by_membership_id'),
    ('support_access_grants', 'starts_at'),
    ('support_access_grants', 'expires_at')
) as columns(relation_name, column_name);

-- anon has no direct access; authenticated is read-only and RLS-filtered.
select ok(
  not has_table_privilege('anon', format('public.%I', relation_name), 'SELECT, INSERT, UPDATE, DELETE'),
  'anon has no privileges on ' || relation_name
)
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

select ok(
  not has_table_privilege('authenticated', format('public.%I', relation_name), 'INSERT, UPDATE, DELETE'),
  'authenticated cannot write ' || relation_name
)
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

select ok(
  has_table_privilege('authenticated', format('public.%I', relation_name), 'SELECT'),
  'authenticated can select ' || relation_name || ' through RLS'
)
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

-- Deterministic registry and templates.
select is((select count(*) from public.permissions), 38::bigint, 'registry has 38 permissions');
select is((select count(*) from public.permissions where critical), 6::bigint, 'registry has six critical permissions');
select set_eq(
  $$select code from public.permissions where critical$$,
  $$values
    ('purchases.reverse'),
    ('sales.reverse'),
    ('sales.discount.override'),
    ('debts.limit.override'),
    ('cash.move.override'),
    ('support.access.approve')$$,
  'critical permission set is exact'
);
select is(
  (select count(*) from public.permission_profiles where code = 'owner_default' and is_system and organization_id is null),
  1::bigint,
  'owner system template exists'
);
select is(
  (select count(*) from public.permission_profiles where code = 'seller_default' and is_system and organization_id is null),
  1::bigint,
  'seller system template exists'
);
select is(
  (
    select count(*)
    from public.permission_profile_permissions
    where permission_profile_id = '00000000-0000-0000-0000-000000000101'
  ),
  38::bigint,
  'owner template contains every permission'
);
select is(
  (
    select count(*)
    from public.permission_profile_permissions
    where permission_profile_id = '00000000-0000-0000-0000-000000000102'
  ),
  13::bigint,
  'seller template contains the minimal 13 permissions'
);
select is(
  (
    select count(*)
    from public.permission_profile_permissions ppp
    join public.permissions p on p.id = ppp.permission_id
    where ppp.permission_profile_id = '00000000-0000-0000-0000-000000000102'
      and p.critical
  ),
  0::bigint,
  'seller template has no critical permissions'
);
select is(
  (
    select count(*)
    from public.permission_profile_permissions ppp
    join public.permissions p on p.id = ppp.permission_id
    where ppp.permission_profile_id = '00000000-0000-0000-0000-000000000102'
      and p.code like '%.manage'
  ),
  0::bigint,
  'seller template has no manage permissions'
);

-- Stable authorization API.
select has_function('public', 'v2_current_user_profile_id', array[]::text[], 'current profile helper exists');
select has_function('public', 'v2_current_membership_id', array['uuid'], 'current membership helper exists');
select has_function('public', 'v2_is_active_member', array['uuid'], 'active member helper exists');
select has_function('public', 'v2_is_owner', array['uuid'], 'owner helper exists');
select has_function('public', 'v2_has_permission', array['uuid', 'text', 'uuid'], 'permission helper exists');

-- Deferred foundation links are now enforced.
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.command_log'::regclass
      and conname = 'command_log_actor_membership_id_fkey'
      and contype = 'f'
  ),
  'command_log actor membership FK exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.audit_events'::regclass
      and conname = 'audit_events_actor_membership_id_fkey'
      and contype = 'f'
  ),
  'audit_events actor membership FK exists'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.audit_events'::regclass
      and conname = 'audit_events_approval_request_id_fkey'
      and contype = 'f'
  ),
  'audit_events approval request FK exists'
);

select is(
  (
    select count(*)
    from supabase_migrations.schema_migrations
    where version in ('0007', '0008')
  ),
  2::bigint,
  'foundation and identity migrations are recorded in order'
);

-- Each protected relation has at least one explicit policy.
select ok(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = relation_name
  ),
  relation_name || ' has explicit RLS policies'
)
from (
  values
    ('user_profiles'),
    ('organization_memberships'),
    ('permissions'),
    ('permission_profiles'),
    ('permission_profile_permissions'),
    ('membership_permission_profiles'),
    ('branch_access'),
    ('approval_requests'),
    ('support_access_grants')
) as relations(relation_name);

-- Transaction-only identities and two isolated tenants.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000008001', 'authenticated', 'authenticated', 'owner-a@test.local', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000008002', 'authenticated', 'authenticated', 'seller-a@test.local', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000008003', 'authenticated', 'authenticated', 'owner-b@test.local', '', now(), now(), now()),
  ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000008004', 'authenticated', 'authenticated', 'support@test.local', '', now(), now(), now());

insert into public.organizations (id, name)
values
  ('00000000-0000-0000-0000-000000008101', 'Tenant A'),
  ('00000000-0000-0000-0000-000000008102', 'Tenant B');

insert into public.user_profiles (id, auth_user_id, full_name)
values
  ('00000000-0000-0000-0000-000000008201', '00000000-0000-0000-0000-000000008001', 'Owner A'),
  ('00000000-0000-0000-0000-000000008202', '00000000-0000-0000-0000-000000008002', 'Seller A'),
  ('00000000-0000-0000-0000-000000008203', '00000000-0000-0000-0000-000000008003', 'Owner B'),
  ('00000000-0000-0000-0000-000000008204', '00000000-0000-0000-0000-000000008004', 'Support');

insert into public.organization_memberships (
  id, organization_id, user_profile_id, system_role, status, joined_at
)
values
  ('00000000-0000-0000-0000-000000008301', '00000000-0000-0000-0000-000000008101', '00000000-0000-0000-0000-000000008201', 'owner', 'active', now()),
  ('00000000-0000-0000-0000-000000008302', '00000000-0000-0000-0000-000000008101', '00000000-0000-0000-0000-000000008202', 'seller', 'active', now()),
  ('00000000-0000-0000-0000-000000008303', '00000000-0000-0000-0000-000000008102', '00000000-0000-0000-0000-000000008203', 'owner', 'active', now()),
  ('00000000-0000-0000-0000-000000008304', '00000000-0000-0000-0000-000000008101', '00000000-0000-0000-0000-000000008204', 'service_admin', 'active', now());

select throws_ok(
  $$insert into public.user_profiles (auth_user_id, full_name)
    values ('00000000-0000-0000-0000-000000008001', 'Duplicate')$$,
  '23505', null, 'auth_user_id is unique'
);
select throws_ok(
  $$insert into public.organization_memberships
    (organization_id, user_profile_id, system_role, status, joined_at)
    values (
      '00000000-0000-0000-0000-000000008101',
      '00000000-0000-0000-0000-000000008202',
      'seller', 'active', now()
    )$$,
  '23505', null, 'duplicate tenant membership is rejected'
);
select throws_ok(
  $$insert into public.organization_memberships
    (organization_id, user_profile_id, system_role, status)
    values (
      '00000000-0000-0000-0000-000000008102',
      '00000000-0000-0000-0000-000000008204',
      'service_admin', 'active'
    )$$,
  '23514', null, 'active membership requires joined_at'
);

insert into public.permission_profiles (
  id, organization_id, code, name, is_system
)
values
  ('00000000-0000-0000-0000-000000008401', '00000000-0000-0000-0000-000000008101', 'tenant_a', 'Tenant A', false),
  ('00000000-0000-0000-0000-000000008402', '00000000-0000-0000-0000-000000008102', 'tenant_b', 'Tenant B', false),
  ('00000000-0000-0000-0000-000000008403', '00000000-0000-0000-0000-000000008101', 'archived', 'Archived', false);
update public.permission_profiles
set archived_at = now()
where id = '00000000-0000-0000-0000-000000008403';

select lives_ok(
  $$insert into public.membership_permission_profiles
    (membership_id, permission_profile_id, assigned_by)
    values (
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000000102',
      '00000000-0000-0000-0000-000000008301'
    )$$,
  'system profile can be assigned to a tenant'
);
select is(
  (select permission_version from public.organization_memberships where id = '00000000-0000-0000-0000-000000008302'),
  2::bigint,
  'profile assignment bumps permission_version'
);
select throws_ok(
  $$insert into public.membership_permission_profiles
    (membership_id, permission_profile_id, assigned_by)
    values (
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000008402',
      '00000000-0000-0000-0000-000000008301'
    )$$,
  'P0001', 'V2_PERMISSION_PROFILE_TENANT_MISMATCH',
  'cross-tenant profile assignment is rejected'
);
select throws_ok(
  $$insert into public.membership_permission_profiles
    (membership_id, permission_profile_id, assigned_by)
    values (
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000008403',
      '00000000-0000-0000-0000-000000008301'
    )$$,
  'P0001', 'V2_ARCHIVED_PERMISSION_PROFILE_ASSIGNMENT_FORBIDDEN',
  'archived profile assignment is rejected'
);

insert into public.branch_access (
  id, organization_id, membership_id, branch_id, is_primary
)
values (
  '00000000-0000-0000-0000-000000008501',
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008302',
  '00000000-0000-0000-0000-000000008601',
  true
);
select is(
  (select permission_version from public.organization_memberships where id = '00000000-0000-0000-0000-000000008302'),
  3::bigint,
  'branch scope insert bumps permission_version'
);
select throws_ok(
  $$insert into public.branch_access (organization_id, membership_id, branch_id)
    values (
      '00000000-0000-0000-0000-000000008101',
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000008601'
    )$$,
  '23505', null, 'duplicate branch access is rejected'
);
select throws_ok(
  $$insert into public.branch_access (organization_id, membership_id, branch_id, is_primary)
    values (
      '00000000-0000-0000-0000-000000008101',
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000008602', true
    )$$,
  '23505', null, 'second primary branch is rejected'
);
select throws_ok(
  $$insert into public.branch_access (organization_id, membership_id, branch_id)
    values (
      '00000000-0000-0000-0000-000000008102',
      '00000000-0000-0000-0000-000000008302',
      '00000000-0000-0000-0000-000000008603'
    )$$,
  'P0001', 'V2_BRANCH_ACCESS_TENANT_MISMATCH',
  'cross-tenant branch access is rejected'
);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000008001', true);
select ok(public.v2_is_owner('00000000-0000-0000-0000-000000008101'), 'owner helper recognizes own tenant');
select ok(not public.v2_is_owner('00000000-0000-0000-0000-000000008102'), 'owner helper isolates other tenant');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000008002', true);
select ok(public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post'), 'seller gets assigned permission');
select ok(public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post', '00000000-0000-0000-0000-000000008601'), 'seller gets permission in assigned branch');
select ok(not public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post', '00000000-0000-0000-0000-000000008699'), 'seller is denied outside branch scope');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000008004', true);
select ok(not public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post'), 'service admin role grants no hidden access');

insert into public.command_log (
  id, organization_id, local_operation_id, command_type, payload_hash
)
values (
  '00000000-0000-0000-0000-000000008701',
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008702',
  'test.approval',
  'command-hash'
);
insert into public.approval_requests (
  id, organization_id, command_id, permission_code, requested_by,
  reason, payload_hash, expires_at
)
values (
  '00000000-0000-0000-0000-000000008703',
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008701',
  'sales.reverse',
  '00000000-0000-0000-0000-000000008302',
  'Test approval', 'approval-hash', now() + interval '1 hour'
);
select throws_ok(
  $$update public.approval_requests
    set status = 'approved',
        approved_by = '00000000-0000-0000-0000-000000008302',
        decided_at = now()
    where id = '00000000-0000-0000-0000-000000008703'$$,
  '23514', null, 'self approval is rejected'
);
select lives_ok(
  $$update public.approval_requests
    set status = 'approved',
        approved_by = '00000000-0000-0000-0000-000000008301',
        decided_at = now()
    where id = '00000000-0000-0000-0000-000000008703'$$,
  'coherent approval transition succeeds'
);
select throws_ok(
  $$update public.approval_requests
    set payload_hash = 'changed'
    where id = '00000000-0000-0000-0000-000000008703'$$,
  'P0001', 'V2_TERMINAL_APPROVAL_MUTATION_FORBIDDEN',
  'terminal approval is immutable'
);
insert into public.command_log (
  id, organization_id, local_operation_id, command_type, payload_hash
)
values (
  '00000000-0000-0000-0000-000000008704',
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008705',
  'test.pending',
  'pending-command-hash'
);
insert into public.approval_requests (
  organization_id, command_id, permission_code, requested_by,
  reason, payload_hash, expires_at
)
values (
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008704',
  'sales.reverse',
  '00000000-0000-0000-0000-000000008302',
  'Pending test', 'pending-hash', now() + interval '1 hour'
);
select throws_ok(
  $$insert into public.approval_requests (
      organization_id, command_id, permission_code, requested_by,
      reason, payload_hash, expires_at
    )
    values (
      '00000000-0000-0000-0000-000000008101',
      '00000000-0000-0000-0000-000000008704',
      'sales.reverse',
      '00000000-0000-0000-0000-000000008302',
      'Duplicate pending', 'pending-hash', now() + interval '1 hour'
    )$$,
  '23505', null, 'duplicate pending approval is rejected'
);

select throws_ok(
  $$insert into public.support_access_grants
    (organization_id, service_admin_profile_id, scopes, reason, status,
     approved_by_membership_id, starts_at, expires_at)
    values (
      '00000000-0000-0000-0000-000000008101',
      '00000000-0000-0000-0000-000000008204',
      array['sales.view'], 'Bad approver', 'active',
      '00000000-0000-0000-0000-000000008302',
      now() - interval '1 minute', now() + interval '1 hour'
    )$$,
  'P0001', 'V2_SUPPORT_GRANT_OWNER_APPROVER_REQUIRED',
  'active support grant requires tenant owner'
);
insert into public.support_access_grants (
  id, organization_id, service_admin_profile_id, scopes, reason, status,
  approved_by_membership_id, starts_at, expires_at
)
values (
  '00000000-0000-0000-0000-000000008801',
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008204',
  array['sales.view'], 'Support test', 'active',
  '00000000-0000-0000-0000-000000008301',
  now() - interval '1 minute', now() + interval '1 hour'
);
select ok(public.v2_has_support_grant('00000000-0000-0000-0000-000000008101', 'sales.view'), 'support grant allows exact scope');
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000008101', 'sales.post'), 'support grant has no wildcard scope');
update public.support_access_grants
set status = 'revoked', revoked_at = now()
where id = '00000000-0000-0000-0000-000000008801';
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000008101', 'sales.view'), 'revoked support grant is denied');
insert into public.support_access_grants (
  organization_id, service_admin_profile_id, scopes, reason, status,
  approved_by_membership_id, starts_at, expires_at
)
values (
  '00000000-0000-0000-0000-000000008101',
  '00000000-0000-0000-0000-000000008204',
  array['sales.view'], 'Expired by time', 'active',
  '00000000-0000-0000-0000-000000008301',
  now() - interval '2 hours', now() - interval '1 hour'
);
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000008101', 'sales.view'), 'expired-by-time support grant is denied');

update public.user_profiles set status = 'blocked' where id = '00000000-0000-0000-0000-000000008202';
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000008002', true);
select ok(not public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post'), 'blocked profile is denied');
update public.user_profiles set status = 'active' where id = '00000000-0000-0000-0000-000000008202';
update public.organization_memberships set status = 'blocked' where id = '00000000-0000-0000-0000-000000008302';
select ok(not public.v2_has_permission('00000000-0000-0000-0000-000000008101', 'sales.post'), 'blocked membership is denied');

select has_table('public', 'users', 'legacy users table is preserved');
select has_table('public', 'user_store_access', 'legacy user_store_access table is preserved');
select has_type('public', 'user_role', 'legacy user_role enum is preserved');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000008001', true);
set local role authenticated;
select is(
  (select count(*) from public.organization_memberships where organization_id = '00000000-0000-0000-0000-000000008102'),
  0::bigint,
  'RLS hides memberships from another tenant owner'
);
reset role;

select * from finish();
rollback;
