-- MARKET POS V2: FINAL RECONCILIATION AND CUTOVER PREPARATION
-- V1 history remains evidence. 0020 materializes only explicitly reviewed
-- opening state and never changes application writer routing.

create table public.cutover_reconciliation_runs(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 backfill_run_id uuid not null references public.migration_backfill_runs(id) on delete restrict,
 owner_membership_id uuid not null references public.organization_memberships(id) on delete restrict,
 source_fingerprint jsonb not null check(jsonb_typeof(source_fingerprint)='object'),
 cutoff_at timestamptz not null,business_date date not null,
 status text not null default'reviewing'check(status in('reviewing','ready','blocked','stale','frozen')),
 opening_materialized_at timestamptz,finalized_at timestamptz,frozen_at timestamptz,
 summary jsonb not null default'{}'check(jsonb_typeof(summary)='object'),
 created_at timestamptz not null default now(),
 constraint cutover_run_lifecycle_check check(
  (status='reviewing'and finalized_at is null and frozen_at is null)or
  (status in('ready','blocked','stale')and finalized_at is not null and frozen_at is null)or
  (status='frozen'and finalized_at is not null and frozen_at is not null)
 ),unique(backfill_run_id)
);
create index cutover_runs_org_created_idx on public.cutover_reconciliation_runs(organization_id,created_at desc,id);

create table public.cutover_reconciliation_checks(
 id uuid primary key default gen_random_uuid(),run_id uuid not null references public.cutover_reconciliation_runs(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 check_code text not null check(btrim(check_code)<>''),severity text not null check(severity in('info','warning','blocker')),
 passed boolean not null,details jsonb not null default'{}'check(jsonb_typeof(details)='object'),
 created_at timestamptz not null default now(),unique(run_id,check_code)
);
create index cutover_checks_run_result_idx on public.cutover_reconciliation_checks(run_id,severity,passed,check_code);

create table public.cutover_opening_stock_lines(
 id uuid primary key default gen_random_uuid(),run_id uuid not null references public.cutover_reconciliation_runs(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 source_kind text not null check(source_kind in('legacy_batch','manual')),
 legacy_product_id uuid not null references public.products(id) on delete restrict,
 legacy_batch_id uuid references public.product_batches(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 product_id uuid not null references public.products_v2(id) on delete restrict,
 unit_id uuid not null references public.units_v2(id) on delete restrict,
 quantity numeric(18,6) not null check(quantity>0),unit_cost numeric(18,4) not null check(unit_cost>=0),
 currency_code char(3) not null check(currency_code::text~'^[A-Z]{3}$'),received_date date not null,
 expiration_date date,review_note text,status text not null default'proposed'check(status in('proposed','accepted','rejected','materialized')),
 reviewed_by uuid references public.organization_memberships(id) on delete restrict,reviewed_at timestamptz,
 materialized_document_id uuid references public.inventory_documents(id) on delete restrict,
 product_batch_id uuid,operation_id uuid not null default gen_random_uuid(),created_at timestamptz not null default now(),
 constraint cutover_stock_source_check check((source_kind='legacy_batch'and legacy_batch_id is not null)or(source_kind='manual'and legacy_batch_id is null)),
 constraint cutover_stock_review_check check((status='proposed'and reviewed_by is null and reviewed_at is null)or(status in('accepted','rejected','materialized')and reviewed_by is not null and reviewed_at is not null)),
 constraint cutover_stock_materialized_check check((status='materialized'and materialized_document_id is not null and product_batch_id is not null)or(status<>'materialized'and materialized_document_id is null and product_batch_id is null)),
 unique(run_id,legacy_batch_id),unique(operation_id)
);
create index cutover_stock_run_status_idx on public.cutover_opening_stock_lines(run_id,status,legacy_product_id,id);

create table public.cutover_opening_debts(
 id uuid primary key default gen_random_uuid(),run_id uuid not null references public.cutover_reconciliation_runs(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 legacy_customer_id uuid not null references public.customers(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 amount numeric(18,4) not null check(amount>0),currency_code char(3) not null check(currency_code::text~'^[A-Z]{3}$'),
 as_of_date date not null,due_date date,review_note text,
 status text not null default'proposed'check(status in('proposed','accepted','rejected','materialized')),
 reviewed_by uuid references public.organization_memberships(id) on delete restrict,reviewed_at timestamptz,
 receivable_id uuid,settlement_entry_id uuid,operation_id uuid not null default gen_random_uuid(),created_at timestamptz not null default now(),
 constraint cutover_debt_review_check check((status='proposed'and reviewed_by is null and reviewed_at is null)or(status in('accepted','rejected','materialized')and reviewed_by is not null and reviewed_at is not null)),
 constraint cutover_debt_materialized_check check((status='materialized'and receivable_id is not null and settlement_entry_id is not null)or(status<>'materialized'and receivable_id is null and settlement_entry_id is null)),
 unique(run_id,legacy_customer_id),unique(operation_id)
);
create index cutover_debts_run_status_idx on public.cutover_opening_debts(run_id,status,legacy_customer_id);

create table public.cutover_controls(
 organization_id uuid primary key references public.organizations(id) on delete restrict,
 reconciliation_run_id uuid not null unique references public.cutover_reconciliation_runs(id) on delete restrict,
 state text not null constraint cutover_controls_state_value_check check(state in('reviewing','ready','legacy_frozen')),
 source_fingerprint jsonb not null check(jsonb_typeof(source_fingerprint)='object'),
 ready_at timestamptz,frozen_at timestamptz,accepted_by uuid references public.organization_memberships(id) on delete restrict,
 updated_at timestamptz not null default now(),
 constraint cutover_controls_state_check check(
  (state='reviewing'and ready_at is null and frozen_at is null and accepted_by is null)or
  (state='ready'and ready_at is not null and frozen_at is null and accepted_by is not null)or
  (state='legacy_frozen'and ready_at is not null and frozen_at is not null and accepted_by is not null)
 )
);

alter table public.product_batches_v2 alter column purchase_line_id drop not null;
alter table public.product_batches_v2 add column opening_stock_line_id uuid references public.cutover_opening_stock_lines(id) on delete restrict;
alter table public.product_batches_v2 add constraint product_batches_v2_exact_source_check check(
 (purchase_line_id is not null)::integer+(opening_stock_line_id is not null)::integer=1
);
create unique index product_batches_v2_opening_source_key on public.product_batches_v2(opening_stock_line_id)where opening_stock_line_id is not null;
alter table public.cutover_opening_stock_lines add constraint cutover_stock_batch_fk foreign key(product_batch_id)references public.product_batches_v2(id)on delete restrict;

alter table public.receivables alter column sale_id drop not null;
alter table public.receivables add column opening_debt_id uuid references public.cutover_opening_debts(id)on delete restrict;
alter table public.receivables add constraint receivables_exact_source_check check(
 (sale_id is not null)::integer+(opening_debt_id is not null)::integer=1
);
create unique index receivables_opening_debt_key on public.receivables(opening_debt_id)where opening_debt_id is not null;
alter table public.cutover_opening_debts add constraint cutover_debt_receivable_fk foreign key(receivable_id)references public.receivables(id)on delete restrict;
alter table public.cutover_opening_debts add constraint cutover_debt_settlement_fk foreign key(settlement_entry_id)references public.settlement_entries(id)on delete restrict;

alter table public.settlement_entries drop constraint settlement_entries_type_check;
alter table public.settlement_entries add constraint settlement_entries_type_check check(entry_type in(
 'sale_debt','customer_payment','sale_return','purchase','supplier_payment','goods_taken','write_off','offset','opening_debt'
));
alter table public.settlement_entries drop constraint settlement_entries_source_check;
alter table public.settlement_entries add constraint settlement_entries_source_check check(source_document_type in(
 'sale','sale_return','debt_payment','purchase','debt_allocation','supplier_payment','cash_movement','goods_taken','offset','opening_debt'
));

alter table public.cutover_reconciliation_runs enable row level security;
alter table public.cutover_reconciliation_checks enable row level security;
alter table public.cutover_opening_stock_lines enable row level security;
alter table public.cutover_opening_debts enable row level security;
alter table public.cutover_controls enable row level security;
revoke all on public.cutover_reconciliation_runs,public.cutover_reconciliation_checks,
 public.cutover_opening_stock_lines,public.cutover_opening_debts,public.cutover_controls
 from public,anon,authenticated,service_role;

create or replace function public.v2_cutover_require_owner(o uuid,m uuid)
returns void language plpgsql stable security definer set search_path=''as $$
begin
 if not exists(select 1 from public.organization_memberships om join public.user_profiles p on p.id=om.user_profile_id
  where om.id=m and om.organization_id=o and om.system_role='owner'and om.status='active'and p.status='active')then
  raise exception using errcode='P0001',message='V2_CUTOVER_ACTIVE_OWNER_REQUIRED';
 end if;
end$$;

create or replace function public.v2_cutover_add_check(rid uuid,code text,ok boolean,details jsonb default'{}')
returns void language plpgsql security definer set search_path=''as $$
begin
 insert into public.cutover_reconciliation_checks(run_id,organization_id,check_code,severity,passed,details)
 select r.id,r.organization_id,code,'blocker',ok,coalesce(details,'{}')from public.cutover_reconciliation_runs r where r.id=rid
 on conflict(run_id,check_code)do nothing;
end$$;

create or replace function public.v2_finalize_cutover_reconciliation(run_id uuid,owner_membership_id uuid)
returns jsonb language plpgsql security definer set search_path=''as $$
declare r public.cutover_reconciliation_runs%rowtype;bad bigint;base jsonb;
begin
 select * into r from public.cutover_reconciliation_runs x where x.id=$1 for update;
 if not found then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_NOT_FOUND';end if;
 perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);
 if r.status in('ready','blocked','stale','frozen')then return jsonb_build_object('run_id',r.id,'status',r.status,'failed_blockers',(select count(*)from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker'and not x.passed),'replayed',true);end if;
 if r.status<>'reviewing'or r.opening_materialized_at is null then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_MATERIALIZATION_REQUIRED';end if;
 if r.source_fingerprint is distinct from public.v2_cutover_source_fingerprint(r.organization_id)then
  perform set_config('market_pos.cutover_command','on',true);update public.cutover_reconciliation_runs set status='stale',finalized_at=clock_timestamp(),summary=summary||jsonb_build_object('final_error','V2_CUTOVER_SOURCE_CHANGED')where id=r.id;perform set_config('market_pos.cutover_command','off',true);
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
 perform public.v2_cutover_add_check(r.id,'OPENING_DEBT_COVERAGE',not exists(select 1 from public.customers c join public.stores s on s.id=c.store_id where s.organization_id=r.organization_id and c.current_debt<>(select coalesce(sum(x.original_amount),0)from public.receivables x join public.cutover_opening_debts d on d.id=x.opening_debt_id where d.run_id=r.id and d.legacy_customer_id=c.id)));
 perform public.v2_cutover_add_check(r.id,'RECEIVABLE_RECONCILIATION',not exists(select 1 from public.receivables x where x.organization_id=r.organization_id and x.outstanding_amount<>x.original_amount-coalesce((select sum(a.amount)from public.debt_allocations a where a.receivable_id=x.id),0)));
 perform public.v2_cutover_add_check(r.id,'SETTLEMENT_RECONCILIATION',not exists(select 1 from public.cutover_opening_debts d where d.run_id=r.id and d.status='materialized'and not exists(select 1 from public.settlement_entries e where e.id=d.settlement_entry_id and e.source_document_type='opening_debt'and e.source_document_id=d.id and e.amount_delta=d.amount)));
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
 perform public.v2_cutover_add_check(r.id,'SETTLEMENT_ACT_RECONCILIATION',not exists(select 1 from public.settlement_act_lines l join public.settlement_acts a on a.id=l.settlement_act_id join public.settlement_periods p on p.id=a.settlement_period_id join public.settlement_entries e on e.id=l.settlement_entry_id where p.organization_id=r.organization_id and(e.organization_id<>p.organization_id or e.counterparty_id<>p.counterparty_id or e.currency_code<>p.currency_code or e.business_date<p.starts_on or e.business_date>=p.ends_on or e.amount_delta<>l.amount_delta)));
 perform public.v2_cutover_add_check(r.id,'AUDIT_OUTBOX_COVERAGE',not exists(select 1 from public.command_log c where c.organization_id=r.organization_id and c.status='succeeded'and c.command_type like'cutover.%'and(not exists(select 1 from public.audit_events a where a.command_log_id=c.id)or not exists(select 1 from public.outbox_events o where o.correlation_id=c.id))));
 perform public.v2_cutover_add_check(r.id,'CROSS_TENANT_INTEGRITY',not exists(select 1 from public.cutover_opening_stock_lines x join public.branches b on b.id=x.branch_id join public.warehouses w on w.id=x.warehouse_id join public.products_v2 p on p.id=x.product_id where x.run_id=r.id and(b.organization_id<>x.organization_id or w.organization_id<>x.organization_id or w.branch_id<>x.branch_id or p.organization_id<>x.organization_id))and not exists(select 1 from public.cutover_opening_debts x join public.branches b on b.id=x.branch_id join public.counterparties c on c.id=x.counterparty_id where x.run_id=r.id and(b.organization_id<>x.organization_id or c.organization_id<>x.organization_id)));
 base:=r.summary->'baseline';
 perform public.v2_cutover_add_check(r.id,'NO_FAKE_LEGACY_HISTORY',
  coalesce((base->>'purchases')::bigint,0)=(select count(*)from public.purchase_documents where organization_id=r.organization_id)and
  coalesce((base->>'sales')::bigint,0)=(select count(*)from public.sales_v2 where organization_id=r.organization_id)and
  coalesce((base->>'payments')::bigint,0)=(select count(*)from public.payments_v2 where organization_id=r.organization_id)and
  coalesce((base->>'shifts')::bigint,0)=(select count(*)from public.shifts_v2 where organization_id=r.organization_id)and
  coalesce((base->>'sync_commands')::bigint,0)=(select count(*)from public.sync_commands where organization_id=r.organization_id));
 select count(*)into bad from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker'and not x.passed;
 update public.cutover_reconciliation_runs set status=case when bad=0 then'ready'else'blocked'end,finalized_at=clock_timestamp(),summary=summary||jsonb_build_object('reconciliation_check_count',(select count(*)from public.cutover_reconciliation_checks where cutover_reconciliation_checks.run_id=r.id),'failed_blockers',bad)where id=r.id;
 if bad=0 then update public.cutover_controls set state='ready',ready_at=clock_timestamp(),accepted_by=owner_membership_id,updated_at=clock_timestamp()where organization_id=r.organization_id and reconciliation_run_id=r.id;end if;
 perform set_config('market_pos.cutover_command','off',true);
 return jsonb_build_object('run_id',r.id,'status',case when bad=0 then'ready'else'blocked'end,'failed_blockers',bad,'replayed',false);
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_guard_legacy_cutover_freeze()
returns trigger language plpgsql set search_path=''as $$
declare j jsonb:=case when tg_op='DELETE'then to_jsonb(old)else to_jsonb(new)end;o uuid;
begin
 case tg_table_name
  when'users'then o:=(j->>'organization_id')::uuid;
  when'user_store_access'then select organization_id into o from public.users where id=(j->>'user_id')::uuid;
  when'stores'then o:=(j->>'organization_id')::uuid;
  when'categories'then o:=(j->>'organization_id')::uuid;
  when'brands'then o:=(j->>'organization_id')::uuid;
  when'units'then o:=(j->>'organization_id')::uuid;
  when'product_types'then o:=(j->>'organization_id')::uuid;
  when'products'then o:=(j->>'organization_id')::uuid;
  when'suppliers'then o:=(j->>'organization_id')::uuid;
  when'customers'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'devices'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'product_batches'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'stock_movements'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'sales'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'sale_items'then select s.organization_id into o from public.sales x join public.stores s on s.id=x.store_id where x.id=(j->>'sale_id')::uuid;
  when'payments'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'shifts'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'debt_payments'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'debt_entries'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'sync_operations'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  when'operation_logs'then select organization_id into o from public.stores where id=(j->>'store_id')::uuid;
  else raise exception using errcode='P0001',message='V2_CUTOVER_LEGACY_TABLE_UNSUPPORTED';end case;
 if o is not null and exists(select 1 from public.cutover_controls c where c.organization_id=o and c.state='legacy_frozen')then raise exception using errcode='P0001',message='V2_LEGACY_WRITES_FROZEN';end if;
 return case when tg_op='DELETE'then old else new end;
end$$;

create trigger v2_cutover_freeze_users before insert or update or delete on public.users for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_user_store_access before insert or update or delete on public.user_store_access for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_stores before insert or update or delete on public.stores for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_categories before insert or update or delete on public.categories for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_brands before insert or update or delete on public.brands for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_units before insert or update or delete on public.units for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_product_types before insert or update or delete on public.product_types for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_products before insert or update or delete on public.products for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_suppliers before insert or update or delete on public.suppliers for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_customers before insert or update or delete on public.customers for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_devices before insert or update or delete on public.devices for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_product_batches before insert or update or delete on public.product_batches for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_stock_movements before insert or update or delete on public.stock_movements for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_sales before insert or update or delete on public.sales for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_sale_items before insert or update or delete on public.sale_items for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_payments before insert or update or delete on public.payments for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_shifts before insert or update or delete on public.shifts for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_debt_payments before insert or update or delete on public.debt_payments for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_debt_entries before insert or update or delete on public.debt_entries for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_sync_operations before insert or update or delete on public.sync_operations for each row execute function public.v2_guard_legacy_cutover_freeze();
create trigger v2_cutover_freeze_operation_logs before insert or update or delete on public.operation_logs for each row execute function public.v2_guard_legacy_cutover_freeze();

create or replace function public.v2_freeze_legacy_for_cutover(run_id uuid,owner_membership_id uuid,confirmation text)
returns jsonb language plpgsql security definer set search_path=''as $$
declare r public.cutover_reconciliation_runs%rowtype;c public.command_log%rowtype;p jsonb;fp jsonb;
begin
 if confirmation<>'FREEZE_LEGACY_WRITES'then raise exception using errcode='P0001',message='V2_CUTOVER_FREEZE_CONFIRMATION_REQUIRED';end if;
 select * into r from public.cutover_reconciliation_runs x where x.id=run_id for update;
 if not found or r.status<>'ready'or not exists(select 1 from public.cutover_controls x where x.organization_id=r.organization_id and x.reconciliation_run_id=r.id and x.state='ready')then raise exception using errcode='P0001',message='V2_CUTOVER_NOT_READY';end if;
 perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);fp:=public.v2_cutover_source_fingerprint(r.organization_id);
 if fp is distinct from r.source_fingerprint then raise exception using errcode='P0001',message='V2_CUTOVER_SOURCE_CHANGED';end if;
 if exists(select 1 from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text='open')or
   exists(select 1 from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=r.organization_id and x.status::text in('pending','syncing','error','conflict'))or
   exists(select 1 from public.shifts_v2 x where x.organization_id=r.organization_id and x.status in('open','closing'))or
   exists(select 1 from public.sync_commands x where x.organization_id=r.organization_id and x.status in('received','processing'))or
   exists(select 1 from public.command_log x where x.organization_id=r.organization_id and x.status='processing')or
   exists(select 1 from public.migration_exceptions x where x.organization_id=r.organization_id and x.status='open')or
   exists(select 1 from public.cutover_reconciliation_checks x where x.run_id=r.id and x.severity='blocker'and not x.passed)then raise exception using errcode='P0001',message='V2_CUTOVER_FREEZE_PRECONDITION_FAILED';end if;
 p:=jsonb_build_object('run_id',r.id,'organization_id',r.organization_id,'confirmation',confirmation);
 c:=public.v2_cutover_command(r.organization_id,null,owner_membership_id,r.id,'cutover.legacy.freeze',p);
 if c.status='succeeded'then return jsonb_build_object('run_id',r.id,'status','frozen','replayed',true);end if;
 perform set_config('market_pos.cutover_command','on',true);
 update public.cutover_controls set state='legacy_frozen',source_fingerprint=fp,frozen_at=clock_timestamp(),updated_at=clock_timestamp()where organization_id=r.organization_id and reconciliation_run_id=r.id;
 update public.cutover_reconciliation_runs set status='frozen',frozen_at=clock_timestamp()where id=r.id;
 perform public.v2_emit_domain_event(r.organization_id,null,null,owner_membership_id,c.id,null,'cutover_reconciliation_run',r.id,'cutover.legacy_writes_frozen','LegacyWritesFrozenForCutover',jsonb_build_object('run_id',r.id,'organization_id',r.organization_id));
 perform public.v2_complete_inventory_command(c.id,'cutover_reconciliation_run',r.id,jsonb_build_object('id',r.id,'status','frozen'));
 perform set_config('market_pos.cutover_command','off',true);
 return jsonb_build_object('run_id',r.id,'status','frozen','replayed',false);
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_cutover_command(o uuid,b uuid,a uuid,op uuid,ct text,p jsonb)
returns public.command_log language plpgsql security definer set search_path=''as $$
declare c public.command_log%rowtype;h text:=encode(extensions.digest(p::text,'sha256'),'hex');
begin
 select * into c from public.command_log x where x.organization_id=o and x.device_id is null and x.local_operation_id=op for update;
 if found then
  if c.command_type<>ct then raise exception using errcode='P0001',message='V2_IDEMPOTENCY_COMMAND_TYPE_MISMATCH';end if;
  if c.payload_hash<>h then raise exception using errcode='P0001',message='V2_IDEMPOTENCY_PAYLOAD_MISMATCH';end if;
  perform set_config('market_pos.current_command_id',c.id::text,true);return c;
 end if;
 insert into public.command_log(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,local_operation_id,command_type,payload_hash)
 values(o,b,null,null,a,op,ct,h)returning * into c;
 perform set_config('market_pos.current_command_id',c.id::text,true);return c;
end$$;

create or replace function public.v2_materialize_cutover_opening_state(run_id uuid,owner_membership_id uuid)
returns jsonb language plpgsql security definer set search_path=''as $$
declare r public.cutover_reconciliation_runs%rowtype;l public.cutover_opening_stock_lines%rowtype;d public.cutover_opening_debts%rowtype;
 c public.command_log%rowtype;doc uuid;dl uuid;batch uuid;rec uuid;entry uuid;p jsonb;stock_count integer:=0;debt_count integer:=0;
begin
 select * into r from public.cutover_reconciliation_runs x where x.id=run_id for update;
 if not found then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_NOT_FOUND';end if;
 perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);
 if r.opening_materialized_at is not null then return jsonb_build_object('run_id',r.id,'stock_lines',(select count(*)from public.cutover_opening_stock_lines x where x.run_id=r.id and x.status='materialized'),'opening_debts',(select count(*)from public.cutover_opening_debts x where x.run_id=r.id and x.status='materialized'),'replayed',true);end if;
 if r.status<>'reviewing'then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_NOT_REVIEWING';end if;
 perform public.v2_cutover_assert_current(r);
 if exists(select 1 from public.purchase_documents x where x.organization_id=r.organization_id)or
   exists(select 1 from public.inventory_documents x where x.organization_id=r.organization_id)or
   exists(select 1 from public.inventory_movements x where x.organization_id=r.organization_id)or
   exists(select 1 from public.warehouse_transfers x where x.organization_id=r.organization_id)or
   exists(select 1 from public.sales_v2 x where x.organization_id=r.organization_id)or
   exists(select 1 from public.sale_returns x where x.organization_id=r.organization_id)or
   exists(select 1 from public.payments_v2 x where x.organization_id=r.organization_id)or
   exists(select 1 from public.receivables x where x.organization_id=r.organization_id)or
   exists(select 1 from public.debt_allocations x where x.organization_id=r.organization_id)or
   exists(select 1 from public.settlement_entries x where x.organization_id=r.organization_id)or
   exists(select 1 from public.shifts_v2 x where x.organization_id=r.organization_id)or
   exists(select 1 from public.cash_movements x where x.organization_id=r.organization_id)or
   exists(select 1 from public.supplier_payments x where x.organization_id=r.organization_id)then
  raise exception using errcode='P0001',message='V2_CUTOVER_PREEXISTING_V2_ACTIVITY';end if;
 if exists(select 1 from public.products lp where lp.organization_id=r.organization_id and(lp.current_quantity<0 or lp.current_quantity<>(select coalesce(sum(x.quantity),0)from public.cutover_opening_stock_lines x where x.run_id=r.id and x.legacy_product_id=lp.id and x.status='accepted')))then
  raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_COVERAGE_REQUIRED';end if;
 if exists(select 1 from public.customers lc join public.stores st on st.id=lc.store_id where st.organization_id=r.organization_id and lc.current_debt<>(select coalesce(sum(x.amount),0)from public.cutover_opening_debts x where x.run_id=r.id and x.legacy_customer_id=lc.id and x.status='accepted'))then
  raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_DEBT_COVERAGE_REQUIRED';end if;
 perform set_config('market_pos.cutover_command','on',true);perform set_config('market_pos.inventory_command','on',true);perform set_config('market_pos.debt_command','on',true);perform set_config('market_pos.settlement_command','on',true);
 for l in select * from public.cutover_opening_stock_lines x where x.run_id=r.id and x.status='accepted'order by x.id for update loop
  p:=jsonb_build_object('run_id',r.id,'opening_stock_line_id',l.id,'quantity',l.quantity,'unit_cost',l.unit_cost,'currency_code',l.currency_code);
  c:=public.v2_cutover_command(r.organization_id,l.branch_id,l.reviewed_by,l.operation_id,'cutover.opening_stock.materialize',p);
  if c.status='succeeded'then continue;end if;
  doc:=gen_random_uuid();batch:=gen_random_uuid();dl:=gen_random_uuid();
  insert into public.inventory_documents(id,organization_id,branch_id,warehouse_id,document_type,document_number,business_date,status,reason_code,local_operation_id,posted_by)
  values(doc,r.organization_id,l.branch_id,l.warehouse_id,'opening','CUTOVER-'||upper(replace(l.id::text,'-','')),r.business_date,'draft','cutover_opening_stock',l.operation_id,l.reviewed_by);
  insert into public.product_batches_v2(id,organization_id,warehouse_id,product_id,purchase_line_id,opening_stock_line_id,batch_code,received_date,expiration_date,initial_quantity,purchase_unit_cost,currency_code)
  values(batch,r.organization_id,l.warehouse_id,l.product_id,null,l.id,'OPEN-'||upper(right(replace(l.id::text,'-',''),16)),l.received_date,l.expiration_date,l.quantity,l.unit_cost,l.currency_code);
  insert into public.inventory_document_lines(id,organization_id,inventory_document_id,line_number,product_id,batch_id,unit_id,quantity,unit_factor,base_quantity_delta,comment)
  values(dl,r.organization_id,doc,1,l.product_id,batch,l.unit_id,l.quantity,1,l.quantity,'Reviewed cutover opening stock');
  perform public.v2_apply_inventory_movement(r.organization_id,l.branch_id,l.warehouse_id,l.product_id,batch,'opening',l.quantity,'inventory_document',doc,dl,'primary',null,c.id,l.reviewed_by);
  update public.inventory_documents set status='posted',posted_at=clock_timestamp()where id=doc;
  perform public.v2_emit_domain_event(r.organization_id,l.branch_id,null,l.reviewed_by,c.id,null,'inventory_document',doc,'inventory.opening_materialized','OpeningStockMaterialized',jsonb_build_object('opening_stock_line_id',l.id,'inventory_document_id',doc,'product_batch_id',batch,'quantity',l.quantity));
  perform public.v2_complete_inventory_command(c.id,'inventory_document',doc,jsonb_build_object('id',doc,'opening_stock_line_id',l.id));
  update public.cutover_opening_stock_lines set status='materialized',materialized_document_id=doc,product_batch_id=batch where id=l.id;stock_count:=stock_count+1;
 end loop;
 for d in select * from public.cutover_opening_debts x where x.run_id=r.id and x.status='accepted'order by x.id for update loop
  perform public.v2_lock_settlement_scope(d.organization_id,d.counterparty_id,d.currency_code);
  p:=jsonb_build_object('run_id',r.id,'opening_debt_id',d.id,'amount',d.amount,'currency_code',d.currency_code,'as_of_date',d.as_of_date,'due_date',d.due_date);
  c:=public.v2_cutover_command(r.organization_id,d.branch_id,d.reviewed_by,d.operation_id,'cutover.opening_debt.materialize',p);
  if c.status='succeeded'then continue;end if;
  rec:=gen_random_uuid();entry:=gen_random_uuid();
  insert into public.receivables(id,organization_id,branch_id,counterparty_id,sale_id,opening_debt_id,original_amount,outstanding_amount,currency_code,due_date,status,created_by,command_id)
  values(rec,d.organization_id,d.branch_id,d.counterparty_id,null,d.id,d.amount,d.amount,d.currency_code,d.due_date,'open',d.reviewed_by,c.id);
  insert into public.settlement_entries(id,organization_id,branch_id,counterparty_id,entry_type,amount_delta,currency_code,business_date,source_document_type,source_document_id,command_id,created_by)
  values(entry,d.organization_id,d.branch_id,d.counterparty_id,'opening_debt',d.amount,d.currency_code,d.as_of_date,'opening_debt',d.id,c.id,d.reviewed_by);
  perform public.v2_emit_domain_event(d.organization_id,d.branch_id,null,d.reviewed_by,c.id,null,'receivable',rec,'receivable.opening_recorded','OpeningDebtRecorded',jsonb_build_object('opening_debt_id',d.id,'receivable_id',rec,'amount',d.amount,'currency_code',d.currency_code));
  perform public.v2_emit_domain_event(d.organization_id,d.branch_id,null,d.reviewed_by,c.id,null,'settlement_entry',entry,'settlement.entry_posted','SettlementEntryPosted',jsonb_build_object('settlement_entry_id',entry,'source_type','opening_debt','amount_delta',d.amount,'currency_code',d.currency_code));
  perform public.v2_complete_inventory_command(c.id,'receivable',rec,jsonb_build_object('id',rec,'opening_debt_id',d.id,'settlement_entry_id',entry));
  update public.cutover_opening_debts set status='materialized',receivable_id=rec,settlement_entry_id=entry where id=d.id;debt_count:=debt_count+1;
 end loop;
 update public.cutover_reconciliation_runs set opening_materialized_at=clock_timestamp(),summary=summary||jsonb_build_object('opening_stock_materialized',stock_count,'opening_debts_materialized',debt_count)where id=r.id;
 update public.migration_exceptions e set status='resolved',resolution='Resolved by exact 0020 opening-state materialization',resolved_at=clock_timestamp()
 where e.organization_id=r.organization_id and e.migration_name='0019_v2_backfill'and e.status='open'and e.error_code in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED')and(
  (e.error_code in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH')and exists(select 1 from public.products lp where lp.id::text=e.legacy_id and lp.current_quantity=(select coalesce(sum(s.quantity),0)from public.cutover_opening_stock_lines s where s.run_id=r.id and s.legacy_product_id=lp.id and s.status='materialized')))
  or(e.error_code='V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED'and exists(select 1 from public.customers lc where lc.id::text=e.legacy_id and lc.current_debt=(select coalesce(sum(od.amount),0)from public.cutover_opening_debts od where od.run_id=r.id and od.legacy_customer_id=lc.id and od.status='materialized'))));
 perform set_config('market_pos.settlement_command','off',true);perform set_config('market_pos.debt_command','off',true);perform set_config('market_pos.inventory_command','off',true);perform set_config('market_pos.cutover_command','off',true);
 return jsonb_build_object('run_id',r.id,'stock_lines',stock_count,'opening_debts',debt_count,'replayed',false);
exception when others then perform set_config('market_pos.settlement_command','off',true);perform set_config('market_pos.debt_command','off',true);perform set_config('market_pos.inventory_command','off',true);perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_review_migration_exception(exception_id uuid,decision text,resolution text,owner_membership_id uuid)
returns uuid language plpgsql security definer set search_path=''as $$
declare e public.migration_exceptions%rowtype;
begin
 select * into e from public.migration_exceptions x where x.id=exception_id for update;
 if not found or e.status<>'open'or decision not in('accepted','resolved')or nullif(btrim(resolution),'')is null then raise exception using errcode='P0001',message='V2_CUTOVER_EXCEPTION_REVIEW_INVALID';end if;
 perform public.v2_cutover_require_owner(e.organization_id,owner_membership_id);
 if e.migration_name='0019_v2_backfill'and e.error_code in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED')then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_MATERIALIZATION_REQUIRED';end if;
 update public.migration_exceptions set status=decision,resolution=$3,resolved_at=clock_timestamp()where id=exception_id;return exception_id;
end$$;

create or replace function public.v2_cutover_source_fingerprint(o uuid)
returns jsonb language sql stable security definer set search_path=''as $$
 select jsonb_build_object(
  'users',jsonb_build_object('count',(select count(*)from public.users x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(jsonb_build_array(x.id,x.auth_user_id,x.organization_id,x.full_name,x.phone,x.email,x.role::text,x.status::text,x.created_at,x.updated_at)order by x.id),'[]')::text)from public.users x where x.organization_id=o)),
  'user_store_access',jsonb_build_object('count',(select count(*)from public.user_store_access x join public.users u on u.id=x.user_id where u.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(jsonb_build_array(x.id,x.user_id,x.store_id,x.role_in_store::text,x.created_at)order by x.id),'[]')::text)from public.user_store_access x join public.users u on u.id=x.user_id where u.organization_id=o)),
  'stores',jsonb_build_object('count',(select count(*)from public.stores x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.stores x where x.organization_id=o)),
  'categories',jsonb_build_object('count',(select count(*)from public.categories x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.categories x where x.organization_id=o)),
  'brands',jsonb_build_object('count',(select count(*)from public.brands x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.brands x where x.organization_id=o)),
  'units',jsonb_build_object('count',(select count(*)from public.units x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.units x where x.organization_id=o)),
  'product_types',jsonb_build_object('count',(select count(*)from public.product_types x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.product_types x where x.organization_id=o)),
  'products',jsonb_build_object('count',(select count(*)from public.products x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.products x where x.organization_id=o)),
  'suppliers',jsonb_build_object('count',(select count(*)from public.suppliers x where x.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.suppliers x where x.organization_id=o)),
  'customers',jsonb_build_object('count',(select count(*)from public.customers x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.customers x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'devices',jsonb_build_object('count',(select count(*)from public.devices x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.devices x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'product_batches',jsonb_build_object('count',(select count(*)from public.product_batches x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.product_batches x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'stock_movements',jsonb_build_object('count',(select count(*)from public.stock_movements x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.stock_movements x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'sales',jsonb_build_object('count',(select count(*)from public.sales x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.sales x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'sale_items',jsonb_build_object('count',(select count(*)from public.sale_items x join public.sales a on a.id=x.sale_id join public.stores s on s.id=a.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.sale_items x join public.sales a on a.id=x.sale_id join public.stores s on s.id=a.store_id where s.organization_id=o)),
  'payments',jsonb_build_object('count',(select count(*)from public.payments x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.payments x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'shifts',jsonb_build_object('count',(select count(*)from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'debt_payments',jsonb_build_object('count',(select count(*)from public.debt_payments x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.debt_payments x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'debt_entries',jsonb_build_object('count',(select count(*)from public.debt_entries x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.debt_entries x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'sync_operations',jsonb_build_object('count',(select count(*)from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=o)),
  'operation_logs',jsonb_build_object('count',(select count(*)from public.operation_logs x join public.stores s on s.id=x.store_id where s.organization_id=o),'hash',(select md5(coalesce(jsonb_agg(to_jsonb(x)order by x.id),'[]')::text)from public.operation_logs x join public.stores s on s.id=x.store_id where s.organization_id=o))
 )
$$;

create or replace function public.v2_cutover_validate_backfill(o uuid,rid uuid)
returns public.migration_backfill_runs language plpgsql stable security definer set search_path=''as $$
declare r public.migration_backfill_runs%rowtype;allowed constant text[]:=array[
 'V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH',
 'V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED'];changed boolean;
begin
 select * into r from public.migration_backfill_runs x where x.id=rid and x.organization_id=o;
 if not found or r.mode<>'apply'or r.status not in('prepared','blocked')or
   (select count(*)from public.migration_backfill_checkpoints c where c.run_id=r.id and c.status='completed')<>10 or
   exists(select 1 from public.migration_backfill_checkpoints c where c.run_id=r.id and c.status<>'completed')or
   (r.status='blocked'and exists(select 1 from public.migration_backfill_findings f
      where f.run_id=r.id and f.severity='blocker'and not(f.error_code=any(allowed))))then
  raise exception using errcode='P0001',message='V2_CUTOVER_BACKFILL_NOT_ELIGIBLE';
 end if;
 if r.summary->'source_fingerprint'is distinct from public.v2_backfill_source_fingerprint(o)then changed:=true;end if;
 select coalesce(changed,false)or exists(
  select 1 from public.users x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.stores x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.categories x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.brands x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.units x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.product_types x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.products x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.suppliers x where x.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.customers x join public.stores s on s.id=x.store_id where s.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.devices x join public.stores s on s.id=x.store_id where s.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.user_store_access x join public.users u on u.id=x.user_id where u.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.product_batches x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.stock_movements x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.sales x join public.stores s on s.id=x.store_id where s.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.payments x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.shifts x join public.stores s on s.id=x.store_id where s.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.debt_payments x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.debt_entries x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
  union all select 1 from public.sync_operations x join public.stores s on s.id=x.store_id where s.organization_id=o and(x.created_at>r.source_snapshot_at or x.updated_at>r.source_snapshot_at)
  union all select 1 from public.operation_logs x join public.stores s on s.id=x.store_id where s.organization_id=o and x.created_at>r.source_snapshot_at
 )into changed;
 if changed then raise exception using errcode='P0001',message='V2_CUTOVER_BACKFILL_SOURCE_CHANGED';end if;
 return r;
end$$;

create or replace function public.v2_cutover_context_required()
returns trigger language plpgsql set search_path=''as $$
begin
 if coalesce(current_setting('market_pos.cutover_command',true),'')<>'on'then
  raise exception using errcode='P0001',message='V2_CUTOVER_SERVICE_CONTEXT_REQUIRED';
 end if;
 return case when tg_op='DELETE'then old else new end;
end$$;

create or replace function public.v2_guard_cutover_evidence()
returns trigger language plpgsql set search_path=''as $$
declare n jsonb:=to_jsonb(new);o jsonb:=to_jsonb(old);
begin
 if tg_op='DELETE'then raise exception using errcode='P0001',message='V2_CUTOVER_HARD_DELETE_FORBIDDEN';end if;
 if tg_table_name='cutover_reconciliation_checks'then
  raise exception using errcode='P0001',message='V2_CUTOVER_CHECK_IMMUTABLE';
 elsif tg_table_name='cutover_reconciliation_runs'then
  if n-array['status','opening_materialized_at','finalized_at','frozen_at','summary']<>o-array['status','opening_materialized_at','finalized_at','frozen_at','summary']or not(
    (old.status='reviewing'and new.status in('reviewing','ready','blocked','stale'))or(old.status='ready'and new.status in('ready','frozen'))or old.status=new.status
  )then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_MUTATION_FORBIDDEN';end if;
 elsif tg_table_name='cutover_opening_stock_lines'then
  if n-array['status','reviewed_by','reviewed_at','review_note','materialized_document_id','product_batch_id']<>
     o-array['status','reviewed_by','reviewed_at','review_note','materialized_document_id','product_batch_id']or not(
    (old.status='proposed'and new.status in('accepted','rejected'))or(old.status='accepted'and new.status='materialized')or old.status=new.status
  )then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_IMMUTABLE';end if;
 elsif tg_table_name='cutover_opening_debts'then
  if n-array['status','reviewed_by','reviewed_at','review_note','due_date','receivable_id','settlement_entry_id']<>
     o-array['status','reviewed_by','reviewed_at','review_note','due_date','receivable_id','settlement_entry_id']or not(
    (old.status='proposed'and new.status in('accepted','rejected'))or(old.status='accepted'and new.status='materialized')or old.status=new.status
  )then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_DEBT_IMMUTABLE';end if;
 elsif tg_table_name='cutover_controls'then
  if n-array['state','source_fingerprint','ready_at','frozen_at','accepted_by','updated_at']<>
     o-array['state','source_fingerprint','ready_at','frozen_at','accepted_by','updated_at']or not(
    (old.state='reviewing'and new.state in('reviewing','ready'))or(old.state='ready'and new.state in('ready','legacy_frozen'))or old.state=new.state
  )then raise exception using errcode='P0001',message='V2_CUTOVER_CONTROL_MUTATION_FORBIDDEN';end if;
 end if;
 return new;
end$$;

create trigger a_cutover_runs_context before insert or update or delete on public.cutover_reconciliation_runs for each row execute function public.v2_cutover_context_required();
create trigger b_cutover_runs_guard before update or delete on public.cutover_reconciliation_runs for each row execute function public.v2_guard_cutover_evidence();
create trigger a_cutover_checks_context before insert or update or delete on public.cutover_reconciliation_checks for each row execute function public.v2_cutover_context_required();
create trigger b_cutover_checks_guard before update or delete on public.cutover_reconciliation_checks for each row execute function public.v2_guard_cutover_evidence();
create trigger a_cutover_stock_context before insert or update or delete on public.cutover_opening_stock_lines for each row execute function public.v2_cutover_context_required();
create trigger b_cutover_stock_guard before update or delete on public.cutover_opening_stock_lines for each row execute function public.v2_guard_cutover_evidence();
create trigger a_cutover_debts_context before insert or update or delete on public.cutover_opening_debts for each row execute function public.v2_cutover_context_required();
create trigger b_cutover_debts_guard before update or delete on public.cutover_opening_debts for each row execute function public.v2_guard_cutover_evidence();
create trigger a_cutover_controls_context before insert or update or delete on public.cutover_controls for each row execute function public.v2_cutover_context_required();
create trigger b_cutover_controls_guard before update or delete on public.cutover_controls for each row execute function public.v2_guard_cutover_evidence();

create or replace function public.v2_cutover_assert_current(r public.cutover_reconciliation_runs)
returns void language plpgsql stable security definer set search_path=''as $$
begin
 if r.source_fingerprint is distinct from public.v2_cutover_source_fingerprint(r.organization_id)then
  raise exception using errcode='P0001',message='V2_CUTOVER_SOURCE_CHANGED';
 end if;
end$$;

create or replace function public.v2_start_cutover_reconciliation(organization_id uuid,backfill_run_id uuid,owner_membership_id uuid)
returns uuid language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
declare rid uuid;fp jsonb;bd date;cur char(3);p record;
begin
 perform pg_advisory_xact_lock(hashtextextended('cutover:'||organization_id::text,0));
 perform public.v2_cutover_require_owner(organization_id,owner_membership_id);
 perform public.v2_cutover_validate_backfill(organization_id,backfill_run_id);
 if exists(select 1 from public.cutover_controls c where c.organization_id=v2_start_cutover_reconciliation.organization_id and c.state='legacy_frozen')then
  raise exception using errcode='P0001',message='V2_CUTOVER_LEGACY_ALREADY_FROZEN';
 end if;
 select r.id into rid from public.cutover_reconciliation_runs r where r.backfill_run_id=v2_start_cutover_reconciliation.backfill_run_id;
 if rid is not null then return rid;end if;
 select (clock_timestamp()at time zone s.timezone)::date,s.currency_code into bd,cur
 from public.organization_settings s where s.organization_id=v2_start_cutover_reconciliation.organization_id;
 if bd is null then raise exception using errcode='P0001',message='V2_ORGANIZATION_SETTINGS_REQUIRED';end if;
 fp:=public.v2_cutover_source_fingerprint(organization_id);
 perform set_config('market_pos.cutover_command','on',true);
 insert into public.cutover_reconciliation_runs(organization_id,backfill_run_id,owner_membership_id,source_fingerprint,cutoff_at,business_date,summary)
 values($1,$2,$3,fp,clock_timestamp(),bd,jsonb_build_object(
  'baseline',jsonb_build_object(
   'purchases',(select count(*)from public.purchase_documents x where x.organization_id=$1),
   'sales',(select count(*)from public.sales_v2 x where x.organization_id=$1),
   'payments',(select count(*)from public.payments_v2 x where x.organization_id=$1),
   'shifts',(select count(*)from public.shifts_v2 x where x.organization_id=$1),
   'sync_commands',(select count(*)from public.sync_commands x where x.organization_id=$1)
  )))returning id into rid;
 insert into public.cutover_controls(organization_id,reconciliation_run_id,state,source_fingerprint)
 values($1,rid,'reviewing',fp)
 on conflict(organization_id)do update set reconciliation_run_id=excluded.reconciliation_run_id,state='reviewing',source_fingerprint=excluded.source_fingerprint,ready_at=null,frozen_at=null,accepted_by=null,updated_at=clock_timestamp();

 for p in
  select lp.id legacy_product_id,lp.current_quantity,vp.id product_id,vp.base_unit_id,
    count(pb.id)filter(where pb.remaining_quantity>0) positive_batches,
    count(pb.id)filter(where pb.remaining_quantity>0 and(br.id is null or wh.id is null)) unmapped_batches,
    coalesce(sum(pb.remaining_quantity)filter(where pb.remaining_quantity>0),0) batch_total
  from public.products lp
  join public.products_v2 vp on vp.organization_id=lp.organization_id and vp.legacy_product_id=lp.id
  left join public.product_batches pb on pb.product_id=lp.id
  left join public.stores st on st.id=pb.store_id and st.organization_id=lp.organization_id
  left join public.branches br on br.legacy_store_id=st.id and br.organization_id=lp.organization_id
  left join lateral(select w.id from public.warehouses w where w.organization_id=lp.organization_id and w.branch_id=br.id and w.is_primary and w.status='active'and w.archived_at is null order by w.id fetch first 1 row only)wh on true
  where lp.organization_id=v2_start_cutover_reconciliation.organization_id and lp.current_quantity>0
  group by lp.id,lp.current_quantity,vp.id,vp.base_unit_id
  having coalesce(sum(pb.remaining_quantity)filter(where pb.remaining_quantity>0),0)=lp.current_quantity
     and count(pb.id)filter(where pb.remaining_quantity>0)>0
     and count(pb.id)filter(where pb.remaining_quantity>0 and(br.id is null or wh.id is null))=0
 loop
  insert into public.cutover_opening_stock_lines(run_id,organization_id,source_kind,legacy_product_id,legacy_batch_id,branch_id,warehouse_id,product_id,unit_id,quantity,unit_cost,currency_code,received_date,expiration_date)
  select rid,$1,'legacy_batch',p.legacy_product_id,pb.id,br.id,wh.id,p.product_id,p.base_unit_id,pb.remaining_quantity,pb.purchase_price,cur,pb.received_date,pb.expiration_date
  from public.product_batches pb join public.stores st on st.id=pb.store_id
  join public.branches br on br.legacy_store_id=st.id and br.organization_id=$1
  join lateral(select w.id from public.warehouses w where w.organization_id=$1 and w.branch_id=br.id and w.is_primary and w.status='active'and w.archived_at is null order by w.id fetch first 1 row only)wh on true
  where pb.product_id=p.legacy_product_id and pb.remaining_quantity>0 on conflict do nothing;
 end loop;

 insert into public.cutover_opening_debts(run_id,organization_id,legacy_customer_id,branch_id,counterparty_id,amount,currency_code,as_of_date)
 select rid,$1,c.id,b.id,cp.id,c.current_debt,cur,bd
 from public.customers c join public.stores s on s.id=c.store_id and s.organization_id=$1
 join public.branches b on b.legacy_store_id=s.id and b.organization_id=$1
 join public.counterparties cp on cp.legacy_customer_id=c.id and cp.organization_id=$1
 where c.current_debt>0 and exists(select 1 from public.counterparty_roles cr where cr.organization_id=$1 and cr.counterparty_id=cp.id and cr.role_code='customer')
 on conflict do nothing;
 perform set_config('market_pos.cutover_command','off',true);
 return rid;
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_record_debt_payment(organization_id uuid,branch_id uuid,register_id uuid,current_shift_id uuid,counterparty_id uuid,document_number text,business_date date,currency_code char(3),device_id uuid,local_operation_id uuid,client_created_at timestamptz,payments jsonb,allocations jsonb)
returns uuid language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
declare i uuid;c uuid;pmt record;rr record;resolved jsonb:=allocations;total numeric:=0;remaining numeric;take numeric;
begin
 perform public.v2_lock_operation_scope(organization_id,device_id,local_operation_id);
 perform public.v2_lock_register_shift_scope(organization_id,branch_id,register_id);
 perform public.v2_lock_settlement_scope(organization_id,counterparty_id,currency_code);
 if allocations is null or allocations='[]'::jsonb then
  if jsonb_typeof(payments)='array'then select coalesce(sum((x->>'amount')::numeric),0)into total from jsonb_array_elements(payments)x;end if;
  remaining:=total;resolved:='[]'::jsonb;
  for rr in
   select r.id,r.outstanding_amount from public.receivables r
   left join public.sales_v2 s on s.id=r.sale_id
   left join public.cutover_opening_debts d on d.id=r.opening_debt_id
   where r.organization_id=v2_record_debt_payment.organization_id and r.branch_id=v2_record_debt_payment.branch_id and r.counterparty_id=v2_record_debt_payment.counterparty_id and r.currency_code=v2_record_debt_payment.currency_code and r.status in('open','partial')
   order by r.due_date nulls last,coalesce(s.business_date,d.as_of_date),r.id for update of r
  loop
   exit when remaining<=0;take:=least(rr.outstanding_amount,remaining);
   resolved:=resolved||jsonb_build_array(jsonb_build_object('receivable_id',rr.id,'amount',take));remaining:=remaining-take;
  end loop;
 end if;
 i:=public.v2_record_debt_payment_0015_cash_base(organization_id,branch_id,register_id,current_shift_id,counterparty_id,document_number,business_date,currency_code,device_id,local_operation_id,client_created_at,payments,resolved);
 c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;
 for pmt in select id from public.payments_v2 where debt_payment_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;
 return i;
end$$;

create or replace function public.v2_guard_product_batch_v2()returns trigger language plpgsql set search_path=''as $$
declare l public.cutover_opening_stock_lines%rowtype;
begin
 if new.purchase_line_id is not null then
  if new.opening_stock_line_id is not null or not exists(select 1 from public.purchase_lines pl join public.purchase_documents d on d.id=pl.purchase_document_id where pl.id=new.purchase_line_id and pl.organization_id=new.organization_id and pl.product_id=new.product_id and d.organization_id=new.organization_id and d.warehouse_id=new.warehouse_id and d.status='posted')then
   raise exception using errcode='P0001',message='V2_BATCH_PURCHASE_SCOPE_MISMATCH';end if;
 else
  select * into l from public.cutover_opening_stock_lines x where x.id=new.opening_stock_line_id;
  if l.id is null or l.status not in('accepted','materialized')or l.organization_id<>new.organization_id or l.warehouse_id<>new.warehouse_id or l.product_id<>new.product_id or l.quantity<>new.initial_quantity or l.unit_cost<>new.purchase_unit_cost or l.currency_code<>new.currency_code or l.expiration_date is distinct from new.expiration_date or
    not exists(select 1 from public.cutover_controls c where c.organization_id=l.organization_id and c.reconciliation_run_id=l.run_id and c.state in('reviewing','ready'))or
    coalesce(current_setting('market_pos.cutover_command',true),'')<>'on'then
   raise exception using errcode='P0001',message='V2_BATCH_OPENING_SOURCE_MISMATCH';end if;
 end if;
 if tg_op='UPDATE'and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.warehouse_id is distinct from old.warehouse_id or new.product_id is distinct from old.product_id or new.purchase_line_id is distinct from old.purchase_line_id or new.opening_stock_line_id is distinct from old.opening_stock_line_id or new.batch_code is distinct from old.batch_code or new.initial_quantity is distinct from old.initial_quantity or new.purchase_unit_cost is distinct from old.purchase_unit_cost or new.currency_code is distinct from old.currency_code or new.created_at is distinct from old.created_at or old.status='reversed'or(new.status='reversed'and old.status not in('open','depleted','blocked')))then
  raise exception using errcode='P0001',message='V2_BATCH_IDENTITY_MUTATION_FORBIDDEN';end if;
 return new;
end$$;

create or replace function public.v2_guard_receivable()returns trigger language plpgsql set search_path=''as $$
declare s public.sales_v2%rowtype;c public.counterparties%rowtype;m public.organization_memberships%rowtype;d public.cutover_opening_debts%rowtype;cmd public.command_log%rowtype;
begin
 if tg_op='INSERT'then
  select * into c from public.counterparties where id=new.counterparty_id;select * into m from public.organization_memberships where id=new.created_by;
  if c.id is null or m.id is null or c.organization_id<>new.organization_id or m.organization_id<>new.organization_id then raise exception using errcode='P0001',message='V2_RECEIVABLE_SCOPE_MISMATCH';end if;
  if new.sale_id is not null then
   if new.opening_debt_id is not null then raise exception using errcode='P0001',message='V2_RECEIVABLE_SCOPE_MISMATCH';end if;
   select * into s from public.sales_v2 where id=new.sale_id;
   if s.id is null or s.organization_id<>new.organization_id or s.branch_id<>new.branch_id or s.customer_counterparty_id is distinct from new.counterparty_id or s.currency_code<>new.currency_code then raise exception using errcode='P0001',message='V2_RECEIVABLE_SCOPE_MISMATCH';end if;
  else
   select * into d from public.cutover_opening_debts where id=new.opening_debt_id;select * into cmd from public.command_log where id=new.command_id;
   if d.id is null or d.status not in('accepted','materialized')or d.organization_id<>new.organization_id or d.branch_id<>new.branch_id or d.counterparty_id<>new.counterparty_id or d.currency_code<>new.currency_code or d.amount<>new.original_amount or d.amount<>new.outstanding_amount or new.status<>'open'or d.reviewed_by is distinct from new.created_by or cmd.id is null or cmd.organization_id<>new.organization_id or cmd.branch_id is distinct from new.branch_id or cmd.actor_membership_id is distinct from new.created_by or cmd.command_type<>'cutover.opening_debt.materialize'or coalesce(current_setting('market_pos.current_command_id',true),'')<>cmd.id::text or coalesce(current_setting('market_pos.cutover_command',true),'')<>'on'then
    raise exception using errcode='P0001',message='V2_RECEIVABLE_OPENING_SOURCE_MISMATCH';end if;
  end if;
 elsif(to_jsonb(new)-array['outstanding_amount','status','version','closed_at'])<>(to_jsonb(old)-array['outstanding_amount','status','version','closed_at'])then raise exception using errcode='P0001',message='V2_RECEIVABLE_IDENTITY_MUTATION_FORBIDDEN';end if;
 return new;
end$$;

create or replace function public.v2_guard_settlement_entry()returns trigger language plpgsql set search_path=''as $$
declare b public.branches%rowtype;c public.counterparties%rowtype;o public.settlement_entries%rowtype;cmd public.command_log%rowtype;sv public.sales_v2%rowtype;sr public.sale_returns%rowtype;dp public.debt_payments_v2%rowtype;pd public.purchase_documents%rowtype;da public.debt_allocations%rowtype;rec public.receivables%rowtype;od public.cutover_opening_debts%rowtype;source_ok boolean:=false;
begin
 perform public.v2_lock_settlement_scope(new.organization_id,new.counterparty_id,new.currency_code);
 select * into b from public.branches where id=new.branch_id;select * into c from public.counterparties where id=new.counterparty_id;select * into cmd from public.command_log where id=new.command_id;
 if b.id is null or c.id is null or cmd.id is null or b.organization_id<>new.organization_id or c.organization_id<>new.organization_id or cmd.organization_id<>new.organization_id or cmd.status not in('processing','succeeded')then raise exception using errcode='P0001',message='V2_SETTLEMENT_ENTRY_SCOPE_MISMATCH';end if;
 if exists(select 1 from public.settlement_periods p where p.organization_id=new.organization_id and p.counterparty_id=new.counterparty_id and p.currency_code=new.currency_code and p.status in('closed','corrected')and new.business_date>=p.starts_on and new.business_date<p.ends_on)then raise exception using errcode='P0001',message='V2_SETTLEMENT_PERIOD_CLOSED';end if;
 if new.reversal_of_id is not null then select * into o from public.settlement_entries where id=new.reversal_of_id;if o.id is null or o.reversal_of_id is not null or o.organization_id<>new.organization_id or o.branch_id<>new.branch_id or o.counterparty_id<>new.counterparty_id or o.entry_type<>new.entry_type or o.currency_code<>new.currency_code or new.amount_delta<>-o.amount_delta then raise exception using errcode='P0001',message='V2_SETTLEMENT_REVERSAL_MISMATCH';end if;end if;
 case new.source_document_type
 when'sale'then select * into sv from public.sales_v2 where id=new.source_document_id;source_ok:=sv.id is not null and sv.organization_id=new.organization_id and sv.branch_id=new.branch_id and sv.customer_counterparty_id is not distinct from new.counterparty_id and sv.currency_code=new.currency_code and new.entry_type='sale_debt'and((sv.reversal_of_id is null and new.reversal_of_id is null and new.amount_delta>0)or(sv.reversal_of_id is not null and new.reversal_of_id is not null and o.source_document_id=sv.reversal_of_id and new.amount_delta<0));
 when'sale_return'then select * into sr from public.sale_returns where id=new.source_document_id;select * into sv from public.sales_v2 where id=sr.original_sale_id;source_ok:=sr.id is not null and sr.organization_id=new.organization_id and sv.branch_id=new.branch_id and sv.customer_counterparty_id is not distinct from new.counterparty_id and sv.currency_code=new.currency_code and new.entry_type='sale_return'and((sr.reversal_of_id is null and new.reversal_of_id is null and new.amount_delta<0)or(sr.reversal_of_id is not null and new.reversal_of_id is not null and o.source_document_id=sr.reversal_of_id and new.amount_delta>0));
 when'debt_payment'then select * into dp from public.debt_payments_v2 where id=new.source_document_id;source_ok:=dp.id is not null and dp.organization_id=new.organization_id and dp.branch_id=new.branch_id and dp.counterparty_id=new.counterparty_id and dp.currency_code=new.currency_code and new.entry_type='customer_payment'and((dp.reversal_of_id is null and new.reversal_of_id is null and new.amount_delta<0)or(dp.reversal_of_id is not null and new.reversal_of_id is not null and o.source_document_id=dp.reversal_of_id and new.amount_delta>0));
 when'purchase'then select * into pd from public.purchase_documents where id=new.source_document_id;source_ok:=pd.id is not null and pd.organization_id=new.organization_id and pd.branch_id=new.branch_id and pd.counterparty_id=new.counterparty_id and pd.currency_code=new.currency_code and new.entry_type='purchase'and((pd.reversal_of_id is null and new.reversal_of_id is null and new.amount_delta<0)or(pd.reversal_of_id is not null and new.reversal_of_id is not null and o.source_document_id=pd.reversal_of_id and new.amount_delta>0));
 when'debt_allocation'then select * into da from public.debt_allocations where id=new.source_document_id;select * into rec from public.receivables where id=da.receivable_id;source_ok:=da.id is not null and da.allocation_type='write_off'and da.organization_id=new.organization_id and rec.branch_id=new.branch_id and rec.counterparty_id=new.counterparty_id and rec.currency_code=new.currency_code and new.entry_type='write_off'and((da.reversal_of_id is null and new.reversal_of_id is null and new.amount_delta<0)or(da.reversal_of_id is not null and new.reversal_of_id is not null and o.source_document_id=da.reversal_of_id and new.amount_delta>0));
 when'opening_debt'then
  select * into od from public.cutover_opening_debts where id=new.source_document_id;
  source_ok:=od.id is not null and od.status in('accepted','materialized')and od.organization_id=new.organization_id and od.branch_id=new.branch_id and od.counterparty_id=new.counterparty_id and od.currency_code=new.currency_code and od.amount=new.amount_delta and new.amount_delta>0 and new.entry_type='opening_debt'and new.reversal_of_id is null and od.reviewed_by is not distinct from new.created_by and cmd.command_type='cutover.opening_debt.materialize'and coalesce(current_setting('market_pos.current_command_id',true),'')=cmd.id::text and coalesce(current_setting('market_pos.cutover_command',true),'')='on';
 else source_ok:=false;end case;
 if not source_ok then raise exception using errcode='P0001',message='V2_SETTLEMENT_SOURCE_GRAPH_MISMATCH';end if;return new;
end$$;

create or replace function public.v2_add_cutover_opening_stock_line(run_id uuid,branch_id uuid,warehouse_id uuid,product_id uuid,quantity numeric,unit_cost numeric,received_date date,expiration_date date,owner_membership_id uuid,reason text)
returns uuid language plpgsql security definer set search_path=''as $$
declare r public.cutover_reconciliation_runs%rowtype;lp uuid;u uuid;i uuid;allocated numeric;required numeric;cur char(3);
begin
 select * into r from public.cutover_reconciliation_runs x where x.id=$1 for update;
 if not found or r.status<>'reviewing'then raise exception using errcode='P0001',message='V2_CUTOVER_RUN_NOT_REVIEWING';end if;
 perform public.v2_cutover_require_owner(r.organization_id,$9);perform public.v2_cutover_assert_current(r);
 if $5<=0 or $6<0 or nullif(btrim($10),'')is null then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_INVALID';end if;
 select p.legacy_product_id,p.base_unit_id into lp,u from public.products_v2 p where p.id=$4 and p.organization_id=r.organization_id;
 if lp is null or not exists(select 1 from public.branches b where b.id=$2 and b.organization_id=r.organization_id)or
   not exists(select 1 from public.warehouses w where w.id=$3 and w.organization_id=r.organization_id and w.branch_id=$2 and w.status='active')then
  raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_SCOPE_MISMATCH';end if;
 select current_quantity into required from public.products where id=lp and organization_id=r.organization_id;
 select coalesce(sum(s.quantity),0)into allocated from public.cutover_opening_stock_lines s where s.run_id=r.id and s.legacy_product_id=lp and s.status in('proposed','accepted','materialized');
 if allocated+$5>required then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_OVERALLOCATED';end if;
 select currency_code into cur from public.organization_settings where organization_id=r.organization_id;
 perform set_config('market_pos.cutover_command','on',true);
 insert into public.cutover_opening_stock_lines(run_id,organization_id,source_kind,legacy_product_id,branch_id,warehouse_id,product_id,unit_id,quantity,unit_cost,currency_code,received_date,expiration_date,review_note)
 values(r.id,r.organization_id,'manual',lp,$2,$3,$4,u,$5,$6,cur,$7,$8,$10)returning id into i;
 perform set_config('market_pos.cutover_command','off',true);return i;
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_review_cutover_opening_stock(line_id uuid,decision text,owner_membership_id uuid,review_note text)
returns uuid language plpgsql security definer set search_path=''as $$
declare l public.cutover_opening_stock_lines%rowtype;r public.cutover_reconciliation_runs%rowtype;required numeric;accepted numeric;
begin
 select * into l from public.cutover_opening_stock_lines x where x.id=line_id for update;select * into r from public.cutover_reconciliation_runs x where x.id=l.run_id;
 if l.id is null or r.status<>'reviewing'or l.status<>'proposed'or decision not in('accepted','rejected')then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_REVIEW_INVALID';end if;
 perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);perform public.v2_cutover_assert_current(r);
 if decision='accepted'then
  if not exists(select 1 from public.products_v2 p join public.products lp on lp.id=p.legacy_product_id where p.id=l.product_id and p.organization_id=l.organization_id and lp.id=l.legacy_product_id and(not p.is_expirable or l.expiration_date is not null))or
    not exists(select 1 from public.warehouses w where w.id=l.warehouse_id and w.organization_id=l.organization_id and w.branch_id=l.branch_id and w.status='active')then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_SCOPE_MISMATCH';end if;
  select current_quantity into required from public.products where id=l.legacy_product_id;
  select coalesce(sum(quantity),0)into accepted from public.cutover_opening_stock_lines where run_id=l.run_id and legacy_product_id=l.legacy_product_id and status in('accepted','materialized');
  if accepted+l.quantity>required then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_STOCK_OVERALLOCATED';end if;
 end if;
 perform set_config('market_pos.cutover_command','on',true);update public.cutover_opening_stock_lines set status=decision,reviewed_by=owner_membership_id,reviewed_at=clock_timestamp(),review_note=coalesce($4,cutover_opening_stock_lines.review_note)where id=line_id;perform set_config('market_pos.cutover_command','off',true);return line_id;
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

create or replace function public.v2_review_cutover_opening_debt(opening_debt_id uuid,decision text,owner_membership_id uuid,due_date date default null,review_note text default null)
returns uuid language plpgsql security definer set search_path=''as $$
declare d public.cutover_opening_debts%rowtype;r public.cutover_reconciliation_runs%rowtype;v numeric;
begin
 select * into d from public.cutover_opening_debts x where x.id=opening_debt_id for update;select * into r from public.cutover_reconciliation_runs x where x.id=d.run_id;
 if d.id is null or r.status<>'reviewing'or d.status<>'proposed'or decision not in('accepted','rejected')then raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_DEBT_REVIEW_INVALID';end if;
 perform public.v2_cutover_require_owner(r.organization_id,owner_membership_id);perform public.v2_cutover_assert_current(r);
 select current_debt into v from public.customers where id=d.legacy_customer_id;
 if decision='accepted'and(v is distinct from d.amount or not exists(select 1 from public.counterparties c join public.counterparty_roles cr on cr.counterparty_id=c.id where c.id=d.counterparty_id and c.organization_id=d.organization_id and cr.organization_id=d.organization_id and cr.role_code='customer'))then
  raise exception using errcode='P0001',message='V2_CUTOVER_OPENING_DEBT_SOURCE_MISMATCH';end if;
 perform set_config('market_pos.cutover_command','on',true);update public.cutover_opening_debts set status=decision,reviewed_by=owner_membership_id,reviewed_at=clock_timestamp(),due_date=case when decision='accepted'then $4 else null end,review_note=$5 where id=opening_debt_id;perform set_config('market_pos.cutover_command','off',true);return opening_debt_id;
exception when others then perform set_config('market_pos.cutover_command','off',true);raise;end$$;

-- Cutover execution is an operator/service concern, never a browser surface.
revoke execute on function public.v2_start_cutover_reconciliation(uuid,uuid,uuid),
 public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text),
 public.v2_review_cutover_opening_stock(uuid,text,uuid,text),
 public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text),
 public.v2_materialize_cutover_opening_state(uuid,uuid),
 public.v2_review_migration_exception(uuid,text,text,uuid),
 public.v2_finalize_cutover_reconciliation(uuid,uuid),
 public.v2_freeze_legacy_for_cutover(uuid,uuid,text)
 from public,anon,authenticated;
grant execute on function public.v2_start_cutover_reconciliation(uuid,uuid,uuid),
 public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text),
 public.v2_review_cutover_opening_stock(uuid,text,uuid,text),
 public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text),
 public.v2_materialize_cutover_opening_state(uuid,uuid),
 public.v2_review_migration_exception(uuid,text,text,uuid),
 public.v2_finalize_cutover_reconciliation(uuid,uuid),
 public.v2_freeze_legacy_for_cutover(uuid,uuid,text)
 to service_role;

revoke execute on function public.v2_cutover_require_owner(uuid,uuid),
 public.v2_cutover_source_fingerprint(uuid),public.v2_cutover_validate_backfill(uuid,uuid),
 public.v2_cutover_context_required(),public.v2_guard_cutover_evidence(),
 public.v2_cutover_assert_current(public.cutover_reconciliation_runs),
 public.v2_cutover_command(uuid,uuid,uuid,uuid,text,jsonb),
 public.v2_cutover_add_check(uuid,text,boolean,jsonb),public.v2_guard_legacy_cutover_freeze(),
 public.v2_guard_product_batch_v2(),public.v2_guard_receivable(),public.v2_guard_settlement_entry()
 from public,anon,authenticated,service_role;

comment on table public.cutover_reconciliation_runs is 'Immutable 0020 reconciliation evidence; ready/frozen do not switch application routing.';
comment on table public.cutover_opening_stock_lines is 'Reviewed opening inventory state, never synthetic V1 purchase history.';
comment on table public.cutover_opening_debts is 'Reviewed opening receivable state, never synthetic V1 sale history.';
comment on table public.cutover_controls is 'Explicit readiness and optional physical V1 write-freeze evidence.';
