begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(509);

-- Five private evidence tables form the cutover control plane.
select has_table('public',t,t||' exists')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),
 ('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t);

with expected(t,c)as(values
 ('cutover_reconciliation_runs','id'),('cutover_reconciliation_runs','organization_id'),('cutover_reconciliation_runs','backfill_run_id'),('cutover_reconciliation_runs','owner_membership_id'),('cutover_reconciliation_runs','source_fingerprint'),('cutover_reconciliation_runs','cutoff_at'),('cutover_reconciliation_runs','business_date'),('cutover_reconciliation_runs','status'),('cutover_reconciliation_runs','opening_materialized_at'),('cutover_reconciliation_runs','finalized_at'),('cutover_reconciliation_runs','frozen_at'),('cutover_reconciliation_runs','summary'),('cutover_reconciliation_runs','created_at'),
 ('cutover_reconciliation_checks','id'),('cutover_reconciliation_checks','run_id'),('cutover_reconciliation_checks','organization_id'),('cutover_reconciliation_checks','check_code'),('cutover_reconciliation_checks','severity'),('cutover_reconciliation_checks','passed'),('cutover_reconciliation_checks','details'),('cutover_reconciliation_checks','created_at'),
 ('cutover_opening_stock_lines','id'),('cutover_opening_stock_lines','run_id'),('cutover_opening_stock_lines','organization_id'),('cutover_opening_stock_lines','source_kind'),('cutover_opening_stock_lines','legacy_product_id'),('cutover_opening_stock_lines','legacy_batch_id'),('cutover_opening_stock_lines','branch_id'),('cutover_opening_stock_lines','warehouse_id'),('cutover_opening_stock_lines','product_id'),('cutover_opening_stock_lines','unit_id'),('cutover_opening_stock_lines','quantity'),('cutover_opening_stock_lines','unit_cost'),('cutover_opening_stock_lines','currency_code'),('cutover_opening_stock_lines','received_date'),('cutover_opening_stock_lines','expiration_date'),('cutover_opening_stock_lines','review_note'),('cutover_opening_stock_lines','status'),('cutover_opening_stock_lines','reviewed_by'),('cutover_opening_stock_lines','reviewed_at'),('cutover_opening_stock_lines','materialized_document_id'),('cutover_opening_stock_lines','product_batch_id'),('cutover_opening_stock_lines','operation_id'),('cutover_opening_stock_lines','created_at'),
 ('cutover_opening_debts','id'),('cutover_opening_debts','run_id'),('cutover_opening_debts','organization_id'),('cutover_opening_debts','legacy_customer_id'),('cutover_opening_debts','branch_id'),('cutover_opening_debts','counterparty_id'),('cutover_opening_debts','amount'),('cutover_opening_debts','currency_code'),('cutover_opening_debts','as_of_date'),('cutover_opening_debts','due_date'),('cutover_opening_debts','review_note'),('cutover_opening_debts','status'),('cutover_opening_debts','reviewed_by'),('cutover_opening_debts','reviewed_at'),('cutover_opening_debts','receivable_id'),('cutover_opening_debts','settlement_entry_id'),('cutover_opening_debts','operation_id'),('cutover_opening_debts','created_at'),
 ('cutover_controls','organization_id'),('cutover_controls','reconciliation_run_id'),('cutover_controls','state'),('cutover_controls','source_fingerprint'),('cutover_controls','ready_at'),('cutover_controls','frozen_at'),('cutover_controls','accepted_by'),('cutover_controls','updated_at'))
select has_column('public',t,c,t||'.'||c||' exists')from expected;

with expected(t,c,typ)as(values
 ('cutover_reconciliation_runs','id','uuid'),('cutover_reconciliation_runs','organization_id','uuid'),('cutover_reconciliation_runs','backfill_run_id','uuid'),('cutover_reconciliation_runs','owner_membership_id','uuid'),('cutover_reconciliation_runs','source_fingerprint','jsonb'),('cutover_reconciliation_runs','cutoff_at','timestamp with time zone'),('cutover_reconciliation_runs','business_date','date'),('cutover_reconciliation_runs','status','text'),('cutover_reconciliation_runs','opening_materialized_at','timestamp with time zone'),('cutover_reconciliation_runs','finalized_at','timestamp with time zone'),('cutover_reconciliation_runs','frozen_at','timestamp with time zone'),('cutover_reconciliation_runs','summary','jsonb'),('cutover_reconciliation_runs','created_at','timestamp with time zone'),
 ('cutover_reconciliation_checks','id','uuid'),('cutover_reconciliation_checks','run_id','uuid'),('cutover_reconciliation_checks','organization_id','uuid'),('cutover_reconciliation_checks','check_code','text'),('cutover_reconciliation_checks','severity','text'),('cutover_reconciliation_checks','passed','boolean'),('cutover_reconciliation_checks','details','jsonb'),('cutover_reconciliation_checks','created_at','timestamp with time zone'),
 ('cutover_opening_stock_lines','id','uuid'),('cutover_opening_stock_lines','run_id','uuid'),('cutover_opening_stock_lines','organization_id','uuid'),('cutover_opening_stock_lines','source_kind','text'),('cutover_opening_stock_lines','legacy_product_id','uuid'),('cutover_opening_stock_lines','legacy_batch_id','uuid'),('cutover_opening_stock_lines','branch_id','uuid'),('cutover_opening_stock_lines','warehouse_id','uuid'),('cutover_opening_stock_lines','product_id','uuid'),('cutover_opening_stock_lines','unit_id','uuid'),('cutover_opening_stock_lines','quantity','numeric(18,6)'),('cutover_opening_stock_lines','unit_cost','numeric(18,4)'),('cutover_opening_stock_lines','currency_code','character(3)'),('cutover_opening_stock_lines','received_date','date'),('cutover_opening_stock_lines','expiration_date','date'),('cutover_opening_stock_lines','review_note','text'),('cutover_opening_stock_lines','status','text'),('cutover_opening_stock_lines','reviewed_by','uuid'),('cutover_opening_stock_lines','reviewed_at','timestamp with time zone'),('cutover_opening_stock_lines','materialized_document_id','uuid'),('cutover_opening_stock_lines','product_batch_id','uuid'),('cutover_opening_stock_lines','operation_id','uuid'),('cutover_opening_stock_lines','created_at','timestamp with time zone'),
 ('cutover_opening_debts','id','uuid'),('cutover_opening_debts','run_id','uuid'),('cutover_opening_debts','organization_id','uuid'),('cutover_opening_debts','legacy_customer_id','uuid'),('cutover_opening_debts','branch_id','uuid'),('cutover_opening_debts','counterparty_id','uuid'),('cutover_opening_debts','amount','numeric(18,4)'),('cutover_opening_debts','currency_code','character(3)'),('cutover_opening_debts','as_of_date','date'),('cutover_opening_debts','due_date','date'),('cutover_opening_debts','review_note','text'),('cutover_opening_debts','status','text'),('cutover_opening_debts','reviewed_by','uuid'),('cutover_opening_debts','reviewed_at','timestamp with time zone'),('cutover_opening_debts','receivable_id','uuid'),('cutover_opening_debts','settlement_entry_id','uuid'),('cutover_opening_debts','operation_id','uuid'),('cutover_opening_debts','created_at','timestamp with time zone'),
 ('cutover_controls','organization_id','uuid'),('cutover_controls','reconciliation_run_id','uuid'),('cutover_controls','state','text'),('cutover_controls','source_fingerprint','jsonb'),('cutover_controls','ready_at','timestamp with time zone'),('cutover_controls','frozen_at','timestamp with time zone'),('cutover_controls','accepted_by','uuid'),('cutover_controls','updated_at','timestamp with time zone'))
select col_type_is('public',t,c,typ,t||'.'||c||' type is '||typ)from expected;

with required(t,c)as(values
 ('cutover_reconciliation_runs','id'),('cutover_reconciliation_runs','organization_id'),('cutover_reconciliation_runs','backfill_run_id'),('cutover_reconciliation_runs','owner_membership_id'),('cutover_reconciliation_runs','source_fingerprint'),('cutover_reconciliation_runs','cutoff_at'),('cutover_reconciliation_runs','business_date'),('cutover_reconciliation_runs','status'),('cutover_reconciliation_runs','summary'),('cutover_reconciliation_runs','created_at'),
 ('cutover_reconciliation_checks','id'),('cutover_reconciliation_checks','run_id'),('cutover_reconciliation_checks','organization_id'),('cutover_reconciliation_checks','check_code'),('cutover_reconciliation_checks','severity'),('cutover_reconciliation_checks','passed'),('cutover_reconciliation_checks','details'),('cutover_reconciliation_checks','created_at'),
 ('cutover_opening_stock_lines','id'),('cutover_opening_stock_lines','run_id'),('cutover_opening_stock_lines','organization_id'),('cutover_opening_stock_lines','source_kind'),('cutover_opening_stock_lines','legacy_product_id'),('cutover_opening_stock_lines','branch_id'),('cutover_opening_stock_lines','warehouse_id'),('cutover_opening_stock_lines','product_id'),('cutover_opening_stock_lines','unit_id'),('cutover_opening_stock_lines','quantity'),('cutover_opening_stock_lines','unit_cost'),('cutover_opening_stock_lines','currency_code'),('cutover_opening_stock_lines','received_date'),('cutover_opening_stock_lines','status'),('cutover_opening_stock_lines','operation_id'),('cutover_opening_stock_lines','created_at'),
 ('cutover_opening_debts','id'),('cutover_opening_debts','run_id'),('cutover_opening_debts','organization_id'),('cutover_opening_debts','legacy_customer_id'),('cutover_opening_debts','branch_id'),('cutover_opening_debts','counterparty_id'),('cutover_opening_debts','amount'),('cutover_opening_debts','currency_code'),('cutover_opening_debts','as_of_date'),('cutover_opening_debts','status'),('cutover_opening_debts','operation_id'),('cutover_opening_debts','created_at'),
 ('cutover_controls','organization_id'),('cutover_controls','reconciliation_run_id'),('cutover_controls','state'),('cutover_controls','source_fingerprint'),('cutover_controls','updated_at'))
select col_not_null('public',t,c,t||'.'||c||' is required')from required;

select ok(c.relrowsecurity and not c.relforcerowsecurity,t||' uses standard non-FORCE RLS')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t)
join pg_class c on c.oid=format('public.%I',t)::regclass;
select is((select count(*)from pg_policies where schemaname='public'and tablename=t),0::bigint,t||' has no browser policy')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t);
select ok(not has_table_privilege(r,format('public.%I',t),p),r||' denied '||t||' '||p)
from(values('anon'),('authenticated'))roles(r)cross join(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))tables(t)
cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))privs(p);

with f(sig)as(values
 ('public.v2_start_cutover_reconciliation(uuid,uuid,uuid)'),('public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text)'),('public.v2_review_cutover_opening_stock(uuid,text,uuid,text)'),('public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text)'),('public.v2_materialize_cutover_opening_state(uuid,uuid)'),('public.v2_review_migration_exception(uuid,text,text,uuid)'),('public.v2_finalize_cutover_reconciliation(uuid,uuid)'),('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'),
 ('public.v2_cutover_require_owner(uuid,uuid)'),('public.v2_cutover_source_fingerprint(uuid)'),('public.v2_cutover_validate_backfill(uuid,uuid)'),('public.v2_cutover_context_required()'),('public.v2_guard_cutover_evidence()'),('public.v2_cutover_command(uuid,uuid,uuid,uuid,text,jsonb)'),('public.v2_cutover_add_check(uuid,text,boolean,jsonb)'),('public.v2_guard_legacy_cutover_freeze()'),('public.v2_guard_product_batch_v2()'),('public.v2_guard_receivable()'),('public.v2_guard_settlement_entry()'))
select ok(to_regprocedure(sig)is not null,sig||' exists')from f;
with f(sig)as(values
 ('public.v2_start_cutover_reconciliation(uuid,uuid,uuid)'),('public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text)'),('public.v2_review_cutover_opening_stock(uuid,text,uuid,text)'),('public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text)'),('public.v2_materialize_cutover_opening_state(uuid,uuid)'),('public.v2_review_migration_exception(uuid,text,text,uuid)'),('public.v2_finalize_cutover_reconciliation(uuid,uuid)'),('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'),
 ('public.v2_cutover_require_owner(uuid,uuid)'),('public.v2_cutover_source_fingerprint(uuid)'),('public.v2_cutover_validate_backfill(uuid,uuid)'),('public.v2_cutover_context_required()'),('public.v2_guard_cutover_evidence()'),('public.v2_cutover_command(uuid,uuid,uuid,uuid,text,jsonb)'),('public.v2_cutover_add_check(uuid,text,boolean,jsonb)'),('public.v2_guard_legacy_cutover_freeze()'),('public.v2_guard_product_batch_v2()'),('public.v2_guard_receivable()'),('public.v2_guard_settlement_entry()'))
select ok((select array_to_string(proconfig,',')='search_path=""'from pg_proc where oid=sig::regprocedure),sig||' has empty search_path')from f;

with f(sig)as(values
 ('public.v2_start_cutover_reconciliation(uuid,uuid,uuid)'),('public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text)'),('public.v2_review_cutover_opening_stock(uuid,text,uuid,text)'),('public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text)'),('public.v2_materialize_cutover_opening_state(uuid,uuid)'),('public.v2_review_migration_exception(uuid,text,text,uuid)'),('public.v2_finalize_cutover_reconciliation(uuid,uuid)'),('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'))
select ok(has_function_privilege('service_role',sig,'EXECUTE'),'service_role executes '||sig)from f;
with f(sig)as(values
 ('public.v2_start_cutover_reconciliation(uuid,uuid,uuid)'),('public.v2_add_cutover_opening_stock_line(uuid,uuid,uuid,uuid,numeric,numeric,date,date,uuid,text)'),('public.v2_review_cutover_opening_stock(uuid,text,uuid,text)'),('public.v2_review_cutover_opening_debt(uuid,text,uuid,date,text)'),('public.v2_materialize_cutover_opening_state(uuid,uuid)'),('public.v2_review_migration_exception(uuid,text,text,uuid)'),('public.v2_finalize_cutover_reconciliation(uuid,uuid)'),('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' cannot execute service API '||sig)from f cross join(values('public'),('anon'),('authenticated'))roles(r);
with f(sig)as(values
 ('public.v2_cutover_require_owner(uuid,uuid)'),('public.v2_cutover_source_fingerprint(uuid)'),('public.v2_cutover_validate_backfill(uuid,uuid)'),('public.v2_cutover_context_required()'),('public.v2_guard_cutover_evidence()'),('public.v2_cutover_command(uuid,uuid,uuid,uuid,text,jsonb)'),('public.v2_cutover_add_check(uuid,text,boolean,jsonb)'),('public.v2_guard_legacy_cutover_freeze()'),('public.v2_guard_product_batch_v2()'),('public.v2_guard_receivable()'),('public.v2_guard_settlement_entry()'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' cannot execute internal '||sig)from f cross join(values('public'),('anon'),('authenticated'),('service_role'))roles(r);

select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='p'),t||' has primary key')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t);
select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='f'),t||' has foreign keys')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t);
select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='c'),t||' has checks')from(values
 ('cutover_reconciliation_runs'),('cutover_reconciliation_checks'),('cutover_opening_stock_lines'),('cutover_opening_debts'),('cutover_controls'))x(t);
select ok(to_regclass('public.'||i)is not null,i||' exists')from(values
 ('cutover_runs_org_created_idx'),('cutover_checks_run_result_idx'),('cutover_stock_run_status_idx'),('cutover_debts_run_status_idx'),('product_batches_v2_opening_source_key'),('receivables_opening_debt_key'))x(i);

select trigger_is('public',t,trg,'public',fn,trg||' installed')from(values
 ('cutover_reconciliation_runs','a_cutover_runs_context','v2_cutover_context_required'),('cutover_reconciliation_runs','b_cutover_runs_guard','v2_guard_cutover_evidence'),
 ('cutover_reconciliation_checks','a_cutover_checks_context','v2_cutover_context_required'),('cutover_reconciliation_checks','b_cutover_checks_guard','v2_guard_cutover_evidence'),
 ('cutover_opening_stock_lines','a_cutover_stock_context','v2_cutover_context_required'),('cutover_opening_stock_lines','b_cutover_stock_guard','v2_guard_cutover_evidence'),
 ('cutover_opening_debts','a_cutover_debts_context','v2_cutover_context_required'),('cutover_opening_debts','b_cutover_debts_guard','v2_guard_cutover_evidence'),
 ('cutover_controls','a_cutover_controls_context','v2_cutover_context_required'),('cutover_controls','b_cutover_controls_guard','v2_guard_cutover_evidence'))x(t,trg,fn);
select trigger_is('public',t,'v2_cutover_freeze_'||t,'public','v2_guard_legacy_cutover_freeze','freeze trigger on '||t)from(values
 ('users'),('user_store_access'),('stores'),('categories'),('brands'),('units'),('product_types'),('products'),('suppliers'),('customers'),('devices'),('product_batches'),('stock_movements'),('sales'),('sale_items'),('payments'),('shifts'),('debt_payments'),('debt_entries'),('sync_operations'),('operation_logs'))x(t);

select col_is_null('public','product_batches_v2','purchase_line_id','purchase batch source is nullable for exact opening alternative');
select col_is_null('public','receivables','sale_id','receivable sale source is nullable for exact opening alternative');
select has_column('public','product_batches_v2','opening_stock_line_id','batch has opening source');
select has_column('public','receivables','opening_debt_id','receivable has opening debt source');
select ok(exists(select 1 from pg_constraint where conname='product_batches_v2_exact_source_check'),'batch exact-one source check exists');
select ok(exists(select 1 from pg_constraint where conname='receivables_exact_source_check'),'receivable exact-one source check exists');
select ok((select pg_get_constraintdef(oid)like'%opening_debt%'from pg_constraint where conname='settlement_entries_type_check'),'settlement entry type includes opening debt');
select ok((select pg_get_constraintdef(oid)like'%opening_debt%'from pg_constraint where conname='settlement_entries_source_check'),'settlement source includes opening debt');

select is((select count(*)from permissions),54::bigint,'permission registry remains 54');
select is((select count(*)from permissions where critical),10::bigint,'critical permissions remain 10');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000101'),54::bigint,'owner template remains 54');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000102'),16::bigint,'seller template remains 16');
select is((select count(*)from supabase_migrations.schema_migrations where version between'0001'and'0020'),20::bigint,'migrations 0001 through 0020 recorded');

-- A real 0019 apply run supplies the opening-state fixture and preserves its evidence.
create function pg_temp.run_backfill(run_id uuid,batch_size integer default 200)
returns void language plpgsql as $$
declare phase text;result jsonb;guard integer;
begin
 foreach phase in array array['identity_profiles','identity_access','locations','catalog_categories','catalog_category_parents','catalog_references','catalog_products','counterparties','pricing','cutover_assessment']loop
  guard:=0;loop result:=public.v2_run_backfill_batch(run_id,phase,batch_size);exit when result->>'status'='completed';guard:=guard+1;if guard>100 then raise exception'test runner guard';end if;end loop;
 end loop;
end$$;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000020201','authenticated','authenticated','owner-20@test.local','',now(),now()-interval'20 days',now()-interval'20 days');
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020101','Cutover Exact',now()-interval'20 days',now()-interval'20 days'),
 ('00000000-0000-0000-0000-000000020102','Cutover Other',now()-interval'20 days',now()-interval'20 days');

-- Eligibility is deliberately narrower than generic 0019 blocked status.
insert into migration_backfill_runs(id,organization_id,mode,source_snapshot_at,status,finished_at,summary)values
 ('00000000-0000-0000-0000-000000020901','00000000-0000-0000-0000-000000020102','apply',clock_timestamp()+interval'1 hour','prepared',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102'))),
 ('00000000-0000-0000-0000-000000020902','00000000-0000-0000-0000-000000020102','apply',clock_timestamp()+interval'1 hour','blocked',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102'))),
 ('00000000-0000-0000-0000-000000020903','00000000-0000-0000-0000-000000020102','apply',clock_timestamp()+interval'1 hour','blocked',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102'))),
 ('00000000-0000-0000-0000-000000020904','00000000-0000-0000-0000-000000020102','dry_run',clock_timestamp()+interval'1 hour','prepared',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102'))),
 ('00000000-0000-0000-0000-000000020905','00000000-0000-0000-0000-000000020102','apply',clock_timestamp()+interval'1 hour','stale',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102'))),
 ('00000000-0000-0000-0000-000000020906','00000000-0000-0000-0000-000000020102','apply',clock_timestamp()-interval'1 second','prepared',clock_timestamp(),jsonb_build_object('source_fingerprint',v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000020102')));
insert into migration_backfill_checkpoints(run_id,phase,status)
select r.id,p,'completed'from migration_backfill_runs r cross join unnest(array['identity_profiles','identity_access','locations','catalog_categories','catalog_category_parents','catalog_references','catalog_products','counterparties','pricing','cutover_assessment'])p
where r.id between'00000000-0000-0000-0000-000000020901'and'00000000-0000-0000-0000-000000020906';
insert into migration_backfill_findings(run_id,organization_id,phase,legacy_table,severity,error_code)values
 ('00000000-0000-0000-0000-000000020902','00000000-0000-0000-0000-000000020102','cutover_assessment','products','blocker','V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED'),
 ('00000000-0000-0000-0000-000000020903','00000000-0000-0000-0000-000000020102','locations','stores','blocker','V2_BACKFILL_TARGET_DIVERGED');
select lives_ok($$select (v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020901')).id$$,'prepared apply run eligible');
select lives_ok($$select (v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020902')).id$$,'blocked run with only opening blocker eligible');
select throws_ok($$select v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020903')$$,'P0001','V2_CUTOVER_BACKFILL_NOT_ELIGIBLE','structural blocker is ineligible');
select throws_ok($$select v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020904')$$,'P0001','V2_CUTOVER_BACKFILL_NOT_ELIGIBLE','dry-run is ineligible');
select throws_ok($$select v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020905')$$,'P0001','V2_CUTOVER_BACKFILL_NOT_ELIGIBLE','stale run is ineligible');
select lives_ok($$select (v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020906')).id$$,'current source passes 0019 freshness check');
insert into categories(organization_id,name,status)values('00000000-0000-0000-0000-000000020102','Post snapshot category','active');
select throws_ok($$select v2_cutover_validate_backfill('00000000-0000-0000-0000-000000020102','00000000-0000-0000-0000-000000020906')$$,'P0001','V2_CUTOVER_BACKFILL_SOURCE_CHANGED','post-snapshot V1 change denied');
insert into users(id,auth_user_id,organization_id,full_name,email,password_hash,role,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020301','00000000-0000-0000-0000-000000020201','00000000-0000-0000-0000-000000020101','Cutover Owner','owner20@test.local','never-exposed','owner','active',now()-interval'19 days',now()-interval'19 days');
insert into stores(id,organization_id,name,address,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020401','00000000-0000-0000-0000-000000020101','Cutover Store','Tashkent','active',now()-interval'18 days',now()-interval'18 days');
insert into products(id,organization_id,name,barcode,unit,sale_price,current_quantity,min_quantity,is_expirable,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020501','00000000-0000-0000-0000-000000020101','Opening Product','020501','pc',100,5,0,false,'active',now()-interval'17 days',now()-interval'17 days'),
 ('00000000-0000-0000-0000-000000020502','00000000-0000-0000-0000-000000020101','Manual Expirable Product','020502','pc',50,2,0,true,'active',now()-interval'17 days',now()-interval'17 days');
insert into product_batches(id,store_id,product_id,received_date,initial_quantity,remaining_quantity,purchase_price,sale_price_at_arrival,created_at)values
 ('00000000-0000-0000-0000-000000020511','00000000-0000-0000-0000-000000020401','00000000-0000-0000-0000-000000020501',current_date-10,5,5,40,100,now()-interval'16 days');
insert into customers(id,store_id,full_name,phone,current_debt,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020601','00000000-0000-0000-0000-000000020401','Opening Customer','998900000020',75,'active',now()-interval'15 days',now()-interval'15 days');
insert into devices(id,store_id,name,device_type,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000020701','00000000-0000-0000-0000-000000020401','Legacy POS','desktop','active',now()-interval'14 days',now()-interval'14 days');

create temp table fingerprint_samples(name text primary key,value jsonb);
insert into fingerprint_samples values('initial',v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'));
select is(v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'),(select value from fingerprint_samples where name='initial'),'full legacy fingerprint is deterministic');
select ok(not(v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101')::text like'%never-exposed%'),'fingerprint never exposes password content');
insert into categories(id,organization_id,name,status)values('00000000-0000-0000-0000-000000020801','00000000-0000-0000-0000-000000020101','Fingerprint Insert','active');
insert into fingerprint_samples values('inserted',v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'));
select isnt((select value from fingerprint_samples where name='inserted'),(select value from fingerprint_samples where name='initial'),'legacy insert changes fingerprint');
update categories set name='Fingerprint Update'where id='00000000-0000-0000-0000-000000020801';
insert into fingerprint_samples values('updated',v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'));
select isnt((select value from fingerprint_samples where name='updated'),(select value from fingerprint_samples where name='inserted'),'legacy update changes fingerprint');
delete from categories where id='00000000-0000-0000-0000-000000020801';
select is(v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'),(select value from fingerprint_samples where name='initial'),'legacy delete changes fingerprint back to exact source state');
select is((v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020102')->'products'->>'count')::bigint,0::bigint,'fingerprint is tenant scoped');
select is((select count(*)::integer from jsonb_object_keys(v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000020101'))),21,'fingerprint covers twenty-one authoritative V1 tables');

create temp table test_ids(name text primary key,id uuid not null);
insert into test_ids values('backfill',v2_start_backfill_run('00000000-0000-0000-0000-000000020101','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L)',(select id from test_ids where name='backfill')),'all real 0019 phases complete');
select is((v2_finalize_backfill_run((select id from test_ids where name='backfill'))->>'status'),'blocked','0019 run is blocked only for reviewed opening state');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_ids where name='backfill')and severity='blocker'and error_code not in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED')),0::bigint,'blocked run has no structural blocker');
select is((select count(*)from migration_backfill_checkpoints where run_id=(select id from test_ids where name='backfill')and status='completed'),10::bigint,'all ten backfill phases completed');

-- Re-enroll the legacy device deliberately; 0019 warning remains immutable evidence.
insert into devices_v2(organization_id,branch_id,register_id,legacy_device_id,name,device_type,fingerprint_hash,status)
select b.organization_id,b.id,r.id,'00000000-0000-0000-0000-000000020701','Cutover POS','desktop','cutover-device-20','trusted'
from branches b join registers r on r.branch_id=b.id where b.legacy_store_id='00000000-0000-0000-0000-000000020401';
select lives_ok(format('select v2_start_cutover_reconciliation(%L,%L,%L)','00000000-0000-0000-0000-000000020101',(select id from test_ids where name='backfill'),(select target_id from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000020101'and legacy_table='users'and legacy_key='00000000-0000-0000-0000-000000020301'and target_table='organization_memberships')),'blocked 0019 run with only opening blockers is eligible');
insert into test_ids select'cutover',id from cutover_reconciliation_runs where backfill_run_id=(select id from test_ids where name='backfill');
insert into test_ids select'owner',target_id from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000020101'and legacy_table='users'and legacy_key='00000000-0000-0000-0000-000000020301'and target_table='organization_memberships';
select is((select status from cutover_reconciliation_runs where id=(select id from test_ids where name='cutover')),'reviewing','cutover starts reviewing');
select is((select state from cutover_controls where organization_id='00000000-0000-0000-0000-000000020101'),'reviewing','control starts reviewing');
select is((select count(*)from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')),1::bigint,'exact legacy batch auto-proposes one stock line');
select is((select quantity from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')),5::numeric,'auto stock quantity is exact');
select is((select unit_cost from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')),40::numeric,'auto stock cost is exact');
select is((select count(*)from cutover_opening_debts where run_id=(select id from test_ids where name='cutover')),1::bigint,'positive legacy customer debt auto-proposes once');
select is((select amount from cutover_opening_debts where run_id=(select id from test_ids where name='cutover')),75::numeric,'opening debt amount equals current debt');
select is((select count(*)from purchase_documents where organization_id='00000000-0000-0000-0000-000000020101'),0::bigint,'start creates no purchase history');
select is((select count(*)from sales_v2 where organization_id='00000000-0000-0000-0000-000000020101'),0::bigint,'start creates no sale history');
select is((select count(*)from receivables where organization_id='00000000-0000-0000-0000-000000020101'),0::bigint,'start creates no receivable before review');

select throws_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')),'wrong',(select id from test_ids where name='owner'),'bad'),'P0001','V2_CUTOVER_OPENING_STOCK_REVIEW_INVALID','invalid stock decision rejected');
select lives_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')),'accepted',(select id from test_ids where name='owner'),'exact legacy batch'),'opening stock accepted');
select lives_ok(format('select v2_add_cutover_opening_stock_line(%L,%L,%L,%L,2,20,current_date,null,%L,%L)',(select id from test_ids where name='cutover'),(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401'),(select id from warehouses where branch_id=(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401')and is_primary),(select id from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000020502'),(select id from test_ids where name='owner'),'manual source review'),'manual opening line can fill unproven batch distribution');
select throws_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and legacy_product_id='00000000-0000-0000-0000-000000020502'and status='proposed'),'accepted',(select id from test_ids where name='owner'),'missing expiry'),'P0001','V2_CUTOVER_OPENING_STOCK_SCOPE_MISMATCH','expirable opening stock requires expiry');
select lives_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and legacy_product_id='00000000-0000-0000-0000-000000020502'and status='proposed'),'rejected',(select id from test_ids where name='owner'),'replaced with exact expiry'),'invalid manual evidence is rejected');
select lives_ok(format('select v2_add_cutover_opening_stock_line(%L,%L,%L,%L,2,20,current_date,current_date+90,%L,%L)',(select id from test_ids where name='cutover'),(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401'),(select id from warehouses where branch_id=(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401')and is_primary),(select id from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000020502'),(select id from test_ids where name='owner'),'known expiry'),'replacement manual line records exact expiry');
select throws_ok(format('select v2_add_cutover_opening_stock_line(%L,%L,%L,%L,1,20,current_date,current_date+90,%L,%L)',(select id from test_ids where name='cutover'),(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401'),(select id from warehouses where branch_id=(select id from branches where legacy_store_id='00000000-0000-0000-0000-000000020401')and is_primary),(select id from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000020502'),(select id from test_ids where name='owner'),'over allocation'),'P0001','V2_CUTOVER_OPENING_STOCK_OVERALLOCATED','manual opening stock cannot exceed V1 current quantity');
select lives_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and legacy_product_id='00000000-0000-0000-0000-000000020502'and status='proposed'),'accepted',(select id from test_ids where name='owner'),'exact manual expiry'),'valid expirable manual line accepted');
select lives_ok(format('select v2_review_cutover_opening_debt(%L,%L,%L,%L,%L)',(select id from cutover_opening_debts where run_id=(select id from test_ids where name='cutover')),'accepted',(select id from test_ids where name='owner'),current_date+30,'reviewed legacy balance'),'opening debt accepted');
select is((select status from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and legacy_product_id='00000000-0000-0000-0000-000000020501'),'accepted','auto stock lifecycle reached accepted');
select is((select status from cutover_opening_debts where run_id=(select id from test_ids where name='cutover')),'accepted','debt lifecycle reached accepted');
select throws_ok(format('select v2_review_cutover_opening_stock(%L,%L,%L,%L)',(select id from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and legacy_product_id='00000000-0000-0000-0000-000000020501'),'rejected',(select id from test_ids where name='owner'),'late'),'P0001','V2_CUTOVER_OPENING_STOCK_REVIEW_INVALID','accepted stock cannot be rejected');

-- Resolve the non-opening device warning through the explicit service review API.
select lives_ok(format('select v2_review_migration_exception(%L,%L,%L,%L)',(select id from migration_exceptions where organization_id='00000000-0000-0000-0000-000000020101'and error_code='V2_BACKFILL_DEVICE_REENROLL_REQUIRED'and status='open'),'accepted','device re-enrolled as trusted V2 device',(select id from test_ids where name='owner')),'ordinary migration warning can be accepted');
select throws_ok(format('select v2_review_migration_exception(%L,%L,%L,%L)',(select id from migration_exceptions where organization_id='00000000-0000-0000-0000-000000020101'and error_code='V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED'and status='open'order by id limit 1),'accepted','not materialized',(select id from test_ids where name='owner')),'P0001','V2_CUTOVER_OPENING_MATERIALIZATION_REQUIRED','opening exception cannot be manually accepted');

select lives_ok(format('select v2_materialize_cutover_opening_state(%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner')),'reviewed opening state materializes');
select is((select count(*)from cutover_opening_stock_lines where run_id=(select id from test_ids where name='cutover')and status='materialized'),2::bigint,'both accepted stock lines materialized');
select is((select status from cutover_opening_debts where run_id=(select id from test_ids where name='cutover')),'materialized','opening debt materialized');
select is((select count(*)from inventory_documents where organization_id='00000000-0000-0000-0000-000000020101'and document_type='opening'),2::bigint,'one explicit document per accepted opening stock line created');
select is((select count(*)from purchase_documents where organization_id='00000000-0000-0000-0000-000000020101'),0::bigint,'opening stock creates no synthetic purchase');
select is((select count(*)from product_batches_v2 where organization_id='00000000-0000-0000-0000-000000020101'and purchase_line_id is null and opening_stock_line_id is not null),2::bigint,'opening batches use only opening source');
select is((select sum(on_hand_quantity)from inventory_balances where organization_id='00000000-0000-0000-0000-000000020101'and batch_id is not null),7::numeric,'batch inventory projection equals all opening quantities');
select is((select sum(on_hand_quantity)from inventory_balances where organization_id='00000000-0000-0000-0000-000000020101'and batch_id is null),7::numeric,'aggregate inventory projection equals all opening quantities');
select is((select count(*)from inventory_movements where organization_id='00000000-0000-0000-0000-000000020101'and movement_type='opening'),2::bigint,'canonical opening movements created once per line');
select is((select count(*)from sales_v2 where organization_id='00000000-0000-0000-0000-000000020101'),0::bigint,'opening debt creates no synthetic sale');
select is((select count(*)from receivables where organization_id='00000000-0000-0000-0000-000000020101'and sale_id is null and opening_debt_id is not null),1::bigint,'opening receivable uses exact opening source');
select is((select original_amount from receivables where organization_id='00000000-0000-0000-0000-000000020101'),75::numeric,'opening receivable original amount exact');
select is((select outstanding_amount from receivables where organization_id='00000000-0000-0000-0000-000000020101'),75::numeric,'opening receivable outstanding amount exact');
select is((select count(*)from settlement_entries where organization_id='00000000-0000-0000-0000-000000020101'and entry_type='opening_debt'and source_document_type='opening_debt'),1::bigint,'positive opening settlement entry created once');
select is((select amount_delta from settlement_entries where organization_id='00000000-0000-0000-0000-000000020101'and entry_type='opening_debt'),75::numeric,'opening settlement amount exact');
select is((select count(*)from command_log where organization_id='00000000-0000-0000-0000-000000020101'and command_type like'cutover.opening_%'and status='succeeded'),3::bigint,'opening materialization commands succeeded');
select is((select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000020101'and error_code in('V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED','V2_BACKFILL_STOCK_SOURCE_MISMATCH','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED')and status='open'),0::bigint,'opening exceptions resolve only after materialization');
select lives_ok(format('select v2_materialize_cutover_opening_state(%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner')),'exact materialization replay succeeds');
select is((select count(*)from inventory_documents where organization_id='00000000-0000-0000-0000-000000020101'),2::bigint,'materialization replay creates no duplicate document');
select is((select count(*)from receivables where organization_id='00000000-0000-0000-0000-000000020101'),1::bigint,'materialization replay creates no duplicate receivable');
select is((select count(*)from settlement_entries where organization_id='00000000-0000-0000-0000-000000020101'),1::bigint,'materialization replay creates no duplicate settlement entry');

select lives_ok(format('select v2_finalize_cutover_reconciliation(%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner')),'final reconciliation executes');
select is((select count(*)from cutover_reconciliation_checks where run_id=(select id from test_ids where name='cutover')),24::bigint,'mandatory reconciliation matrix has twenty-four checks');
select is((select count(*)from cutover_reconciliation_checks where run_id=(select id from test_ids where name='cutover')and not passed),0::bigint,'all blocker checks pass for exact fixture');
select is((select status from cutover_reconciliation_runs where id=(select id from test_ids where name='cutover')),'ready','successful reconciliation becomes ready');
select is((select state from cutover_controls where organization_id='00000000-0000-0000-0000-000000020101'),'ready','control records ready evidence');
select is((select settings from organization_settings where organization_id='00000000-0000-0000-0000-000000020101'),'{}'::jsonb,'ready does not flip application settings');
select lives_ok(format('select v2_finalize_cutover_reconciliation(%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner')),'final reconciliation replay stable');
select is((select count(*)from cutover_reconciliation_checks where run_id=(select id from test_ids where name='cutover')),24::bigint,'replay does not duplicate checks');
select throws_ok(format('select v2_freeze_legacy_for_cutover(%L,%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner'),'WRONG'),'P0001','V2_CUTOVER_FREEZE_CONFIRMATION_REQUIRED','freeze requires exact confirmation');
select lives_ok(format('select v2_freeze_legacy_for_cutover(%L,%L,%L)',(select id from test_ids where name='cutover'),(select id from test_ids where name='owner'),'FREEZE_LEGACY_WRITES'),'explicit legacy freeze succeeds');
select is((select status from cutover_reconciliation_runs where id=(select id from test_ids where name='cutover')),'frozen','run records frozen state');
select is((select state from cutover_controls where organization_id='00000000-0000-0000-0000-000000020101'),'legacy_frozen','control records real legacy freeze');
select is((select count(*)from audit_events where organization_id='00000000-0000-0000-0000-000000020101'and action='cutover.legacy_writes_frozen'),1::bigint,'freeze emits safe audit evidence');
select is((select count(*)from outbox_events where organization_id='00000000-0000-0000-0000-000000020101'and event_type='LegacyWritesFrozenForCutover'),1::bigint,'freeze emits outbox evidence');
select throws_ok($$update products set name='Denied after freeze'where id='00000000-0000-0000-0000-000000020501'$$,'P0001','V2_LEGACY_WRITES_FROZEN','legacy product update denied after freeze');
select throws_ok($$insert into categories(organization_id,name,status)values('00000000-0000-0000-0000-000000020101','Denied category','active')$$,'P0001','V2_LEGACY_WRITES_FROZEN','legacy category insert denied after freeze');
select lives_ok($$insert into categories(organization_id,name,status)values('00000000-0000-0000-0000-000000020102','Other tenant remains writable','active')$$,'another organization remains writable');
select ok(to_regprocedure('public.v2_unfreeze_legacy_for_cutover(uuid,uuid)')is null,'no general unfreeze API exists');
select throws_ok(format('delete from cutover_reconciliation_runs where id=%L',(select id from test_ids where name='cutover')),'P0001','V2_CUTOVER_SERVICE_CONTEXT_REQUIRED','cutover evidence hard delete denied outside service context');
select throws_ok(format('update cutover_opening_stock_lines set quantity=6 where run_id=%L',(select id from test_ids where name='cutover')),'P0001','V2_CUTOVER_SERVICE_CONTEXT_REQUIRED','opening stock source evidence immutable outside service context');

select * from finish();
rollback;
