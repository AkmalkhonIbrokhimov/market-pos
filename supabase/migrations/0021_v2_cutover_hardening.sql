-- Market POS V2: forward-only hardening for the merged 0020 cutover gate.

create or replace function public.v2_lock_legacy_cutover_sources()
returns void
language plpgsql
set search_path = ''
as $$
begin
  -- SHARE ROW EXCLUSIVE conflicts with the RowExclusiveLock taken by
  -- ordinary INSERT/UPDATE/DELETE.  The static alphabetical order is part
  -- of the cutover contract and avoids relation-lock ordering ambiguity.
  lock table
    public.brands,
    public.categories,
    public.customers,
    public.debt_entries,
    public.debt_payments,
    public.devices,
    public.operation_logs,
    public.payments,
    public.product_batches,
    public.product_types,
    public.products,
    public.sale_items,
    public.sales,
    public.shifts,
    public.stock_movements,
    public.stores,
    public.suppliers,
    public.sync_operations,
    public.units,
    public.user_store_access,
    public.users
  in share row exclusive mode;
end
$$;

create or replace function public.v2_guard_legacy_cutover_freeze()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  old_row jsonb;
  new_row jsonb;
  old_organization_id uuid;
  new_organization_id uuid;
begin
  if tg_op <> 'INSERT' then old_row := to_jsonb(old); end if;
  if tg_op <> 'DELETE' then new_row := to_jsonb(new); end if;

  case tg_table_name
    when 'users' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'user_store_access' then
      select organization_id into old_organization_id from public.users where id=(old_row->>'user_id')::uuid;
      select organization_id into new_organization_id from public.users where id=(new_row->>'user_id')::uuid;
    when 'stores' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'categories' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'brands' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'units' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'product_types' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'products' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'suppliers' then
      old_organization_id := (old_row->>'organization_id')::uuid;
      new_organization_id := (new_row->>'organization_id')::uuid;
    when 'customers' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'devices' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'product_batches' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'stock_movements' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'sales' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'sale_items' then
      select s.organization_id into old_organization_id
      from public.sales x join public.stores s on s.id=x.store_id
      where x.id=(old_row->>'sale_id')::uuid;
      select s.organization_id into new_organization_id
      from public.sales x join public.stores s on s.id=x.store_id
      where x.id=(new_row->>'sale_id')::uuid;
    when 'payments' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'shifts' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'debt_payments' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'debt_entries' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'sync_operations' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    when 'operation_logs' then
      select organization_id into old_organization_id from public.stores where id=(old_row->>'store_id')::uuid;
      select organization_id into new_organization_id from public.stores where id=(new_row->>'store_id')::uuid;
    else
      raise exception using errcode='P0001',message='V2_CUTOVER_LEGACY_TABLE_UNSUPPORTED';
  end case;

  if exists(
    select 1 from public.cutover_controls c
    where c.state='legacy_frozen'
      and c.organization_id in(old_organization_id,new_organization_id)
  ) then
    raise exception using errcode='P0001',message='V2_LEGACY_WRITES_FROZEN';
  end if;

  return case when tg_op='DELETE' then old else new end;
end
$$;

create or replace function public.v2_cutover_settlement_acts_reconciled(p_organization_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select not exists(
    select 1
    from public.settlement_periods p
    join public.settlement_acts a on a.settlement_period_id=p.id
    cross join lateral (
      select
        coalesce(sum(e.amount_delta) filter(where e.business_date<p.starts_on),0) as opening_balance,
        coalesce(sum(e.amount_delta) filter(where e.business_date>=p.starts_on and e.business_date<p.ends_on and e.amount_delta>0),0) as total_debit,
        coalesce(abs(sum(e.amount_delta) filter(where e.business_date>=p.starts_on and e.business_date<p.ends_on and e.amount_delta<0)),0) as total_credit
      from public.settlement_entries e
      where e.organization_id=p.organization_id and e.counterparty_id=p.counterparty_id and e.currency_code=p.currency_code and e.business_date<p.ends_on
    ) totals
    cross join lateral (
      select encode(extensions.digest(jsonb_build_object(
        'schema_version',1,
        'organization_id',p.organization_id,
        'counterparty_id',p.counterparty_id,
        'currency_code',p.currency_code,
        'starts_on',p.starts_on,
        'ends_on',p.ends_on,
        'opening_balance',totals.opening_balance,
        'entries',coalesce(jsonb_agg(jsonb_build_object('id',e.id,'entry_type',e.entry_type,'amount_delta',e.amount_delta,'business_date',e.business_date)order by e.business_date,e.created_at,e.id),'[]'::jsonb),
        'closing_balance',totals.opening_balance+totals.total_debit-totals.total_credit
      )::text,'sha256'),'hex') as snapshot_hash
      from public.settlement_entries e
      where e.organization_id=p.organization_id and e.counterparty_id=p.counterparty_id and e.currency_code=p.currency_code and e.business_date>=p.starts_on and e.business_date<p.ends_on
    ) canonical
    where p.organization_id=p_organization_id and (
      p.opening_balance<>totals.opening_balance or
      p.closing_balance<>totals.opening_balance+totals.total_debit-totals.total_credit or
      a.total_debit<>totals.total_debit or
      a.total_credit<>totals.total_credit or
      a.closing_balance<>totals.opening_balance+totals.total_debit-totals.total_credit or
      a.snapshot_hash<>canonical.snapshot_hash or
      (select count(*)from public.settlement_act_lines l where l.settlement_act_id=a.id)<>
        (select count(*)from public.settlement_entries e where e.organization_id=p.organization_id and e.counterparty_id=p.counterparty_id and e.currency_code=p.currency_code and e.business_date>=p.starts_on and e.business_date<p.ends_on) or
      exists(
        with expected as (
          select e.id,row_number()over(order by e.business_date,e.created_at,e.id)::integer as line_number,e.amount_delta
          from public.settlement_entries e
          where e.organization_id=p.organization_id and e.counterparty_id=p.counterparty_id and e.currency_code=p.currency_code and e.business_date>=p.starts_on and e.business_date<p.ends_on
        ), actual as (
          select l.id,l.settlement_entry_id,l.line_number,l.amount_delta
          from public.settlement_act_lines l where l.settlement_act_id=a.id
        )
        select 1 from expected full join actual on actual.settlement_entry_id=expected.id
        where expected.id is null or actual.id is null or actual.line_number<>expected.line_number or actual.amount_delta<>expected.amount_delta
      )
    )
  )
$$;

create or replace function public.v2_finalize_cutover_reconciliation(run_id uuid,owner_membership_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.cutover_reconciliation_runs%rowtype;
  bad bigint;
  base jsonb;
begin
  select * into r from public.cutover_reconciliation_runs x where x.id=$1 for update;
  if not found then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_NOT_FOUND'; end if;
  perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);
  if r.status in('ready','blocked','stale','frozen') then
    return jsonb_build_object(
      'run_id',r.id,'status',r.status,
      'failed_blockers',(select count(*) from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker' and not x.passed),
      'replayed',true
    );
  end if;
  if r.status<>'reviewing' or r.opening_materialized_at is null then
    raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_MATERIALIZATION_REQUIRED';
  end if;
  if r.source_fingerprint is distinct from public.v2_cutover_source_fingerprint(r.organization_id) then
    perform set_config('market_pos.cutover_command','on',true);
    update public.cutover_reconciliation_runs
      set status='stale',finalized_at=clock_timestamp(),summary=summary||jsonb_build_object('final_error','V2_CUTOVER_SOURCE_CHANGED')
      where id=r.id;
    perform set_config('market_pos.cutover_command','off',true);
    return jsonb_build_object('run_id',r.id,'status','stale','error_code','V2_CUTOVER_SOURCE_CHANGED');
  end if;

  perform set_config('market_pos.cutover_command','on',true);
  perform public.v2_cutover_add_check(r.id,'BACKFILL_ELIGIBLE',exists(select 1 from public.migration_backfill_runs b where b.id=r.backfill_run_id and b.organization_id=r.organization_id and b.mode='apply'and b.status in('prepared','blocked')and not exists(select 1 from public.migration_backfill_findings f where f.run_id=b.id and f.severity='blocker'and f.error_code not in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED'))));
  perform public.v2_cutover_add_check(r.id,'BACKFILL_MAPPING_COVERAGE',not exists(
    select 1 from public.products p where p.organization_id=r.organization_id and p.status::text='active'and not exists(select 1 from public.products_v2 v where v.organization_id=r.organization_id and v.legacy_product_id=p.id)
    union all select 1 from public.stores s where s.organization_id=r.organization_id and s.status::text='active'and not exists(select 1 from public.branches b where b.organization_id=r.organization_id and b.legacy_store_id=s.id)
    union all select 1 from public.customers c join public.stores s on s.id=c.store_id where s.organization_id=r.organization_id and c.status::text='active'and not exists(select 1 from public.counterparties x where x.organization_id=r.organization_id and x.legacy_customer_id=c.id)
    union all select 1 from public.suppliers s where s.organization_id=r.organization_id and s.status::text='active'and not exists(select 1 from public.counterparties x where x.organization_id=r.organization_id and x.legacy_supplier_id=s.id)));
  perform public.v2_cutover_add_check(r.id,'MIGRATION_EXCEPTIONS_CLASSIFIED',not exists(select 1 from public.migration_exceptions e where e.organization_id=r.organization_id and e.migration_name='0019_v2_backfill'and e.status='open'));
  perform public.v2_cutover_add_check(r.id,'LEGACY_STOCK_NONNEGATIVE',not exists(select 1 from public.products p where p.organization_id=r.organization_id and p.current_quantity<0));
  perform public.v2_cutover_add_check(r.id,'OPENING_STOCK_COVERAGE',not exists(select 1 from public.products p where p.organization_id=r.organization_id and p.current_quantity<>(select coalesce(sum(x.quantity),0)from public.cutover_opening_stock_lines x where x.run_id=r.id and x.legacy_product_id=p.id and x.status='materialized')));
  perform public.v2_cutover_add_check(r.id,'INVENTORY_AGGREGATE_MATCH',not exists(select 1 from public.products p join public.products_v2 v on v.legacy_product_id=p.id and v.organization_id=r.organization_id where p.organization_id=r.organization_id and p.current_quantity<>(select coalesce(sum(b.on_hand_quantity),0)from public.inventory_balances b where b.organization_id=r.organization_id and b.product_id=v.id and b.batch_id is null)));
  perform public.v2_cutover_add_check(r.id,'INVENTORY_BATCH_MATCH',not exists(select 1 from public.inventory_balances a where a.organization_id=r.organization_id and a.batch_id is null and a.on_hand_quantity<>(select coalesce(sum(b.on_hand_quantity),0)from public.inventory_balances b where b.organization_id=a.organization_id and b.warehouse_id=a.warehouse_id and b.product_id=a.product_id and b.batch_id is not null)));
  perform public.v2_cutover_add_check(r.id,'OPENING_DEBT_COVERAGE',not exists(
    select 1
    from public.customers c join public.stores s on s.id=c.store_id
    where s.organization_id=r.organization_id and (
      c.current_debt is distinct from (
        select coalesce(sum(x.original_amount),0)
        from public.receivables x join public.cutover_opening_debts d on d.id=x.opening_debt_id
        where d.run_id=r.id and d.legacy_customer_id=c.id
      ) or c.current_debt is distinct from (
        select coalesce(sum(x.outstanding_amount),0)
        from public.receivables x join public.cutover_opening_debts d on d.id=x.opening_debt_id
        where d.run_id=r.id and d.legacy_customer_id=c.id
      )
    )
  ));
  perform public.v2_cutover_add_check(r.id,'RECEIVABLE_RECONCILIATION',not exists(select 1 from public.receivables x where x.organization_id=r.organization_id and x.outstanding_amount<>x.original_amount-coalesce((select sum(a.amount)from public.debt_allocations a where a.receivable_id=x.id),0)));
  perform public.v2_cutover_add_check(r.id,'SETTLEMENT_RECONCILIATION',not exists(
    select 1
    from public.cutover_opening_debts d
    left join public.receivables x on x.id=d.receivable_id and x.opening_debt_id=d.id
    left join public.settlement_entries e on e.id=d.settlement_entry_id
    where d.run_id=r.id and d.status='materialized' and (
      x.id is null or e.id is null or
      e.organization_id<>d.organization_id or e.branch_id<>d.branch_id or
      e.counterparty_id<>d.counterparty_id or e.currency_code<>d.currency_code or
      e.source_document_type<>'opening_debt' or e.source_document_id<>d.id or
      e.entry_type<>'opening_debt' or e.amount_delta<>d.amount or
      e.amount_delta-coalesce((select sum(a.amount)from public.debt_allocations a where a.receivable_id=x.id),0)<>x.outstanding_amount
    )
  ));
  perform public.v2_cutover_add_check(r.id,'PRICE_READINESS',not exists(select 1 from public.products_v2 p where p.organization_id=r.organization_id and p.status='active'and 1<>(select count(*)from public.product_prices pp join public.price_lists pl on pl.id=pp.price_list_id where pp.organization_id=r.organization_id and pp.product_id=p.id and pl.status='active'and pl.is_default and pl.currency_code=pp.currency_code and pp.valid_from<=clock_timestamp()and(pp.valid_to is null or pp.valid_to>clock_timestamp()))));
  perform public.v2_cutover_add_check(r.id,'LOCATION_READINESS',not exists(select 1 from public.branches b where b.organization_id=r.organization_id and b.status='active'and 1<>(select count(*)from public.warehouses w where w.organization_id=r.organization_id and w.branch_id=b.id and w.status='active'and w.is_primary))and not exists(select 1 from public.registers x where x.organization_id=r.organization_id and x.status='active'and not exists(select 1 from public.warehouses w where w.id=x.default_warehouse_id and w.organization_id=x.organization_id and w.branch_id=x.branch_id and w.status='active')));
  perform public.v2_cutover_add_check(r.id,'DEVICE_READINESS',not exists(select 1 from public.registers x where x.organization_id=r.organization_id and x.status='active'and not exists(select 1 from public.devices_v2 d where d.organization_id=x.organization_id and d.branch_id=x.branch_id and d.register_id=x.id and d.status='trusted')));
  perform public.v2_cutover_add_check(r.id,'LEGACY_SHIFT_DRAINED',not exists(select 1 from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text='open'));
  perform public.v2_cutover_add_check(r.id,'LEGACY_SYNC_DRAINED',not exists(select 1 from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text in('pending','syncing','error','conflict')));
  perform public.v2_cutover_add_check(r.id,'V2_SHIFT_DRAINED',not exists(select 1 from public.shifts_v2 x where x.organization_id=r.organization_id and x.status in('open','closing')));
  perform public.v2_cutover_add_check(r.id,'V2_SYNC_DRAINED',not exists(select 1 from public.sync_commands x where x.organization_id=r.organization_id and x.status in('received','processing')));
  perform public.v2_cutover_add_check(r.id,'COMMAND_QUEUE_DRAINED',not exists(select 1 from public.command_log x where x.organization_id=r.organization_id and x.status='processing'));
  perform public.v2_cutover_add_check(r.id,'INVENTORY_LEDGER_PROJECTION',not exists(select 1 from public.inventory_balances b where b.organization_id=r.organization_id and b.on_hand_quantity<>(select coalesce(sum(m.quantity_delta),0)from public.inventory_movements m where m.organization_id=b.organization_id and m.warehouse_id=b.warehouse_id and m.product_id=b.product_id and(b.batch_id is null or m.batch_id=b.batch_id))));
  perform public.v2_cutover_add_check(r.id,'SHIFT_LEDGER_RECONCILIATION',not exists(select 1 from public.shift_totals t join public.shifts_v2 s on s.id=t.shift_id where t.organization_id=r.organization_id and t.expected_amount<>(select coalesce(sum(p.amount),0)from public.payments_v2 p where p.organization_id=r.organization_id and p.shift_id=s.id and p.method=t.payment_method and p.status='confirmed')));
  perform public.v2_cutover_add_check(r.id,'SETTLEMENT_ACT_RECONCILIATION',public.v2_cutover_settlement_acts_reconciled(r.organization_id));
  perform public.v2_cutover_add_check(r.id,'AUDIT_OUTBOX_COVERAGE',not exists(select 1 from public.command_log c where c.organization_id=r.organization_id and c.status='succeeded'and c.command_type like'cutover.%'and(not exists(select 1 from public.audit_events a where a.command_log_id=c.id)or not exists(select 1 from public.outbox_events o where o.correlation_id=c.id))));
  perform public.v2_cutover_add_check(r.id,'CROSS_TENANT_INTEGRITY',not exists(select 1 from public.cutover_opening_stock_lines x join public.branches b on b.id=x.branch_id join public.warehouses w on w.id=x.warehouse_id join public.products_v2 p on p.id=x.product_id where x.run_id=r.id and(b.organization_id<>x.organization_id or w.organization_id<>x.organization_id or w.branch_id<>x.branch_id or p.organization_id<>x.organization_id))and not exists(select 1 from public.cutover_opening_debts x join public.branches b on b.id=x.branch_id join public.counterparties c on c.id=x.counterparty_id where x.run_id=r.id and(b.organization_id<>x.organization_id or c.organization_id<>x.organization_id)));
  base:=r.summary->'baseline';
  perform public.v2_cutover_add_check(r.id,'NO_FAKE_LEGACY_HISTORY',
    coalesce((base->>'purchases')::bigint,0)=(select count(*)from public.purchase_documents where organization_id=r.organization_id)and
    coalesce((base->>'sales')::bigint,0)=(select count(*)from public.sales_v2 where organization_id=r.organization_id)and
    coalesce((base->>'payments')::bigint,0)=(select count(*)from public.payments_v2 where organization_id=r.organization_id)and
    coalesce((base->>'shifts')::bigint,0)=(select count(*)from public.shifts_v2 where organization_id=r.organization_id)and
    coalesce((base->>'sync_commands')::bigint,0)=(select count(*)from public.sync_commands where organization_id=r.organization_id));
  select count(*) into bad from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker'and not x.passed;
  update public.cutover_reconciliation_runs
    set status=case when bad=0 then'ready'else'blocked'end,
        finalized_at=clock_timestamp(),
        summary=summary||jsonb_build_object('reconciliation_check_count',(select count(*)from public.cutover_reconciliation_checks where cutover_reconciliation_checks.run_id=r.id),'failed_blockers',bad)
    where id=r.id;
  if bad=0 then
    update public.cutover_controls set state='ready',ready_at=clock_timestamp(),accepted_by=owner_membership_id,updated_at=clock_timestamp()
    where organization_id=r.organization_id and reconciliation_run_id=r.id;
  end if;
  perform set_config('market_pos.cutover_command','off',true);
  return jsonb_build_object('run_id',r.id,'status',case when bad=0 then'ready'else'blocked'end,'failed_blockers',bad,'replayed',false);
exception when others then
  perform set_config('market_pos.cutover_command','off',true);
  raise;
end
$$;

create or replace function public.v2_freeze_legacy_for_cutover(run_id uuid,owner_membership_id uuid,confirmation text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.cutover_reconciliation_runs%rowtype;
  c public.command_log%rowtype;
  p jsonb;
  fp jsonb;
begin
  if confirmation<>'FREEZE_LEGACY_WRITES' then
    raise exception using errcode='P0001',message='V2_CUTOVER_FREEZE_CONFIRMATION_REQUIRED';
  end if;
  select * into r from public.cutover_reconciliation_runs x where x.id=run_id for update;
  if not found or r.status<>'ready' or not exists(
    select 1 from public.cutover_controls x
    where x.organization_id=r.organization_id and x.reconciliation_run_id=r.id and x.state='ready'
  ) then
    raise exception using errcode='P0001',message='V2_CUTOVER_NOT_READY';
  end if;
  perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);

  -- From this point through transaction end, every V1 writer conflicts with
  -- the relation locks, so the final fingerprint and drain checks are atomic
  -- with the legacy_frozen state transition.
  perform public.v2_lock_legacy_cutover_sources();
  fp:=public.v2_cutover_source_fingerprint(r.organization_id);
  if fp is distinct from r.source_fingerprint then
    raise exception using errcode='P0001',message='V2_CUTOVER_SOURCE_CHANGED';
  end if;
  if exists(select 1 from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text='open')or
     exists(select 1 from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text in('pending','syncing','error','conflict'))or
     exists(select 1 from public.shifts_v2 x where x.organization_id=r.organization_id and x.status in('open','closing'))or
     exists(select 1 from public.sync_commands x where x.organization_id=r.organization_id and x.status in('received','processing'))or
     exists(select 1 from public.command_log x where x.organization_id=r.organization_id and x.status='processing')or
     exists(select 1 from public.migration_exceptions x where x.organization_id=r.organization_id and x.status='open')or
     exists(select 1 from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker'and not x.passed) then
    raise exception using errcode='P0001',message='V2_CUTOVER_FREEZE_PRECONDITION_FAILED';
  end if;

  p:=jsonb_build_object('run_id',r.id,'organization_id',r.organization_id,'confirmation',confirmation);
  c:=public.v2_cutover_command(r.organization_id,null,owner_membership_id,r.id,'cutover.legacy.freeze',p);
  if c.status='succeeded' then return jsonb_build_object('run_id',r.id,'status','frozen','replayed',true); end if;
  perform set_config('market_pos.cutover_command','on',true);
  update public.cutover_controls
    set state='legacy_frozen',source_fingerprint=fp,frozen_at=clock_timestamp(),updated_at=clock_timestamp()
    where organization_id=r.organization_id and reconciliation_run_id=r.id;
  update public.cutover_reconciliation_runs set status='frozen',frozen_at=clock_timestamp() where id=r.id;
  perform public.v2_emit_domain_event(r.organization_id,null,null,owner_membership_id,c.id,null,'cutover_reconciliation_run',r.id,'cutover.legacy_writes_frozen','LegacyWritesFrozenForCutover',jsonb_build_object('run_id',r.id,'organization_id',r.organization_id));
  perform public.v2_complete_inventory_command(c.id,'cutover_reconciliation_run',r.id,jsonb_build_object('id',r.id,'status','frozen'));
  perform set_config('market_pos.cutover_command','off',true);
  return jsonb_build_object('run_id',r.id,'status','frozen','replayed',false);
exception when others then
  perform set_config('market_pos.cutover_command','off',true);
  raise;
end
$$;

revoke execute on function public.v2_lock_legacy_cutover_sources()
from public,anon,authenticated,service_role;

revoke execute on function public.v2_cutover_settlement_acts_reconciled(uuid)
from public,anon,authenticated,service_role;

revoke execute on function public.v2_guard_legacy_cutover_freeze()
from public,anon,authenticated,service_role;

comment on function public.v2_lock_legacy_cutover_sources() is
'Internal 0021 static relation lock barrier for the 21 authoritative V1 cutover sources.';
