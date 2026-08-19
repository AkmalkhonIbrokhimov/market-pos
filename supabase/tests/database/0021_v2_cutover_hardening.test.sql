begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(89);

-- Corrective surface and immutable contracts.
select ok(to_regprocedure('public.v2_lock_legacy_cutover_sources()')is not null,'static legacy source lock helper exists');
select ok(to_regprocedure('public.v2_cutover_settlement_acts_reconciled(uuid)')is not null,'canonical act reconciliation helper exists');
select ok(to_regprocedure('public.v2_finalize_cutover_reconciliation(uuid,uuid)')is not null,'final reconciliation remains available');
select ok(to_regprocedure('public.v2_guard_legacy_cutover_freeze()')is not null,'legacy freeze guard remains available');
select ok(to_regprocedure('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)')is not null,'final freeze remains available');
select ok((select array_to_string(proconfig,',')='search_path=""'from pg_proc where oid=sig::regprocedure),sig||' has empty search_path')from(values
 ('public.v2_lock_legacy_cutover_sources()'),('public.v2_cutover_settlement_acts_reconciled(uuid)'),
 ('public.v2_finalize_cutover_reconciliation(uuid,uuid)'),('public.v2_guard_legacy_cutover_freeze()'),
 ('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'))x(sig);
select ok(not has_function_privilege(r,'public.v2_lock_legacy_cutover_sources()','EXECUTE'),r||' cannot execute source lock helper')
from(values('public'),('anon'),('authenticated'),('service_role'))x(r);
select ok(not has_function_privilege(r,'public.v2_cutover_settlement_acts_reconciled(uuid)','EXECUTE'),r||' cannot execute act reconciliation helper')
from(values('public'),('anon'),('authenticated'),('service_role'))x(r);
select is((select count(*)from permissions),54::bigint,'permission registry remains 54');
select is((select count(*)from permissions where critical),10::bigint,'critical permission count remains 10');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000101'),54::bigint,'owner template remains 54');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000102'),16::bigint,'seller template remains 16');
select is((select count(*)from supabase_migrations.schema_migrations where version between'0001'and'0021'),21::bigint,'migrations 0001 through 0021 recorded');

-- Every authoritative V1 relation is named statically and no dynamic SQL exists.
with d as(select pg_get_functiondef('public.v2_lock_legacy_cutover_sources()'::regprocedure)body)
select ok(position('public.'||t in body)>0,'source lock covers public.'||t)from d cross join(values
 ('brands'),('categories'),('customers'),('debt_entries'),('debt_payments'),('devices'),('operation_logs'),
 ('payments'),('product_batches'),('product_types'),('products'),('sale_items'),('sales'),('shifts'),
 ('stock_movements'),('stores'),('suppliers'),('sync_operations'),('units'),('user_store_access'),('users'))x(t);
select ok(position('share row exclusive mode'in lower(pg_get_functiondef('public.v2_lock_legacy_cutover_sources()'::regprocedure)))>0,'source lock conflicts with ordinary V1 writes');
select ok(position('execute'in lower(pg_get_functiondef('public.v2_lock_legacy_cutover_sources()'::regprocedure)))=0,'source lock helper contains no dynamic SQL');
select ok(position('old_organization_id'in pg_get_functiondef('public.v2_guard_legacy_cutover_freeze()'::regprocedure))>0,'freeze guard resolves OLD scope');
select ok(position('new_organization_id'in pg_get_functiondef('public.v2_guard_legacy_cutover_freeze()'::regprocedure))>0,'freeze guard resolves NEW scope');
select ok(position('v2_lock_legacy_cutover_sources'in f)<position('v2_cutover_source_fingerprint'in f),'relation lock precedes final fingerprint')
from(select pg_get_functiondef('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'::regprocedure)f)x;
select ok(position('v2_lock_legacy_cutover_sources'in f)<position('state=''legacy_frozen'''in f),'relation lock precedes frozen state mutation')
from(select pg_get_functiondef('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'::regprocedure)f)x;
select ok(position('v2_lock_legacy_cutover_sources'in f)<position('status=''processing'''in f),'relation lock precedes queue drain check')
from(select pg_get_functiondef('public.v2_freeze_legacy_for_cutover(uuid,uuid,text)'::regprocedure)f)x;
select ok(position('original_amount'in f)>0 and position('outstanding_amount'in f)>0,'opening debt coverage checks original and outstanding balances')
from(select pg_get_functiondef('public.v2_finalize_cutover_reconciliation(uuid,uuid)'::regprocedure)f)x;
select ok(position('business_date,e.created_at,e.id'in replace(f,' ',''))>0,'act reconciliation uses canonical business_date, created_at, id order')
from(select pg_get_functiondef('public.v2_cutover_settlement_acts_reconciled(uuid)'::regprocedure)f)x;

-- Main owner fixture used by real opening, sale, debt, purchase and cash workflows.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000021001','authenticated','authenticated','owner21@test.local','',now(),now(),now());
insert into organizations(id,name)values('00000000-0000-0000-0000-000000021101','Org21 Main');
insert into organization_settings(organization_id,currency_code,timezone)values('00000000-0000-0000-0000-000000021101','UZS','Asia/Tashkent');
insert into user_profiles(id,auth_user_id,full_name)values('00000000-0000-0000-0000-000000021201','00000000-0000-0000-0000-000000021001','Owner21');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at)values
 ('00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021201','owner','active',now());
insert into membership_permission_profiles(membership_id,permission_profile_id,assigned_by)values
 ('00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000021301');
insert into stores(id,organization_id,name,status)values('00000000-0000-0000-0000-000000021401','00000000-0000-0000-0000-000000021101','Legacy Main','active');
insert into branches(id,organization_id,code,name,legacy_store_id)values('00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021101','B21','Branch21','00000000-0000-0000-0000-000000021401');
insert into warehouses(id,organization_id,branch_id,code,name,is_primary)values('00000000-0000-0000-0000-000000021501','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','W21','Warehouse21',true);
insert into registers(id,organization_id,branch_id,default_warehouse_id,code,name)values('00000000-0000-0000-0000-000000021601','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021501','R21','Register21');
insert into devices_v2(id,organization_id,branch_id,register_id,name,device_type,fingerprint_hash,status)values('00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601','Device21','desktop','fingerprint-21','trusted');

insert into products(id,organization_id,name,barcode,unit,sale_price,current_quantity,min_quantity,is_expirable,status)values
 ('00000000-0000-0000-0000-000000021801','00000000-0000-0000-0000-000000021101','Opening Product','OPEN-21','pc',10,2,0,false,'active'),
 ('00000000-0000-0000-0000-000000021802','00000000-0000-0000-0000-000000021101','Purchase Product','PUR-21','pc',12,0,0,false,'active');
insert into customers(id,store_id,full_name,current_debt,status)values('00000000-0000-0000-0000-000000021901','00000000-0000-0000-0000-000000021401','Opening Customer',75,'active');

select set_config('market_pos.catalog_command','on',true);
insert into units_v2(id,organization_id,code,name,short_name)values('00000000-0000-0000-0000-000000021810','00000000-0000-0000-0000-000000021101','EA21','Each21','ea');
insert into products_v2(id,organization_id,legacy_product_id,sku,name,base_unit_id)values
 ('00000000-0000-0000-0000-000000021811','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021801','OPEN21','Opening Product','00000000-0000-0000-0000-000000021810'),
 ('00000000-0000-0000-0000-000000021812','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021802','PUR21','Purchase Product','00000000-0000-0000-0000-000000021810');
select set_config('market_pos.catalog_command','off',true);

select set_config('market_pos.counterparty_command','on',true);
insert into counterparties(id,organization_id,legacy_customer_id,display_name)values('00000000-0000-0000-0000-000000021920','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021901','Customer Supplier 21');
insert into counterparties(id,organization_id,display_name)values('00000000-0000-0000-0000-000000021923','00000000-0000-0000-0000-000000021101','Supplier 21');
insert into counterparty_roles(id,organization_id,counterparty_id,role_code)values
 ('00000000-0000-0000-0000-000000021921','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021920','customer'),
 ('00000000-0000-0000-0000-000000021924','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021923','supplier');
select set_config('market_pos.counterparty_command','off',true);

select set_config('market_pos.pricing_command','on',true);
insert into price_lists(id,organization_id,branch_id,code,name,currency_code,is_default)values('00000000-0000-0000-0000-000000021830','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','POS21','POS21','UZS',true);
insert into product_prices(id,organization_id,price_list_id,product_id,amount,currency_code,valid_from,confirmed_by)values
 ('00000000-0000-0000-0000-000000021831','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021830','00000000-0000-0000-0000-000000021811',10,'UZS',now()-interval'1 hour','00000000-0000-0000-0000-000000021301'),
 ('00000000-0000-0000-0000-000000021832','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021830','00000000-0000-0000-0000-000000021812',12,'UZS',now()-interval'1 hour','00000000-0000-0000-0000-000000021301');
select set_config('market_pos.pricing_command','off',true);

insert into migration_backfill_runs(id,organization_id,mode,source_snapshot_at,status,finished_at,summary)values
 ('00000000-0000-0000-0000-000000021940','00000000-0000-0000-0000-000000021101','apply',clock_timestamp(),'prepared',clock_timestamp(),'{}');
select set_config('market_pos.cutover_command','on',true);
insert into cutover_reconciliation_runs(id,organization_id,backfill_run_id,owner_membership_id,source_fingerprint,cutoff_at,business_date,status,summary)values
 ('00000000-0000-0000-0000-000000021941','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021940','00000000-0000-0000-0000-000000021301',v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000021101'),clock_timestamp(),current_date,'reviewing',jsonb_build_object('baseline',jsonb_build_object('purchases',0,'sales',0,'payments',0,'shifts',0,'sync_commands',0)));
insert into cutover_controls(organization_id,reconciliation_run_id,state,source_fingerprint)values
 ('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021941','reviewing',v2_cutover_source_fingerprint('00000000-0000-0000-0000-000000021101'));
insert into cutover_opening_stock_lines(id,run_id,organization_id,source_kind,legacy_product_id,branch_id,warehouse_id,product_id,unit_id,quantity,unit_cost,currency_code,received_date,status,reviewed_by,reviewed_at,operation_id)values
 ('00000000-0000-0000-0000-000000021942','00000000-0000-0000-0000-000000021941','00000000-0000-0000-0000-000000021101','manual','00000000-0000-0000-0000-000000021801','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021501','00000000-0000-0000-0000-000000021811','00000000-0000-0000-0000-000000021810',2,4,'UZS',current_date-10,'accepted','00000000-0000-0000-0000-000000021301',clock_timestamp(),'00000000-0000-0000-0000-000000021943');
insert into cutover_opening_debts(id,run_id,organization_id,legacy_customer_id,branch_id,counterparty_id,amount,currency_code,as_of_date,due_date,status,reviewed_by,reviewed_at,operation_id)values
 ('00000000-0000-0000-0000-000000021944','00000000-0000-0000-0000-000000021941','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021901','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021920',75,'UZS',current_date,current_date+30,'accepted','00000000-0000-0000-0000-000000021301',clock_timestamp(),'00000000-0000-0000-0000-000000021945');
select set_config('market_pos.cutover_command','off',true);

select lives_ok($$select v2_materialize_cutover_opening_state('00000000-0000-0000-0000-000000021941','00000000-0000-0000-0000-000000021301')$$,'reviewed opening state materializes through service API');
select is((select count(*)from product_batches_v2 where opening_stock_line_id='00000000-0000-0000-0000-000000021942'),1::bigint,'one exact opening-source batch materialized');
select is((select outstanding_amount from receivables where opening_debt_id='00000000-0000-0000-0000-000000021944'),75.0000::numeric,'opening receivable begins at exact V1 debt');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000021001',true);
set local role authenticated;
select lives_ok($$select v2_open_shift('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601','00000000-0000-0000-0000-000000021701',100,'UZS',current_date,'00000000-0000-0000-0000-000000021950')$$,'owner opens operational shift after materialization');
select lives_ok($$select v2_post_sale('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601','00000000-0000-0000-0000-000000021501',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000021601'),null,'S21-OPEN',current_date,'UZS','00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021951',now(),jsonb_build_array(jsonb_build_object('line_number',1,'product_id','00000000-0000-0000-0000-000000021811','unit_id','00000000-0000-0000-0000-000000021810','product_price_id','00000000-0000-0000-0000-000000021831','effective_at',now(),'quantity',1,'unit_factor',1,'unit_sale_price',10,'discount_amount',0,'tax_amount',0)),jsonb_build_array(jsonb_build_object('method','cash','amount',10,'local_operation_id','00000000-0000-0000-0000-000000021952')),null)$$,'normal FEFO sale consumes opening-source batch');
select lives_ok($$select v2_create_purchase_draft('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021501','00000000-0000-0000-0000-000000021923','P21-1',current_date,'UZS',null,'00000000-0000-0000-0000-000000021953')$$,'normal purchase draft created');
select lives_ok($$select v2_upsert_purchase_line(null,(select id from purchase_documents where document_number='P21-1'),1,'00000000-0000-0000-0000-000000021812','00000000-0000-0000-0000-000000021810',3,1,10,null,'P21-LOT')$$,'normal purchase line created');
select lives_ok($$select v2_post_purchase((select id from purchase_documents where document_number='P21-1'),'00000000-0000-0000-0000-000000021954','{}')$$,'normal purchase posts and creates purchase-source batch');
select lives_ok($$select v2_post_sale('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601','00000000-0000-0000-0000-000000021501',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000021601'),null,'S21-PURCHASE',current_date,'UZS','00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021955',now(),jsonb_build_array(jsonb_build_object('line_number',1,'product_id','00000000-0000-0000-0000-000000021812','unit_id','00000000-0000-0000-0000-000000021810','product_price_id','00000000-0000-0000-0000-000000021832','effective_at',now(),'quantity',1,'unit_factor',1,'unit_sale_price',12,'discount_amount',0,'tax_amount',0)),jsonb_build_array(jsonb_build_object('method','card','amount',12,'local_operation_id','00000000-0000-0000-0000-000000021956')),null)$$,'normal FEFO sale consumes purchase-source batch');
select lives_ok($$select v2_record_debt_payment('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000021601'),'00000000-0000-0000-0000-000000021920','DP21-EXPLICIT',current_date,'UZS','00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021957',now(),jsonb_build_array(jsonb_build_object('method','cash','amount',10,'local_operation_id','00000000-0000-0000-0000-000000021958')),jsonb_build_array(jsonb_build_object('receivable_id',(select id from receivables where opening_debt_id='00000000-0000-0000-0000-000000021944'),'amount',10)))$$,'public debt payment explicitly allocates to opening receivable');
select lives_ok($$select v2_record_debt_payment('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000021601'),'00000000-0000-0000-0000-000000021920','DP21-AUTO',current_date,'UZS','00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021959',now(),jsonb_build_array(jsonb_build_object('method','card','amount',5,'local_operation_id','00000000-0000-0000-0000-000000021960')),'[]'::jsonb)$$,'empty allocation mode selects opening receivable');
select lives_ok($$select v2_record_supplier_payment('00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021411','00000000-0000-0000-0000-000000021601',(select id from shifts_v2 where register_id='00000000-0000-0000-0000-000000021601'),'00000000-0000-0000-0000-000000021923','SP21-1',current_date,'UZS','00000000-0000-0000-0000-000000021701','00000000-0000-0000-0000-000000021961',now(),jsonb_build_array(jsonb_build_object('method','card','amount',-5,'local_operation_id','00000000-0000-0000-0000-000000021962')))$$,'supplier settlement source graph remains operational');
reset role;

select is((select a.quantity from sale_line_batch_allocations a join sale_lines_v2 l on l.id=a.sale_line_id join sales_v2 s on s.id=l.sale_id where s.document_number='S21-OPEN'),1.000000::numeric,'opening-source FEFO allocation exact');
select ok((select pb.opening_stock_line_id is not null and pb.purchase_line_id is null from sale_line_batch_allocations a join sale_lines_v2 l on l.id=a.sale_line_id join sales_v2 s on s.id=l.sale_id join product_batches_v2 pb on pb.id=a.product_batch_id where s.document_number='S21-OPEN'),'opening sale preserves exact opening batch source');
select ok((select pb.purchase_line_id is not null and pb.opening_stock_line_id is null from sale_line_batch_allocations a join sale_lines_v2 l on l.id=a.sale_line_id join sales_v2 s on s.id=l.sale_id join product_batches_v2 pb on pb.id=a.product_batch_id where s.document_number='S21-PURCHASE'),'purchase sale preserves exact purchase batch source');
select is((select outstanding_amount from receivables where opening_debt_id='00000000-0000-0000-0000-000000021944'),60.0000::numeric,'explicit and auto payments reduce opening receivable exactly');
select is((select count(*)from debt_allocations a join receivables r on r.id=a.receivable_id where r.opening_debt_id='00000000-0000-0000-0000-000000021944'),2::bigint,'opening receivable has explicit and auto allocations');
select is((select count(*)from cash_movements c join payments_v2 p on p.id=c.source_id join debt_payments_v2 d on d.id=p.debt_payment_id where c.source_type='payment'and c.movement_type='debt_payment'and d.document_number='DP21-EXPLICIT'),1::bigint,'cash debt payment creates exact 0016 cash movement');
select is((select count(*)from settlement_entries e join supplier_payments p on p.id=e.source_document_id where e.source_document_type='supplier_payment'and e.entry_type='supplier_payment'and p.document_number='SP21-1'),1::bigint,'supplier settlement entry keeps exact 0016 source graph');

-- Canonical settlement act detects amount tamper, missing membership, and hash tamper.
insert into command_log(id,organization_id,actor_membership_id,local_operation_id,command_type,payload_hash)values
 ('00000000-0000-0000-0000-000000021970','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000021971','settlement.test.period',repeat('a',64)),
 ('00000000-0000-0000-0000-000000021972','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000021973','settlement.test.act',repeat('b',64));
set local session_replication_role=replica;
insert into settlement_periods(id,organization_id,counterparty_id,currency_code,starts_on,ends_on,status,opening_balance,closing_balance,closed_by,closed_at,created_by,command_id)
select'00000000-0000-0000-0000-000000021974','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021920','UZS',current_date,current_date+1,'closed',0,coalesce(sum(amount_delta),0),'00000000-0000-0000-0000-000000021301',clock_timestamp(),'00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000021970'from settlement_entries where organization_id='00000000-0000-0000-0000-000000021101'and counterparty_id='00000000-0000-0000-0000-000000021920'and currency_code='UZS'and business_date=current_date;
with ordered as(select e.*,row_number()over(order by business_date,created_at,id)ln from settlement_entries e where e.organization_id='00000000-0000-0000-0000-000000021101'and e.counterparty_id='00000000-0000-0000-0000-000000021920'and e.currency_code='UZS'and e.business_date=current_date),canonical as(select jsonb_build_object('schema_version',1,'organization_id','00000000-0000-0000-0000-000000021101'::uuid,'counterparty_id','00000000-0000-0000-0000-000000021920'::uuid,'currency_code','UZS'::char(3),'starts_on',current_date,'ends_on',current_date+1,'opening_balance',0::numeric,'entries',coalesce(jsonb_agg(jsonb_build_object('id',id,'entry_type',entry_type,'amount_delta',amount_delta,'business_date',business_date)order by ln),'[]'::jsonb),'closing_balance',coalesce(sum(amount_delta),0))j,coalesce(sum(amount_delta)filter(where amount_delta>0),0)debit,coalesce(abs(sum(amount_delta)filter(where amount_delta<0)),0)credit,coalesce(sum(amount_delta),0)closing from ordered)
insert into settlement_acts(id,organization_id,settlement_period_id,act_number,total_debit,total_credit,closing_balance,snapshot_hash,created_by,command_id)select'00000000-0000-0000-0000-000000021975','00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021974','ACT21',debit,credit,closing,encode(extensions.digest(j::text,'sha256'),'hex'),'00000000-0000-0000-0000-000000021301','00000000-0000-0000-0000-000000021972'from canonical;
insert into settlement_act_lines(id,organization_id,settlement_act_id,settlement_entry_id,line_number,amount_delta)select gen_random_uuid(),'00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021975',id,row_number()over(order by business_date,created_at,id),amount_delta from settlement_entries where organization_id='00000000-0000-0000-0000-000000021101'and counterparty_id='00000000-0000-0000-0000-000000021920'and currency_code='UZS'and business_date=current_date;
set local session_replication_role=origin;
select ok(v2_cutover_settlement_acts_reconciled('00000000-0000-0000-0000-000000021101'),'canonical act initially reconciles');
set local session_replication_role=replica;update settlement_act_lines set amount_delta=amount_delta+1 where settlement_act_id='00000000-0000-0000-0000-000000021975'and line_number=1;set local session_replication_role=origin;
select ok(not v2_cutover_settlement_acts_reconciled('00000000-0000-0000-0000-000000021101'),'act line amount tamper is detected');
set local session_replication_role=replica;update settlement_act_lines l set amount_delta=e.amount_delta from settlement_entries e where l.settlement_entry_id=e.id and l.settlement_act_id='00000000-0000-0000-0000-000000021975'and l.line_number=1;delete from settlement_act_lines where settlement_act_id='00000000-0000-0000-0000-000000021975'and line_number=(select max(line_number)from settlement_act_lines where settlement_act_id='00000000-0000-0000-0000-000000021975');set local session_replication_role=origin;
select ok(not v2_cutover_settlement_acts_reconciled('00000000-0000-0000-0000-000000021101'),'missing act line is detected');
set local session_replication_role=replica;delete from settlement_act_lines where settlement_act_id='00000000-0000-0000-0000-000000021975';insert into settlement_act_lines(id,organization_id,settlement_act_id,settlement_entry_id,line_number,amount_delta)select gen_random_uuid(),'00000000-0000-0000-0000-000000021101','00000000-0000-0000-0000-000000021975',id,row_number()over(order by business_date,created_at,id),amount_delta from settlement_entries where organization_id='00000000-0000-0000-0000-000000021101'and counterparty_id='00000000-0000-0000-0000-000000021920'and currency_code='UZS'and business_date=current_date;update settlement_acts set snapshot_hash=repeat('f',64)where id='00000000-0000-0000-0000-000000021975';set local session_replication_role=origin;
select ok(not v2_cutover_settlement_acts_reconciled('00000000-0000-0000-0000-000000021101'),'wrong canonical snapshot hash is detected');

select lives_ok($$select v2_finalize_cutover_reconciliation('00000000-0000-0000-0000-000000021941','00000000-0000-0000-0000-000000021301')$$,'reconciliation reruns after opening balance activity');
select ok(not(select passed from cutover_reconciliation_checks where run_id='00000000-0000-0000-0000-000000021941'and check_code='OPENING_DEBT_COVERAGE'),'opening debt changed after materialization blocks coverage');
select ok((select passed from cutover_reconciliation_checks where run_id='00000000-0000-0000-0000-000000021941'and check_code='SETTLEMENT_RECONCILIATION'),'opening settlement position follows authoritative receivable outstanding');
select ok(not(select passed from cutover_reconciliation_checks where run_id='00000000-0000-0000-0000-000000021941'and check_code='SETTLEMENT_ACT_RECONCILIATION'),'tampered act blocks final reconciliation');
select is((select count(*)from cutover_reconciliation_checks where run_id='00000000-0000-0000-0000-000000021941'),24::bigint,'all existing twenty-four checks are preserved');

-- OLD and NEW scopes both block attempts to move legacy rows out of a frozen tenant.
insert into organizations(id,name)values
 ('00000000-0000-0000-0000-000000021102','Org21 Frozen'),
 ('00000000-0000-0000-0000-000000021103','Org21 Unfrozen');
insert into stores(id,organization_id,name,status)values
 ('00000000-0000-0000-0000-000000021402','00000000-0000-0000-0000-000000021102','Frozen Store','active'),
 ('00000000-0000-0000-0000-000000021403','00000000-0000-0000-0000-000000021103','Open Store','active');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000021002','authenticated','authenticated','frozen21@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000021003','authenticated','authenticated','open21@test.local','',now(),now(),now());
insert into users(id,auth_user_id,organization_id,full_name,email,password_hash,role,status)values
 ('00000000-0000-0000-0000-000000021302','00000000-0000-0000-0000-000000021002','00000000-0000-0000-0000-000000021102','Frozen User','frozen-v1@test.local','x','owner','active'),
 ('00000000-0000-0000-0000-000000021303','00000000-0000-0000-0000-000000021003','00000000-0000-0000-0000-000000021103','Open User','open-v1@test.local','x','owner','active');
insert into user_store_access(id,user_id,store_id,role_in_store)values
 ('00000000-0000-0000-0000-000000021304','00000000-0000-0000-0000-000000021302','00000000-0000-0000-0000-000000021402','owner'),
 ('00000000-0000-0000-0000-000000021305','00000000-0000-0000-0000-000000021303','00000000-0000-0000-0000-000000021403','owner');
insert into products(id,organization_id,name,barcode,unit,status)values
 ('00000000-0000-0000-0000-000000021803','00000000-0000-0000-0000-000000021102','Frozen Product','FROZEN-21','pc','active'),
 ('00000000-0000-0000-0000-000000021804','00000000-0000-0000-0000-000000021103','Open Product','OPEN-OTHER-21','pc','active');
insert into customers(id,store_id,full_name,status)values
 ('00000000-0000-0000-0000-000000021902','00000000-0000-0000-0000-000000021402','Frozen Customer','active'),
 ('00000000-0000-0000-0000-000000021903','00000000-0000-0000-0000-000000021403','Open Customer','active');
insert into sales(id,store_id,seller_id,status,local_operation_id)values
 ('00000000-0000-0000-0000-000000021980','00000000-0000-0000-0000-000000021402','00000000-0000-0000-0000-000000021302','completed','sale-frozen-21'),
 ('00000000-0000-0000-0000-000000021981','00000000-0000-0000-0000-000000021403','00000000-0000-0000-0000-000000021303','completed','sale-open-21');
insert into sale_items(id,sale_id,product_id,quantity)values
 ('00000000-0000-0000-0000-000000021982','00000000-0000-0000-0000-000000021980','00000000-0000-0000-0000-000000021803',1),
 ('00000000-0000-0000-0000-000000021983','00000000-0000-0000-0000-000000021981','00000000-0000-0000-0000-000000021804',1);
set local session_replication_role=replica;
insert into cutover_controls(organization_id,reconciliation_run_id,state,source_fingerprint,ready_at,frozen_at,accepted_by)values
 ('00000000-0000-0000-0000-000000021102','00000000-0000-0000-0000-000000021999','legacy_frozen','{}',clock_timestamp(),clock_timestamp(),'00000000-0000-0000-0000-000000021399');
set local session_replication_role=origin;
select throws_ok($$update products set organization_id='00000000-0000-0000-0000-000000021103'where id='00000000-0000-0000-0000-000000021803'$$,'P0001','V2_LEGACY_WRITES_FROZEN','frozen product cannot move to unfrozen organization');
select throws_ok($$update customers set store_id='00000000-0000-0000-0000-000000021403'where id='00000000-0000-0000-0000-000000021902'$$,'P0001','V2_LEGACY_WRITES_FROZEN','frozen customer cannot move to unfrozen store');
select throws_ok($$update sale_items set sale_id='00000000-0000-0000-0000-000000021981'where id='00000000-0000-0000-0000-000000021982'$$,'P0001','V2_LEGACY_WRITES_FROZEN','frozen sale item cannot move to unfrozen sale');
select throws_ok($$update user_store_access set user_id='00000000-0000-0000-0000-000000021303'where id='00000000-0000-0000-0000-000000021304'$$,'P0001','V2_LEGACY_WRITES_FROZEN','frozen user access cannot move to unfrozen user');
select lives_ok($$update products set name='Open Product Updated'where id='00000000-0000-0000-0000-000000021804'$$,'ordinary update in unfrozen organization remains writable');

select lives_ok($$select v2_lock_legacy_cutover_sources()$$,'static legacy source lock helper acquires all relation locks');
select is((select count(distinct c.relname)from pg_locks l join pg_class c on c.oid=l.relation join pg_namespace n on n.oid=c.relnamespace where l.pid=pg_backend_pid()and l.mode='ShareRowExclusiveLock'and n.nspname='public'and c.relname in('brands','categories','customers','debt_entries','debt_payments','devices','operation_logs','payments','product_batches','product_types','products','sale_items','sales','shifts','stock_movements','stores','suppliers','sync_operations','units','user_store_access','users')),21::bigint,'helper holds ShareRowExclusiveLock on all twenty-one V1 sources');
select ok(to_regprocedure('public.v2_unfreeze_legacy_for_cutover(uuid,uuid)')is null,'no unfreeze API exists');

select * from finish();
rollback;
