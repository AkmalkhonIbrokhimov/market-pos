begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select plan(494);

-- Registry and coexistence.
select is((select count(*)from permissions),54::bigint,'permission registry 54');
select is((select count(*)from permissions where critical),10::bigint,'critical permissions 10');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000101'),54::bigint,'owner profile 54');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000102'),16::bigint,'seller profile 16');
select ok(exists(select 1 from permissions where code='sync.resolve'and module='sync'and not critical),'sync.resolve is the only new noncritical sync permission');
select ok(exists(select 1 from permission_profile_permissions x join permissions p on p.id=x.permission_id where x.permission_profile_id='00000000-0000-0000-0000-000000000101'and p.code='sync.resolve'),'owner receives sync.resolve');
select ok(not exists(select 1 from permission_profile_permissions x join permissions p on p.id=x.permission_id where x.permission_profile_id='00000000-0000-0000-0000-000000000102'and p.code='sync.resolve'),'seller does not receive sync.resolve');
select has_table('public','sync_operations','legacy sync_operations remains');
select has_table('public','sync_commands','authoritative sync_commands exists');
select has_table('public','sync_cursor_state','internal cursor state exists');
select ok('public.sync_operations'::regclass<>'public.sync_commands'::regclass,'legacy and V2 sync tables are distinct');

-- Every sync command field: existence, exact type and nullability.
with expected(c,t,required)as(values
 ('id','uuid'::regtype,true),('organization_id','uuid'::regtype,true),('device_id','uuid'::regtype,true),('actor_membership_id','uuid'::regtype,true),('local_operation_id','uuid'::regtype,true),('command_type','text'::regtype,true),('schema_version','int4'::regtype,true),('payload','jsonb'::regtype,true),('payload_hash','text'::regtype,true),('dependency_operation_ids','uuid[]'::regtype,true),('status','text'::regtype,true),('command_id','uuid'::regtype,false),('result','jsonb'::regtype,false),('error_code','text'::regtype,false),('resolution_of_id','uuid'::regtype,false),('client_created_at','timestamptz'::regtype,true),('received_at','timestamptz'::regtype,true),('processed_at','timestamptz'::regtype,false))
select ok(exists(select 1 from pg_attribute where attrelid='public.sync_commands'::regclass and attname=c and not attisdropped),'sync_commands.'||c||' exists')from expected;
with expected(c,t,required)as(values
 ('id','uuid'::regtype,true),('organization_id','uuid'::regtype,true),('device_id','uuid'::regtype,true),('actor_membership_id','uuid'::regtype,true),('local_operation_id','uuid'::regtype,true),('command_type','text'::regtype,true),('schema_version','int4'::regtype,true),('payload','jsonb'::regtype,true),('payload_hash','text'::regtype,true),('dependency_operation_ids','uuid[]'::regtype,true),('status','text'::regtype,true),('command_id','uuid'::regtype,false),('result','jsonb'::regtype,false),('error_code','text'::regtype,false),('resolution_of_id','uuid'::regtype,false),('client_created_at','timestamptz'::regtype,true),('received_at','timestamptz'::regtype,true),('processed_at','timestamptz'::regtype,false))
select ok((select atttypid=t from pg_attribute where attrelid='public.sync_commands'::regclass and attname=c),'sync_commands.'||c||' type '||t::text)from expected;
with expected(c,required)as(values('id',true),('organization_id',true),('device_id',true),('actor_membership_id',true),('local_operation_id',true),('command_type',true),('schema_version',true),('payload',true),('payload_hash',true),('dependency_operation_ids',true),('status',true),('command_id',false),('result',false),('error_code',false),('resolution_of_id',false),('client_created_at',true),('received_at',true),('processed_at',false))
select ok((select attnotnull=required from pg_attribute where attrelid='public.sync_commands'::regclass and attname=c),'sync_commands.'||c||case when required then' required'else' nullable'end)from expected;

select ok(exists(select 1 from pg_constraint where conrelid='public.sync_commands'::regclass and conname=n),n||' installed')from(values
 ('sync_commands_pkey'),('sync_commands_operation_key'),('sync_commands_type_not_blank'),('sync_commands_schema_positive'),('sync_commands_payload_object'),('sync_commands_hash_not_blank'),('sync_commands_status_check'),('sync_commands_terminal_shape'),('sync_commands_organization_id_fkey'),('sync_commands_device_id_fkey'),('sync_commands_actor_membership_id_fkey'),('sync_commands_command_id_fkey'),('sync_commands_resolution_of_id_fkey'))x(n);
select ok(exists(select 1 from pg_indexes where schemaname='public'and tablename=t and indexname=n),n||' exists')from(values
 ('sync_commands','sync_commands_operation_key'),('sync_commands','sync_commands_device_status_idx'),('sync_commands','sync_commands_command_idx'),('sync_commands','sync_commands_resolution_idx'),('outbox_events','outbox_events_organization_cursor_key'),('outbox_events','outbox_events_sync_scan_idx'),('sync_cursor_state','sync_cursor_state_pkey'))x(t,n);
select ok(exists(select 1 from pg_trigger where tgrelid=format('public.%I',t)::regclass and tgname=n and not tgisinternal),n||' installed')from(values
 ('sync_commands','v2_sync_commands_guard'),('sync_commands','v2_sync_commands_no_delete'),('outbox_events','v2_outbox_assign_sync_cursor'),('outbox_events','v2_outbox_events_guard_update'))x(t,n);
select ok((select relrowsecurity from pg_class where oid='public.sync_commands'::regclass),'sync_commands RLS enabled');
select ok(not has_table_privilege(r,'public.sync_commands',p),r||' denied sync_commands '||p)from(values('anon'),('authenticated'))roles(r)cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))privs(p);
select ok(not has_table_privilege(r,'public.sync_cursor_state',p),r||' denied cursor state '||p)from(values('public'),('anon'),('authenticated'))roles(r)cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))privs(p);

-- Outbox cursor enrichment and allocation contract.
select has_column('public','outbox_events','sync_cursor','outbox sync_cursor exists');
select ok((select attnotnull from pg_attribute where attrelid='public.outbox_events'::regclass and attname='sync_cursor'),'outbox sync_cursor required');
select ok((select atttypid='int8'::regtype from pg_attribute where attrelid='public.outbox_events'::regclass and attname='sync_cursor'),'outbox sync_cursor bigint');
select ok(exists(select 1 from pg_attribute where attrelid='public.sync_cursor_state'::regclass and attname=c and not attisdropped),'sync_cursor_state.'||c||' exists')from(values('organization_id'),('last_cursor'),('updated_at'))x(c);
select ok((select atttypid=t::regtype from pg_attribute where attrelid='public.sync_cursor_state'::regclass and attname=c),'sync_cursor_state.'||c||' type '||t)from(values('organization_id','uuid'),('last_cursor','int8'),('updated_at','timestamptz'))x(c,t);
select ok((select attnotnull from pg_attribute where attrelid='public.sync_cursor_state'::regclass and attname=c),'sync_cursor_state.'||c||' required')from(values('organization_id'),('last_cursor'),('updated_at'))x(c);
select ok(not exists(select 1 from outbox_events where sync_cursor is null or sync_cursor<=0),'all enriched outbox cursors positive');
select ok(not exists(select 1 from outbox_events group by organization_id,sync_cursor having count(*)>1),'outbox cursors unique per tenant');
select ok(not exists(select 1 from sync_cursor_state s where s.last_cursor<>(select coalesce(max(e.sync_cursor),0)from outbox_events e where e.organization_id=s.organization_id)),'cursor state matches enriched high-water');
select ok(position('on conflict(organization_id)'in lower(pg_get_functiondef('public.v2_assign_outbox_sync_cursor()'::regprocedure)))>0,'cursor allocator locks state through conflicting update');
select ok(position('last_cursor+1'in replace(lower(pg_get_functiondef('public.v2_assign_outbox_sync_cursor()'::regprocedure)),' ',''))>0,'cursor allocator increments exactly once');
select ok(position('sync_cursor is distinct from old.sync_cursor'in lower(pg_get_functiondef('public.v2_guard_outbox_update()'::regprocedure)))>0,'outbox guard makes cursor immutable');

-- Public API and private helper inventory.
with api(sig)as(values
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)'),('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)'),('public.v2_sync_command_journal(uuid,uuid)'),('public.v2_audit_journal(uuid,timestamp with time zone,integer)'),('public.v2_outbox_diagnostics(uuid)'),('public.v2_event_reconciliation(uuid,integer)'),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)'))
select ok(to_regprocedure(sig)is not null,sig||' exists')from api;
with api(sig)as(values
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)'),('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)'),('public.v2_sync_command_journal(uuid,uuid)'),('public.v2_audit_journal(uuid,timestamp with time zone,integer)'),('public.v2_outbox_diagnostics(uuid)'),('public.v2_event_reconciliation(uuid,integer)'),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)'))
select ok(has_function_privilege('authenticated',sig,'EXECUTE'),'authenticated executes '||sig)from api;
with api(sig)as(values
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)'),('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)'),('public.v2_sync_command_journal(uuid,uuid)'),('public.v2_audit_journal(uuid,timestamp with time zone,integer)'),('public.v2_outbox_diagnostics(uuid)'),('public.v2_event_reconciliation(uuid,integer)'),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' denied '||sig)from api cross join(values('public'),('anon'))roles(r);

with helper(sig)as(values
 ('public.v2_guard_sync_command()'),('public.v2_assign_outbox_sync_cursor()'),('public.v2_sync_error_is_conflict(text)'),('public.v2_emit_sync_technical_event(uuid,text,text)'),('public.v2_sync_validate_payload(text,jsonb)'),('public.v2_dispatch_sync_command(uuid)'),('public.v2_sync_dependency_state(uuid)'),('public.v2_close_shift_0016_sync_base(uuid,uuid,jsonb,jsonb,uuid,uuid)'))
select ok(to_regprocedure(sig)is not null,sig||' helper exists')from helper;
with helper(sig)as(values
 ('public.v2_guard_sync_command()'),('public.v2_assign_outbox_sync_cursor()'),('public.v2_sync_error_is_conflict(text)'),('public.v2_emit_sync_technical_event(uuid,text,text)'),('public.v2_sync_validate_payload(text,jsonb)'),('public.v2_dispatch_sync_command(uuid)'),('public.v2_sync_dependency_state(uuid)'),('public.v2_close_shift_0016_sync_base(uuid,uuid,jsonb,jsonb,uuid,uuid)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' denied internal '||sig)from helper cross join(values('public'),('anon'),('authenticated'))roles(r);

with worker(sig)as(values('public.v2_claim_outbox_events(text,integer,integer)'),('public.v2_mark_outbox_delivered(uuid,text)'),('public.v2_mark_outbox_failed(uuid,text,text,integer)'),('public.v2_requeue_stale_outbox(integer)'))
select ok(to_regprocedure(sig)is not null,sig||' worker API exists')from worker;
with worker(sig)as(values('public.v2_claim_outbox_events(text,integer,integer)'),('public.v2_mark_outbox_delivered(uuid,text)'),('public.v2_mark_outbox_failed(uuid,text,text,integer)'),('public.v2_requeue_stale_outbox(integer)'))
select ok(has_function_privilege('service_role',sig,'EXECUTE'),'service_role executes '||sig)from worker;
with worker(sig)as(values('public.v2_claim_outbox_events(text,integer,integer)'),('public.v2_mark_outbox_delivered(uuid,text)'),('public.v2_mark_outbox_failed(uuid,text,text,integer)'),('public.v2_requeue_stale_outbox(integer)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' denied worker '||sig)from worker cross join(values('public'),('anon'),('authenticated'))roles(r);

-- Every new function is schema-qualified and uses an empty search_path.
with fn(n)as(values('v2_guard_sync_command'),('v2_assign_outbox_sync_cursor'),('v2_sync_error_is_conflict'),('v2_emit_sync_technical_event'),('v2_sync_validate_payload'),('v2_dispatch_sync_command'),('v2_sync_dependency_state'),('v2_submit_sync_command'),('v2_resolve_sync_conflict'),('v2_close_shift'),('v2_pull_sync_changes'),('v2_ack_sync_cursor'),('v2_claim_outbox_events'),('v2_mark_outbox_delivered'),('v2_mark_outbox_failed'),('v2_requeue_stale_outbox'),('v2_sync_command_journal'),('v2_audit_journal'),('v2_outbox_diagnostics'),('v2_event_reconciliation'))
select ok(exists(select 1 from pg_proc p join pg_namespace n0 on n0.oid=p.pronamespace where n0.nspname='public'and p.proname=n and array_to_string(p.proconfig,',')='search_path=""'),n||' search_path empty')from fn;

-- Exact function execution model: privilege elevation and volatility are intentional.
with expected(sig,definer)as(values
 ('public.v2_guard_sync_command()',false),('public.v2_assign_outbox_sync_cursor()',false),('public.v2_sync_error_is_conflict(text)',false),('public.v2_emit_sync_technical_event(uuid,text,text)',true),('public.v2_sync_validate_payload(text,jsonb)',false),('public.v2_dispatch_sync_command(uuid)',true),('public.v2_sync_dependency_state(uuid)',true),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)',true),('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])',true),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)',true),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)',true),('public.v2_ack_sync_cursor(uuid,uuid,bigint)',true),('public.v2_claim_outbox_events(text,integer,integer)',true),('public.v2_mark_outbox_delivered(uuid,text)',true),('public.v2_mark_outbox_failed(uuid,text,text,integer)',true),('public.v2_requeue_stale_outbox(integer)',true),('public.v2_sync_command_journal(uuid,uuid)',true),('public.v2_audit_journal(uuid,timestamp with time zone,integer)',true),('public.v2_outbox_diagnostics(uuid)',true),('public.v2_event_reconciliation(uuid,integer)',true))
select ok((select prosecdef=definer from pg_proc where oid=sig::regprocedure),sig||case when definer then' security definer'else' invoker guard'end)from expected;
with expected(sig,volatility)as(values
 ('public.v2_guard_sync_command()','v'),('public.v2_assign_outbox_sync_cursor()','v'),('public.v2_sync_error_is_conflict(text)','i'),('public.v2_emit_sync_technical_event(uuid,text,text)','v'),('public.v2_sync_validate_payload(text,jsonb)','i'),('public.v2_dispatch_sync_command(uuid)','v'),('public.v2_sync_dependency_state(uuid)','s'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','v'),('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])','v'),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)','v'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','s'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','v'),('public.v2_claim_outbox_events(text,integer,integer)','v'),('public.v2_mark_outbox_delivered(uuid,text)','v'),('public.v2_mark_outbox_failed(uuid,text,text,integer)','v'),('public.v2_requeue_stale_outbox(integer)','v'),('public.v2_sync_command_journal(uuid,uuid)','s'),('public.v2_audit_journal(uuid,timestamp with time zone,integer)','s'),('public.v2_outbox_diagnostics(uuid)','v'),('public.v2_event_reconciliation(uuid,integer)','v'))
select ok((select provolatile=volatility::"char"from pg_proc where oid=sig::regprocedure),sig||' volatility '||volatility)from expected;

-- Defaults and foreign-key targets are part of the wire/storage contract.
select ok((select adbin is not null from pg_attrdef d join pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum where d.adrelid='public.sync_commands'::regclass and a.attname=c),'sync_commands.'||c||' default exists')from(values('id'),('dependency_operation_ids'),('status'),('received_at'))x(c);
select ok((select adbin is not null from pg_attrdef d join pg_attribute a on a.attrelid=d.adrelid and a.attnum=d.adnum where d.adrelid='public.sync_cursor_state'::regclass and a.attname=c),'sync_cursor_state.'||c||' default exists')from(values('last_cursor'),('updated_at'))x(c);
select ok(exists(select 1 from pg_constraint c join pg_attribute a on a.attrelid=c.conrelid and a.attnum=any(c.conkey)where c.contype='f'and c.conrelid='public.sync_commands'::regclass and a.attname=col and c.confrelid=format('public.%I',target)::regclass and c.confdeltype='r'),col||' restrict FK to '||target)from(values('organization_id','organizations'),('device_id','devices_v2'),('actor_membership_id','organization_memberships'),('command_id','command_log'),('resolution_of_id','sync_commands'))x(col,target);
select ok((select indisunique=expected from pg_index where indexrelid=format('public.%I',idx)::regclass),idx||case when expected then' unique'else' nonunique'end)from(values
 ('sync_commands_operation_key',true),('sync_commands_device_status_idx',false),('sync_commands_command_idx',false),('sync_commands_resolution_idx',false),('outbox_events_organization_cursor_key',true),('outbox_events_sync_scan_idx',false))x(idx,expected);
select ok((select indpred is not null=partial from pg_index where indexrelid=format('public.%I',idx)::regclass),idx||case when partial then' partial'else' full'end)from(values
 ('sync_commands_operation_key',false),('sync_commands_device_status_idx',false),('sync_commands_command_idx',true),('sync_commands_resolution_idx',true),('outbox_events_organization_cursor_key',false),('outbox_events_sync_scan_idx',false))x(idx,partial);
select ok(position(fragment in pg_get_constraintdef(oid))>0,n||' encodes '||fragment)from pg_constraint cross join lateral(values
 ('sync_commands_status_check','received'),('sync_commands_status_check','processing'),('sync_commands_status_check','accepted'),('sync_commands_status_check','rejected'),('sync_commands_status_check','conflict'),('sync_commands_terminal_shape','processed_at'),('sync_commands_terminal_shape','error_code'),('sync_commands_payload_object','jsonb_typeof'),('sync_commands_schema_positive','schema_version'),('outbox_events_sync_cursor_positive','sync_cursor'))x(n,fragment)where conrelid in('public.sync_commands'::regclass,'public.outbox_events'::regclass)and conname=n;

-- Each public JSON surface has an explicit bounded/read-safe result contract.
select ok(position(fragment in lower(pg_get_functiondef(sig::regprocedure)))>0,sig||' includes '||fragment)from(values
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','sync_command_id'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','waiting_for_dependencies'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','processed_at'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','next_cursor'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','has_more'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','requested_limit not between 1 and 500'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','last_sync_cursor'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','last_seen_at'),('public.v2_sync_command_journal(uuid,uuid)','owner_access'),('public.v2_audit_journal(uuid,timestamp with time zone,integer)','requested_limit not between 1 and 500'),('public.v2_outbox_diagnostics(uuid)','event_count'),('public.v2_event_reconciliation(uuid,integer)','issue_code'))x(sig,fragment);

-- Explicit dispatcher allowlist, payload keys and absence of dynamic SQL.
select ok(position(q in pg_get_functiondef('public.v2_dispatch_sync_command(uuid)'::regprocedure))>0,'dispatcher supports '||q)from(values('shift.open'),('sale.post'),('sale.return'),('debt_payment.record'),('cash.movement.record'),('shift.close'))x(q);
select ok(position(q in pg_get_functiondef('public.v2_sync_validate_payload(text,jsonb)'::regprocedure))>0,'payload validator names '||q)from(values
 ('branch_id'),('register_id'),('opening_amount'),('currency_code'),('business_date'),('warehouse_id'),('shift_id'),('customer_counterparty_id'),('document_number'),('lines'),('payments'),('approval_id'),('debt_terms'),('sale_id'),('counterparty_id'),('allocations'),('movement_type'),('amount'),('reason'),('actual_totals'),('cash_counts'))x(q);
select ok(position('execute 'in lower(pg_get_functiondef('public.v2_dispatch_sync_command(uuid)'::regprocedure)))=0,'dispatcher contains no dynamic SQL');
select ok(position('v2_reverse_sale'in pg_get_functiondef('public.v2_dispatch_sync_command(uuid)'::regprocedure))=0,'sale reversal excluded offline');
select ok(position('v2_post_purchase'in pg_get_functiondef('public.v2_dispatch_sync_command(uuid)'::regprocedure))=0,'purchases excluded offline');
select ok(position('v2_close_settlement_period'in pg_get_functiondef('public.v2_dispatch_sync_command(uuid)'::regprocedure))=0,'settlement close excluded offline');

-- Stable errors are encoded in the responsible function.
with errors(sig,code)as(values
 ('public.v2_guard_sync_command()','V2_SYNC_DEPENDENCIES_INVALID'),('public.v2_guard_sync_command()','V2_SYNC_RESOLUTION_SOURCE_INVALID'),('public.v2_guard_sync_command()','V2_SYNC_DEVICE_TENANT_MISMATCH'),('public.v2_guard_sync_command()','V2_SYNC_ACTOR_TENANT_MISMATCH'),('public.v2_guard_sync_command()','V2_SYNC_COMMAND_CORRELATION_INVALID'),('public.v2_guard_sync_command()','V2_SYNC_ACCEPTED_COMMAND_NOT_SUCCEEDED'),('public.v2_guard_sync_command()','V2_SYNC_ENVELOPE_IMMUTABLE'),('public.v2_guard_sync_command()','V2_SYNC_TERMINAL_IMMUTABLE'),('public.v2_guard_sync_command()','V2_SYNC_STATUS_TRANSITION_INVALID'),
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_ACTIVE_MEMBERSHIP_REQUIRED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_TRUSTED_DEVICE_REQUIRED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_DEVICE_ACCESS_REQUIRED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_RESOLVE_REQUIRED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_IDEMPOTENCY_MISMATCH'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_SCHEMA_UNSUPPORTED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_DEPENDENCY_CYCLE'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_DEPENDENCY_FAILED'),('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','V2_SYNC_COMMAND_CORRELATION_INVALID'),
 ('public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[])','V2_SYNC_RESOLVE_REQUIRED'),('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','V2_SYNC_DEVICE_ACCESS_REQUIRED'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','V2_SYNC_DEVICE_ACCESS_REQUIRED'),('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)','V2_SHIFT_PENDING_SYNC'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','V2_SYNC_ACK_DECREASE_FORBIDDEN'),('public.v2_ack_sync_cursor(uuid,uuid,bigint)','V2_SYNC_ACK_EXCEEDS_HIGH_WATER'),('public.v2_event_reconciliation(uuid,integer)','V2_RECONCILE_MAX_ATTEMPTS_INVALID'),('public.v2_mark_outbox_delivered(uuid,text)','V2_OUTBOX_LEASE_MISMATCH'),('public.v2_mark_outbox_failed(uuid,text,text,integer)','V2_OUTBOX_LEASE_MISMATCH'))
select ok(position(code in pg_get_functiondef(sig::regprocedure))>0,sig||' owns '||code)from errors;

-- Definition-level lock, dependency, subtransaction, redaction and lease facts.
select ok(position(fragment in lower(pg_get_functiondef(sig::regprocedure)))>0,description)from(values
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','v2_lock_operation_scope','submission locks operation scope'),
 ('public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamp with time zone,uuid[],uuid)','exception when sqlstate','domain errors use exception subtransaction'),
 ('public.v2_sync_dependency_state(uuid)','with recursive','dependency cycle detection is recursive'),
 ('public.v2_claim_outbox_events(text,integer,integer)','for update skip locked','worker claim uses SKIP LOCKED'),
 ('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','sync_cursor>after_cursor','pull scans after cursor'),
 ('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)','aggregate_type','pull exposes invalidation metadata'),
 ('public.v2_ack_sync_cursor(uuid,uuid,bigint)','for update','ACK locks exact device'),
 ('public.v2_emit_sync_technical_event(uuid,text,text)','jsonb_strip_nulls','technical event payload is explicit safe object'),
 ('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)','current_sync_command_id','sync close excludes own row'),
 ('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)','v2_lock_register_shift_scope','close checks queue under register lock'))x(sig,fragment,description);
select ok(position(secret in lower(pg_get_functiondef('public.v2_pull_sync_changes(uuid,uuid,bigint,integer)'::regprocedure)))=0,'pull omits '||secret)from(values('payload_hash'),('fingerprint_hash'),('reason'),('before_data'),('after_data'))x(secret);
select ok(position(secret in lower(pg_get_functiondef('public.v2_audit_journal(uuid,timestamp with time zone,integer)'::regprocedure)))=0,'audit journal omits '||secret)from(values('metadata'),('reason'),('before_data'),('after_data'),('payload'),('payload_hash'))x(secret);
select ok(position(fragment in lower(pg_get_functiondef(sig::regprocedure)))>0,description)from(values
 ('public.v2_claim_outbox_events(text,integer,integer)','attempt_count<max_attempts','claim enforces max attempts'),('public.v2_claim_outbox_events(text,integer,integer)','available_at<=clock_timestamp()','claim respects retry availability'),('public.v2_mark_outbox_failed(uuid,text,text,integer)','make_interval','failure schedules future retry'),('public.v2_requeue_stale_outbox(integer)','v2_outbox_stale_lease','stale requeue records safe code'),('public.v2_emit_sync_technical_event(uuid,text,text)','on conflict','technical outbox replay is idempotent'))x(sig,fragment,description);

-- Real owner/device fixture.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000017001','authenticated','authenticated','owner17@test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000017002','authenticated','authenticated','inactive17@test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000017003','authenticated','authenticated','seller17@test','',now(),now(),now());
insert into organizations(id,name)values
 ('00000000-0000-0000-0000-000000017101','Org17'),
 ('00000000-0000-0000-0000-000000017102','Org17 Other Tenant');
insert into organization_settings(organization_id,currency_code,timezone)values('00000000-0000-0000-0000-000000017101','UZS','Asia/Tashkent');
insert into user_profiles(id,auth_user_id,full_name)values
 ('00000000-0000-0000-0000-000000017201','00000000-0000-0000-0000-000000017001','Owner17'),
 ('00000000-0000-0000-0000-000000017202','00000000-0000-0000-0000-000000017002','Inactive17'),
 ('00000000-0000-0000-0000-000000017203','00000000-0000-0000-0000-000000017003','Seller17');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at)values
 ('00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017201','owner','active',now()),
 ('00000000-0000-0000-0000-000000017302','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017202','owner','inactive',now()),
 ('00000000-0000-0000-0000-000000017303','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017203','seller','active',now()),
 ('00000000-0000-0000-0000-000000017304','00000000-0000-0000-0000-000000017102','00000000-0000-0000-0000-000000017201','owner','active',now());
insert into membership_permission_profiles(membership_id,permission_profile_id,assigned_by)values
 ('00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000017301'),
 ('00000000-0000-0000-0000-000000017303','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000017301');
insert into branches(id,organization_id,code,name)values
 ('00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017101','B17','Branch17'),
 ('00000000-0000-0000-0000-000000017402','00000000-0000-0000-0000-000000017101','B17X','Unauthorized Branch17'),
 ('00000000-0000-0000-0000-000000017403','00000000-0000-0000-0000-000000017102','B17O','Other Tenant Branch17');
insert into branch_access(organization_id,membership_id,branch_id,is_primary)values('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017303','00000000-0000-0000-0000-000000017401',true);
insert into warehouses(id,organization_id,branch_id,code,name,is_primary)values('00000000-0000-0000-0000-000000017501','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','W17','Warehouse17',true);
insert into registers(id,organization_id,branch_id,default_warehouse_id,code,name)values('00000000-0000-0000-0000-000000017601','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017501','R17','Register17');
insert into devices_v2(id,organization_id,branch_id,register_id,name,device_type,fingerprint_hash,status)values
 ('00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017601','Device17','desktop','fingerprint-17','trusted'),
 ('00000000-0000-0000-0000-000000017703','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017402',null,'Unauthorized Device17','desktop','fingerprint-17-x','trusted'),
 ('00000000-0000-0000-0000-000000017704','00000000-0000-0000-0000-000000017102','00000000-0000-0000-0000-000000017403',null,'Other Tenant Device17','desktop','fingerprint-17-o','trusted');
insert into devices_v2(id,organization_id,branch_id,register_id,name,device_type,fingerprint_hash,status,revoked_at)values
 ('00000000-0000-0000-0000-000000017702','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017601','Revoked17','desktop','fingerprint-17-r','revoked',now());
select set_config('market_pos.catalog_command','on',true);
insert into units_v2(id,organization_id,code,name,short_name)values('00000000-0000-0000-0000-000000017901','00000000-0000-0000-0000-000000017101','EA17','Each17','ea');
insert into products_v2(id,organization_id,name,base_unit_id)values('00000000-0000-0000-0000-000000017902','00000000-0000-0000-0000-000000017101','Product17','00000000-0000-0000-0000-000000017901');
select set_config('market_pos.catalog_command','off',true);
select set_config('market_pos.pricing_command','on',true);
insert into price_lists(id,organization_id,branch_id,code,name,currency_code,is_default)values('00000000-0000-0000-0000-000000017903','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','POS17','POS17','UZS',true);
insert into product_prices(id,organization_id,price_list_id,product_id,amount,currency_code,valid_from,confirmed_by)values('00000000-0000-0000-0000-000000017904','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017903','00000000-0000-0000-0000-000000017902',10,'UZS',now()-interval'1 hour','00000000-0000-0000-0000-000000017301');
select set_config('market_pos.pricing_command','off',true);
select set_config('market_pos.purchase_command','on',true);
insert into purchase_documents(id,organization_id,branch_id,warehouse_id,document_number,business_date,currency_code)values('00000000-0000-0000-0000-000000017905','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017501','P17-SEED',current_date,'UZS');
insert into purchase_lines(id,organization_id,purchase_document_id,line_number,product_id,unit_id,quantity,unit_factor,base_quantity,unit_purchase_price,line_amount)values('00000000-0000-0000-0000-000000017906','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017905',1,'00000000-0000-0000-0000-000000017902','00000000-0000-0000-0000-000000017901',10,1,10,4,40);
update purchase_documents set status='posted',subtotal_amount=40,total_amount=40,posted_at=now(),posted_by='00000000-0000-0000-0000-000000017301'where id='00000000-0000-0000-0000-000000017905';
select set_config('market_pos.purchase_command','off',true);
select set_config('market_pos.inventory_command','on',true);
insert into product_batches_v2(id,organization_id,warehouse_id,product_id,purchase_line_id,batch_code,received_date,initial_quantity,purchase_unit_cost,currency_code,status)values('00000000-0000-0000-0000-000000017907','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017501','00000000-0000-0000-0000-000000017902','00000000-0000-0000-0000-000000017906','LOT17',current_date,10,4,'UZS','open');
insert into inventory_balances(organization_id,warehouse_id,product_id,batch_id,on_hand_quantity)values('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017501','00000000-0000-0000-0000-000000017902','00000000-0000-0000-0000-000000017907',10),('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017501','00000000-0000-0000-0000-000000017902',null,10);
select set_config('market_pos.inventory_command','off',true);
select set_config('market_pos.counterparty_command','on',true);
insert into counterparties(id,organization_id,display_name)values('00000000-0000-0000-0000-000000017908','00000000-0000-0000-0000-000000017101','Customer17');
insert into counterparty_roles(organization_id,counterparty_id,role_code)values('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017908','customer');
insert into counterparty_credit_settings(counterparty_id,organization_id,credit_enabled,credit_limit_amount,max_due_days,currency_code,updated_by)values('00000000-0000-0000-0000-000000017908','00000000-0000-0000-0000-000000017101',true,1000,30,'UZS','00000000-0000-0000-0000-000000017301');
select set_config('market_pos.counterparty_command','off',true);

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);
set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017801','shift.open',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','opening_amount',100,'currency_code','UZS','business_date',current_date),now())->>'status','accepted','offline shift open accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017801','shift.open',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','opening_amount',100,'currency_code','UZS','business_date',current_date),now())->>'status','accepted','exact retry returns stored accepted result');
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017801','shift.open',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','opening_amount',101,'currency_code','UZS','business_date',current_date),now())$$,'P0001','V2_SYNC_IDEMPOTENCY_MISMATCH','changed payload cannot overwrite original');
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017801','cash.movement.record',1,'{}',now())$$,'P0001','V2_SYNC_IDEMPOTENCY_MISMATCH','changed command type cannot overwrite original');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017802','shift.open',2,'{}',now())->>'error_code','V2_SYNC_SCHEMA_UNSUPPORTED','unsupported schema rejected');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017803','purchase.post',1,'{}',now())->>'error_code','V2_SYNC_COMMAND_UNSUPPORTED_OFFLINE','unsupported offline type rejected');
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017702',gen_random_uuid(),'shift.open',1,'{}',now())$$,'P0001','V2_SYNC_TRUSTED_DEVICE_REQUIRED','revoked device denied');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017002',true);set local role authenticated;
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',gen_random_uuid(),'shift.open',1,'{}',now())$$,'P0001','V2_SYNC_ACTIVE_MEMBERSHIP_REQUIRED','inactive membership denied');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017003',true);set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017821','shift.open',2,'{}',now())->>'error_code','V2_SYNC_SCHEMA_UNSUPPORTED','seller creates own technical sync result on authorized branch');
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017703','00000000-0000-0000-0000-000000017824','shift.open',2,'{}',now())$$,'P0001','V2_SYNC_DEVICE_ACCESS_REQUIRED','seller submit denied for unauthorized device branch');
select throws_ok($$select v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017703',0,100)$$,'P0001','V2_SYNC_DEVICE_ACCESS_REQUIRED','seller pull denied for unauthorized device branch');
select throws_ok($$select v2_ack_sync_cursor('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017703',0)$$,'P0001','V2_SYNC_DEVICE_ACCESS_REQUIRED','seller ACK denied for unauthorized device branch');
reset role;
select set_config('test.seller_sync_id',(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017821')::text,true);
select is((select count(*)from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017824'),0::bigint,'unauthorized device submit creates no sync row');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017804','cash.movement.record',1,jsonb_build_object('shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'movement_type','cash_in','amount',20,'currency_code','UZS','business_date',current_date,'reason','sync cash'),now())->>'status','accepted','offline cash movement accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017811','sale.post',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','warehouse_id','00000000-0000-0000-0000-000000017501','shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'document_number','S17-PAID','business_date',current_date,'currency_code','UZS','lines',jsonb_build_array(jsonb_build_object('line_number',1,'product_id','00000000-0000-0000-0000-000000017902','unit_id','00000000-0000-0000-0000-000000017901','product_price_id','00000000-0000-0000-0000-000000017904','effective_at',now(),'quantity',2,'unit_factor',1,'unit_sale_price',10,'discount_amount',0,'tax_amount',0)),'payments',jsonb_build_array(jsonb_build_object('method','cash','amount',20,'local_operation_id','00000000-0000-0000-0000-000000017812'))),now())->>'status','accepted','offline sale accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017813','sale.return',1,jsonb_build_object('sale_id',(select id from sales_v2 where document_number='S17-PAID'),'shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'document_number','R17-1','lines',jsonb_build_array(jsonb_build_object('original_sale_line_id',(select id from sale_lines_v2 where sale_id=(select id from sales_v2 where document_number='S17-PAID')),'quantity',1,'refund_amount',10)),'payments',jsonb_build_array(jsonb_build_object('method','cash','amount',-10,'original_payment_id',(select id from payments_v2 where sale_id=(select id from sales_v2 where document_number='S17-PAID')),'local_operation_id','00000000-0000-0000-0000-000000017814'))),now())->>'status','accepted','offline return accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017815','sale.post',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','warehouse_id','00000000-0000-0000-0000-000000017501','shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'customer_counterparty_id','00000000-0000-0000-0000-000000017908','document_number','S17-DEBT','business_date',current_date,'currency_code','UZS','lines',jsonb_build_array(jsonb_build_object('line_number',1,'product_id','00000000-0000-0000-0000-000000017902','unit_id','00000000-0000-0000-0000-000000017901','product_price_id','00000000-0000-0000-0000-000000017904','effective_at',now(),'quantity',1,'unit_factor',1,'unit_sale_price',10,'discount_amount',0,'tax_amount',0)),'payments','[]'::jsonb,'debt_terms',jsonb_build_object('due_date',current_date+7)),now())->>'status','accepted','offline debt sale accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017816','debt_payment.record',1,jsonb_build_object('branch_id','00000000-0000-0000-0000-000000017401','register_id','00000000-0000-0000-0000-000000017601','shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'counterparty_id','00000000-0000-0000-0000-000000017908','document_number','DP17-1','business_date',current_date,'currency_code','UZS','payments',jsonb_build_array(jsonb_build_object('method','cash','amount',5,'local_operation_id','00000000-0000-0000-0000-000000017817')),'allocations',jsonb_build_array(jsonb_build_object('receivable_id',(select r.id from receivables r join sales_v2 s on s.id=r.sale_id where s.document_number='S17-DEBT'),'amount',5))),now())->>'status','accepted','offline debt payment accepted');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017805','shift.open',1,'{}',now(),array['00000000-0000-0000-0000-000000017899'::uuid])->>'status','received','missing dependency waits');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017806','shift.open',1,'{}',now(),array['00000000-0000-0000-0000-000000017803'::uuid])->>'error_code','V2_SYNC_DEPENDENCY_FAILED','failed dependency raises conflict');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017807','shift.open',1,'{}',now(),array['00000000-0000-0000-0000-000000017808'::uuid])->>'status','received','first cycle edge waits');
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017808','shift.open',1,'{}',now(),array['00000000-0000-0000-0000-000000017807'::uuid])->>'error_code','V2_SYNC_DEPENDENCY_CYCLE','recursive cycle becomes conflict');
reset role;
select set_config('test.source_sync_id',(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017806')::text,true);
select set_config('test.shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601')::text,true);
select set_config('test.tech_audit_before',(select count(*)from audit_events where entity_type='sync_command')::text,true);
select set_config('test.tech_outbox_before',(select count(*)from outbox_events where aggregate_type='sync_command')::text,true);
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017003',true);
set local role authenticated;
select throws_ok($$select v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017822','cash.movement.record',1,jsonb_build_object('shift_id',current_setting('test.shift_id')::uuid,'movement_type','cash_in','amount',1,'currency_code','UZS','business_date',current_date,'reason','forbidden direct resolution'),now(),'{}'::uuid[],current_setting('test.source_sync_id')::uuid)$$,'P0001','V2_SYNC_RESOLVE_REQUIRED','seller cannot bypass sync.resolve through direct submit');
reset role;
select is((select count(*)from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017822'),0::bigint,'denied direct resolution creates no replacement sync row');
select is((select count(*)from command_log where local_operation_id='00000000-0000-0000-0000-000000017822'),0::bigint,'denied direct resolution creates no command');
select is((select count(*)from cash_movements where local_operation_id='00000000-0000-0000-0000-000000017822'),0::bigint,'denied direct resolution creates no domain row');
select is((select count(*)from audit_events where entity_type='sync_command'),current_setting('test.tech_audit_before')::bigint,'denied direct resolution emits no technical audit event');
select is((select count(*)from outbox_events where aggregate_type='sync_command'),current_setting('test.tech_outbox_before')::bigint,'denied direct resolution emits no technical outbox event');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017823','cash.movement.record',1,jsonb_build_object('shift_id',current_setting('test.shift_id')::uuid,'movement_type','cash_in','amount',1,'currency_code','UZS','business_date',current_date,'reason','owner direct resolution'),now(),'{}'::uuid[],current_setting('test.source_sync_id')::uuid)->>'status','accepted','owner direct conflict resolution remains authorized');
select is(v2_resolve_sync_conflict(current_setting('test.source_sync_id')::uuid,'00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017819','cash.movement.record',1,jsonb_build_object('shift_id',current_setting('test.shift_id')::uuid,'movement_type','cash_in','amount',1,'currency_code','UZS','business_date',current_date,'reason','conflict correction'),now())->>'status','accepted','authorized conflict resolution creates accepted replacement');
select is(v2_resolve_sync_conflict(current_setting('test.source_sync_id')::uuid,'00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017820','cash.movement.record',1,jsonb_build_object('shift_id',current_setting('test.shift_id')::uuid,'movement_type','correction','amount',1,'currency_code','UZS','business_date',current_date,'reason','approval required'),now())->>'error_code','V2_APPROVED_REQUEST_REQUIRED','sync.resolve does not replace domain approval and permission checks');
reset role;

select is((select count(*)from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),1::bigint,'open retry created one shift');
select is((select count(*)from cash_movements where local_operation_id='00000000-0000-0000-0000-000000017804'),1::bigint,'cash sync created one domain row');
select is((select count(*)from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017801'),1::bigint,'sync retry created one envelope');
select is((select status from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017806'),'conflict','conflict resolution preserves source terminal row');
select is((select resolution_of_id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017819'),(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017806'),'resolution records exact source command');
select is((select count(*)from cash_movements where local_operation_id='00000000-0000-0000-0000-000000017820'),0::bigint,'rejected resolution leaves no partial domain row');
select is((select count(*)from outbox_events where aggregate_type='sync_command'and aggregate_id=(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017801')),1::bigint,'accepted replay has one technical event');
select is((select count(*)from audit_events where entity_type='sync_command'and entity_id=(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017801')),1::bigint,'accepted replay has one technical audit event');
select ok(not exists(select 1 from outbox_events where aggregate_type='sync_command'and payload::text ilike any(array['%sync cash%','%fingerprint-17%','%payload_hash%'])),'technical events omit reason fingerprint and hashes');

-- Pending authoritative sync blocks close; legacy rows do not participate.
set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017809','shift.close',1,jsonb_build_object('shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'actual_totals',jsonb_build_object('cash',120,'card',0,'transfer',0),'cash_counts',jsonb_build_array(jsonb_build_object('line_number',1,'denomination_value',120,'quantity',1))),now(),array['00000000-0000-0000-0000-000000017899'::uuid])->>'status','received','sync close with unresolved dependency stays received');
select throws_ok($$select v2_close_shift((select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'00000000-0000-0000-0000-000000017701','{"cash":120,"card":0,"transfer":0}'::jsonb,'[{"line_number":1,"denomination_value":120,"quantity":1}]'::jsonb,'00000000-0000-0000-0000-000000017810',null)$$,'P0001','V2_SHIFT_PENDING_SYNC','committed pending sync blocks canonical close');
reset role;
update sync_commands set status='processing'where local_operation_id in('00000000-0000-0000-0000-000000017805','00000000-0000-0000-0000-000000017807','00000000-0000-0000-0000-000000017809');
update sync_commands set status='conflict',error_code='V2_SYNC_DEPENDENCY_FAILED',processed_at=now()where local_operation_id in('00000000-0000-0000-0000-000000017805','00000000-0000-0000-0000-000000017807','00000000-0000-0000-0000-000000017809');
select ok(position('sync_operations'in pg_get_functiondef('public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)'::regprocedure))=0,'legacy sync_operations never blocks close');
set local role authenticated;
select is(v2_submit_sync_command('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017818','shift.close',1,jsonb_build_object('shift_id',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000017601'),'actual_totals',jsonb_build_object('cash',137,'card',0,'transfer',0),'cash_counts',jsonb_build_array(jsonb_build_object('line_number',1,'denomination_value',137,'quantity',1))),now())->>'status','accepted','offline shift close accepted and excludes own sync row');
reset role;

-- Table guard independently enforces tenant and canonical command correlation.
select throws_ok($$insert into sync_commands(id,organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,client_created_at)values('00000000-0000-0000-0000-000000017910','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017704','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017910','shift.open',1,'{}','guard-device',now())$$,'P0001','V2_SYNC_DEVICE_TENANT_MISMATCH','defensive guard rejects cross-tenant device');
select throws_ok($$insert into sync_commands(id,organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,client_created_at)values('00000000-0000-0000-0000-000000017911','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017304','00000000-0000-0000-0000-000000017911','shift.open',1,'{}','guard-actor',now())$$,'P0001','V2_SYNC_ACTOR_TENANT_MISMATCH','defensive guard rejects cross-tenant actor membership');
insert into sync_commands(id,organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,client_created_at)values('00000000-0000-0000-0000-000000017912','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017912','shift.open',1,'{}','guard-command',now());
update sync_commands set status='processing'where id='00000000-0000-0000-0000-000000017912';
select throws_ok($$update sync_commands set status='accepted',command_id=(select id from command_log where local_operation_id='00000000-0000-0000-0000-000000017801'),result='{}',processed_at=now()where id='00000000-0000-0000-0000-000000017912'$$,'P0001','V2_SYNC_COMMAND_CORRELATION_INVALID','accepted sync cannot bind unrelated command log');
select is((select status from sync_commands where id='00000000-0000-0000-0000-000000017912'),'processing','failed unrelated command binding leaves sync nonterminal');
update sync_commands set status='conflict',error_code='V2_SYNC_TEST_CONFLICT',processed_at=now()where id='00000000-0000-0000-0000-000000017912';

-- Pull scans without ACK; ACK is monotonic and bounded.
select set_config('test.owner_sync_id',(select id from sync_commands where local_operation_id='00000000-0000-0000-0000-000000017801')::text,true);
set local role authenticated;
select ok(jsonb_array_length(v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0,500)->'events')>0,'owner pulls safe event metadata');
select is((select count(*)from v2_sync_command_journal('00000000-0000-0000-0000-000000017101',null)j where j.id=current_setting('test.seller_sync_id')::uuid),1::bigint,'owner journal reads organization-wide seller result');
select is((select last_sync_cursor from devices_v2 where id='00000000-0000-0000-0000-000000017701'),0::bigint,'pull does not ACK');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017003',true);set local role authenticated;
select ok(jsonb_array_length(v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0,500)->'events')>0,'seller pulls authorized branch and own-device invalidations');
select ok(exists(select 1 from jsonb_array_elements(v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0,500)->'events')e where e->>'aggregate_type'='sync_command'and(e->>'aggregate_id')::uuid=current_setting('test.seller_sync_id')::uuid),'seller pull includes own technical sync event');
select ok(not exists(select 1 from jsonb_array_elements(v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0,500)->'events')e where e->>'aggregate_type'='sync_command'and(e->>'aggregate_id')::uuid=current_setting('test.owner_sync_id')::uuid),'seller pull hides another actor technical sync event on shared device');
select ok((v2_pull_sync_changes('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0,500)->'events')::text not ilike any(array['%payload_hash%','%fingerprint_hash%','%before_data%','%after_data%','%reason%']),'seller pull redacts command payloads and sensitive metadata');
select is((select count(*)from v2_sync_command_journal('00000000-0000-0000-0000-000000017101',null)j where j.id=current_setting('test.owner_sync_id')::uuid),0::bigint,'non-owner journal hides owner sync rows');
select is((select count(*)from v2_sync_command_journal('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701')j where j.id=current_setting('test.seller_sync_id')::uuid),1::bigint,'non-owner journal returns own actor row when device narrows scope');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);set local role authenticated;
select lives_ok($$select v2_ack_sync_cursor('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',1)$$,'ACK advances cursor');
select lives_ok($$select v2_ack_sync_cursor('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',1)$$,'ACK retry idempotent');
select throws_ok($$select v2_ack_sync_cursor('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',0)$$,'P0001','V2_SYNC_ACK_DECREASE_FORBIDDEN','ACK cannot decrease');
select throws_ok($$select v2_ack_sync_cursor('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701',9223372036854775807)$$,'P0001','V2_SYNC_ACK_EXCEEDS_HIGH_WATER','ACK cannot exceed high water');
reset role;

-- Worker claim, exact lease, failure/retry/stale and delivered terminal state.
set local role service_role;
create temp table claimed17 as select id from v2_claim_outbox_events('worker17',1,3);
select ok((select count(*)from claimed17)=1,'worker claims one available event');
select throws_ok($$select v2_mark_outbox_delivered((select id from claimed17),'wrong-worker')$$,'P0001','V2_OUTBOX_LEASE_MISMATCH','wrong worker cannot deliver lease');
select lives_ok($$select v2_mark_outbox_failed((select id from claimed17),'worker17','TEMPORARY',1)$$,'lease owner marks failed with retry');
reset role;
update outbox_events set available_at=now()-interval'1 second'where status='failed'and last_error_code='TEMPORARY';
set local role service_role;
create temp table reclaimed17 as select id from v2_claim_outbox_events('worker17b',1,3);
select ok((select count(*)from reclaimed17)=1,'failed event is reclaimed after retry time');
select lives_ok($$select v2_mark_outbox_delivered((select id from reclaimed17),'worker17b')$$,'exact worker delivers event');
reset role;
select throws_ok($$update outbox_events set status='failed'where id=(select id from outbox_events where status='delivered'limit 1)$$,'P0001','V2_OUTBOX_DELIVERED_EVENT_REOPEN_FORBIDDEN','delivered event is terminal');
select throws_ok($$update outbox_events set sync_cursor=sync_cursor+1 where id=(select id from outbox_events limit 1)$$,'P0001','V2_OUTBOX_EVENT_MUTATION_FORBIDDEN','outbox cursor immutable');
set local role service_role;
create temp table stale17 as select id from v2_claim_outbox_events('stale-worker17',1,3);
reset role;
update outbox_events set locked_at=now()-interval'10 minutes'where id=(select id from stale17);
set local role service_role;
select is(v2_requeue_stale_outbox(60),1,'stale processing lease returns to retry state');
reset role;
select is((select status||':'||last_error_code from outbox_events where id=(select id from stale17)),'failed:V2_OUTBOX_STALE_LEASE','stale requeue persists safe diagnostic code');
create temp table exhausted17 as select id from outbox_events where status='pending'limit 1;
update outbox_events set status='failed',attempt_count=3,available_at=now()-interval'1 second'where id=(select id from exhausted17);
select set_config('test.exhausted_id',(select id from exhausted17)::text,true);
set local role service_role;
create temp table exhaust_claim17 as select id from v2_claim_outbox_events('exhaust-worker17',500,3);
select ok(not exists(select 1 from exhaust_claim17 where id=current_setting('test.exhausted_id')::uuid),'exhausted failed event is not reclaimed');
reset role;

-- Safe diagnostics expose aggregates and identifiers, never raw event data.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);
set local role authenticated;
select ok(not exists(select 1 from v2_outbox_diagnostics('00000000-0000-0000-0000-000000017101')d where to_jsonb(d)::text ilike any(array['%payload%','%reason%','%fingerprint%','%hash%'])),'outbox diagnostics contain no payload or sensitive metadata');
select ok(not exists(select 1 from v2_audit_journal('00000000-0000-0000-0000-000000017101','-infinity',500)a where to_jsonb(a)::text ilike any(array['%before_data%','%after_data%','%metadata%','%payload%','%reason%'])),'audit journal returns only redacted identifiers');
reset role;

-- Reconciliation uses caller-supplied worker threshold and detects each missing side independently.
insert into command_log(id,organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,local_operation_id,command_type,payload_hash,status,entity_type,entity_id,result,completed_at)values
 ('00000000-0000-0000-0000-000000017920','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017001','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017920','test.coverage.audit_missing','hash-audit-missing','succeeded','test_entity','00000000-0000-0000-0000-000000017921','{}',now()),
 ('00000000-0000-0000-0000-000000017930','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017001','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017930','test.coverage.outbox_missing','hash-outbox-missing','succeeded','test_entity','00000000-0000-0000-0000-000000017931','{}',now());
insert into outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)values('00000000-0000-0000-0000-000000017101','test_entity','00000000-0000-0000-0000-000000017921','TestEntityChanged','{}','00000000-0000-0000-0000-000000017920');
insert into audit_events(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,command_log_id,local_operation_id,correlation_id,action,entity_type,entity_id,metadata)values('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017001','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017930','00000000-0000-0000-0000-000000017930','00000000-0000-0000-0000-000000017930','TestEntityChanged','test_entity','00000000-0000-0000-0000-000000017931','{}');

insert into sync_commands(id,organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,status,error_code,client_created_at,processed_at)values
 ('00000000-0000-0000-0000-000000017940','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017940','shift.open',1,'{}','missing-technical','rejected','V2_SYNC_TEST_REJECTED',now(),now()),
 ('00000000-0000-0000-0000-000000017941','00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017941','shift.open',1,'{}','duplicate-technical','rejected','V2_SYNC_TEST_REJECTED',now(),now());
insert into audit_events(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,local_operation_id,correlation_id,action,entity_type,entity_id,metadata)values
 ('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017001','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017941','00000000-0000-0000-0000-000000017941','SyncCommandRejected','sync_command','00000000-0000-0000-0000-000000017941','{}'),
 ('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017401','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017001','00000000-0000-0000-0000-000000017301','00000000-0000-0000-0000-000000017941','00000000-0000-0000-0000-000000017941','SyncConflictRaised','sync_command','00000000-0000-0000-0000-000000017941','{}');
insert into outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)values
 ('00000000-0000-0000-0000-000000017101','sync_command','00000000-0000-0000-0000-000000017941','SyncCommandRejected','{}','00000000-0000-0000-0000-000000017941'),
 ('00000000-0000-0000-0000-000000017101','sync_command','00000000-0000-0000-0000-000000017941','SyncConflictRaised','{}','00000000-0000-0000-0000-000000017941');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000017001',true);set local role authenticated;
select throws_ok($$select * from v2_event_reconciliation('00000000-0000-0000-0000-000000017101',0)$$,'P0001','V2_RECONCILE_MAX_ATTEMPTS_INVALID','reconciliation validates worker max attempts');
select ok(not exists(select 1 from v2_event_reconciliation('00000000-0000-0000-0000-000000017101')where issue_code='V2_RECONCILE_OUTBOX_EXHAUSTED'and entity_id=current_setting('test.exhausted_id')::uuid),'retryable failed outbox is not exhausted at default threshold');
select ok(exists(select 1 from v2_event_reconciliation('00000000-0000-0000-0000-000000017101',3)where issue_code='V2_RECONCILE_OUTBOX_EXHAUSTED'and entity_id=current_setting('test.exhausted_id')::uuid),'failed outbox at max attempts is reported exhausted');
select is((select details from v2_event_reconciliation('00000000-0000-0000-0000-000000017101')where issue_code='V2_RECONCILE_EVENT_COVERAGE'and entity_id='00000000-0000-0000-0000-000000017920'),jsonb_build_object('audit_present',false,'outbox_present',true),'missing audit is independently detected');
select is((select details from v2_event_reconciliation('00000000-0000-0000-0000-000000017101')where issue_code='V2_RECONCILE_EVENT_COVERAGE'and entity_id='00000000-0000-0000-0000-000000017930'),jsonb_build_object('audit_present',true,'outbox_present',false),'missing outbox is independently detected');
select is((select details from v2_event_reconciliation('00000000-0000-0000-0000-000000017101')where issue_code='V2_RECONCILE_SYNC_TECH_EVENT'and entity_id='00000000-0000-0000-0000-000000017940'),jsonb_build_object('audit_event_count',0,'outbox_event_count',0),'missing technical audit and outbox events detected');
select is((select details from v2_event_reconciliation('00000000-0000-0000-0000-000000017101')where issue_code='V2_RECONCILE_SYNC_TECH_EVENT'and entity_id='00000000-0000-0000-0000-000000017941'),jsonb_build_object('audit_event_count',2,'outbox_event_count',2),'duplicate technical audit and outbox events detected');
reset role;

-- Browser cannot mutate raw authoritative surfaces.
set local role authenticated;
select throws_ok($$insert into sync_commands(organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,client_created_at)values('00000000-0000-0000-0000-000000017101','00000000-0000-0000-0000-000000017701','00000000-0000-0000-0000-000000017301',gen_random_uuid(),'shift.open',1,'{}','x',now())$$,'42501','permission denied for table sync_commands','browser insert denied');
select throws_ok($$update sync_commands set status='processing'$$,'42501','permission denied for table sync_commands','browser update denied');
select throws_ok($$delete from sync_commands$$,'42501','permission denied for table sync_commands','browser delete denied');
reset role;

-- Reconciliation definitions cover the required infrastructure failure classes.
select ok(position(code in pg_get_functiondef('public.v2_event_reconciliation(uuid,integer)'::regprocedure))>0,'reconciliation detects '||code)from(values
 ('V2_RECONCILE_SYNC_COMMAND_NOT_SUCCEEDED'),('V2_RECONCILE_SYNC_COMMAND_TENANT'),('V2_RECONCILE_SYNC_TECH_EVENT'),('V2_RECONCILE_OUTBOX_CURSOR'),('V2_RECONCILE_OUTBOX_EXHAUSTED'),('V2_RECONCILE_EVENT_COVERAGE'))x(code);

select * from finish();
rollback;
