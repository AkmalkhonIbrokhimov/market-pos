-- MARKET POS V2: SYNC, AUDIT AND OUTBOX COMPLETION
-- Additive coexistence: legacy sync_operations remains untouched.

-- Permission registry -------------------------------------------------------
alter table public.permissions disable trigger v2_permissions_prevent_insert;
insert into public.permissions(code,module,description,critical)
values('sync.resolve','sync','Resolve an offline synchronization conflict.',false)
on conflict(code) do update
set module=excluded.module,description=excluded.description,critical=excluded.critical;
alter table public.permissions enable trigger v2_permissions_prevent_insert;

insert into public.permission_profile_permissions(permission_profile_id,permission_id)
select '00000000-0000-0000-0000-000000000101'::uuid,id
from public.permissions where code='sync.resolve'
on conflict do nothing;

update public.organization_memberships m
set permission_version=permission_version+1
where m.status='active' and exists(
  select 1 from public.membership_permission_profiles x
  where x.membership_id=m.id
    and x.permission_profile_id='00000000-0000-0000-0000-000000000101'::uuid
);

-- Authoritative offline command envelope -----------------------------------
create table public.sync_commands(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  device_id uuid not null references public.devices_v2(id) on delete restrict,
  actor_membership_id uuid not null references public.organization_memberships(id) on delete restrict,
  local_operation_id uuid not null,
  command_type text not null,
  schema_version integer not null,
  payload jsonb not null,
  payload_hash text not null,
  dependency_operation_ids uuid[] not null default '{}'::uuid[],
  status text not null default 'received',
  command_id uuid references public.command_log(id) on delete restrict,
  result jsonb,
  error_code text,
  resolution_of_id uuid references public.sync_commands(id) on delete restrict,
  client_created_at timestamptz not null,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  constraint sync_commands_operation_key unique(organization_id,device_id,local_operation_id),
  constraint sync_commands_type_not_blank check(btrim(command_type)<>''),
  constraint sync_commands_schema_positive check(schema_version>0),
  constraint sync_commands_payload_object check(jsonb_typeof(payload)='object'),
  constraint sync_commands_hash_not_blank check(btrim(payload_hash)<>''),
  constraint sync_commands_status_check check(status in('received','processing','accepted','rejected','conflict')),
  constraint sync_commands_terminal_shape check(
    (status in('received','processing') and processed_at is null and error_code is null)
    or(status='accepted' and command_id is not null and result is not null and processed_at is not null and error_code is null)
    or(status in('rejected','conflict') and processed_at is not null and btrim(error_code)<>'')
  )
);
create index sync_commands_device_status_idx on public.sync_commands(organization_id,device_id,status,received_at,id);
create index sync_commands_command_idx on public.sync_commands(command_id) where command_id is not null;
create index sync_commands_resolution_idx on public.sync_commands(resolution_of_id) where resolution_of_id is not null;

create or replace function public.v2_guard_sync_command()
returns trigger language plpgsql set search_path='' as $$
declare x uuid;source public.sync_commands%rowtype;
begin
  if exists(select 1 from unnest(new.dependency_operation_ids) d where d is null or d='00000000-0000-0000-0000-000000000000'::uuid)
     or cardinality(new.dependency_operation_ids)<>(select count(distinct d) from unnest(new.dependency_operation_ids)d)
     or new.local_operation_id=any(new.dependency_operation_ids) then
    raise exception using errcode='P0001',message='V2_SYNC_DEPENDENCIES_INVALID';
  end if;
  if new.resolution_of_id is not null then
    select * into source from public.sync_commands where id=new.resolution_of_id;
    if source.id is null or source.organization_id<>new.organization_id or source.status<>'conflict' then
      raise exception using errcode='P0001',message='V2_SYNC_RESOLUTION_SOURCE_INVALID';
    end if;
  end if;
  if tg_op='UPDATE' then
    if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id
      or new.device_id is distinct from old.device_id or new.actor_membership_id is distinct from old.actor_membership_id
      or new.local_operation_id is distinct from old.local_operation_id or new.command_type is distinct from old.command_type
      or new.schema_version is distinct from old.schema_version or new.payload is distinct from old.payload
      or new.payload_hash is distinct from old.payload_hash
      or new.dependency_operation_ids is distinct from old.dependency_operation_ids
      or new.resolution_of_id is distinct from old.resolution_of_id
      or new.client_created_at is distinct from old.client_created_at or new.received_at is distinct from old.received_at then
      raise exception using errcode='P0001',message='V2_SYNC_ENVELOPE_IMMUTABLE';
    end if;
    if old.status in('accepted','rejected','conflict') then
      raise exception using errcode='P0001',message='V2_SYNC_TERMINAL_IMMUTABLE';
    end if;
    if not((old.status='received' and new.status in('received','processing'))
       or(old.status='processing' and new.status in('accepted','rejected','conflict'))) then
      raise exception using errcode='P0001',message='V2_SYNC_STATUS_TRANSITION_INVALID';
    end if;
  end if;
  return new;
end$$;
create trigger v2_sync_commands_guard before insert or update on public.sync_commands
for each row execute function public.v2_guard_sync_command();
create trigger v2_sync_commands_no_delete before delete on public.sync_commands
for each row execute function public.v2_prevent_row_mutation();

alter table public.sync_commands enable row level security;
revoke all on public.sync_commands from public,anon,authenticated;

-- Commit-ordered per-organization outbox cursor ----------------------------
create table public.sync_cursor_state(
  organization_id uuid primary key references public.organizations(id) on delete restrict,
  last_cursor bigint not null default 0 check(last_cursor>=0),
  updated_at timestamptz not null default now()
);
revoke all on public.sync_cursor_state from public,anon,authenticated;

alter table public.outbox_events add column sync_cursor bigint;

with ranked as(
  select id,organization_id,row_number()over(partition by organization_id order by created_at,id)::bigint cursor
  from public.outbox_events
)
update public.outbox_events o set sync_cursor=r.cursor from ranked r where r.id=o.id;

insert into public.sync_cursor_state(organization_id,last_cursor)
select o.id,coalesce(max(e.sync_cursor),0)
from public.organizations o left join public.outbox_events e on e.organization_id=o.id
group by o.id
on conflict(organization_id)do update set last_cursor=excluded.last_cursor,updated_at=now();

alter table public.outbox_events alter column sync_cursor set not null;
alter table public.outbox_events add constraint outbox_events_sync_cursor_positive check(sync_cursor>0);
create unique index outbox_events_organization_cursor_key on public.outbox_events(organization_id,sync_cursor);
create index outbox_events_sync_scan_idx on public.outbox_events(organization_id,sync_cursor,id);

create or replace function public.v2_assign_outbox_sync_cursor()
returns trigger language plpgsql set search_path='' as $$
begin
  if new.sync_cursor is not null then
    raise exception using errcode='P0001',message='V2_OUTBOX_CURSOR_MANUAL_FORBIDDEN';
  end if;
  insert into public.sync_cursor_state(organization_id,last_cursor,updated_at)
  values(new.organization_id,1,clock_timestamp())
  on conflict(organization_id)do update
    set last_cursor=public.sync_cursor_state.last_cursor+1,updated_at=clock_timestamp()
  returning last_cursor into new.sync_cursor;
  return new;
end$$;
create trigger v2_outbox_assign_sync_cursor before insert on public.outbox_events
for each row execute function public.v2_assign_outbox_sync_cursor();

create or replace function public.v2_guard_outbox_update()
returns trigger language plpgsql set search_path='' as $$
begin
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id
    or new.aggregate_type is distinct from old.aggregate_type or new.aggregate_id is distinct from old.aggregate_id
    or new.event_type is distinct from old.event_type or new.event_version is distinct from old.event_version
    or new.payload is distinct from old.payload or new.correlation_id is distinct from old.correlation_id
    or new.created_at is distinct from old.created_at or new.sync_cursor is distinct from old.sync_cursor then
    raise exception using errcode='P0001',message='V2_OUTBOX_EVENT_MUTATION_FORBIDDEN';
  end if;
  if new.attempt_count<old.attempt_count then
    raise exception using errcode='P0001',message='V2_OUTBOX_ATTEMPT_COUNT_DECREASE_FORBIDDEN';
  end if;
  if old.status='delivered' then
    raise exception using errcode='P0001',message='V2_OUTBOX_DELIVERED_EVENT_REOPEN_FORBIDDEN';
  end if;
  return new;
end$$;

-- Private sync helpers ------------------------------------------------------
create or replace function public.v2_sync_error_is_conflict(error_code text)
returns boolean language sql immutable set search_path='' as $$
  select coalesce(error_code,'')~'(CONFLICT|IDEMPOTENCY|STOCK|PRICE|SHIFT_(NOT_OPEN|ALREADY_OPEN|PENDING_SYNC)|CREDIT|DEBT_LIMIT|LIMIT_OVERRIDE)'
$$;

create or replace function public.v2_emit_sync_technical_event(sync_id uuid,event_name text,error_code text default null)
returns void language plpgsql security definer set search_path='' as $$
declare s public.sync_commands%rowtype;safe jsonb;
begin
  select * into s from public.sync_commands where id=sync_id;
  if s.id is null or event_name not in('SyncCommandAccepted','SyncCommandRejected','SyncConflictRaised') then
    raise exception using errcode='P0001',message='V2_SYNC_TECHNICAL_EVENT_INVALID';
  end if;
  safe=jsonb_strip_nulls(jsonb_build_object('sync_command_id',s.id,'device_id',s.device_id,'status',s.status,'error_code',error_code));
  if not exists(select 1 from public.audit_events where organization_id=s.organization_id and correlation_id=s.id and action=event_name) then
    insert into public.audit_events(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,command_log_id,local_operation_id,correlation_id,action,entity_type,entity_id,metadata,client_created_at)
    select s.organization_id,d.branch_id,s.device_id,auth.uid(),s.actor_membership_id,s.command_id,s.local_operation_id,s.id,event_name,'sync_command',s.id,safe,s.client_created_at
    from public.devices_v2 d where d.id=s.device_id;
  end if;
  insert into public.outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)
  values(s.organization_id,'sync_command',s.id,event_name,safe,s.id)
  on conflict(organization_id,correlation_id,aggregate_type,aggregate_id,event_type)do nothing;
end$$;

create or replace function public.v2_sync_validate_payload(command_type text,payload jsonb)
returns void language plpgsql immutable set search_path='' as $$
declare allowed text[];required text[];
begin
  if jsonb_typeof(payload)<>'object' then raise exception using errcode='P0001',message='V2_SYNC_PAYLOAD_INVALID';end if;
  case command_type
    when'shift.open'then allowed:=array['branch_id','register_id','opening_amount','currency_code','business_date'];required:=allowed;
    when'sale.post'then allowed:=array['branch_id','register_id','warehouse_id','shift_id','customer_counterparty_id','document_number','business_date','currency_code','lines','payments','approval_id','debt_terms'];required:=array['branch_id','register_id','warehouse_id','shift_id','document_number','business_date','currency_code','lines','payments'];
    when'sale.return'then allowed:=array['sale_id','shift_id','document_number','lines','payments'];required:=allowed;
    when'debt_payment.record'then allowed:=array['branch_id','register_id','shift_id','counterparty_id','document_number','business_date','currency_code','payments','allocations'];required:=allowed;
    when'cash.movement.record'then allowed:=array['shift_id','movement_type','amount','currency_code','business_date','reason','approval_id'];required:=array['shift_id','movement_type','amount','currency_code','business_date','reason'];
    when'shift.close'then allowed:=array['shift_id','actual_totals','cash_counts','approval_id'];required:=array['shift_id','actual_totals','cash_counts'];
    else raise exception using errcode='P0001',message='V2_SYNC_COMMAND_UNSUPPORTED_OFFLINE';
  end case;
  if exists(select 1 from jsonb_object_keys(payload)k where not(k=any(allowed)))
     or exists(select 1 from unnest(required)k where not(payload?k)) then
    raise exception using errcode='P0001',message='V2_SYNC_PAYLOAD_INVALID';
  end if;
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format then
  raise exception using errcode='P0001',message='V2_SYNC_PAYLOAD_INVALID';
end$$;

create or replace function public.v2_dispatch_sync_command(sync_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.sync_commands%rowtype;e uuid;
begin
  select * into s from public.sync_commands where id=sync_id;
  perform public.v2_sync_validate_payload(s.command_type,s.payload);
  perform set_config('market_pos.current_sync_command_id',s.id::text,true);
  case s.command_type
    when'shift.open'then
      e:=public.v2_open_shift(s.organization_id,(s.payload->>'branch_id')::uuid,(s.payload->>'register_id')::uuid,s.device_id,(s.payload->>'opening_amount')::numeric,(s.payload->>'currency_code')::char(3),(s.payload->>'business_date')::date,s.local_operation_id);
    when'sale.post'then
      e:=public.v2_post_sale(s.organization_id,(s.payload->>'branch_id')::uuid,(s.payload->>'register_id')::uuid,(s.payload->>'warehouse_id')::uuid,(s.payload->>'shift_id')::uuid,nullif(s.payload->>'customer_counterparty_id','')::uuid,s.payload->>'document_number',(s.payload->>'business_date')::date,(s.payload->>'currency_code')::char(3),s.device_id,s.local_operation_id,s.client_created_at,s.payload->'lines',s.payload->'payments',nullif(s.payload->>'approval_id','')::uuid,coalesce(s.payload->'debt_terms','{}'::jsonb));
    when'sale.return'then
      e:=public.v2_post_sale_return((s.payload->>'sale_id')::uuid,(s.payload->>'shift_id')::uuid,s.payload->>'document_number',s.device_id,s.local_operation_id,s.payload->'lines',s.payload->'payments');
    when'debt_payment.record'then
      e:=public.v2_record_debt_payment(s.organization_id,(s.payload->>'branch_id')::uuid,(s.payload->>'register_id')::uuid,(s.payload->>'shift_id')::uuid,(s.payload->>'counterparty_id')::uuid,s.payload->>'document_number',(s.payload->>'business_date')::date,(s.payload->>'currency_code')::char(3),s.device_id,s.local_operation_id,s.client_created_at,s.payload->'payments',s.payload->'allocations');
    when'cash.movement.record'then
      e:=public.v2_record_cash_movement((s.payload->>'shift_id')::uuid,s.device_id,s.payload->>'movement_type',(s.payload->>'amount')::numeric,(s.payload->>'currency_code')::char(3),(s.payload->>'business_date')::date,s.payload->>'reason',s.local_operation_id,nullif(s.payload->>'approval_id','')::uuid);
    when'shift.close'then
      e:=public.v2_close_shift((s.payload->>'shift_id')::uuid,s.device_id,s.payload->'actual_totals',s.payload->'cash_counts',s.local_operation_id,nullif(s.payload->>'approval_id','')::uuid);
  end case;
  return jsonb_build_object('entity_id',e,'command_id',nullif(current_setting('market_pos.current_command_id',true),'')::uuid,'status','accepted');
exception when invalid_text_representation or numeric_value_out_of_range or invalid_datetime_format or null_value_not_allowed then
  raise exception using errcode='P0001',message='V2_SYNC_PAYLOAD_INVALID';
end$$;

create or replace function public.v2_sync_dependency_state(sync_id uuid)
returns text language plpgsql stable security definer set search_path='' as $$
declare s public.sync_commands%rowtype;dep uuid;st text;
begin
  select * into s from public.sync_commands where id=sync_id;
  if exists(
    with recursive walk(op,path,cycle)as(
      select d,array[s.local_operation_id,d],d=s.local_operation_id from unnest(s.dependency_operation_ids)d
      union all
      select d2,w.path||d2,d2=any(w.path) from walk w join public.sync_commands x on x.organization_id=s.organization_id and x.device_id=s.device_id and x.local_operation_id=w.op cross join lateral unnest(x.dependency_operation_ids)d2 where not w.cycle
    )select 1 from walk where cycle
  )then return'cycle';end if;
  foreach dep in array s.dependency_operation_ids loop
    select status into st from public.sync_commands where organization_id=s.organization_id and device_id=s.device_id and local_operation_id=dep;
    if st in('rejected','conflict')then return'failed';end if;
    if st is null or st in('received','processing')then return'waiting';end if;
  end loop;
  return'ready';
end$$;

-- Single-command authenticated submission ---------------------------------
create or replace function public.v2_submit_sync_command(
  organization_id uuid,device_id uuid,local_operation_id uuid,command_type text,
  schema_version integer,payload jsonb,client_created_at timestamptz,
  dependency_operation_ids uuid[] default'{}',resolution_of_id uuid default null
)returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid;s public.sync_commands%rowtype;h text;dep_state text;dispatch_result jsonb;code text;command uuid;
begin
  a:=public.v2_current_membership_id(organization_id);
  if a is null then raise exception using errcode='P0001',message='V2_SYNC_ACTIVE_MEMBERSHIP_REQUIRED';end if;
  if not exists(select 1 from public.devices_v2 d where d.id=v2_submit_sync_command.device_id and d.organization_id=v2_submit_sync_command.organization_id and d.status='trusted'and d.revoked_at is null)then
    raise exception using errcode='P0001',message='V2_SYNC_TRUSTED_DEVICE_REQUIRED';
  end if;
  perform public.v2_lock_operation_scope(organization_id,device_id,local_operation_id);
  h:=encode(extensions.digest(jsonb_build_object('command_type',command_type,'schema_version',schema_version,'payload',payload,'dependencies',coalesce(dependency_operation_ids,'{}'::uuid[]),'resolution_of_id',resolution_of_id,'client_created_at',client_created_at)::text,'sha256'),'hex');
  select * into s from public.sync_commands x where x.organization_id=v2_submit_sync_command.organization_id and x.device_id=v2_submit_sync_command.device_id and x.local_operation_id=v2_submit_sync_command.local_operation_id for update;
  if found then
    if s.payload_hash<>h then raise exception using errcode='P0001',message='V2_SYNC_IDEMPOTENCY_MISMATCH';end if;
    if s.status in('accepted','rejected','conflict')then
      return jsonb_strip_nulls(jsonb_build_object('sync_command_id',s.id,'status',s.status,'command_id',s.command_id,'result',s.result,'error_code',s.error_code));
    end if;
  else
    insert into public.sync_commands(organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,dependency_operation_ids,resolution_of_id,client_created_at)
    values(organization_id,device_id,a,local_operation_id,command_type,schema_version,payload,h,coalesce(dependency_operation_ids,'{}'),resolution_of_id,client_created_at)returning * into s;
  end if;
  if schema_version<>1 then
    update public.sync_commands set status='processing'where id=s.id;
    update public.sync_commands set status='rejected',error_code='V2_SYNC_SCHEMA_UNSUPPORTED',processed_at=clock_timestamp()where id=s.id;
    perform public.v2_emit_sync_technical_event(s.id,'SyncCommandRejected','V2_SYNC_SCHEMA_UNSUPPORTED');
    return jsonb_build_object('sync_command_id',s.id,'status','rejected','error_code','V2_SYNC_SCHEMA_UNSUPPORTED');
  end if;
  dep_state:=public.v2_sync_dependency_state(s.id);
  if dep_state='waiting'then return jsonb_build_object('sync_command_id',s.id,'status','received','waiting_for_dependencies',true);end if;
  if dep_state in('failed','cycle')then
    code:=case dep_state when'cycle'then'V2_SYNC_DEPENDENCY_CYCLE'else'V2_SYNC_DEPENDENCY_FAILED'end;
    update public.sync_commands set status='processing'where id=s.id;
    update public.sync_commands set status='conflict',error_code=code,processed_at=clock_timestamp()where id=s.id;
    perform public.v2_emit_sync_technical_event(s.id,'SyncConflictRaised',code);
    return jsonb_build_object('sync_command_id',s.id,'status','conflict','error_code',code);
  end if;
  update public.sync_commands set status='processing'where id=s.id;
  begin
    dispatch_result:=public.v2_dispatch_sync_command(s.id);
  exception when sqlstate'P0001' then
    get stacked diagnostics code=message_text;
    update public.sync_commands set status=case when public.v2_sync_error_is_conflict(code)then'conflict'else'rejected'end,error_code=code,processed_at=clock_timestamp()where id=s.id;
    perform public.v2_emit_sync_technical_event(s.id,case when public.v2_sync_error_is_conflict(code)then'SyncConflictRaised'else'SyncCommandRejected'end,code);
    return jsonb_build_object('sync_command_id',s.id,'status',case when public.v2_sync_error_is_conflict(code)then'conflict'else'rejected'end,'error_code',code);
  end;
  command:=(dispatch_result->>'command_id')::uuid;
  if command is null or not exists(select 1 from public.command_log c where c.id=command and c.organization_id=v2_submit_sync_command.organization_id and c.device_id=v2_submit_sync_command.device_id and c.local_operation_id=v2_submit_sync_command.local_operation_id and c.status='succeeded')then
    raise exception using errcode='P0001',message='V2_SYNC_COMMAND_CORRELATION_INVALID';
  end if;
  update public.sync_commands set status='accepted',command_id=command,result=dispatch_result,processed_at=clock_timestamp()where id=s.id;
  perform public.v2_emit_sync_technical_event(s.id,'SyncCommandAccepted',null);
  return jsonb_build_object('sync_command_id',s.id,'status','accepted','command_id',command,'result',dispatch_result);
end$$;

create or replace function public.v2_resolve_sync_conflict(
  source_sync_command_id uuid,device_id uuid,new_local_operation_id uuid,command_type text,
  schema_version integer,payload jsonb,client_created_at timestamptz,
  dependency_operation_ids uuid[] default'{}'
)returns jsonb language plpgsql security definer set search_path='' as $$
declare source public.sync_commands%rowtype;
begin
  select * into source from public.sync_commands where id=source_sync_command_id;
  if source.id is null or source.status<>'conflict'then raise exception using errcode='P0001',message='V2_SYNC_RESOLUTION_SOURCE_INVALID';end if;
  if not public.v2_has_permission(source.organization_id,'sync.resolve',null)then raise exception using errcode='P0001',message='V2_SYNC_RESOLVE_REQUIRED';end if;
  if new_local_operation_id=source.local_operation_id then raise exception using errcode='P0001',message='V2_SYNC_RESOLUTION_OPERATION_REQUIRED';end if;
  return public.v2_submit_sync_command(source.organization_id,device_id,new_local_operation_id,command_type,schema_version,payload,client_created_at,dependency_operation_ids,source.id);
end$$;

-- Shift close wrapper: authoritative pending sync queue ---------------------
alter function public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid) rename to v2_close_shift_0016_sync_base;
create or replace function public.v2_close_shift(i uuid,d uuid,actuals jsonb,counts jsonb,op uuid,approval uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.shifts_v2%rowtype;own_sync uuid:=nullif(current_setting('market_pos.current_sync_command_id',true),'')::uuid;
begin
  select * into s from public.shifts_v2 where id=i;
  if s.id is null then raise exception using errcode='P0001',message='V2_SHIFT_NOT_FOUND';end if;
  perform public.v2_lock_operation_scope(s.organization_id,d,op);
  -- v2_begin_inventory_command remains delegated to the 0016 canonical base
  -- after the operation lock and before that base reacquires the register lock.
  perform public.v2_lock_register_shift_scope(s.organization_id,s.branch_id,s.register_id);
  if exists(
    select 1 from public.sync_commands q join public.devices_v2 dv on dv.id=q.device_id
    where q.organization_id=s.organization_id and dv.register_id=s.register_id
      and q.status in('received','processing') and q.id is distinct from own_sync
  )then raise exception using errcode='P0001',message='V2_SHIFT_PENDING_SYNC';end if;
  -- The delegated 0016 base preserves the complete close contract:
  -- status='closing'; v2_validate_shift_close_snapshot;
  -- V2_SHIFT_CASH_COUNT_TOTAL_MISMATCH; V2_SHIFT_DISCREPANCY_APPROVAL_REQUIRED;
  -- ShiftDiscrepancyDetected; ShiftClosed.
  return public.v2_close_shift_0016_sync_base(i,d,actuals,counts,op,approval);
end$$;

-- Safe pull and ACK ---------------------------------------------------------
create or replace function public.v2_pull_sync_changes(organization_id uuid,device_id uuid,after_cursor bigint,requested_limit integer)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a uuid;role_code text;scan_to bigint;events jsonb;more boolean;
begin
  if requested_limit not between 1 and 500 or after_cursor<0 then raise exception using errcode='P0001',message='V2_SYNC_PULL_ARGUMENT_INVALID';end if;
  a:=public.v2_current_membership_id(organization_id);
  if a is null or not exists(select 1 from public.devices_v2 d where d.id=v2_pull_sync_changes.device_id and d.organization_id=v2_pull_sync_changes.organization_id and d.status='trusted'and d.revoked_at is null)then raise exception using errcode='P0001',message='V2_SYNC_TRUSTED_DEVICE_REQUIRED';end if;
  select system_role into role_code from public.organization_memberships where id=a;
  with scanned as(select * from public.outbox_events e where e.organization_id=v2_pull_sync_changes.organization_id and e.sync_cursor>after_cursor order by e.sync_cursor limit requested_limit)
  select coalesce(max(sync_cursor),after_cursor),coalesce(jsonb_agg(jsonb_build_object('cursor',sync_cursor,'aggregate_type',aggregate_type,'aggregate_id',aggregate_id,'event_type',event_type,'event_version',event_version,'created_at',created_at)order by sync_cursor)filter(where
    role_code='owner'or(
      (aggregate_type='sync_command'and exists(select 1 from public.sync_commands q where q.id=aggregate_id and q.device_id=v2_pull_sync_changes.device_id))
      or(aggregate_type in('product','category','brand','unit','product_type','price_list','organization_settings'))
      or(aggregate_type not in('purchase','supplier_payment','settlement','settlement_period','settlement_act','approval_request')and exists(select 1 from public.audit_events a0 where a0.organization_id=v2_pull_sync_changes.organization_id and a0.correlation_id=scanned.correlation_id and a0.branch_id is not null and public.v2_can_access_branch(v2_pull_sync_changes.organization_id,a0.branch_id)))
    )),'[]'::jsonb)
  into scan_to,events from scanned;
  select exists(select 1 from public.outbox_events e where e.organization_id=v2_pull_sync_changes.organization_id and e.sync_cursor>scan_to)into more;
  return jsonb_build_object('events',events,'next_cursor',scan_to,'has_more',more);
end$$;

create or replace function public.v2_ack_sync_cursor(organization_id uuid,device_id uuid,cursor bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a uuid;high bigint;d public.devices_v2%rowtype;
begin
  a:=public.v2_current_membership_id(organization_id);
  select * into d from public.devices_v2 x where x.id=v2_ack_sync_cursor.device_id and x.organization_id=v2_ack_sync_cursor.organization_id for update;
  if a is null or d.id is null or d.status<>'trusted'or d.revoked_at is not null then raise exception using errcode='P0001',message='V2_SYNC_TRUSTED_DEVICE_REQUIRED';end if;
  select coalesce(last_cursor,0)into high from public.sync_cursor_state where sync_cursor_state.organization_id=v2_ack_sync_cursor.organization_id;
  if cursor<d.last_sync_cursor then raise exception using errcode='P0001',message='V2_SYNC_ACK_DECREASE_FORBIDDEN';end if;
  if cursor>coalesce(high,0)then raise exception using errcode='P0001',message='V2_SYNC_ACK_EXCEEDS_HIGH_WATER';end if;
  update public.devices_v2 set last_sync_cursor=cursor,last_seen_at=greatest(coalesce(last_seen_at,'-infinity'::timestamptz),clock_timestamp())where id=d.id;
  return jsonb_build_object('device_id',d.id,'acknowledged_cursor',cursor);
end$$;

-- Service-role outbox lifecycle --------------------------------------------
create or replace function public.v2_claim_outbox_events(worker_id text,batch_size integer,max_attempts integer)
returns setof public.outbox_events language plpgsql security definer set search_path='' as $$
begin
  if btrim(coalesce(worker_id,''))=''or batch_size not between 1 and 500 or max_attempts<1 then raise exception using errcode='P0001',message='V2_OUTBOX_CLAIM_ARGUMENT_INVALID';end if;
  return query with claim as(
    select id from public.outbox_events where status in('pending','failed')and available_at<=clock_timestamp()and attempt_count<max_attempts order by available_at,sync_cursor for update skip locked limit batch_size
  )update public.outbox_events e set status='processing',locked_by=worker_id,locked_at=clock_timestamp(),attempt_count=e.attempt_count+1,last_error_code=null from claim where e.id=claim.id returning e.*;
end$$;
create or replace function public.v2_mark_outbox_delivered(event_id uuid,worker_id text)
returns void language plpgsql security definer set search_path='' as $$
begin update public.outbox_events set status='delivered',delivered_at=clock_timestamp(),locked_at=null,locked_by=null,last_error_code=null where id=event_id and status='processing'and locked_by=worker_id;if not found then raise exception using errcode='P0001',message='V2_OUTBOX_LEASE_MISMATCH';end if;end$$;
create or replace function public.v2_mark_outbox_failed(event_id uuid,worker_id text,error_code text,retry_after_seconds integer)
returns void language plpgsql security definer set search_path='' as $$
begin if btrim(coalesce(error_code,''))=''or retry_after_seconds<1 then raise exception using errcode='P0001',message='V2_OUTBOX_FAILURE_ARGUMENT_INVALID';end if;update public.outbox_events set status='failed',available_at=clock_timestamp()+make_interval(secs=>retry_after_seconds),locked_at=null,locked_by=null,last_error_code=error_code where id=event_id and status='processing'and locked_by=worker_id;if not found then raise exception using errcode='P0001',message='V2_OUTBOX_LEASE_MISMATCH';end if;end$$;
create or replace function public.v2_requeue_stale_outbox(stale_after_seconds integer)
returns integer language plpgsql security definer set search_path='' as $$
declare n integer;begin if stale_after_seconds<1 then raise exception using errcode='P0001',message='V2_OUTBOX_STALE_ARGUMENT_INVALID';end if;update public.outbox_events set status='failed',available_at=clock_timestamp(),locked_at=null,locked_by=null,last_error_code='V2_OUTBOX_STALE_LEASE'where status='processing'and locked_at<clock_timestamp()-make_interval(secs=>stale_after_seconds);get diagnostics n=row_count;return n;end$$;

-- Safe diagnostic surfaces -------------------------------------------------
create or replace function public.v2_sync_command_journal(p_organization_id uuid,p_device_id uuid default null)
returns table(id uuid,device_id uuid,local_operation_id uuid,command_type text,status text,command_id uuid,result jsonb,error_code text,received_at timestamptz,processed_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare a uuid;owner_access boolean;
begin a:=public.v2_current_membership_id(p_organization_id);if a is null then raise exception using errcode='P0001',message='V2_SYNC_ACTIVE_MEMBERSHIP_REQUIRED';end if;select system_role='owner'into owner_access from public.organization_memberships where organization_memberships.id=a;
return query select s.id,s.device_id,s.local_operation_id,s.command_type,s.status,s.command_id,s.result,s.error_code,s.received_at,s.processed_at from public.sync_commands s where s.organization_id=p_organization_id and(owner_access or s.device_id=p_device_id)and(p_device_id is null or s.device_id=p_device_id)order by s.received_at desc,s.id;end$$;

create or replace function public.v2_audit_journal(organization_id uuid,after_created_at timestamptz default '-infinity',requested_limit integer default 100)
returns table(id uuid,created_at timestamptz,action text,entity_type text,entity_id uuid,correlation_id uuid,branch_id uuid)
language plpgsql stable security definer set search_path='' as $$
begin if requested_limit not between 1 and 500 then raise exception using errcode='P0001',message='V2_AUDIT_JOURNAL_ARGUMENT_INVALID';end if;if not(public.v2_has_permission(organization_id,'audit.view',null)or public.v2_has_support_grant(organization_id,'audit.view'))then raise exception using errcode='P0001',message='V2_AUDIT_VIEW_REQUIRED';end if;return query select a.id,a.created_at,a.action,a.entity_type,a.entity_id,a.correlation_id,a.branch_id from public.audit_events a where a.organization_id=v2_audit_journal.organization_id and a.created_at>after_created_at order by a.created_at,a.id limit requested_limit;end$$;

create or replace function public.v2_outbox_diagnostics(organization_id uuid)
returns table(status text,event_count bigint,oldest_age_seconds bigint,max_attempt_count integer)
language plpgsql volatile security definer set search_path='' as $$
begin if not(public.v2_has_permission(organization_id,'audit.view',null)or public.v2_has_support_grant(organization_id,'audit.view'))then raise exception using errcode='P0001',message='V2_AUDIT_VIEW_REQUIRED';end if;return query select e.status,count(*),extract(epoch from clock_timestamp()-min(e.created_at))::bigint,max(e.attempt_count)from public.outbox_events e where e.organization_id=v2_outbox_diagnostics.organization_id group by e.status order by e.status;end$$;

create or replace function public.v2_event_reconciliation(organization_id uuid)
returns table(issue_code text,entity_id uuid,details jsonb)
language plpgsql volatile security definer set search_path='' as $$
begin if not(public.v2_has_permission(organization_id,'audit.view',null)or public.v2_has_support_grant(organization_id,'audit.view'))then raise exception using errcode='P0001',message='V2_AUDIT_VIEW_REQUIRED';end if;
return query
 select'V2_RECONCILE_SYNC_COMMAND_NOT_SUCCEEDED',s.id,jsonb_build_object('command_id',s.command_id)from public.sync_commands s left join public.command_log c on c.id=s.command_id where s.organization_id=v2_event_reconciliation.organization_id and s.status='accepted'and(c.id is null or c.status<>'succeeded')
 union all select'V2_RECONCILE_SYNC_COMMAND_TENANT',s.id,'{}'::jsonb from public.sync_commands s join public.command_log c on c.id=s.command_id where s.organization_id=v2_event_reconciliation.organization_id and c.organization_id<>s.organization_id
 union all select'V2_RECONCILE_SYNC_TECH_EVENT',s.id,jsonb_build_object('event_count',count(e.id))from public.sync_commands s left join public.outbox_events e on e.organization_id=s.organization_id and e.aggregate_type='sync_command'and e.aggregate_id=s.id where s.organization_id=v2_event_reconciliation.organization_id and s.status in('accepted','rejected','conflict')group by s.id having count(e.id)<>1
 union all select'V2_RECONCILE_OUTBOX_CURSOR',e.id,jsonb_build_object('cursor',e.sync_cursor)from public.outbox_events e where e.organization_id=v2_event_reconciliation.organization_id and(e.sync_cursor is null or e.sync_cursor<=0)
 union all select'V2_RECONCILE_OUTBOX_EXHAUSTED',e.id,jsonb_build_object('attempt_count',e.attempt_count)from public.outbox_events e where e.organization_id=v2_event_reconciliation.organization_id and e.status='failed'and e.attempt_count>0 and e.available_at<=clock_timestamp()
 union all select'V2_RECONCILE_EVENT_COVERAGE',c.id,'{}'::jsonb from public.command_log c where c.organization_id=v2_event_reconciliation.organization_id and c.status='succeeded'and c.entity_id is not null and not exists(select 1 from public.audit_events a where a.command_log_id=c.id)and not exists(select 1 from public.outbox_events o where o.correlation_id=c.id);
end$$;

-- Privileges ---------------------------------------------------------------
revoke execute on function public.v2_guard_sync_command(),public.v2_assign_outbox_sync_cursor(),public.v2_sync_error_is_conflict(text),public.v2_emit_sync_technical_event(uuid,text,text),public.v2_sync_validate_payload(text,jsonb),public.v2_dispatch_sync_command(uuid),public.v2_sync_dependency_state(uuid),public.v2_close_shift_0016_sync_base(uuid,uuid,jsonb,jsonb,uuid,uuid)from public,anon,authenticated;
revoke execute on function public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamptz,uuid[],uuid),public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamptz,uuid[]),public.v2_pull_sync_changes(uuid,uuid,bigint,integer),public.v2_ack_sync_cursor(uuid,uuid,bigint),public.v2_sync_command_journal(uuid,uuid),public.v2_audit_journal(uuid,timestamptz,integer),public.v2_outbox_diagnostics(uuid),public.v2_event_reconciliation(uuid)from public,anon;
grant execute on function public.v2_submit_sync_command(uuid,uuid,uuid,text,integer,jsonb,timestamptz,uuid[],uuid),public.v2_resolve_sync_conflict(uuid,uuid,uuid,text,integer,jsonb,timestamptz,uuid[]),public.v2_pull_sync_changes(uuid,uuid,bigint,integer),public.v2_ack_sync_cursor(uuid,uuid,bigint),public.v2_sync_command_journal(uuid,uuid),public.v2_audit_journal(uuid,timestamptz,integer),public.v2_outbox_diagnostics(uuid),public.v2_event_reconciliation(uuid)to authenticated;
revoke execute on function public.v2_claim_outbox_events(text,integer,integer),public.v2_mark_outbox_delivered(uuid,text),public.v2_mark_outbox_failed(uuid,text,text,integer),public.v2_requeue_stale_outbox(integer)from public,anon,authenticated;
grant execute on function public.v2_claim_outbox_events(text,integer,integer),public.v2_mark_outbox_delivered(uuid,text),public.v2_mark_outbox_failed(uuid,text,text,integer),public.v2_requeue_stale_outbox(integer)to service_role;
revoke execute on function public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)from public,anon;
grant execute on function public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid)to authenticated;

comment on table public.sync_commands is'Authoritative immutable offline command envelopes; legacy sync_operations is intentionally untouched.';
comment on column public.outbox_events.sync_cursor is'Commit-ordered per-organization invalidation cursor allocated under sync_cursor_state row lock.';
