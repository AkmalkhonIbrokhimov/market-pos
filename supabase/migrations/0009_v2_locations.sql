-- =========================================================
-- MARKET POS V2: LOCATIONS
-- =========================================================
-- Additive only. V1 stores remain authoritative until a later backfill.

-- =========================================================
-- TABLES
-- =========================================================

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  address text,
  phone text,
  timezone text,
  status text not null default 'active',
  legacy_store_id uuid
    references public.stores(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint branches_code_not_blank_check check (btrim(code) <> ''),
  constraint branches_name_not_blank_check check (btrim(name) <> ''),
  constraint branches_timezone_not_blank_check
    check (timezone is null or btrim(timezone) <> ''),
  constraint branches_status_check
    check (status in ('active', 'inactive', 'archived')),
  constraint branches_lifecycle_check
    check (
      (status = 'archived' and archived_at is not null)
      or
      (status in ('active', 'inactive') and archived_at is null)
    )
);

create index branches_organization_status_name_idx
  on public.branches (organization_id, status, name);
create unique index branches_active_code_key
  on public.branches (organization_id, lower(code))
  where archived_at is null;
create unique index branches_active_name_key
  on public.branches (organization_id, lower(name))
  where archived_at is null;
create unique index branches_legacy_store_id_key
  on public.branches (legacy_store_id)
  where legacy_store_id is not null;

create table public.warehouses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid not null
    references public.branches(id) on delete restrict,
  code text not null,
  name text not null,
  is_primary boolean not null default false,
  allow_negative_stock boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint warehouses_code_not_blank_check check (btrim(code) <> ''),
  constraint warehouses_name_not_blank_check check (btrim(name) <> ''),
  constraint warehouses_status_check
    check (status in ('active', 'inactive', 'archived')),
  constraint warehouses_lifecycle_check
    check (
      (status = 'archived' and archived_at is not null)
      or
      (status in ('active', 'inactive') and archived_at is null)
    ),
  constraint warehouses_archived_not_primary_check
    check (not is_primary or archived_at is null)
);

create unique index warehouses_organization_code_key
  on public.warehouses (organization_id, lower(code));
create unique index warehouses_one_primary_per_branch_key
  on public.warehouses (branch_id)
  where is_primary and archived_at is null;
create index warehouses_branch_status_idx
  on public.warehouses (branch_id, status);
create index warehouses_organization_status_idx
  on public.warehouses (organization_id, status);

create table public.registers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid not null
    references public.branches(id) on delete restrict,
  default_warehouse_id uuid not null
    references public.warehouses(id) on delete restrict,
  code text not null,
  name text not null,
  settings jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint registers_code_not_blank_check check (btrim(code) <> ''),
  constraint registers_name_not_blank_check check (btrim(name) <> ''),
  constraint registers_settings_object_check
    check (jsonb_typeof(settings) = 'object'),
  constraint registers_status_check
    check (status in ('active', 'inactive', 'archived')),
  constraint registers_lifecycle_check
    check (
      (status = 'archived' and archived_at is not null)
      or
      (status in ('active', 'inactive') and archived_at is null)
    )
);

create unique index registers_branch_code_key
  on public.registers (branch_id, lower(code));
create index registers_organization_branch_status_idx
  on public.registers (organization_id, branch_id, status);

create table public.devices_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid not null
    references public.branches(id) on delete restrict,
  register_id uuid
    references public.registers(id) on delete restrict,
  legacy_device_id uuid
    references public.devices(id) on delete restrict,
  name text not null,
  device_type text not null,
  fingerprint_hash text not null,
  status text not null default 'pending',
  last_sync_cursor bigint not null default 0,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint devices_v2_name_not_blank_check check (btrim(name) <> ''),
  constraint devices_v2_fingerprint_not_blank_check
    check (btrim(fingerprint_hash) <> ''),
  constraint devices_v2_type_check
    check (device_type in ('desktop', 'tablet', 'mobile')),
  constraint devices_v2_status_check
    check (status in ('pending', 'trusted', 'revoked')),
  constraint devices_v2_cursor_nonnegative_check check (last_sync_cursor >= 0),
  constraint devices_v2_lifecycle_check
    check (
      (status = 'revoked' and revoked_at is not null)
      or
      (status in ('pending', 'trusted') and revoked_at is null)
    ),
  constraint devices_v2_fingerprint_key
    unique (organization_id, fingerprint_hash)
);

create unique index devices_v2_legacy_device_id_key
  on public.devices_v2 (legacy_device_id)
  where legacy_device_id is not null;
create index devices_v2_organization_branch_status_idx
  on public.devices_v2 (organization_id, branch_id, status);
create index devices_v2_register_status_idx
  on public.devices_v2 (register_id, status);
create index devices_v2_last_seen_at_idx
  on public.devices_v2 (last_seen_at);

create table public.organization_settings (
  organization_id uuid primary key
    references public.organizations(id) on delete restrict,
  currency_code char(3) not null default 'UZS',
  timezone text not null default 'Asia/Tashkent',
  default_locale text not null default 'ru',
  price_rounding_scale smallint not null default 0,
  max_offline_hours integer not null default 24,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint organization_settings_currency_code_check
    check (currency_code ~ '^[A-Z]{3}$'),
  constraint organization_settings_timezone_not_blank_check
    check (btrim(timezone) <> ''),
  constraint organization_settings_locale_check
    check (default_locale in ('ru', 'en', 'uz-Latn', 'uz-Cyrl')),
  constraint organization_settings_rounding_scale_check
    check (price_rounding_scale between 0 and 4),
  constraint organization_settings_offline_hours_check
    check (max_offline_hours between 1 and 168),
  constraint organization_settings_object_check
    check (jsonb_typeof(settings) = 'object')
);

-- =========================================================
-- LOCATION GUARDS
-- =========================================================

create or replace function public.v2_prevent_location_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'V2_LOCATION_HARD_DELETE_FORBIDDEN';
end;
$$;

create or replace function public.v2_guard_organization_settings_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_ORGANIZATION_SETTINGS_IDENTITY_MUTATION_FORBIDDEN';
  end if;

  return new;
end;
$$;

create or replace function public.v2_prevent_organization_settings_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'V2_ORGANIZATION_SETTINGS_DELETE_FORBIDDEN';
end;
$$;

create or replace function public.v2_guard_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  legacy_store_organization_id uuid;
begin
  if new.legacy_store_id is not null then
    select organization_id
    into legacy_store_organization_id
    from public.stores
    where id = new.legacy_store_id;

    if legacy_store_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_BRANCH_LEGACY_STORE_TENANT_MISMATCH';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.code is distinct from old.code
      or new.legacy_store_id is distinct from old.legacy_store_id
      or new.created_at is distinct from old.created_at
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_BRANCH_IDENTITY_MUTATION_FORBIDDEN';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_warehouse()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  branch_organization_id uuid;
begin
  select organization_id
  into branch_organization_id
  from public.branches
  where id = new.branch_id;

  if found and branch_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_WAREHOUSE_BRANCH_TENANT_MISMATCH';
  end if;

  if tg_op = 'UPDATE'
    and (
      new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.branch_id is distinct from old.branch_id
      or new.code is distinct from old.code
      or new.created_at is distinct from old.created_at
    )
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_WAREHOUSE_IDENTITY_MUTATION_FORBIDDEN';
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_register()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  branch_organization_id uuid;
  warehouse_organization_id uuid;
  warehouse_branch_id uuid;
begin
  select organization_id
  into branch_organization_id
  from public.branches
  where id = new.branch_id;

  if found and branch_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_REGISTER_BRANCH_TENANT_MISMATCH';
  end if;

  select organization_id, branch_id
  into warehouse_organization_id, warehouse_branch_id
  from public.warehouses
  where id = new.default_warehouse_id;

  if warehouse_organization_id is distinct from new.organization_id
    or warehouse_branch_id is distinct from new.branch_id
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_REGISTER_WAREHOUSE_LOCATION_MISMATCH';
  end if;

  if tg_op = 'UPDATE'
    and (
      new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.branch_id is distinct from old.branch_id
      or new.code is distinct from old.code
      or new.created_at is distinct from old.created_at
    )
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_REGISTER_IDENTITY_MUTATION_FORBIDDEN';
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_device()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  branch_organization_id uuid;
  register_organization_id uuid;
  register_branch_id uuid;
  legacy_device_organization_id uuid;
begin
  select organization_id
  into branch_organization_id
  from public.branches
  where id = new.branch_id;

  if branch_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_DEVICE_BRANCH_TENANT_MISMATCH';
  end if;

  if new.register_id is not null then
    select organization_id, branch_id
    into register_organization_id, register_branch_id
    from public.registers
    where id = new.register_id;

    if register_organization_id is distinct from new.organization_id
      or register_branch_id is distinct from new.branch_id
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_REGISTER_LOCATION_MISMATCH';
    end if;
  end if;

  if new.legacy_device_id is not null then
    select s.organization_id
    into legacy_device_organization_id
    from public.devices as legacy_device
    join public.stores as s on s.id = legacy_device.store_id
    where legacy_device.id = new.legacy_device_id;

    if legacy_device_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_LEGACY_TENANT_MISMATCH';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if old.status = 'revoked' then
      raise exception using
        errcode = 'P0001',
        message = 'V2_REVOKED_DEVICE_MUTATION_FORBIDDEN';
    end if;

    if new.id is distinct from old.id
      or new.organization_id is distinct from old.organization_id
      or new.branch_id is distinct from old.branch_id
      or new.register_id is distinct from old.register_id
      or new.legacy_device_id is distinct from old.legacy_device_id
      or new.name is distinct from old.name
      or new.fingerprint_hash is distinct from old.fingerprint_hash
      or new.device_type is distinct from old.device_type
      or new.created_at is distinct from old.created_at
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_IDENTITY_MUTATION_FORBIDDEN';
    end if;

    if new.status is distinct from old.status
      and not (
        (old.status = 'pending' and new.status in ('trusted', 'revoked'))
        or
        (old.status = 'trusted' and new.status = 'revoked')
      )
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_STATUS_TRANSITION_INVALID';
    end if;

    if new.last_sync_cursor < old.last_sync_cursor then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_CURSOR_DECREASE_FORBIDDEN';
    end if;

    if old.last_seen_at is not null
      and (
        new.last_seen_at is null
        or new.last_seen_at < old.last_seen_at
      )
    then
      raise exception using
        errcode = 'P0001',
        message = 'V2_DEVICE_LAST_SEEN_DECREASE_FORBIDDEN';
    end if;
  end if;

  return new;
end;
$$;

-- =========================================================
-- EXTENDED IDENTITY/FOUNDATION TENANT GUARDS
-- =========================================================

create or replace function public.v2_validate_branch_access()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  membership_organization_id uuid;
  branch_organization_id uuid;
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

  select organization_id
  into branch_organization_id
  from public.branches
  where id = new.branch_id;

  if found and branch_organization_id is distinct from new.organization_id then
    raise exception using
      errcode = 'P0001',
      message = 'V2_BRANCH_ACCESS_BRANCH_TENANT_MISMATCH';
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
  branch_organization_id uuid;
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

  if new.branch_id is not null then
    select organization_id
    into branch_organization_id
    from public.branches
    where id = new.branch_id;

    if found and branch_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_APPROVAL_BRANCH_TENANT_MISMATCH';
    end if;
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
  branch_organization_id uuid;
  device_organization_id uuid;
  device_branch_id uuid;
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

  if new.branch_id is not null then
    select organization_id
    into branch_organization_id
    from public.branches
    where id = new.branch_id;

    if found and branch_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_COMMAND_BRANCH_TENANT_MISMATCH';
    end if;
  end if;

  if new.device_id is not null then
    select organization_id, branch_id
    into device_organization_id, device_branch_id
    from public.devices_v2
    where id = new.device_id;

    if found and device_organization_id is distinct from new.organization_id then
      raise exception using
        errcode = 'P0001',
        message = 'V2_COMMAND_DEVICE_TENANT_MISMATCH';
    end if;

    if found and (
      new.branch_id is null
      or device_branch_id is distinct from new.branch_id
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'V2_COMMAND_DEVICE_BRANCH_MISMATCH';
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
  branch_organization_id uuid;
  register_organization_id uuid;
  register_branch_id uuid;
  device_organization_id uuid;
  device_branch_id uuid;
  device_register_id uuid;
begin
  if new.actor_membership_id is not null then
    select organization_id into related_organization_id
    from public.organization_memberships where id = new.actor_membership_id;
    if related_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_ACTOR_TENANT_MISMATCH';
    end if;
  end if;

  if new.command_log_id is not null then
    select organization_id into related_organization_id
    from public.command_log where id = new.command_log_id;
    if related_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_COMMAND_TENANT_MISMATCH';
    end if;
  end if;

  if new.approval_request_id is not null then
    select organization_id into related_organization_id
    from public.approval_requests where id = new.approval_request_id;
    if related_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_APPROVAL_TENANT_MISMATCH';
    end if;
  end if;

  if new.branch_id is not null then
    select organization_id into branch_organization_id
    from public.branches where id = new.branch_id;
    if found and branch_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_BRANCH_TENANT_MISMATCH';
    end if;
  end if;

  if new.register_id is not null then
    select organization_id, branch_id
    into register_organization_id, register_branch_id
    from public.registers where id = new.register_id;
    if found and register_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_REGISTER_TENANT_MISMATCH';
    end if;
    if found and (
      new.branch_id is null
      or register_branch_id is distinct from new.branch_id
    ) then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_LOCATION_MISMATCH';
    end if;
  end if;

  if new.device_id is not null then
    select organization_id, branch_id, register_id
    into device_organization_id, device_branch_id, device_register_id
    from public.devices_v2 where id = new.device_id;
    if found and device_organization_id is distinct from new.organization_id then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_DEVICE_TENANT_MISMATCH';
    end if;
    if found and (
      new.branch_id is null
      or device_branch_id is distinct from new.branch_id
      or (
        new.register_id is not null
        and device_register_id is distinct from new.register_id
      )
    ) then
      raise exception using errcode = 'P0001',
        message = 'V2_AUDIT_LOCATION_MISMATCH';
    end if;
  end if;

  return new;
end;
$$;

-- =========================================================
-- AUTHORIZATION
-- =========================================================

create or replace function public.v2_can_access_branch(
  p_organization_id uuid,
  p_branch_id uuid
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
    join public.branches as b
      on b.id = p_branch_id
     and b.organization_id = p_organization_id
    where om.organization_id = p_organization_id
      and om.status = 'active'
      and up.status = 'active'
      and up.auth_user_id = auth.uid()
      and (
        om.system_role = 'owner'
        or (
          om.system_role = 'seller'
          and exists (
            select 1
            from public.branch_access as ba
            where ba.organization_id = p_organization_id
              and ba.membership_id = om.id
              and ba.branch_id = p_branch_id
          )
        )
      )
  )
$$;

-- =========================================================
-- TRIGGERS
-- =========================================================

create trigger v2_branches_updated_at
before update on public.branches
for each row execute function public.set_updated_at();
create trigger v2_warehouses_updated_at
before update on public.warehouses
for each row execute function public.set_updated_at();
create trigger v2_registers_updated_at
before update on public.registers
for each row execute function public.set_updated_at();
create trigger v2_devices_v2_updated_at
before update on public.devices_v2
for each row execute function public.set_updated_at();
create trigger v2_organization_settings_updated_at
before update on public.organization_settings
for each row execute function public.set_updated_at();

create trigger v2_organization_settings_identity_guard
before update on public.organization_settings
for each row execute function public.v2_guard_organization_settings_update();
create trigger v2_organization_settings_prevent_delete
before delete on public.organization_settings
for each row execute function public.v2_prevent_organization_settings_delete();

create trigger v2_branches_guard
before insert or update on public.branches
for each row execute function public.v2_guard_branch();
create trigger v2_warehouses_guard
before insert or update on public.warehouses
for each row execute function public.v2_guard_warehouse();
create trigger v2_registers_guard
before insert or update on public.registers
for each row execute function public.v2_guard_register();
create trigger v2_devices_v2_guard
before insert or update on public.devices_v2
for each row execute function public.v2_guard_device();

create trigger v2_branches_prevent_delete
before delete on public.branches
for each row execute function public.v2_prevent_location_delete();
create trigger v2_warehouses_prevent_delete
before delete on public.warehouses
for each row execute function public.v2_prevent_location_delete();
create trigger v2_registers_prevent_delete
before delete on public.registers
for each row execute function public.v2_prevent_location_delete();
create trigger v2_devices_v2_prevent_delete
before delete on public.devices_v2
for each row execute function public.v2_prevent_location_delete();

-- =========================================================
-- DEFERRED FOREIGN KEYS
-- =========================================================

alter table public.branch_access
  add constraint branch_access_branch_id_fkey
  foreign key (branch_id) references public.branches(id) on delete restrict
  deferrable initially deferred;
alter table public.approval_requests
  add constraint approval_requests_branch_id_fkey
  foreign key (branch_id) references public.branches(id) on delete restrict
  deferrable initially deferred;
alter table public.command_log
  add constraint command_log_branch_id_fkey
  foreign key (branch_id) references public.branches(id) on delete restrict
  deferrable initially deferred;
alter table public.command_log
  add constraint command_log_device_id_fkey
  foreign key (device_id) references public.devices_v2(id) on delete restrict
  deferrable initially deferred;
alter table public.audit_events
  add constraint audit_events_branch_id_fkey
  foreign key (branch_id) references public.branches(id) on delete restrict
  deferrable initially deferred;
alter table public.audit_events
  add constraint audit_events_register_id_fkey
  foreign key (register_id) references public.registers(id) on delete restrict
  deferrable initially deferred;
alter table public.audit_events
  add constraint audit_events_device_id_fkey
  foreign key (device_id) references public.devices_v2(id) on delete restrict
  deferrable initially deferred;

-- =========================================================
-- RLS AND GRANTS
-- =========================================================

alter table public.branches enable row level security;
alter table public.warehouses enable row level security;
alter table public.registers enable row level security;
alter table public.devices_v2 enable row level security;
alter table public.organization_settings enable row level security;

create policy organization_settings_select_authorized
on public.organization_settings for select to authenticated
using (
  public.v2_is_active_member(organization_id)
  or public.v2_has_support_grant(organization_id, 'organization.manage')
);

create policy branches_select_authorized
on public.branches for select to authenticated
using (
  public.v2_can_access_branch(organization_id, id)
  or public.v2_has_support_grant(organization_id, 'branches.manage')
);

create policy warehouses_select_authorized
on public.warehouses for select to authenticated
using (
  public.v2_can_access_branch(organization_id, branch_id)
  or public.v2_has_support_grant(organization_id, 'warehouses.manage')
);

create policy registers_select_authorized
on public.registers for select to authenticated
using (
  public.v2_can_access_branch(organization_id, branch_id)
  or public.v2_has_support_grant(organization_id, 'registers.manage')
);

create policy devices_v2_select_authorized
on public.devices_v2 for select to authenticated
using (
  public.v2_can_access_branch(organization_id, branch_id)
  or public.v2_has_support_grant(organization_id, 'devices.manage')
);

revoke all privileges on table
  public.branches,
  public.warehouses,
  public.registers,
  public.devices_v2,
  public.organization_settings
from public, anon, authenticated;

grant select on table
  public.branches,
  public.warehouses,
  public.registers,
  public.devices_v2,
  public.organization_settings
to authenticated;

revoke all privileges on function public.v2_can_access_branch(uuid, uuid)
  from public, anon;
grant execute on function public.v2_can_access_branch(uuid, uuid)
  to authenticated;

revoke all privileges on function public.v2_prevent_location_delete()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_organization_settings_update()
  from public, anon, authenticated;
revoke all privileges on function public.v2_prevent_organization_settings_delete()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_branch()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_warehouse()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_register()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_device()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_branch_access()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_approval_request()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_command_actor_tenant()
  from public, anon, authenticated;
revoke all privileges on function public.v2_validate_audit_tenant()
  from public, anon, authenticated;

comment on column public.branches.legacy_store_id is
  'Optional one-to-one mapping to the preserved V1 public.stores row.';
