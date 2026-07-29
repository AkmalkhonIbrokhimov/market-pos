-- =========================================================
-- MARKET POS V2: IDENTITY AND ACCESS
-- =========================================================
-- Additive only. Legacy users, user_store_access, user_role and
-- organizations.owner_user_id remain unchanged.

-- =========================================================
-- TABLES
-- =========================================================

create or replace function public.v2_text_array_has_no_blank(p_values text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(value is not null and btrim(value) <> ''), false)
  from unnest(p_values) as value
$$;

create table public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique
    references auth.users(id) on delete restrict,
  full_name text not null,
  phone text,
  email_snapshot text,
  status text not null default 'active',
  preferred_locale text not null default 'ru',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_profiles_full_name_not_blank_check
    check (btrim(full_name) <> ''),
  constraint user_profiles_status_check
    check (status in ('invited', 'active', 'blocked', 'inactive')),
  constraint user_profiles_locale_check
    check (preferred_locale in ('ru', 'en', 'uz-Latn', 'uz-Cyrl'))
);

create table public.organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  user_profile_id uuid not null
    references public.user_profiles(id) on delete restrict,
  system_role text not null,
  status text not null default 'invited',
  permission_version bigint not null default 1,
  invited_by uuid,
  joined_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organization_memberships_identity_key
    unique (organization_id, user_profile_id),
  constraint organization_memberships_system_role_check
    check (system_role in ('owner', 'seller', 'service_admin')),
  constraint organization_memberships_status_check
    check (status in ('invited', 'active', 'blocked', 'inactive')),
  constraint organization_memberships_permission_version_check
    check (permission_version > 0),
  constraint organization_memberships_joined_state_check
    check (status <> 'active' or joined_at is not null)
);

alter table public.organization_memberships
  add constraint organization_memberships_invited_by_fkey
  foreign key (invited_by)
  references public.organization_memberships(id)
  on delete restrict;

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  module text not null,
  description text not null,
  critical boolean not null default false,
  created_at timestamptz not null default now(),
  constraint permissions_code_not_blank_check check (btrim(code) <> ''),
  constraint permissions_module_not_blank_check check (btrim(module) <> ''),
  constraint permissions_description_not_blank_check
    check (btrim(description) <> '')
);

create table public.permission_profiles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid
    references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  is_system boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permission_profiles_code_not_blank_check check (btrim(code) <> ''),
  constraint permission_profiles_name_not_blank_check check (btrim(name) <> ''),
  constraint permission_profiles_scope_check
    check (
      (is_system and organization_id is null)
      or
      (not is_system and organization_id is not null)
    )
);

create unique index permission_profiles_scope_code_key
  on public.permission_profiles (
    coalesce(
      organization_id,
      '00000000-0000-0000-0000-000000000000'::uuid
    ),
    lower(code)
  );

create table public.permission_profile_permissions (
  id uuid primary key default gen_random_uuid(),
  permission_profile_id uuid not null
    references public.permission_profiles(id) on delete cascade,
  permission_id uuid not null
    references public.permissions(id) on delete cascade,
  constraints jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint permission_profile_permissions_identity_key
    unique (permission_profile_id, permission_id),
  constraint permission_profile_permissions_constraints_object_check
    check (jsonb_typeof(constraints) = 'object')
);

create table public.membership_permission_profiles (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null
    references public.organization_memberships(id) on delete restrict,
  permission_profile_id uuid not null
    references public.permission_profiles(id) on delete restrict,
  assigned_by uuid not null
    references public.organization_memberships(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint membership_permission_profiles_identity_key
    unique (membership_id, permission_profile_id)
);

create table public.branch_access (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  membership_id uuid not null
    references public.organization_memberships(id) on delete restrict,
  branch_id uuid not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint branch_access_identity_key unique (membership_id, branch_id)
);

comment on column public.branch_access.branch_id is
  'Compatibility field without FK until branches are introduced in migration 0009.';

create unique index branch_access_one_primary_per_membership
  on public.branch_access (membership_id)
  where is_primary;

create table public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid,
  command_id uuid not null
    references public.command_log(id) on delete restrict,
  permission_code text not null
    references public.permissions(code) on delete restrict,
  requested_by uuid not null
    references public.organization_memberships(id) on delete restrict,
  status text not null default 'pending',
  reason text not null,
  payload_hash text not null,
  approved_by uuid
    references public.organization_memberships(id) on delete restrict,
  decided_at timestamptz,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint approval_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'expired')),
  constraint approval_requests_reason_not_blank_check check (btrim(reason) <> ''),
  constraint approval_requests_payload_hash_not_blank_check
    check (btrim(payload_hash) <> ''),
  constraint approval_requests_expiry_check check (expires_at > created_at),
  constraint approval_requests_decision_state_check
    check (
      (status = 'pending' and approved_by is null and decided_at is null)
      or
      (
        status in ('approved', 'rejected')
        and approved_by is not null
        and decided_at is not null
      )
      or
      (status = 'expired' and decided_at is not null)
    ),
  constraint approval_requests_no_self_approval_check
    check (approved_by is null or approved_by <> requested_by)
);

comment on column public.approval_requests.branch_id is
  'Compatibility field without FK until branches are introduced in migration 0009.';

create unique index approval_requests_one_pending_command
  on public.approval_requests (organization_id, command_id)
  where status = 'pending';

create table public.support_access_grants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  service_admin_profile_id uuid not null
    references public.user_profiles(id) on delete restrict,
  scopes text[] not null,
  reason text not null,
  status text not null default 'pending',
  approved_by_membership_id uuid
    references public.organization_memberships(id) on delete restrict,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint support_access_grants_status_check
    check (status in ('pending', 'active', 'revoked', 'expired')),
  constraint support_access_grants_scopes_check
    check (
      cardinality(scopes) > 0
      and public.v2_text_array_has_no_blank(scopes)
    ),
  constraint support_access_grants_reason_not_blank_check
    check (btrim(reason) <> ''),
  constraint support_access_grants_expiry_check
    check (expires_at > starts_at),
  constraint support_access_grants_state_check
    check (
      (status = 'pending' and approved_by_membership_id is null and revoked_at is null)
      or
      (status = 'active' and approved_by_membership_id is not null and revoked_at is null)
      or
      (status = 'revoked' and revoked_at is not null)
      or
      (status = 'expired' and revoked_at is null)
    )
);

-- =========================================================
-- INDEXES
-- =========================================================

create index user_profiles_status_idx
  on public.user_profiles (status);
create index organization_memberships_profile_status_idx
  on public.organization_memberships (user_profile_id, status);
create index organization_memberships_organization_status_idx
  on public.organization_memberships (organization_id, status);
create index organization_memberships_role_status_idx
  on public.organization_memberships (organization_id, system_role, status);
create index permission_profiles_organization_idx
  on public.permission_profiles (organization_id);
create index permission_profile_permissions_profile_idx
  on public.permission_profile_permissions (permission_profile_id);
create index permission_profile_permissions_permission_idx
  on public.permission_profile_permissions (permission_id);
create index membership_permission_profiles_membership_idx
  on public.membership_permission_profiles (membership_id);
create index membership_permission_profiles_profile_idx
  on public.membership_permission_profiles (permission_profile_id);
create index membership_permission_profiles_assigned_by_idx
  on public.membership_permission_profiles (assigned_by);
create index branch_access_branch_membership_idx
  on public.branch_access (branch_id, membership_id);
create index approval_requests_status_expiry_idx
  on public.approval_requests (organization_id, status, expires_at);
create index approval_requests_requester_created_idx
  on public.approval_requests (requested_by, created_at desc);
create index support_access_grants_profile_status_expiry_idx
  on public.support_access_grants (
    service_admin_profile_id,
    status,
    expires_at
  );
create index support_access_grants_organization_status_expiry_idx
  on public.support_access_grants (organization_id, status, expires_at);

-- =========================================================
-- PERMISSION REGISTRY AND SYSTEM TEMPLATES
-- =========================================================

insert into public.permissions (code, module, description, critical)
values
  ('organization.manage', 'organization', 'Manage organization settings.', false),
  ('users.manage', 'identity', 'Manage organization users.', false),
  ('permissions.manage', 'identity', 'Manage permission assignments.', false),
  ('branches.manage', 'organization', 'Manage branches.', false),
  ('warehouses.manage', 'inventory', 'Manage warehouses.', false),
  ('registers.manage', 'sales', 'Manage registers.', false),
  ('devices.manage', 'sync', 'Manage devices.', false),
  ('catalog.view', 'catalog', 'View catalog.', false),
  ('catalog.manage', 'catalog', 'Manage catalog.', false),
  ('pricing.view', 'pricing', 'View prices.', false),
  ('pricing.manage', 'pricing', 'Manage prices.', false),
  ('pricing.confirm', 'pricing', 'Confirm price changes.', false),
  ('purchases.view', 'purchases', 'View purchases.', false),
  ('purchases.post', 'purchases', 'Post purchases.', false),
  ('purchases.reverse', 'purchases', 'Reverse posted purchases.', true),
  ('inventory.view', 'inventory', 'View inventory.', false),
  ('inventory.adjust', 'inventory', 'Adjust inventory.', false),
  ('inventory.transfer', 'inventory', 'Transfer inventory.', false),
  ('sales.view', 'sales', 'View sales.', false),
  ('sales.post', 'sales', 'Post sales.', false),
  ('sales.return', 'sales', 'Return sales.', false),
  ('sales.reverse', 'sales', 'Reverse posted sales.', true),
  ('sales.discount', 'sales', 'Apply allowed sales discount.', false),
  ('sales.discount.override', 'sales', 'Override sales discount limit.', true),
  ('payments.collect', 'payments', 'Collect payments.', false),
  ('debts.view', 'debts', 'View debts.', false),
  ('debts.create', 'debts', 'Create debts.', false),
  ('debts.collect', 'debts', 'Collect debt payments.', false),
  ('debts.limit.override', 'debts', 'Override debt limit.', true),
  ('settlements.view', 'settlements', 'View settlements.', false),
  ('settlements.manage', 'settlements', 'Manage settlements.', false),
  ('shifts.open', 'shifts', 'Open shifts.', false),
  ('shifts.close', 'shifts', 'Close shifts.', false),
  ('cash.move', 'cash', 'Create cash movements.', false),
  ('cash.move.override', 'cash', 'Override cash movement limit.', true),
  ('reports.view', 'reports', 'View reports.', false),
  ('audit.view', 'audit', 'View audit events.', false),
  ('support.access.approve', 'support', 'Approve support access.', true)
on conflict (code) do update
set
  module = excluded.module,
  description = excluded.description,
  critical = excluded.critical;

insert into public.permission_profiles (
  id,
  organization_id,
  code,
  name,
  description,
  is_system
)
values
  (
    '00000000-0000-0000-0000-000000000101',
    null,
    'owner_default',
    'Owner default',
    'System template containing every Core Pilot permission.',
    true
  ),
  (
    '00000000-0000-0000-0000-000000000102',
    null,
    'seller_default',
    'Seller default',
    'Minimal Core Pilot seller permission template.',
    true
  )
on conflict (id) do update
set
  code = excluded.code,
  name = excluded.name,
  description = excluded.description,
  is_system = excluded.is_system;

insert into public.permission_profile_permissions (
  permission_profile_id,
  permission_id
)
select
  '00000000-0000-0000-0000-000000000101'::uuid,
  p.id
from public.permissions as p
on conflict (permission_profile_id, permission_id) do nothing;

insert into public.permission_profile_permissions (
  permission_profile_id,
  permission_id
)
select
  '00000000-0000-0000-0000-000000000102'::uuid,
  p.id
from public.permissions as p
where p.code in (
  'catalog.view',
  'pricing.view',
  'inventory.view',
  'sales.view',
  'sales.post',
  'sales.return',
  'sales.discount',
  'payments.collect',
  'debts.view',
  'debts.create',
  'debts.collect',
  'shifts.open',
  'shifts.close'
)
on conflict (permission_profile_id, permission_id) do nothing;

-- =========================================================
-- AUTHORIZATION HELPERS
-- =========================================================

create or replace function public.v2_current_user_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select up.id
  from public.user_profiles as up
  where up.auth_user_id = auth.uid()
    and up.status = 'active'
  limit 1
$$;

create or replace function public.v2_current_membership_id(
  p_organization_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select om.id
  from public.organization_memberships as om
  join public.user_profiles as up on up.id = om.user_profile_id
  where om.organization_id = p_organization_id
    and om.status = 'active'
    and up.status = 'active'
    and up.auth_user_id = auth.uid()
  limit 1
$$;

create or replace function public.v2_is_active_member(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v2_current_membership_id(p_organization_id) is not null
$$;

create or replace function public.v2_is_owner(
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships as om
    join public.user_profiles as up on up.id = om.user_profile_id
    where om.organization_id = p_organization_id
      and om.system_role = 'owner'
      and om.status = 'active'
      and up.status = 'active'
      and up.auth_user_id = auth.uid()
  )
$$;

create or replace function public.v2_has_permission(
  p_organization_id uuid,
  p_permission_code text,
  p_branch_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organization_memberships as om
    join public.user_profiles as up on up.id = om.user_profile_id
    where om.organization_id = p_organization_id
      and om.status = 'active'
      and up.status = 'active'
      and up.auth_user_id = auth.uid()
      and om.system_role <> 'service_admin'
      and (
        om.system_role = 'owner'
        or (
          om.system_role = 'seller'
          and exists (
            select 1
            from public.membership_permission_profiles as mpp
            join public.permission_profiles as pp
              on pp.id = mpp.permission_profile_id
            join public.permission_profile_permissions as ppp
              on ppp.permission_profile_id = pp.id
            join public.permissions as p
              on p.id = ppp.permission_id
            where mpp.membership_id = om.id
              and pp.archived_at is null
              and (pp.is_system or pp.organization_id = om.organization_id)
              and p.code = p_permission_code
          )
          and (
            p_branch_id is null
            or exists (
              select 1
              from public.branch_access as ba
              where ba.membership_id = om.id
                and ba.organization_id = om.organization_id
                and ba.branch_id = p_branch_id
            )
          )
        )
      )
  )
$$;

create or replace function public.v2_has_support_grant(
  p_organization_id uuid,
  p_required_scope text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.support_access_grants as sag
    join public.user_profiles as up
      on up.id = sag.service_admin_profile_id
    where sag.organization_id = p_organization_id
      and up.auth_user_id = auth.uid()
      and up.status = 'active'
      and sag.status = 'active'
      and now() >= sag.starts_at
      and now() < sag.expires_at
      and p_required_scope = any(sag.scopes)
  )
$$;

-- =========================================================
-- DEFENSIVE FUNCTIONS
-- =========================================================

create or replace function public.v2_prevent_identity_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'V2_HARD_DELETE_FORBIDDEN';
end;
$$;

create or replace function public.v2_guard_permission_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'V2_PERMISSION_REGISTRY_MUTATION_FORBIDDEN';
end;
$$;

create or replace function public.v2_validate_membership_inviter()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  inviter_organization_id uuid;
begin
  if new.invited_by is not null then
    select organization_id
    into inviter_organization_id
    from public.organization_memberships
    where id = new.invited_by;

    if inviter_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_MEMBERSHIP_INVITER_TENANT_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.v2_validate_profile_assignment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_organization_id uuid;
  actor_organization_id uuid;
  profile_organization_id uuid;
  profile_is_system boolean;
  profile_archived_at timestamptz;
begin
  select organization_id
  into target_organization_id
  from public.organization_memberships
  where id = new.membership_id;

  select organization_id
  into actor_organization_id
  from public.organization_memberships
  where id = new.assigned_by;

  select organization_id, is_system, archived_at
  into profile_organization_id, profile_is_system, profile_archived_at
  from public.permission_profiles
  where id = new.permission_profile_id;

  if profile_archived_at is not null then
    raise exception using
      errcode = 'P0001',
      message = 'V2_ARCHIVED_PERMISSION_PROFILE_ASSIGNMENT_FORBIDDEN';
  end if;

  if not profile_is_system
    and profile_organization_id is distinct from target_organization_id
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_PERMISSION_PROFILE_TENANT_MISMATCH';
  end if;

  if actor_organization_id is distinct from target_organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_PERMISSION_ASSIGNER_TENANT_MISMATCH';
  end if;

  return new;
end;
$$;

create or replace function public.v2_validate_branch_access()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  membership_organization_id uuid;
begin
  select organization_id
  into membership_organization_id
  from public.organization_memberships
  where id = new.membership_id;

  if membership_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_BRANCH_ACCESS_TENANT_MISMATCH';
  end if;

  return new;
end;
$$;

create or replace function public.v2_bump_membership_permission_version()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_membership_id uuid;
begin
  target_membership_id := coalesce(new.membership_id, old.membership_id);

  update public.organization_memberships
  set permission_version = permission_version + 1
  where id = target_membership_id;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_approval_request()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  command_organization_id uuid;
  requester_organization_id uuid;
  approver_organization_id uuid;
begin
  select organization_id
  into command_organization_id
  from public.command_log
  where id = new.command_id;

  if command_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_APPROVAL_COMMAND_TENANT_MISMATCH';
  end if;

  select organization_id
  into requester_organization_id
  from public.organization_memberships
  where id = new.requested_by;

  if requester_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_APPROVAL_REQUESTER_TENANT_MISMATCH';
  end if;

  if new.approved_by is not null then
    select organization_id
    into approver_organization_id
    from public.organization_memberships
    where id = new.approved_by;

    if approver_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_APPROVAL_APPROVER_TENANT_MISMATCH';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if old.status <> 'pending' then
      raise exception using
        errcode = 'P0001',
        message = 'V2_TERMINAL_APPROVAL_MUTATION_FORBIDDEN';
    end if;

    if new.status not in ('approved', 'rejected', 'expired') then
      raise exception using
        errcode = 'P0001',
        message = 'V2_APPROVAL_STATUS_TRANSITION_INVALID';
    end if;

    if new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.branch_id is distinct from old.branch_id
      or new.command_id is distinct from old.command_id
      or new.permission_code is distinct from old.permission_code
      or new.requested_by is distinct from old.requested_by
      or new.reason is distinct from old.reason
      or new.payload_hash is distinct from old.payload_hash
      or new.expires_at is distinct from old.expires_at
      or new.created_at is distinct from old.created_at
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_APPROVAL_IDENTITY_MUTATION_FORBIDDEN';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.v2_validate_command_actor_tenant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actor_organization_id uuid;
begin
  if new.actor_membership_id is not null then
    select organization_id
    into actor_organization_id
    from public.organization_memberships
    where id = new.actor_membership_id;

    if actor_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_COMMAND_ACTOR_TENANT_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.v2_validate_audit_tenant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  related_organization_id uuid;
begin
  if new.actor_membership_id is not null then
    select organization_id
    into related_organization_id
    from public.organization_memberships
    where id = new.actor_membership_id;

    if related_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_AUDIT_ACTOR_TENANT_MISMATCH';
    end if;
  end if;

  if new.command_log_id is not null then
    select organization_id
    into related_organization_id
    from public.command_log
    where id = new.command_log_id;

    if related_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_AUDIT_COMMAND_TENANT_MISMATCH';
    end if;
  end if;

  if new.approval_request_id is not null then
    select organization_id
    into related_organization_id
    from public.approval_requests
    where id = new.approval_request_id;

    if related_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_AUDIT_APPROVAL_TENANT_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_support_access_grant()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  approver_organization_id uuid;
  approver_role text;
  approver_status text;
begin
  if new.approved_by_membership_id is not null then
    select organization_id, system_role, status
    into approver_organization_id, approver_role, approver_status
    from public.organization_memberships
    where id = new.approved_by_membership_id;

    if approver_organization_id is distinct from new.organization_id
      or approver_role <> 'owner'
      or approver_status <> 'active'
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_SUPPORT_GRANT_OWNER_APPROVER_REQUIRED';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if old.status in ('revoked', 'expired') then
      raise exception using
        errcode = 'P0001',
        message = 'V2_TERMINAL_SUPPORT_GRANT_MUTATION_FORBIDDEN';
    end if;

    if (
      old.status = 'pending'
      and new.status not in ('active', 'expired')
    ) or (
      old.status = 'active'
      and new.status not in ('revoked', 'expired')
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'V2_SUPPORT_GRANT_STATUS_TRANSITION_INVALID';
    end if;

    if new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.service_admin_profile_id is distinct from old.service_admin_profile_id
      or new.reason is distinct from old.reason
      or new.starts_at is distinct from old.starts_at
      or new.expires_at is distinct from old.expires_at
      or new.created_at is distinct from old.created_at
      or (old.status <> 'pending' and new.scopes is distinct from old.scopes)
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_SUPPORT_GRANT_IDENTITY_MUTATION_FORBIDDEN';
    end if;
  end if;

  return new;
end;
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

create trigger v2_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();
create trigger v2_memberships_updated_at
before update on public.organization_memberships
for each row execute function public.set_updated_at();
create trigger v2_permission_profiles_updated_at
before update on public.permission_profiles
for each row execute function public.set_updated_at();

create trigger v2_memberships_inviter_validate_insert
before insert on public.organization_memberships
for each row execute function public.v2_validate_membership_inviter();
create trigger v2_memberships_inviter_validate_update
before update of invited_by on public.organization_memberships
for each row
when (old.invited_by is distinct from new.invited_by)
execute function public.v2_validate_membership_inviter();

create trigger v2_user_profiles_prevent_delete
before delete on public.user_profiles
for each row execute function public.v2_prevent_identity_delete();
create trigger v2_memberships_prevent_delete
before delete on public.organization_memberships
for each row execute function public.v2_prevent_identity_delete();
create trigger v2_permission_profiles_prevent_delete
before delete on public.permission_profiles
for each row execute function public.v2_prevent_identity_delete();
create trigger v2_approval_requests_prevent_delete
before delete on public.approval_requests
for each row execute function public.v2_prevent_identity_delete();
create trigger v2_support_access_grants_prevent_delete
before delete on public.support_access_grants
for each row execute function public.v2_prevent_identity_delete();

create trigger v2_permissions_prevent_update
before update on public.permissions
for each row execute function public.v2_guard_permission_mutation();
create trigger v2_permissions_prevent_delete
before delete on public.permissions
for each row execute function public.v2_guard_permission_mutation();

create trigger v2_profile_assignment_validate
before insert on public.membership_permission_profiles
for each row execute function public.v2_validate_profile_assignment();
create trigger v2_profile_assignment_bump_insert
after insert on public.membership_permission_profiles
for each row execute function public.v2_bump_membership_permission_version();
create trigger v2_profile_assignment_bump_delete
after delete on public.membership_permission_profiles
for each row execute function public.v2_bump_membership_permission_version();

create trigger v2_branch_access_validate_insert
before insert on public.branch_access
for each row execute function public.v2_validate_branch_access();
create trigger v2_branch_access_validate_update
before update on public.branch_access
for each row execute function public.v2_validate_branch_access();
create trigger v2_branch_access_bump_insert
after insert on public.branch_access
for each row execute function public.v2_bump_membership_permission_version();
create trigger v2_branch_access_bump_update
after update on public.branch_access
for each row
when (old.is_primary is distinct from new.is_primary)
execute function public.v2_bump_membership_permission_version();
create trigger v2_branch_access_bump_delete
after delete on public.branch_access
for each row execute function public.v2_bump_membership_permission_version();

create trigger v2_approval_requests_guard_insert
before insert on public.approval_requests
for each row execute function public.v2_guard_approval_request();
create trigger v2_approval_requests_guard_update
before update on public.approval_requests
for each row execute function public.v2_guard_approval_request();

create trigger v2_support_access_grants_guard_insert
before insert on public.support_access_grants
for each row execute function public.v2_guard_support_access_grant();
create trigger v2_support_access_grants_guard_update
before update on public.support_access_grants
for each row execute function public.v2_guard_support_access_grant();

create trigger v2_command_log_tenant_validate
before insert or update on public.command_log
for each row execute function public.v2_validate_command_actor_tenant();

create trigger v2_audit_events_tenant_validate
before insert on public.audit_events
for each row execute function public.v2_validate_audit_tenant();

-- =========================================================
-- FOUNDATION FOREIGN KEYS
-- =========================================================

alter table public.command_log
  add constraint command_log_actor_membership_id_fkey
  foreign key (actor_membership_id)
  references public.organization_memberships(id)
  on delete restrict;

alter table public.audit_events
  add constraint audit_events_actor_membership_id_fkey
  foreign key (actor_membership_id)
  references public.organization_memberships(id)
  on delete restrict;

alter table public.audit_events
  add constraint audit_events_approval_request_id_fkey
  foreign key (approval_request_id)
  references public.approval_requests(id)
  on delete restrict;

-- =========================================================
-- RLS
-- =========================================================

alter table public.user_profiles enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.permissions enable row level security;
alter table public.permission_profiles enable row level security;
alter table public.permission_profile_permissions enable row level security;
alter table public.membership_permission_profiles enable row level security;
alter table public.branch_access enable row level security;
alter table public.approval_requests enable row level security;
alter table public.support_access_grants enable row level security;

create policy user_profiles_select_self
on public.user_profiles for select to authenticated
using (auth_user_id = auth.uid());

create policy organization_memberships_select_authorized
on public.organization_memberships for select to authenticated
using (
  user_profile_id = public.v2_current_user_profile_id()
  or public.v2_is_owner(organization_id)
  or public.v2_has_support_grant(organization_id, 'users.manage')
);

create policy permissions_select_authenticated
on public.permissions for select to authenticated
using (true);

create policy permission_profiles_select_authorized
on public.permission_profiles for select to authenticated
using (
  is_system
  or (
    organization_id is not null
    and (
      public.v2_is_active_member(organization_id)
      or public.v2_has_support_grant(organization_id, 'permissions.manage')
    )
  )
);

create policy permission_profile_permissions_select_authorized
on public.permission_profile_permissions for select to authenticated
using (
  exists (
    select 1
    from public.permission_profiles as pp
    where pp.id = permission_profile_id
      and (
        pp.is_system
        or (
          pp.organization_id is not null
          and (
            public.v2_is_active_member(pp.organization_id)
            or public.v2_has_support_grant(
              pp.organization_id,
              'permissions.manage'
            )
          )
        )
      )
  )
);

create policy membership_permission_profiles_select_authorized
on public.membership_permission_profiles for select to authenticated
using (
  exists (
    select 1
    from public.organization_memberships as om
    where om.id = membership_id
      and (
        om.id = public.v2_current_membership_id(om.organization_id)
        or public.v2_is_owner(om.organization_id)
        or public.v2_has_support_grant(
          om.organization_id,
          'permissions.manage'
        )
      )
  )
);

create policy branch_access_select_authorized
on public.branch_access for select to authenticated
using (
  membership_id = public.v2_current_membership_id(organization_id)
  or public.v2_is_owner(organization_id)
  or public.v2_has_support_grant(organization_id, 'branches.manage')
);

create policy approval_requests_select_authorized
on public.approval_requests for select to authenticated
using (
  requested_by = public.v2_current_membership_id(organization_id)
  or public.v2_is_owner(organization_id)
  or public.v2_has_permission(
    organization_id,
    permission_code,
    branch_id
  )
  or public.v2_has_support_grant(
    organization_id,
    'support.access.approve'
  )
);

create policy support_access_grants_select_authorized
on public.support_access_grants for select to authenticated
using (
  public.v2_is_owner(organization_id)
  or service_admin_profile_id = public.v2_current_user_profile_id()
);

-- =========================================================
-- GRANTS
-- =========================================================

revoke all privileges on table public.user_profiles from anon, authenticated;
revoke all privileges on table public.organization_memberships from anon, authenticated;
revoke all privileges on table public.permissions from anon, authenticated;
revoke all privileges on table public.permission_profiles from anon, authenticated;
revoke all privileges on table public.permission_profile_permissions from anon, authenticated;
revoke all privileges on table public.membership_permission_profiles from anon, authenticated;
revoke all privileges on table public.branch_access from anon, authenticated;
revoke all privileges on table public.approval_requests from anon, authenticated;
revoke all privileges on table public.support_access_grants from anon, authenticated;

grant select on table public.user_profiles to authenticated;
grant select on table public.organization_memberships to authenticated;
grant select on table public.permissions to authenticated;
grant select on table public.permission_profiles to authenticated;
grant select on table public.permission_profile_permissions to authenticated;
grant select on table public.membership_permission_profiles to authenticated;
grant select on table public.branch_access to authenticated;
grant select on table public.approval_requests to authenticated;
grant select on table public.support_access_grants to authenticated;

revoke all privileges on function public.v2_current_user_profile_id()
  from public, anon;
revoke all privileges on function public.v2_current_membership_id(uuid)
  from public, anon;
revoke all privileges on function public.v2_is_active_member(uuid)
  from public, anon;
revoke all privileges on function public.v2_is_owner(uuid)
  from public, anon;
revoke all privileges on function public.v2_has_permission(uuid, text, uuid)
  from public, anon;
revoke all privileges on function public.v2_has_support_grant(uuid, text)
  from public, anon;

grant execute on function public.v2_current_user_profile_id()
  to authenticated;
grant execute on function public.v2_current_membership_id(uuid)
  to authenticated;
grant execute on function public.v2_is_active_member(uuid)
  to authenticated;
grant execute on function public.v2_is_owner(uuid)
  to authenticated;
grant execute on function public.v2_has_permission(uuid, text, uuid)
  to authenticated;
grant execute on function public.v2_has_support_grant(uuid, text)
  to authenticated;

revoke all privileges on function public.v2_prevent_identity_delete()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_permission_mutation()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_membership_inviter()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_profile_assignment()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_branch_access()
  from public, anon, authenticated;
revoke all privileges on function public.v2_bump_membership_permission_version()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_approval_request()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_support_access_grant()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_command_actor_tenant()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_audit_tenant()
  from public, anon, authenticated;
revoke all privileges on function public.v2_text_array_has_no_blank(text[])
  from public, anon, authenticated;

comment on table public.user_profiles is
  'V2 Supabase Auth profile. No password material is stored.';
comment on table public.organization_memberships is
  'V2 tenant membership and versioned permission snapshot root.';
comment on table public.permissions is
  'Immutable global Core Pilot permission registry.';
comment on table public.support_access_grants is
  'Explicit time-bound support access; a grant never creates membership.';
