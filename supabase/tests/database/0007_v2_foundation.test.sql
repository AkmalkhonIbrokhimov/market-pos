begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(61);

-- Foundation relations.
select has_table('public', 'command_log', 'command_log exists');
select has_table('public', 'outbox_events', 'outbox_events exists');
select has_table('public', 'audit_events', 'audit_events exists');
select has_table(
  'public',
  'migration_exceptions',
  'migration_exceptions exists'
);

-- RLS is enabled.
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.command_log'::regclass
  ),
  'command_log has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.outbox_events'::regclass
  ),
  'outbox_events has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.audit_events'::regclass
  ),
  'audit_events has RLS enabled'
);
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.migration_exceptions'::regclass
  ),
  'migration_exceptions has RLS enabled'
);

-- No policies are exposed yet.
select policies_are(
  'public',
  'command_log',
  array[]::name[],
  'command_log has no policies'
);
select policies_are(
  'public',
  'outbox_events',
  array[]::name[],
  'outbox_events has no policies'
);
select policies_are(
  'public',
  'audit_events',
  array[]::name[],
  'audit_events has no policies'
);
select policies_are(
  'public',
  'migration_exceptions',
  array[]::name[],
  'migration_exceptions has no policies'
);

-- Browser roles have no direct table privileges.
select ok(
  not has_table_privilege(
    'anon',
    'public.command_log',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'anon has no command_log privileges'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.outbox_events',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'anon has no outbox_events privileges'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.audit_events',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'anon has no audit_events privileges'
);
select ok(
  not has_table_privilege(
    'anon',
    'public.migration_exceptions',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'anon has no migration_exceptions privileges'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.command_log',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'authenticated has no command_log privileges'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.outbox_events',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'authenticated has no outbox_events privileges'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.audit_events',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'authenticated has no audit_events privileges'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.migration_exceptions',
    'SELECT, INSERT, UPDATE, DELETE'
  ),
  'authenticated has no migration_exceptions privileges'
);

-- Critical indexes exist.
select has_index(
  'public',
  'command_log',
  'command_log_online_operation_key',
  'online command idempotency index exists'
);
select has_index(
  'public',
  'command_log',
  'command_log_device_operation_key',
  'device command idempotency index exists'
);
select has_index(
  'public',
  'outbox_events',
  'outbox_events_business_event_key',
  'outbox deduplication index exists'
);
select has_index(
  'public',
  'migration_exceptions',
  'migration_exceptions_identity_key',
  'migration exception deduplication index exists'
);

-- Guard functions exist and browser roles cannot execute them.
select has_function(
  'public',
  'v2_prevent_row_mutation',
  array[]::text[],
  'append-only guard exists'
);
select has_function(
  'public',
  'v2_guard_command_log_update',
  array[]::text[],
  'command guard exists'
);
select has_function(
  'public',
  'v2_guard_outbox_update',
  array[]::text[],
  'outbox guard exists'
);
select has_function(
  'public',
  'v2_guard_migration_exception_update',
  array[]::text[],
  'migration exception guard exists'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.v2_prevent_row_mutation()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v2_prevent_row_mutation()',
    'EXECUTE'
  ),
  'append-only guard is private'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.v2_guard_command_log_update()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v2_guard_command_log_update()',
    'EXECUTE'
  ),
  'command guard is private'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.v2_guard_outbox_update()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v2_guard_outbox_update()',
    'EXECUTE'
  ),
  'outbox guard is private'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.v2_guard_migration_exception_update()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v2_guard_migration_exception_update()',
    'EXECUTE'
  ),
  'migration exception guard is private'
);

-- Transaction-scoped fixture organization.
insert into public.organizations (id, name, status)
values (
  '00000000-0000-0000-0000-000000000701'::uuid,
  'V2 pgTAP fixture',
  'active'
);

-- Online idempotency.
insert into public.command_log (
  organization_id,
  local_operation_id,
  command_type,
  payload_hash
)
values (
  '00000000-0000-0000-0000-000000000701'::uuid,
  '00000000-0000-0000-0000-000000000711'::uuid,
  'test.online',
  'online-hash'
);

select throws_ok(
  $$
    insert into public.command_log (
      organization_id,
      local_operation_id,
      command_type,
      payload_hash
    )
    values (
      '00000000-0000-0000-0000-000000000701'::uuid,
      '00000000-0000-0000-0000-000000000711'::uuid,
      'test.online',
      'online-hash'
    )
  $$,
  '23505',
  null,
  'duplicate online operation is rejected'
);

-- Device idempotency and cross-device allowance.
insert into public.command_log (
  organization_id,
  device_id,
  local_operation_id,
  command_type,
  payload_hash
)
values (
  '00000000-0000-0000-0000-000000000701'::uuid,
  '00000000-0000-0000-0000-000000000721'::uuid,
  '00000000-0000-0000-0000-000000000712'::uuid,
  'test.device',
  'device-hash'
);

select throws_ok(
  $$
    insert into public.command_log (
      organization_id,
      device_id,
      local_operation_id,
      command_type,
      payload_hash
    )
    values (
      '00000000-0000-0000-0000-000000000701'::uuid,
      '00000000-0000-0000-0000-000000000721'::uuid,
      '00000000-0000-0000-0000-000000000712'::uuid,
      'test.device',
      'device-hash'
    )
  $$,
  '23505',
  null,
  'duplicate device operation is rejected'
);

select lives_ok(
  $$
    insert into public.command_log (
      organization_id,
      device_id,
      local_operation_id,
      command_type,
      payload_hash
    )
    values (
      '00000000-0000-0000-0000-000000000701'::uuid,
      '00000000-0000-0000-0000-000000000722'::uuid,
      '00000000-0000-0000-0000-000000000712'::uuid,
      'test.device',
      'device-hash'
    )
  $$,
  'same local operation is valid on another device'
);

-- Processing commands can finish exactly once.
insert into public.command_log (
  id,
  organization_id,
  local_operation_id,
  command_type,
  payload_hash
)
values (
  '00000000-0000-0000-0000-000000000731'::uuid,
  '00000000-0000-0000-0000-000000000701'::uuid,
  '00000000-0000-0000-0000-000000000713'::uuid,
  'test.completion',
  'completion-hash'
);

select lives_ok(
  $$
    update public.command_log
    set
      status = 'succeeded',
      entity_type = 'test_entity',
      entity_id = '00000000-0000-0000-0000-000000000732'::uuid,
      result = '{"ok": true}'::jsonb,
      completed_at = now()
    where id = '00000000-0000-0000-0000-000000000731'::uuid
  $$,
  'processing command can transition to succeeded'
);
select is(
  (
    select status
    from public.command_log
    where id = '00000000-0000-0000-0000-000000000731'::uuid
  ),
  'succeeded',
  'completed command stores terminal status'
);
select throws_ok(
  $$
    update public.command_log
    set result = '{"ok": false}'::jsonb
    where id = '00000000-0000-0000-0000-000000000731'::uuid
  $$,
  'P0001',
  'V2_TERMINAL_COMMAND_MUTATION_FORBIDDEN',
  'terminal command is immutable'
);

-- Audit is append-only.
insert into public.audit_events (
  id,
  organization_id,
  correlation_id,
  action,
  entity_type
)
values (
  '00000000-0000-0000-0000-000000000741'::uuid,
  '00000000-0000-0000-0000-000000000701'::uuid,
  '00000000-0000-0000-0000-000000000761'::uuid,
  'test.created',
  'test_entity'
);
select throws_ok(
  $$
    update public.audit_events
    set reason = 'changed'
    where id = '00000000-0000-0000-0000-000000000741'::uuid
  $$,
  'P0001',
  'V2_APPEND_ONLY_MUTATION_FORBIDDEN',
  'audit update is rejected'
);
select throws_ok(
  $$
    delete from public.audit_events
    where id = '00000000-0000-0000-0000-000000000741'::uuid
  $$,
  'P0001',
  'V2_APPEND_ONLY_MUTATION_FORBIDDEN',
  'audit delete is rejected'
);

-- Outbox core data is immutable while delivery metadata is mutable.
insert into public.outbox_events (
  id,
  organization_id,
  aggregate_type,
  aggregate_id,
  event_type,
  payload,
  correlation_id
)
values (
  '00000000-0000-0000-0000-000000000751'::uuid,
  '00000000-0000-0000-0000-000000000701'::uuid,
  'test_entity',
  '00000000-0000-0000-0000-000000000752'::uuid,
  'TestCreated',
  '{"value": 1}'::jsonb,
  '00000000-0000-0000-0000-000000000761'::uuid
);
select throws_ok(
  $$
    update public.outbox_events
    set payload = '{"value": 2}'::jsonb
    where id = '00000000-0000-0000-0000-000000000751'::uuid
  $$,
  'P0001',
  'V2_OUTBOX_EVENT_MUTATION_FORBIDDEN',
  'outbox payload update is rejected'
);
select lives_ok(
  $$
    update public.outbox_events
    set
      status = 'processing',
      attempt_count = 1,
      locked_at = now(),
      locked_by = 'pgtap'
    where id = '00000000-0000-0000-0000-000000000751'::uuid
  $$,
  'outbox delivery metadata can change'
);

-- Migration exception null-scope uniqueness.
insert into public.migration_exceptions (
  migration_name,
  legacy_table,
  legacy_id,
  error_code
)
values ('0019_v2_backfill', 'products', null, 'missing_mapping');
select throws_ok(
  $$
    insert into public.migration_exceptions (
      migration_name,
      legacy_table,
      legacy_id,
      error_code
    )
    values ('0019_v2_backfill', 'products', null, 'missing_mapping')
  $$,
  '23505',
  null,
  'duplicate migration exception is rejected'
);

-- Status checks. audit_events intentionally has no lifecycle status.
select throws_ok(
  $$
    insert into public.command_log (
      organization_id,
      local_operation_id,
      command_type,
      payload_hash,
      status
    )
    values (
      '00000000-0000-0000-0000-000000000701'::uuid,
      '00000000-0000-0000-0000-000000000714'::uuid,
      'test.invalid',
      'invalid-hash',
      'unknown'
    )
  $$,
  '23514',
  null,
  'invalid command status is rejected'
);
select throws_ok(
  $$
    insert into public.outbox_events (
      organization_id,
      aggregate_type,
      aggregate_id,
      event_type,
      correlation_id,
      status
    )
    values (
      '00000000-0000-0000-0000-000000000701'::uuid,
      'test_entity',
      '00000000-0000-0000-0000-000000000753'::uuid,
      'TestInvalid',
      '00000000-0000-0000-0000-000000000762'::uuid,
      'unknown'
    )
  $$,
  '23514',
  null,
  'invalid outbox status is rejected'
);
select throws_ok(
  $$
    insert into public.migration_exceptions (
      migration_name,
      legacy_table,
      error_code,
      status
    )
    values ('0019_v2_backfill', 'products', 'invalid', 'unknown')
  $$,
  '23514',
  null,
  'invalid migration exception status is rejected'
);
select hasnt_column(
  'public',
  'audit_events',
  'status',
  'append-only audit events have no lifecycle status'
);

-- Legacy compatibility remains intact.
select has_table('public', 'stores', 'legacy stores exists');
select has_table('public', 'users', 'legacy users exists');
select has_table('public', 'products', 'legacy products exists');
select has_table(
  'public',
  'product_batches',
  'legacy product_batches exists'
);
select has_table(
  'public',
  'stock_movements',
  'legacy stock_movements exists'
);
select has_table('public', 'sales', 'legacy sales exists');
select has_table('public', 'payments', 'legacy payments exists');
select has_table('public', 'debt_entries', 'legacy debt_entries exists');
select has_table('public', 'shifts', 'legacy shifts exists');
select has_table('public', 'devices', 'legacy devices exists');
select has_table(
  'public',
  'sync_operations',
  'legacy sync_operations exists'
);
select has_table(
  'public',
  'operation_logs',
  'legacy operation_logs exists'
);
select has_column(
  'public',
  'products',
  'current_quantity',
  'legacy products.current_quantity remains'
);

-- A clean reset records the complete migration sequence.
select ok(
  not exists (
    select required.version
    from unnest(
      array['0001', '0002', '0003', '0004', '0005', '0006', '0007']
    ) as required(version)
    except
    select applied.version
    from supabase_migrations.schema_migrations as applied
  ),
  'migrations 0001 through 0007 are recorded'
);

select * from finish();
rollback;
