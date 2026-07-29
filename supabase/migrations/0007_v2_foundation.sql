-- =========================================================
-- MARKET POS V2: FOUNDATION INFRASTRUCTURE
-- =========================================================
-- Additive only. This migration intentionally does not backfill data, alter
-- legacy tables, or expose public business RPC functions.

-- =========================================================
-- COMMAND LOG
-- =========================================================

create table if not exists public.command_log (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid,
  device_id uuid,
  actor_auth_user_id uuid,
  actor_membership_id uuid,
  local_operation_id uuid not null,
  command_type text not null,
  schema_version integer not null default 1,
  payload_hash text not null,
  status text not null default 'processing',
  entity_type text,
  entity_id uuid,
  result jsonb,
  error_code text,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint command_log_command_type_not_blank_check
    check (btrim(command_type) <> ''),
  constraint command_log_payload_hash_not_blank_check
    check (btrim(payload_hash) <> ''),
  constraint command_log_schema_version_positive_check
    check (schema_version > 0),
  constraint command_log_status_check
    check (status in ('processing', 'succeeded', 'failed', 'conflict')),
  constraint command_log_completion_state_check
    check (
      (status = 'processing' and completed_at is null)
      or
      (status in ('succeeded', 'failed', 'conflict') and completed_at is not null)
    )
);

comment on table public.command_log is
  'Canonical V2 idempotency log for online and offline server commands.';
comment on column public.command_log.branch_id is
  'Compatibility field without FK until branches are introduced in migration 0009.';
comment on column public.command_log.device_id is
  'Compatibility field without FK until the V2 device model is introduced in migration 0009.';
comment on column public.command_log.actor_membership_id is
  'Compatibility field without FK until organization_memberships are introduced in migration 0008.';
comment on column public.command_log.actor_auth_user_id is
  'Supabase Auth actor snapshot. An Auth-schema FK is intentionally deferred.';
comment on column public.command_log.local_operation_id is
  'Client-generated idempotency key. Its scope depends on whether device_id is present.';
comment on column public.command_log.payload_hash is
  'Hash of the immutable canonical command payload.';

create unique index if not exists command_log_device_operation_key
  on public.command_log (organization_id, device_id, local_operation_id)
  where device_id is not null;

create unique index if not exists command_log_online_operation_key
  on public.command_log (organization_id, local_operation_id)
  where device_id is null;

create index if not exists command_log_organization_operation_idx
  on public.command_log (organization_id, local_operation_id);

create index if not exists command_log_processing_queue_idx
  on public.command_log (started_at, id)
  where status = 'processing';

create index if not exists command_log_organization_history_idx
  on public.command_log (organization_id, started_at desc, id);

create index if not exists command_log_entity_idx
  on public.command_log (entity_type, entity_id)
  where entity_type is not null and entity_id is not null;

-- =========================================================
-- TRANSACTIONAL OUTBOX
-- =========================================================

create table if not exists public.outbox_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  aggregate_type text not null,
  aggregate_id uuid not null,
  event_type text not null,
  event_version integer not null default 1,
  payload jsonb not null default '{}'::jsonb,
  correlation_id uuid not null,
  status text not null default 'pending',
  attempt_count integer not null default 0,
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  locked_by text,
  delivered_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint outbox_events_aggregate_type_not_blank_check
    check (btrim(aggregate_type) <> ''),
  constraint outbox_events_event_type_not_blank_check
    check (btrim(event_type) <> ''),
  constraint outbox_events_event_version_positive_check
    check (event_version > 0),
  constraint outbox_events_attempt_count_nonnegative_check
    check (attempt_count >= 0),
  constraint outbox_events_status_check
    check (status in ('pending', 'processing', 'delivered', 'failed')),
  constraint outbox_events_delivered_state_check
    check (status <> 'delivered' or delivered_at is not null),
  constraint outbox_events_payload_object_check
    check (jsonb_typeof(payload) = 'object'),
  constraint outbox_events_business_event_key
    unique (
      organization_id,
      correlation_id,
      aggregate_type,
      aggregate_id,
      event_type
    )
);

comment on table public.outbox_events is
  'Transactional outbox. Business event data is immutable after insert.';
comment on column public.outbox_events.correlation_id is
  'Command correlation key used to prevent duplicate events.';
comment on column public.outbox_events.payload is
  'Immutable event payload. Delivery workers may only change delivery metadata.';

create index if not exists outbox_events_worker_queue_idx
  on public.outbox_events (status, available_at, created_at)
  where status in ('pending', 'failed');

create index if not exists outbox_events_aggregate_idx
  on public.outbox_events (
    organization_id,
    aggregate_type,
    aggregate_id,
    created_at desc
  );

create index if not exists outbox_events_correlation_idx
  on public.outbox_events (organization_id, correlation_id);

-- =========================================================
-- AUDIT FOUNDATION
-- =========================================================

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  branch_id uuid,
  register_id uuid,
  device_id uuid,
  actor_auth_user_id uuid,
  actor_membership_id uuid,
  command_log_id uuid
    references public.command_log(id) on delete restrict,
  local_operation_id uuid,
  correlation_id uuid not null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  approval_request_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  client_created_at timestamptz,
  created_at timestamptz not null default now(),
  constraint audit_events_action_not_blank_check
    check (btrim(action) <> ''),
  constraint audit_events_entity_type_not_blank_check
    check (btrim(entity_type) <> ''),
  constraint audit_events_before_data_object_check
    check (before_data is null or jsonb_typeof(before_data) = 'object'),
  constraint audit_events_after_data_object_check
    check (after_data is null or jsonb_typeof(after_data) = 'object'),
  constraint audit_events_metadata_object_check
    check (jsonb_typeof(metadata) = 'object')
);

comment on table public.audit_events is
  'Append-only V2 business and security audit foundation.';
comment on column public.audit_events.branch_id is
  'Compatibility field without FK until branches are introduced in migration 0009.';
comment on column public.audit_events.register_id is
  'Compatibility field without FK until registers are introduced in migration 0009.';
comment on column public.audit_events.device_id is
  'Compatibility field without FK until the V2 device model is introduced in migration 0009.';
comment on column public.audit_events.actor_membership_id is
  'Compatibility field without FK until organization_memberships are introduced in migration 0008.';
comment on column public.audit_events.approval_request_id is
  'Compatibility field without FK until approval_requests are introduced in migration 0008.';
comment on column public.audit_events.actor_auth_user_id is
  'Supabase Auth actor snapshot. An Auth-schema FK is intentionally deferred.';

create index if not exists audit_events_organization_created_idx
  on public.audit_events (organization_id, created_at desc, id);

create index if not exists audit_events_entity_created_idx
  on public.audit_events (entity_type, entity_id, created_at desc)
  where entity_id is not null;

create index if not exists audit_events_actor_created_idx
  on public.audit_events (actor_auth_user_id, created_at desc)
  where actor_auth_user_id is not null;

create index if not exists audit_events_correlation_idx
  on public.audit_events (correlation_id);

create index if not exists audit_events_command_log_idx
  on public.audit_events (command_log_id)
  where command_log_id is not null;

-- =========================================================
-- MIGRATION EXCEPTIONS
-- =========================================================

create table if not exists public.migration_exceptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid
    references public.organizations(id) on delete restrict,
  migration_name text not null,
  legacy_table text not null,
  legacy_id text,
  error_code text not null,
  details jsonb not null default '{}'::jsonb,
  status text not null default 'open',
  resolution text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint migration_exceptions_migration_name_not_blank_check
    check (btrim(migration_name) <> ''),
  constraint migration_exceptions_legacy_table_not_blank_check
    check (btrim(legacy_table) <> ''),
  constraint migration_exceptions_error_code_not_blank_check
    check (btrim(error_code) <> ''),
  constraint migration_exceptions_organization_not_nil_check
    check (
      organization_id is null
      or organization_id <> '00000000-0000-0000-0000-000000000000'::uuid
    ),
  constraint migration_exceptions_legacy_id_not_blank_check
    check (legacy_id is null or btrim(legacy_id) <> ''),
  constraint migration_exceptions_details_object_check
    check (jsonb_typeof(details) = 'object'),
  constraint migration_exceptions_status_check
    check (status in ('open', 'resolved', 'accepted')),
  constraint migration_exceptions_resolution_state_check
    check (
      (status = 'open' and resolved_at is null)
      or
      (status in ('resolved', 'accepted') and resolved_at is not null)
    )
);

comment on table public.migration_exceptions is
  'Issues discovered by future V1 to V2 backfill and reconciliation jobs.';
comment on column public.migration_exceptions.details is
  'Immutable evidence captured when the exception is created.';

create unique index if not exists migration_exceptions_identity_key
  on public.migration_exceptions (
    coalesce(
      organization_id,
      '00000000-0000-0000-0000-000000000000'::uuid
    ),
    migration_name,
    legacy_table,
    coalesce(legacy_id, ''),
    error_code
  );

create index if not exists migration_exceptions_open_idx
  on public.migration_exceptions (created_at, id)
  where status = 'open';

create index if not exists migration_exceptions_source_idx
  on public.migration_exceptions (migration_name, legacy_table, created_at desc);

-- =========================================================
-- DEFENSIVE TRIGGER FUNCTIONS
-- =========================================================

create or replace function public.v2_prevent_row_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P0001',
    message = 'V2_APPEND_ONLY_MUTATION_FORBIDDEN';
end;
$$;

create or replace function public.v2_guard_command_log_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.organization_id is distinct from old.organization_id
    or new.branch_id is distinct from old.branch_id
    or new.device_id is distinct from old.device_id
    or new.actor_auth_user_id is distinct from old.actor_auth_user_id
    or new.actor_membership_id is distinct from old.actor_membership_id
    or new.local_operation_id is distinct from old.local_operation_id
    or new.command_type is distinct from old.command_type
    or new.schema_version is distinct from old.schema_version
    or new.payload_hash is distinct from old.payload_hash
    or new.started_at is distinct from old.started_at
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_COMMAND_IDENTITY_MUTATION_FORBIDDEN';
  end if;

  if old.status <> 'processing' then
    raise exception using
      errcode = 'P0001',
      message = 'V2_TERMINAL_COMMAND_MUTATION_FORBIDDEN';
  end if;

  if new.status not in ('succeeded', 'failed', 'conflict') then
    raise exception using
      errcode = 'P0001',
      message = 'V2_COMMAND_STATUS_TRANSITION_INVALID';
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_outbox_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.organization_id is distinct from old.organization_id
    or new.aggregate_type is distinct from old.aggregate_type
    or new.aggregate_id is distinct from old.aggregate_id
    or new.event_type is distinct from old.event_type
    or new.event_version is distinct from old.event_version
    or new.payload is distinct from old.payload
    or new.correlation_id is distinct from old.correlation_id
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_OUTBOX_EVENT_MUTATION_FORBIDDEN';
  end if;

  if new.attempt_count < old.attempt_count then
    raise exception using
      errcode = 'P0001',
      message = 'V2_OUTBOX_ATTEMPT_COUNT_DECREASE_FORBIDDEN';
  end if;

  if old.status = 'delivered' and new.status <> 'delivered' then
    raise exception using
      errcode = 'P0001',
      message = 'V2_OUTBOX_DELIVERED_EVENT_REOPEN_FORBIDDEN';
  end if;

  return new;
end;
$$;

create or replace function public.v2_guard_migration_exception_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.organization_id is distinct from old.organization_id
    or new.migration_name is distinct from old.migration_name
    or new.legacy_table is distinct from old.legacy_table
    or new.legacy_id is distinct from old.legacy_id
    or new.error_code is distinct from old.error_code
    or new.details is distinct from old.details
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = 'P0001',
      message = 'V2_MIGRATION_EXCEPTION_EVIDENCE_MUTATION_FORBIDDEN';
  end if;

  return new;
end;
$$;

revoke all privileges on function public.v2_prevent_row_mutation()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_command_log_update()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_outbox_update()
  from public, anon, authenticated;
revoke all privileges on function public.v2_guard_migration_exception_update()
  from public, anon, authenticated;

-- =========================================================
-- DEFENSIVE TRIGGERS
-- =========================================================

drop trigger if exists v2_audit_events_prevent_update
  on public.audit_events;
create trigger v2_audit_events_prevent_update
before update on public.audit_events
for each row execute function public.v2_prevent_row_mutation();

drop trigger if exists v2_audit_events_prevent_delete
  on public.audit_events;
create trigger v2_audit_events_prevent_delete
before delete on public.audit_events
for each row execute function public.v2_prevent_row_mutation();

drop trigger if exists v2_command_log_guard_update
  on public.command_log;
create trigger v2_command_log_guard_update
before update on public.command_log
for each row execute function public.v2_guard_command_log_update();

drop trigger if exists v2_outbox_events_guard_update
  on public.outbox_events;
create trigger v2_outbox_events_guard_update
before update on public.outbox_events
for each row execute function public.v2_guard_outbox_update();

drop trigger if exists v2_outbox_events_updated_at
  on public.outbox_events;
create trigger v2_outbox_events_updated_at
before update on public.outbox_events
for each row execute function public.set_updated_at();

drop trigger if exists v2_migration_exceptions_guard_update
  on public.migration_exceptions;
create trigger v2_migration_exceptions_guard_update
before update on public.migration_exceptions
for each row execute function public.v2_guard_migration_exception_update();

drop trigger if exists v2_migration_exceptions_updated_at
  on public.migration_exceptions;
create trigger v2_migration_exceptions_updated_at
before update on public.migration_exceptions
for each row execute function public.set_updated_at();

-- =========================================================
-- RLS AND BROWSER GRANTS
-- =========================================================

alter table public.command_log enable row level security;
alter table public.outbox_events enable row level security;
alter table public.audit_events enable row level security;
alter table public.migration_exceptions enable row level security;

-- No browser policies are intentionally created in this migration. Future
-- server functions and service_role jobs will be the only writers.
revoke all privileges on table public.command_log
  from anon, authenticated;
revoke all privileges on table public.outbox_events
  from anon, authenticated;
revoke all privileges on table public.audit_events
  from anon, authenticated;
revoke all privileges on table public.migration_exceptions
  from anon, authenticated;

comment on table public.command_log is
  'Canonical V2 idempotency log. Browser access is closed until server command functions are introduced.';
comment on table public.outbox_events is
  'Transactional V2 outbox. Browser access is closed; delivery is reserved for server workers.';
comment on table public.audit_events is
  'Append-only V2 audit foundation, closed to direct browser access.';
comment on table public.migration_exceptions is
  'V1 to V2 migration exceptions, reserved for migration and reconciliation tooling.';
