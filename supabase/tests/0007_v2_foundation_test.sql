-- Market POS V2 foundation verification.
-- Run after migrations 0001-0007. All test data is rolled back.

begin;

do $$
declare
  v_organization_id constant uuid :=
    '00000000-0000-0000-0000-000000000701'::uuid;
  v_online_operation_id constant uuid :=
    '00000000-0000-0000-0000-000000000711'::uuid;
  v_device_operation_id constant uuid :=
    '00000000-0000-0000-0000-000000000712'::uuid;
  v_device_one_id constant uuid :=
    '00000000-0000-0000-0000-000000000721'::uuid;
  v_device_two_id constant uuid :=
    '00000000-0000-0000-0000-000000000722'::uuid;
  v_terminal_command_id constant uuid :=
    '00000000-0000-0000-0000-000000000731'::uuid;
  v_audit_id constant uuid :=
    '00000000-0000-0000-0000-000000000741'::uuid;
  v_outbox_id constant uuid :=
    '00000000-0000-0000-0000-000000000751'::uuid;
  v_correlation_id constant uuid :=
    '00000000-0000-0000-0000-000000000761'::uuid;
  v_guard_blocked boolean;
  v_rls_enabled boolean;
  v_outbox_status text;
  v_outbox_attempts integer;
  v_table_name text;
  v_role_name text;
  v_privilege text;
begin
  insert into public.organizations (id, name, status)
  values (v_organization_id, 'V2 foundation test', 'active');

  -- Test 1: all four foundation tables exist.
  foreach v_table_name in array array[
    'command_log',
    'outbox_events',
    'audit_events',
    'migration_exceptions'
  ]
  loop
    if to_regclass('public.' || v_table_name) is null then
      raise exception 'TEST_01_TABLE_MISSING: %', v_table_name;
    end if;
  end loop;

  -- Test 2: RLS is enabled on every foundation table.
  foreach v_table_name in array array[
    'command_log',
    'outbox_events',
    'audit_events',
    'migration_exceptions'
  ]
  loop
    select c.relrowsecurity
    into v_rls_enabled
    from pg_catalog.pg_class as c
    join pg_catalog.pg_namespace as n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = v_table_name;

    if not coalesce(v_rls_enabled, false) then
      raise exception 'TEST_02_RLS_DISABLED: %', v_table_name;
    end if;
  end loop;

  -- Test 3: anon/authenticated have no direct DML grants.
  foreach v_role_name in array array['anon', 'authenticated']
  loop
    foreach v_table_name in array array[
      'command_log',
      'outbox_events',
      'audit_events',
      'migration_exceptions'
    ]
    loop
      foreach v_privilege in array array['INSERT', 'UPDATE', 'DELETE']
      loop
        if has_table_privilege(
          v_role_name,
          'public.' || v_table_name,
          v_privilege
        ) then
          raise exception
            'TEST_03_UNEXPECTED_GRANT: role=% table=% privilege=%',
            v_role_name,
            v_table_name,
            v_privilege;
        end if;
      end loop;
    end loop;
  end loop;

  -- Test 4: duplicate online local_operation_id is rejected.
  insert into public.command_log (
    organization_id,
    local_operation_id,
    command_type,
    payload_hash
  )
  values (
    v_organization_id,
    v_online_operation_id,
    'test.online',
    'online-hash'
  );

  begin
    insert into public.command_log (
      organization_id,
      local_operation_id,
      command_type,
      payload_hash
    )
    values (
      v_organization_id,
      v_online_operation_id,
      'test.online',
      'online-hash'
    );
    raise exception 'TEST_04_DUPLICATE_ONLINE_COMMAND_ACCEPTED';
  exception
    when unique_violation then
      null;
  end;

  -- Test 5: duplicate device/local_operation_id is rejected.
  insert into public.command_log (
    organization_id,
    device_id,
    local_operation_id,
    command_type,
    payload_hash
  )
  values (
    v_organization_id,
    v_device_one_id,
    v_device_operation_id,
    'test.device',
    'device-hash'
  );

  begin
    insert into public.command_log (
      organization_id,
      device_id,
      local_operation_id,
      command_type,
      payload_hash
    )
    values (
      v_organization_id,
      v_device_one_id,
      v_device_operation_id,
      'test.device',
      'device-hash'
    );
    raise exception 'TEST_05_DUPLICATE_DEVICE_COMMAND_ACCEPTED';
  exception
    when unique_violation then
      null;
  end;

  -- Test 6: the same local_operation_id is valid for different devices.
  insert into public.command_log (
    organization_id,
    device_id,
    local_operation_id,
    command_type,
    payload_hash
  )
  values (
    v_organization_id,
    v_device_two_id,
    v_device_operation_id,
    'test.device',
    'device-hash'
  );

  -- Test 7: terminal command rows cannot be changed.
  insert into public.command_log (
    id,
    organization_id,
    local_operation_id,
    command_type,
    payload_hash,
    status,
    completed_at
  )
  values (
    v_terminal_command_id,
    v_organization_id,
    '00000000-0000-0000-0000-000000000713'::uuid,
    'test.terminal',
    'terminal-hash',
    'succeeded',
    now()
  );

  v_guard_blocked := false;
  begin
    update public.command_log
    set result = '{"changed": true}'::jsonb
    where id = v_terminal_command_id;
  exception
    when sqlstate 'P0001' then
      if sqlerrm = 'V2_TERMINAL_COMMAND_MUTATION_FORBIDDEN' then
        v_guard_blocked := true;
      else
        raise;
      end if;
  end;
  if not v_guard_blocked then
    raise exception 'TEST_07_TERMINAL_COMMAND_MUTABLE';
  end if;

  -- Test 8: audit rows cannot be updated.
  insert into public.audit_events (
    id,
    organization_id,
    correlation_id,
    action,
    entity_type
  )
  values (
    v_audit_id,
    v_organization_id,
    v_correlation_id,
    'test.created',
    'test_entity'
  );

  v_guard_blocked := false;
  begin
    update public.audit_events
    set reason = 'changed'
    where id = v_audit_id;
  exception
    when sqlstate 'P0001' then
      if sqlerrm = 'V2_APPEND_ONLY_MUTATION_FORBIDDEN' then
        v_guard_blocked := true;
      else
        raise;
      end if;
  end;
  if not v_guard_blocked then
    raise exception 'TEST_08_AUDIT_UPDATE_ALLOWED';
  end if;

  -- Test 9: audit rows cannot be deleted.
  v_guard_blocked := false;
  begin
    delete from public.audit_events
    where id = v_audit_id;
  exception
    when sqlstate 'P0001' then
      if sqlerrm = 'V2_APPEND_ONLY_MUTATION_FORBIDDEN' then
        v_guard_blocked := true;
      else
        raise;
      end if;
  end;
  if not v_guard_blocked then
    raise exception 'TEST_09_AUDIT_DELETE_ALLOWED';
  end if;

  -- Test 10: immutable outbox payload cannot be changed.
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
    v_outbox_id,
    v_organization_id,
    'test_entity',
    '00000000-0000-0000-0000-000000000752'::uuid,
    'TestCreated',
    '{"value": 1}'::jsonb,
    v_correlation_id
  );

  v_guard_blocked := false;
  begin
    update public.outbox_events
    set payload = '{"value": 2}'::jsonb
    where id = v_outbox_id;
  exception
    when sqlstate 'P0001' then
      if sqlerrm = 'V2_OUTBOX_EVENT_MUTATION_FORBIDDEN' then
        v_guard_blocked := true;
      else
        raise;
      end if;
  end;
  if not v_guard_blocked then
    raise exception 'TEST_10_OUTBOX_PAYLOAD_MUTABLE';
  end if;

  -- Test 11: outbox delivery metadata can be changed.
  update public.outbox_events
  set
    status = 'processing',
    attempt_count = 1,
    locked_at = now(),
    locked_by = 'foundation-test'
  where id = v_outbox_id;

  select status, attempt_count
  into v_outbox_status, v_outbox_attempts
  from public.outbox_events
  where id = v_outbox_id;

  if v_outbox_status <> 'processing' or v_outbox_attempts <> 1 then
    raise exception 'TEST_11_OUTBOX_DELIVERY_METADATA_NOT_UPDATED';
  end if;

  -- Test 12: duplicate migration exceptions are rejected with null scope.
  insert into public.migration_exceptions (
    migration_name,
    legacy_table,
    legacy_id,
    error_code
  )
  values ('0019_v2_backfill', 'products', null, 'missing_mapping');

  begin
    insert into public.migration_exceptions (
      migration_name,
      legacy_table,
      legacy_id,
      error_code
    )
    values ('0019_v2_backfill', 'products', null, 'missing_mapping');
    raise exception 'TEST_12_DUPLICATE_MIGRATION_EXCEPTION_ACCEPTED';
  exception
    when unique_violation then
      null;
  end;

  -- Test 13: status check constraints reject invalid values.
  begin
    insert into public.command_log (
      organization_id,
      local_operation_id,
      command_type,
      payload_hash,
      status
    )
    values (
      v_organization_id,
      '00000000-0000-0000-0000-000000000714'::uuid,
      'test.invalid',
      'invalid-hash',
      'unknown'
    );
    raise exception 'TEST_13_INVALID_STATUS_ACCEPTED';
  exception
    when check_violation then
      null;
  end;

  -- Test 14: required legacy tables still exist.
  foreach v_table_name in array array[
    'stores',
    'users',
    'products',
    'product_batches',
    'stock_movements',
    'sales',
    'payments',
    'debt_entries',
    'shifts',
    'devices',
    'sync_operations',
    'operation_logs'
  ]
  loop
    if to_regclass('public.' || v_table_name) is null then
      raise exception 'TEST_14_LEGACY_TABLE_MISSING: %', v_table_name;
    end if;
  end loop;

  -- Test 15: products.current_quantity remains during compatibility.
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'products'
      and column_name = 'current_quantity'
  ) then
    raise exception 'TEST_15_LEGACY_CURRENT_QUANTITY_MISSING';
  end if;
end;
$$;

rollback;
