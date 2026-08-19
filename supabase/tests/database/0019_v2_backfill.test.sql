begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(435);

-- Tooling schema is explicit, tenant-owned evidence with no browser surface.
select has_table('public',t,'backfill table '||t||' exists')from(values
 ('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))x(t);

with expected(t,c)as(values
 ('migration_backfill_runs','id'),('migration_backfill_runs','organization_id'),
 ('migration_backfill_runs','mode'),('migration_backfill_runs','source_snapshot_at'),
 ('migration_backfill_runs','status'),('migration_backfill_runs','started_at'),
 ('migration_backfill_runs','finished_at'),('migration_backfill_runs','summary'),
 ('migration_backfill_runs','created_at'),
 ('migration_backfill_checkpoints','id'),('migration_backfill_checkpoints','run_id'),
 ('migration_backfill_checkpoints','phase'),('migration_backfill_checkpoints','last_legacy_key'),
 ('migration_backfill_checkpoints','processed_count'),('migration_backfill_checkpoints','mapped_count'),
 ('migration_backfill_checkpoints','finding_count'),('migration_backfill_checkpoints','status'),
 ('migration_backfill_checkpoints','updated_at'),
 ('migration_entity_mappings','id'),('migration_entity_mappings','organization_id'),
 ('migration_entity_mappings','legacy_table'),('migration_entity_mappings','legacy_key'),
 ('migration_entity_mappings','target_table'),('migration_entity_mappings','target_id'),
 ('migration_entity_mappings','mapping_kind'),('migration_entity_mappings','created_at'),
 ('migration_backfill_findings','id'),('migration_backfill_findings','run_id'),
 ('migration_backfill_findings','organization_id'),('migration_backfill_findings','phase'),
 ('migration_backfill_findings','legacy_table'),('migration_backfill_findings','legacy_id'),
 ('migration_backfill_findings','severity'),('migration_backfill_findings','error_code'),
 ('migration_backfill_findings','details'),('migration_backfill_findings','created_at'))
select has_column('public',t,c,t||'.'||c||' exists')from expected;

with expected(t,c,typ)as(values
 ('migration_backfill_runs','id','uuid'),('migration_backfill_runs','organization_id','uuid'),
 ('migration_backfill_runs','mode','text'),('migration_backfill_runs','source_snapshot_at','timestamp with time zone'),
 ('migration_backfill_runs','status','text'),('migration_backfill_runs','started_at','timestamp with time zone'),
 ('migration_backfill_runs','finished_at','timestamp with time zone'),('migration_backfill_runs','summary','jsonb'),
 ('migration_backfill_runs','created_at','timestamp with time zone'),
 ('migration_backfill_checkpoints','id','uuid'),('migration_backfill_checkpoints','run_id','uuid'),
 ('migration_backfill_checkpoints','phase','text'),('migration_backfill_checkpoints','last_legacy_key','text'),
 ('migration_backfill_checkpoints','processed_count','bigint'),('migration_backfill_checkpoints','mapped_count','bigint'),
 ('migration_backfill_checkpoints','finding_count','bigint'),('migration_backfill_checkpoints','status','text'),
 ('migration_backfill_checkpoints','updated_at','timestamp with time zone'),
 ('migration_entity_mappings','id','uuid'),('migration_entity_mappings','organization_id','uuid'),
 ('migration_entity_mappings','legacy_table','text'),('migration_entity_mappings','legacy_key','text'),
 ('migration_entity_mappings','target_table','text'),('migration_entity_mappings','target_id','uuid'),
 ('migration_entity_mappings','mapping_kind','text'),('migration_entity_mappings','created_at','timestamp with time zone'),
 ('migration_backfill_findings','id','uuid'),('migration_backfill_findings','run_id','uuid'),
 ('migration_backfill_findings','organization_id','uuid'),('migration_backfill_findings','phase','text'),
 ('migration_backfill_findings','legacy_table','text'),('migration_backfill_findings','legacy_id','text'),
 ('migration_backfill_findings','severity','text'),('migration_backfill_findings','error_code','text'),
 ('migration_backfill_findings','details','jsonb'),('migration_backfill_findings','created_at','timestamp with time zone'))
select col_type_is('public',t,c,typ,t||'.'||c||' type is '||typ)from expected;

with required(t,c)as(values
 ('migration_backfill_runs','id'),('migration_backfill_runs','organization_id'),
 ('migration_backfill_runs','mode'),('migration_backfill_runs','source_snapshot_at'),
 ('migration_backfill_runs','status'),('migration_backfill_runs','started_at'),
 ('migration_backfill_runs','summary'),('migration_backfill_runs','created_at'),
 ('migration_backfill_checkpoints','id'),('migration_backfill_checkpoints','run_id'),
 ('migration_backfill_checkpoints','phase'),('migration_backfill_checkpoints','processed_count'),
 ('migration_backfill_checkpoints','mapped_count'),('migration_backfill_checkpoints','finding_count'),
 ('migration_backfill_checkpoints','status'),('migration_backfill_checkpoints','updated_at'),
 ('migration_entity_mappings','id'),('migration_entity_mappings','organization_id'),
 ('migration_entity_mappings','legacy_table'),('migration_entity_mappings','legacy_key'),
 ('migration_entity_mappings','target_table'),('migration_entity_mappings','target_id'),
 ('migration_entity_mappings','mapping_kind'),('migration_entity_mappings','created_at'),
 ('migration_backfill_findings','id'),('migration_backfill_findings','run_id'),
 ('migration_backfill_findings','organization_id'),('migration_backfill_findings','phase'),
 ('migration_backfill_findings','legacy_table'),('migration_backfill_findings','severity'),
 ('migration_backfill_findings','error_code'),('migration_backfill_findings','details'),
 ('migration_backfill_findings','created_at'))
select col_not_null('public',t,c,t||'.'||c||' is required')from required;

select ok(c.relrowsecurity and not c.relforcerowsecurity,t||' uses standard RLS')
from(values('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))x(t)
join pg_class c on c.oid=format('public.%I',t)::regclass;
select is((select count(*)from pg_policies where schemaname='public'and tablename=t),0::bigint,t||' has no browser policy')
from(values('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))x(t);
select ok(not has_table_privilege(r,format('public.%I',t),p),r||' denied '||t||' '||p)
from(values('anon'),('authenticated'))roles(r)
cross join(values('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))tables(t)
cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))privs(p);

with f(sig)as(values
  ('public.v2_guard_backfill_evidence()'),('public.v2_backfill_uuid_fragment(uuid)'),
  ('public.v2_backfill_source_fingerprint(uuid)'),
 ('public.v2_backfill_finding(uuid,text,text,text,text,text,jsonb)'),
 ('public.v2_backfill_mapping(uuid,text,text,text,uuid,text)'),
 ('public.v2_start_backfill_run(uuid,text)'),
 ('public.v2_run_backfill_batch(uuid,text,integer)'),
 ('public.v2_finalize_backfill_run(uuid)'))
select ok(to_regprocedure(sig)is not null,sig||' exists')from f;
with f(sig)as(values
  ('public.v2_guard_backfill_evidence()'),('public.v2_backfill_uuid_fragment(uuid)'),
  ('public.v2_backfill_source_fingerprint(uuid)'),
 ('public.v2_backfill_finding(uuid,text,text,text,text,text,jsonb)'),
 ('public.v2_backfill_mapping(uuid,text,text,text,uuid,text)'),
 ('public.v2_start_backfill_run(uuid,text)'),
 ('public.v2_run_backfill_batch(uuid,text,integer)'),
 ('public.v2_finalize_backfill_run(uuid)'))
select ok((select array_to_string(proconfig,',')='search_path=""'from pg_proc where oid=sig::regprocedure),sig||' has empty search_path')from f;
with f(sig)as(values
  ('public.v2_guard_backfill_evidence()'),('public.v2_backfill_uuid_fragment(uuid)'),
  ('public.v2_backfill_source_fingerprint(uuid)'),
 ('public.v2_backfill_finding(uuid,text,text,text,text,text,jsonb)'),
 ('public.v2_backfill_mapping(uuid,text,text,text,uuid,text)'),
 ('public.v2_start_backfill_run(uuid,text)'),
 ('public.v2_run_backfill_batch(uuid,text,integer)'),
 ('public.v2_finalize_backfill_run(uuid)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' cannot execute '||sig)
from f cross join(values('public'),('anon'),('authenticated'))roles(r);
with f(sig)as(values('public.v2_start_backfill_run(uuid,text)'),
 ('public.v2_run_backfill_batch(uuid,text,integer)'),('public.v2_finalize_backfill_run(uuid)'))
select ok(has_function_privilege('service_role',sig,'EXECUTE'),'service_role executes '||sig)from f;
with f(sig)as(values('public.v2_guard_backfill_evidence()'),
 ('public.v2_backfill_uuid_fragment(uuid)'),('public.v2_backfill_source_fingerprint(uuid)'),
 ('public.v2_backfill_finding(uuid,text,text,text,text,text,jsonb)'),
 ('public.v2_backfill_mapping(uuid,text,text,text,uuid,text)'))
select ok(not has_function_privilege('service_role',sig,'EXECUTE'),'service_role cannot call internal '||sig)from f;

select trigger_is('public',t,trg,'public','v2_guard_backfill_evidence',trg||' installed')from(values
 ('migration_backfill_runs','v2_backfill_runs_guard'),
 ('migration_backfill_checkpoints','v2_backfill_checkpoints_guard'),
 ('migration_entity_mappings','v2_backfill_mappings_guard'),
 ('migration_backfill_findings','v2_backfill_findings_guard'))x(t,trg);
select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='p'),t||' has primary key')
from(values('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))x(t);
select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and contype='f'),t||' has foreign key')
from(values('migration_backfill_runs'),('migration_backfill_checkpoints'),
 ('migration_entity_mappings'),('migration_backfill_findings'))x(t);
select ok(to_regclass('public.'||i)is not null,i||' exists')from(values
 ('migration_backfill_runs_org_started_idx'),('migration_backfill_checkpoints_run_status_idx'),
 ('migration_entity_mappings_target_idx'),('migration_backfill_findings_identity_key'),
 ('migration_backfill_findings_run_severity_idx'))x(i);

select is((select count(*)from permissions),54::bigint,'permission registry remains 54');
select is((select count(*)from permissions where critical),10::bigint,'critical permissions remain 10');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000101'),54::bigint,'owner template remains 54');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000102'),16::bigint,'seller template remains 16');
select is((select count(*)from supabase_migrations.schema_migrations where version between'0001'and'0019'),19::bigint,'migrations 0001 through 0019 recorded');

-- V1 sources and forbidden V2 history targets remain structurally independent.
select has_table('public',t,'legacy '||t||' remains')from(values
 ('users'),('stores'),('categories'),('brands'),('units'),('product_types'),('products'),
 ('suppliers'),('customers'),('devices'),('sales'),('sale_items'),('payments'),('shifts'),
 ('debt_payments'),('debt_entries'),('product_batches'),('stock_movements'),
 ('operation_logs'),('sync_operations'))x(t);

-- Test-only runner invokes deterministic phases until each checkpoint completes.
create function pg_temp.run_backfill(run_id uuid,batch_size integer default 200)
returns void language plpgsql as $$
declare phase text;result jsonb;guard integer;
begin
  foreach phase in array array['identity_profiles','identity_access','locations',
    'catalog_categories','catalog_category_parents','catalog_references',
    'catalog_products','counterparties','pricing','cutover_assessment']loop
    guard:=0;
    loop
      result:=public.v2_run_backfill_batch(run_id,phase,batch_size);
      exit when result->>'status'='completed';
      guard:=guard+1;
      if guard>100 then raise exception 'test runner guard';end if;
    end loop;
  end loop;
end$$;

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000019201','authenticated','authenticated','owner-19@test.local','',now(),now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000019202','authenticated','authenticated','seller-19@test.local','',now(),now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000019203','authenticated','authenticated','support-19@test.local','',now(),now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000019204','authenticated','authenticated','duplicate-19@test.local','',now(),now()-interval'10 days',now()-interval'10 days');
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019101','Backfill A',now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000019102','Dry Run',now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000019103','Clean Apply',now()-interval'10 days',now()-interval'10 days'),
 ('00000000-0000-0000-0000-000000019104','Stale Apply',now()-interval'10 days',now()-interval'10 days');
insert into users(id,auth_user_id,organization_id,full_name,email,password_hash,role,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019301','00000000-0000-0000-0000-000000019201','00000000-0000-0000-0000-000000019101','Owner Legacy','owner@test.local','never-copy-owner','owner','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019302','00000000-0000-0000-0000-000000019202','00000000-0000-0000-0000-000000019101','Seller Legacy','seller@test.local','never-copy-seller','seller','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019303','00000000-0000-0000-0000-000000019203','00000000-0000-0000-0000-000000019101','Service Admin Legacy','support@test.local','never-copy-service','service_admin','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019304',null,'00000000-0000-0000-0000-000000019101','Null Auth',null,'never-copy-null','seller','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019305','00000000-0000-0000-0000-000000019299','00000000-0000-0000-0000-000000019101','Missing Auth',null,'never-copy-missing','seller','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019306','00000000-0000-0000-0000-000000019204','00000000-0000-0000-0000-000000019101','Duplicate One',null,'never-copy-dup1','seller','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019307','00000000-0000-0000-0000-000000019204','00000000-0000-0000-0000-000000019101','Duplicate Two',null,'never-copy-dup2','seller','active',now()-interval'9 days',now()-interval'9 days'),
 ('00000000-0000-0000-0000-000000019308',null,'00000000-0000-0000-0000-000000019102','Dry Null Auth',null,'dry-password','seller','active',now()-interval'9 days',now()-interval'9 days');
insert into stores(id,organization_id,name,address,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019101','Main Store','A Street','active',now()-interval'8 days',now()-interval'8 days'),
 ('00000000-0000-0000-0000-000000019402','00000000-0000-0000-0000-000000019101','Old Store','Old Street','deleted',now()-interval'8 days',now()-interval'7 days');
insert into user_store_access(id,user_id,store_id,role_in_store,created_at)values
 ('00000000-0000-0000-0000-000000019411','00000000-0000-0000-0000-000000019302','00000000-0000-0000-0000-000000019401','seller',now()-interval'7 days');
insert into devices(id,store_id,name,device_type,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019421','00000000-0000-0000-0000-000000019401','Legacy Device','desktop','active',now()-interval'7 days',now()-interval'7 days');
insert into categories(id,organization_id,name,parent_id,description,sort_order,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019501','00000000-0000-0000-0000-000000019101','Root',null,'Root description',1,'active',now()-interval'7 days',now()-interval'7 days'),
 ('00000000-0000-0000-0000-000000019502','00000000-0000-0000-0000-000000019101','Child','00000000-0000-0000-0000-000000019501','Child description',2,'active',now()-interval'7 days',now()-interval'7 days');
insert into brands(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019601','00000000-0000-0000-0000-000000019101','Brand 19','active',now()-interval'7 days',now()-interval'7 days');
insert into units(id,organization_id,name,short_name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019602','00000000-0000-0000-0000-000000019101','Piece','pc','active',now()-interval'7 days',now()-interval'7 days');
insert into product_types(id,organization_id,name,code,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019603','00000000-0000-0000-0000-000000019101','Goods',null,'active',now()-interval'7 days',now()-interval'7 days');
insert into products(id,organization_id,category_id,name,barcode,unit,sale_price,current_quantity,min_quantity,is_expirable,status,sku,brand_id,product_type_id,unit_id,description,image_url,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019701','00000000-0000-0000-0000-000000019101','00000000-0000-0000-0000-000000019502','Mapped Product',' 123 ','pc',100,5,1,false,'active','CaseSku','00000000-0000-0000-0000-000000019601','00000000-0000-0000-0000-000000019603','00000000-0000-0000-0000-000000019602','Description','https://legacy.invalid/image.jpg',now()-interval'6 days',now()-interval'6 days'),
 ('00000000-0000-0000-0000-000000019702','00000000-0000-0000-0000-000000019101',null,'Fallback Product','123',' BOX ',50,0,0,false,'active','casesku',null,null,null,null,null,now()-interval'6 days',now()-interval'6 days'),
 ('00000000-0000-0000-0000-000000019703','00000000-0000-0000-0000-000000019101',null,'Fallback Product 2',null,'box',60,0,0,false,'inactive',null,null,null,null,null,null,now()-interval'6 days',now()-interval'6 days');
insert into suppliers(id,organization_id,name,phone,comment,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019801','00000000-0000-0000-0000-000000019101','Same Party Name','998901234567','supplier note','active',now()-interval'6 days',now()-interval'6 days');
insert into customers(id,store_id,full_name,phone,comment,current_debt,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019802','00000000-0000-0000-0000-000000019401','Same Party Name','998901234567','customer note',75,'active',now()-interval'6 days',now()-interval'6 days');
insert into product_batches(id,store_id,product_id,supplier_id,initial_quantity,remaining_quantity,purchase_price,sale_price_at_arrival,created_at)values
 ('00000000-0000-0000-0000-000000019811','00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019701','00000000-0000-0000-0000-000000019801',2,2,40,100,now()-interval'5 days');
insert into shifts(id,store_id,seller_id,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019821','00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019302','open',now()-interval'5 days',now()-interval'5 days');
insert into sales(id,store_id,seller_id,shift_id,customer_id,type,payment_status,total_amount,status,local_operation_id,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019831','00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019302','00000000-0000-0000-0000-000000019821','00000000-0000-0000-0000-000000019802','debt','partial',100,'completed','legacy-19',now()-interval'4 days',now()-interval'4 days');
insert into sale_items(id,sale_id,product_id,quantity,sale_price,total_price)values
 ('00000000-0000-0000-0000-000000019832','00000000-0000-0000-0000-000000019831','00000000-0000-0000-0000-000000019701',1,100,100);
insert into payments(id,store_id,sale_id,method,amount,status,created_by,created_at)values
 ('00000000-0000-0000-0000-000000019833','00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019831','cash',25,'paid','00000000-0000-0000-0000-000000019302',now()-interval'4 days');
insert into sync_operations(id,store_id,device_id,user_id,local_operation_id,operation_type,payload,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019841','00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019421','00000000-0000-0000-0000-000000019302','sync-19','sale','{}','pending',now()-interval'3 days',now()-interval'3 days');

create temp table test_runs(name text primary key,id uuid not null);
insert into test_runs values('dry',v2_start_backfill_run('00000000-0000-0000-0000-000000019102','dry_run'));
select throws_ok($$select v2_start_backfill_run('00000000-0000-0000-0000-000000019102','wrong')$$,'P0001','V2_BACKFILL_MODE_INVALID','invalid mode rejected');
select throws_ok($$select v2_start_backfill_run('00000000-0000-0000-0000-000000019199','dry_run')$$,'P0001','V2_BACKFILL_ORGANIZATION_NOT_FOUND','unknown organization rejected');
select is((select count(*)from migration_backfill_checkpoints where run_id=(select id from test_runs where name='dry')),10::bigint,'start creates ten checkpoints');
select results_eq($$select phase from migration_backfill_checkpoints where run_id=(select id from test_runs where name='dry')order by array_position(array['identity_profiles','identity_access','locations','catalog_categories','catalog_category_parents','catalog_references','catalog_products','counterparties','pricing','cutover_assessment'],phase)$$,
  $$select * from(values('identity_profiles'::text),('identity_access'),('locations'),('catalog_categories'),('catalog_category_parents'),('catalog_references'),('catalog_products'),('counterparties'),('pricing'),('cutover_assessment'))x(phase)$$,
  'ordered phase names are exact');
select throws_ok(format('select v2_run_backfill_batch(%L,%L,0)',(select id from test_runs where name='dry'),'identity_profiles'),'P0001','V2_BACKFILL_BATCH_SIZE_INVALID','zero batch rejected');
select throws_ok(format('select v2_run_backfill_batch(%L,%L,1001)',(select id from test_runs where name='dry'),'identity_profiles'),'P0001','V2_BACKFILL_BATCH_SIZE_INVALID','oversized batch rejected');
select throws_ok(format('select v2_run_backfill_batch(%L,%L,1)',(select id from test_runs where name='dry'),'bad_phase'),'P0001','V2_BACKFILL_PHASE_INVALID','unknown phase rejected');
select throws_ok(format('select v2_run_backfill_batch(%L,%L,1)',(select id from test_runs where name='dry'),'locations'),'P0001','V2_BACKFILL_PHASE_ORDER_REQUIRED','phase order enforced');
select lives_ok(format('select v2_run_backfill_batch(%L,%L,1)',(select id from test_runs where name='dry'),'identity_profiles'),'batch size one executes');
select is((select processed_count from migration_backfill_checkpoints where run_id=(select id from test_runs where name='dry')and phase='identity_profiles'),1::bigint,'checkpoint processed one row');
select is((select status from migration_backfill_checkpoints where run_id=(select id from test_runs where name='dry')and phase='identity_profiles'),'completed','single dry source completes batch');
select lives_ok(format('select pg_temp.run_backfill(%L,1)',(select id from test_runs where name='dry')),'dry-run resumes all phases');
select is((v2_run_backfill_batch((select id from test_runs where name='dry'),'identity_profiles',1)->>'replayed')::boolean,true,'completed phase retry is stable replay');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019102'),0::bigint,'dry-run creates no mappings');
select is((select count(*)from user_profiles where auth_user_id is null),0::bigint,'dry-run creates no profiles');
select is((select count(*)from branches where organization_id='00000000-0000-0000-0000-000000019102'),0::bigint,'dry-run creates no branches');
select is((select count(*)from organization_settings where organization_id='00000000-0000-0000-0000-000000019102'),0::bigint,'dry-run creates no settings');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='dry')and error_code='V2_BACKFILL_AUTH_ID_REQUIRED'),1::bigint,'dry-run reports invalid auth');
select is((select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019102'and migration_name='0019_v2_backfill'),0::bigint,'dry-run creates no canonical exceptions');
select is(v2_finalize_backfill_run((select id from test_runs where name='dry'))->>'status','completed','dry-run finalizes completed');
select is(v2_finalize_backfill_run((select id from test_runs where name='dry'))->>'replayed','true','dry-run finalize replay is stable');

insert into test_runs values('apply',v2_start_backfill_run('00000000-0000-0000-0000-000000019101','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,1)',(select id from test_runs where name='apply')),'apply resumes through batch size one');
select is((select count(*)from migration_backfill_checkpoints where run_id=(select id from test_runs where name='apply')and status='completed'),10::bigint,'all apply checkpoints complete');
select ok((select min(processed_count)>=1 from migration_backfill_checkpoints where run_id=(select id from test_runs where name='apply')and phase in('identity_profiles','locations','catalog_categories','catalog_references','catalog_products','counterparties','pricing','cutover_assessment')),'data phases record progress');

select is((select count(*)from user_profiles where auth_user_id in('00000000-0000-0000-0000-000000019201','00000000-0000-0000-0000-000000019202','00000000-0000-0000-0000-000000019203')),3::bigint,'provable auth profiles mapped');
select is((select full_name from user_profiles where auth_user_id='00000000-0000-0000-0000-000000019201'),'Owner Legacy','profile full name preserved');
select is((select email_snapshot from user_profiles where auth_user_id='00000000-0000-0000-0000-000000019201'),'owner@test.local','profile email snapshot preserved');
select ok(not exists(select 1 from user_profiles where full_name like'%never-copy%'),'password hash is not copied into profile fields');
select ok(position('never-copy' in coalesce((select string_agg(row_to_json(p)::text,'')from user_profiles p),''))=0,'profile JSON cannot expose legacy password hash');
select is((select count(*)from organization_memberships where organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'only owner and seller memberships created');
select is((select count(*)from organization_memberships where organization_id='00000000-0000-0000-0000-000000019101'and system_role='service_admin'),0::bigint,'legacy service admin is not elevated');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_SERVICE_ADMIN_REVIEW_REQUIRED'),1::bigint,'service admin review finding recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_AUTH_ID_REQUIRED'),1::bigint,'null auth blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_AUTH_ID_NOT_FOUND'),1::bigint,'missing auth blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_AUTH_ID_AMBIGUOUS'),2::bigint,'ambiguous auth blockers recorded per row');
select is((select count(*)from membership_permission_profiles mpp join organization_memberships m on m.id=mpp.membership_id where m.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'system profiles assigned to mapped memberships');
select ok(exists(select 1 from membership_permission_profiles mpp join organization_memberships m on m.id=mpp.membership_id where m.organization_id='00000000-0000-0000-0000-000000019101'and m.system_role='owner'and mpp.permission_profile_id='00000000-0000-0000-0000-000000000101'),'owner default assigned');
select ok(exists(select 1 from membership_permission_profiles mpp join organization_memberships m on m.id=mpp.membership_id where m.organization_id='00000000-0000-0000-0000-000000019101'and m.system_role='seller'and mpp.permission_profile_id='00000000-0000-0000-0000-000000000102'),'seller default assigned');

select is((select count(*)from branches where organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'stores map to two branches');
select is((select count(*)from branches where legacy_store_id in('00000000-0000-0000-0000-000000019401','00000000-0000-0000-0000-000000019402')),2::bigint,'legacy store mapping is exact');
select matches((select code from branches where legacy_store_id='00000000-0000-0000-0000-000000019401'),'^MIG-BR-','branch code deterministic prefix');
select is((select status from branches where legacy_store_id='00000000-0000-0000-0000-000000019402'),'archived','deleted store maps archived');
select is((select archived_at from branches where legacy_store_id='00000000-0000-0000-0000-000000019402'),(select updated_at from stores where id='00000000-0000-0000-0000-000000019402'),'archived timestamp is historical');
select is((select count(*)from warehouses w join branches b on b.id=w.branch_id where b.organization_id='00000000-0000-0000-0000-000000019101'and w.is_primary),2::bigint,'one generated primary warehouse per branch');
select is((select count(*)from registers r join branches b on b.id=r.branch_id where b.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'one generated register per branch');
select ok(not exists(select 1 from registers r join warehouses w on w.id=r.default_warehouse_id where r.branch_id<>w.branch_id),'generated register uses same-branch warehouse');
select is((select count(*)from branch_access ba join organization_memberships m on m.id=ba.membership_id where m.organization_id='00000000-0000-0000-0000-000000019101'and m.system_role='seller'),1::bigint,'seller store access maps to branch access');
select is((select count(*)from devices_v2 where legacy_device_id='00000000-0000-0000-0000-000000019421'),0::bigint,'legacy device is not auto-created');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_DEVICE_REENROLL_REQUIRED'),1::bigint,'device reenrollment warning recorded');

select is((select count(*)from categories_v2 where organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'categories mapped once');
select is((select name from categories_v2 where legacy_category_id='00000000-0000-0000-0000-000000019501'),'Root','category name preserved');
select is((select description from categories_v2 where legacy_category_id='00000000-0000-0000-0000-000000019502'),'Child description','category description preserved');
select is((select sort_order from categories_v2 where legacy_category_id='00000000-0000-0000-0000-000000019502'),2,'category sort order preserved');
select is((select p.legacy_category_id from categories_v2 c join categories_v2 p on p.id=c.parent_id where c.legacy_category_id='00000000-0000-0000-0000-000000019502'),'00000000-0000-0000-0000-000000019501'::uuid,'parent attached only in second pass');
select is((select count(*)from brands_v2 where legacy_brand_id='00000000-0000-0000-0000-000000019601'),1::bigint,'brand mapping created');
select is((select count(*)from units_v2 where legacy_unit_id='00000000-0000-0000-0000-000000019602'),1::bigint,'unit mapping created');
select matches((select code from units_v2 where legacy_unit_id='00000000-0000-0000-0000-000000019602'),'^MIG-U-','unit code generated deterministically');
select is((select count(*)from product_types_v2 where legacy_product_type_id='00000000-0000-0000-0000-000000019603'),1::bigint,'product type mapping created');
select matches((select code from product_types_v2 where legacy_product_type_id='00000000-0000-0000-0000-000000019603'),'^MIG-T-','null product type code generated');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'and legacy_table='products.unit'and legacy_key='unit-text:box'and target_table='units_v2'),1::bigint,'normalized fallback unit has one mapping');
select is((select count(*)from units_v2 u join migration_entity_mappings m on m.target_id=u.id where m.organization_id='00000000-0000-0000-0000-000000019101'and m.legacy_table='products.unit'and m.legacy_key='unit-text:box'),1::bigint,'case variants do not duplicate fallback unit');
select is((select count(*)from unit_conversions where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'backfill invents no unit conversions');

select is((select count(*)from products_v2 where organization_id='00000000-0000-0000-0000-000000019101'),3::bigint,'products map once');
select is((select name from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019701'),'Mapped Product','product name preserved');
select ok((select category_id is not null and brand_id is not null and product_type_id is not null and base_unit_id is not null from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019701'),'mapped product references are complete');
select ok((select base_unit_id is not null from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019702'),'fallback product uses generated base unit');
select is((select status from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019703'),'inactive','inactive product lifecycle preserved');
select is((select count(*)from products_v2 where organization_id='00000000-0000-0000-0000-000000019101'and sku is not null),1::bigint,'case-insensitive SKU collision keeps one safe identifier');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_SKU_CONFLICT'),1::bigint,'SKU conflict finding recorded');
select is((select count(*)from product_barcodes where organization_id='00000000-0000-0000-0000-000000019101'),1::bigint,'normalized barcode collision keeps one assignment');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_BARCODE_CONFLICT'),1::bigint,'barcode collision finding recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_IMAGE_REIMPORT_REQUIRED'),1::bigint,'legacy image creates info finding');
select is((select count(*)from product_images where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'legacy image URL is not imported');
select is((select count(*)from inventory_balances where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'current quantity does not create inventory balance');
select is((select count(*)from inventory_movements where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'current quantity does not create inventory movement');

select is((select count(*)from counterparties where organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'supplier and customer map separately');
select is((select count(*)from counterparties where legacy_supplier_id='00000000-0000-0000-0000-000000019801'),1::bigint,'supplier legacy mapping preserved');
select is((select count(*)from counterparties where legacy_customer_id='00000000-0000-0000-0000-000000019802'),1::bigint,'customer legacy mapping preserved');
select is((select count(*)from counterparties where organization_id='00000000-0000-0000-0000-000000019101'and display_name='Same Party Name'),2::bigint,'same phone and name are not auto-merged');
select is((select count(*)from counterparty_roles r join counterparties c on c.id=r.counterparty_id where c.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'supplier and customer roles created');
select is((select count(*)from counterparty_contacts c join counterparties p on p.id=c.counterparty_id where p.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'primary phones preserved as separate contacts');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED'),1::bigint,'opening debt blocker recorded once');
select is((select count(*)from receivables where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'customer debt creates no receivable');
select is((select count(*)from settlement_entries where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'customer debt creates no settlement entry');

select is((select count(*)from price_lists where organization_id='00000000-0000-0000-0000-000000019101'and code='LEGACY-DEFAULT'),1::bigint,'one legacy default price list created');
select is((select count(*)from product_prices where organization_id='00000000-0000-0000-0000-000000019101'),3::bigint,'one current price per mapped product');
select is((select count(*)from price_history where organization_id='00000000-0000-0000-0000-000000019101'and source_type='import'and reason_code='legacy_backfill'),3::bigint,'one import history row per price');
select is((select amount from product_prices pp join products_v2 p on p.id=pp.product_id where p.legacy_product_id='00000000-0000-0000-0000-000000019701'),100::numeric,'current sale price preserved');
select ok((select bool_and(valid_from<=(select source_snapshot_at from migration_backfill_runs where id=(select id from test_runs where name='apply')))from product_prices where organization_id='00000000-0000-0000-0000-000000019101'),'price timestamp is bounded by source snapshot');

select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED'),1::bigint,'nonzero stock blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_STOCK_SOURCE_MISMATCH'),1::bigint,'batch/current mismatch blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_OPEN_SHIFT'),1::bigint,'open shift blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_PENDING_LEGACY_SYNC'),1::bigint,'pending legacy sync blocker recorded');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='apply')and error_code='V2_BACKFILL_OPEN_FINANCIAL_STATE_REVIEW_REQUIRED'),1::bigint,'open financial state blocker recorded');
select is((select summary->'retained_v1_history'->'sales'->>'count' from migration_backfill_runs where id=(select id from test_runs where name='apply')),'1','retained sale count stored in summary');
select is((select summary->'retained_v1_history'->>'sale_items' from migration_backfill_runs where id=(select id from test_runs where name='apply')),'1','retained sale item count stored');
select is((select summary->'retained_v1_history'->>'payments' from migration_backfill_runs where id=(select id from test_runs where name='apply')),'1','retained payment count stored');
select is((select summary->'retained_v1_history'->>'shifts' from migration_backfill_runs where id=(select id from test_runs where name='apply')),'1','retained shift count stored');
select is((select summary->'retained_v1_history'->>'synced_sync_operations' from migration_backfill_runs where id=(select id from test_runs where name='apply')),'0','retained synced operation count stored');

select is((select count(*)from sales_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 sales reconstructed');
select is((select count(*)from sale_lines_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 sale lines reconstructed');
select is((select count(*)from payments_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 payments reconstructed');
select is((select count(*)from shifts_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 shifts reconstructed');
select is((select count(*)from debt_payments_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 debt payments reconstructed');
select is((select count(*)from debt_allocations where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 debt allocations reconstructed');
select is((select count(*)from purchase_documents where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 purchases reconstructed');
select is((select count(*)from product_batches_v2 where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 batches reconstructed');
select is((select count(*)from cash_movements where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no V2 cash ledger reconstructed');
select is((select count(*)from command_log where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no command log fabricated');
select is((select count(*)from audit_events where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no audit events fabricated');
select is((select count(*)from outbox_events where organization_id='00000000-0000-0000-0000-000000019101'),0::bigint,'no outbox events fabricated');

select is(v2_finalize_backfill_run((select id from test_runs where name='apply'))->>'status','blocked','apply with review findings finalizes blocked');
select ok((select finished_at is not null from migration_backfill_runs where id=(select id from test_runs where name='apply')),'blocked run has finish timestamp');
select ok((select count(*)>0 from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019101'and migration_name='0019_v2_backfill'),'apply findings upsert canonical exceptions');
select is((select count(*)from migration_exceptions e where e.organization_id='00000000-0000-0000-0000-000000019101'and e.migration_name='0019_v2_backfill'),(select count(*)from migration_backfill_findings f where f.run_id=(select id from test_runs where name='apply')and f.severity in('warning','blocker')),'canonical exceptions match warning/blocker findings');

-- A second apply validates an existing device mapping, preserves managed state,
-- and creates no duplicate location, catalog or pricing rows.
create temp table retry_counts(name text primary key,value bigint not null);
insert into retry_counts values
 ('exceptions',(select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019101'and migration_name='0019_v2_backfill')),
 ('mappings',(select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'));
insert into devices_v2(id,organization_id,branch_id,register_id,legacy_device_id,name,device_type,fingerprint_hash,status)
select '00000000-0000-0000-0000-000000019901',b.organization_id,b.id,r.id,
  '00000000-0000-0000-0000-000000019421','Re-enrolled Device','desktop','reenrolled-19','pending'
from branches b join registers r on r.branch_id=b.id
where b.legacy_store_id='00000000-0000-0000-0000-000000019401';
update products set sale_price=125 where id='00000000-0000-0000-0000-000000019701';
insert into test_runs values('device_dry',v2_start_backfill_run('00000000-0000-0000-0000-000000019101','dry_run'));
select lives_ok(format('select pg_temp.run_backfill(%L,2)',(select id from test_runs where name='device_dry')),'dry-run validates existing targets without writes');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='device_dry')and legacy_table='devices'and error_code='V2_BACKFILL_MAPPING_CONFLICT'),0::bigint,'valid pre-existing device creates no dry-run mapping blocker');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'),(select value from retry_counts where name='mappings'),'dry-run creates no mapping beside existing evidence');
select is((select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019101'and migration_name='0019_v2_backfill'),(select value from retry_counts where name='exceptions'),'dry-run creates no canonical exception');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='device_dry')and error_code='V2_BACKFILL_SKU_CONFLICT'),1::bigint,'dry-run predicts deterministic SKU conflict');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='device_dry')and error_code='V2_BACKFILL_BARCODE_CONFLICT'),1::bigint,'dry-run predicts normalized barcode conflict');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='device_dry')and error_code='V2_BACKFILL_PRICE_TARGET_DIVERGED'),1::bigint,'dry-run predicts existing price divergence');
insert into test_runs values('retry',v2_start_backfill_run('00000000-0000-0000-0000-000000019101','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,2)',(select id from test_runs where name='retry')),'second apply is restartable');
select is(v2_run_backfill_batch((select id from test_runs where name='retry'),'pricing',2)->>'replayed','true','completed apply phase retry is no-op');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'and legacy_table='devices'and legacy_key='00000000-0000-0000-0000-000000019421'and target_table='devices_v2'),1::bigint,'existing legacy device mapping accepted');
select is((select status from devices_v2 where id='00000000-0000-0000-0000-000000019901'),'pending','existing mapped device is not auto-trusted');
select is((select count(*)from branches where organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'retry creates no branch duplicate');
select is((select count(*)from warehouses w join branches b on b.id=w.branch_id where b.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'retry creates no warehouse duplicate');
select is((select count(*)from registers r join branches b on b.id=r.branch_id where b.organization_id='00000000-0000-0000-0000-000000019101'),2::bigint,'retry creates no register duplicate');
select is((select count(*)from products_v2 where organization_id='00000000-0000-0000-0000-000000019101'),3::bigint,'retry creates no product duplicate');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'and legacy_table='products.unit'and legacy_key='unit-text:box'),1::bigint,'retry creates no fallback unit duplicate');
select is((select count(*)from product_prices where organization_id='00000000-0000-0000-0000-000000019101'),3::bigint,'retry creates no current price duplicate');
select is((select count(*)from price_history where organization_id='00000000-0000-0000-0000-000000019101'and source_type='import'),3::bigint,'retry creates no price history duplicate');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='retry')and error_code='V2_BACKFILL_PRICE_TARGET_DIVERGED'and legacy_id='00000000-0000-0000-0000-000000019701'),1::bigint,'managed price divergence recorded');
select is((select amount from product_prices pp join products_v2 p on p.id=pp.product_id where p.legacy_product_id='00000000-0000-0000-0000-000000019701'),100::numeric,'managed V2 price is not overwritten');
select is((select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019101'and migration_name='0019_v2_backfill'),(select value+1 from retry_counts where name='exceptions'),'retry adds only the newly introduced price-divergence exception');
select ok(not exists(select 1 from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'group by legacy_table,legacy_key,target_table having count(*)>1),'mapping identity remains unique across retries');
select results_eq($$select distinct error_code from migration_backfill_findings where run_id=(select id from test_runs where name='device_dry')and error_code in('V2_BACKFILL_SKU_CONFLICT','V2_BACKFILL_BARCODE_CONFLICT','V2_BACKFILL_PRICE_TARGET_DIVERGED')order by 1$$,$$select distinct error_code from migration_backfill_findings where run_id=(select id from test_runs where name='retry')and error_code in('V2_BACKFILL_SKU_CONFLICT','V2_BACKFILL_BARCODE_CONFLICT','V2_BACKFILL_PRICE_TARGET_DIVERGED')order by 1$$,'dry-run and apply report the same deterministic conflict codes');

-- Category source graph validation is independent of target write order.
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019105','Category Graph',now()-interval'3 days',now()-interval'3 days'),
 ('00000000-0000-0000-0000-000000019106','Category Other',now()-interval'3 days',now()-interval'3 days');
insert into categories(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019511','00000000-0000-0000-0000-000000019105','Cycle A','active',now()-interval'2 days',now()-interval'2 days'),
 ('00000000-0000-0000-0000-000000019512','00000000-0000-0000-0000-000000019105','Cycle B','active',now()-interval'2 days',now()-interval'2 days'),
 ('00000000-0000-0000-0000-000000019513','00000000-0000-0000-0000-000000019105','Cross Tenant','active',now()-interval'2 days',now()-interval'2 days'),
 ('00000000-0000-0000-0000-000000019514','00000000-0000-0000-0000-000000019106','Other Root','active',now()-interval'2 days',now()-interval'2 days');
update categories set parent_id='00000000-0000-0000-0000-000000019512'where id='00000000-0000-0000-0000-000000019511';
update categories set parent_id='00000000-0000-0000-0000-000000019511'where id='00000000-0000-0000-0000-000000019512';
update categories set parent_id='00000000-0000-0000-0000-000000019514'where id='00000000-0000-0000-0000-000000019513';
insert into test_runs values('category',v2_start_backfill_run('00000000-0000-0000-0000-000000019105','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='category')),'category graph apply completes row-level isolation');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='category')and error_code='V2_BACKFILL_CATEGORY_CYCLE'),2::bigint,'both legacy cycle members reported');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='category')and error_code='V2_BACKFILL_CATEGORY_PARENT_TENANT_MISMATCH'),1::bigint,'cross-tenant parent reported');
select is((select count(*)from categories_v2 where organization_id='00000000-0000-0000-0000-000000019105'),3::bigint,'safe category master rows survive bad parent rows');

-- Existing manual location state is never guessed or overwritten.
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019107','Manual Location',now()-interval'3 days',now()-interval'3 days');
insert into stores(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019407','00000000-0000-0000-0000-000000019107','Manual Store','active',now()-interval'2 days',now()-interval'2 days');
insert into branches(id,organization_id,code,name,legacy_store_id)values
 ('00000000-0000-0000-0000-000000019417','00000000-0000-0000-0000-000000019107','MANUAL-19','Manual Branch','00000000-0000-0000-0000-000000019407');
insert into warehouses(id,organization_id,branch_id,code,name,is_primary)values
 ('00000000-0000-0000-0000-000000019427','00000000-0000-0000-0000-000000019107','00000000-0000-0000-0000-000000019417','MANUAL-WH-19','Manual Warehouse',false);
insert into test_runs values('manual',v2_start_backfill_run('00000000-0000-0000-0000-000000019107','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='manual')),'manual location ambiguity isolates row');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='manual')and error_code='V2_BACKFILL_TARGET_DIVERGED'),1::bigint,'manual warehouse ambiguity creates blocker');
select is((select count(*)from branches where organization_id='00000000-0000-0000-0000-000000019107'),1::bigint,'manual branch is not overwritten');
select is((select count(*)from warehouses where organization_id='00000000-0000-0000-0000-000000019107'),1::bigint,'manual warehouse is not overwritten');
select is((select count(*)from registers where organization_id='00000000-0000-0000-0000-000000019107'),0::bigint,'ambiguous location creates no guessed register');

-- Existing V2 targets are accepted only when their tenant, legacy identity,
-- reference graph, lifecycle and required counterparty role remain compatible.
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019108','Target Validation',now()-interval'3 days',now()-interval'3 days');
insert into stores(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019408','00000000-0000-0000-0000-000000019108','Target Store','active',now()-interval'2 days',now()-interval'2 days');
insert into categories(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019518','00000000-0000-0000-0000-000000019108','Expected Category','active',now()-interval'2 days',now()-interval'2 days'),
 ('00000000-0000-0000-0000-000000019519','00000000-0000-0000-0000-000000019108','Wrong Category','active',now()-interval'2 days',now()-interval'2 days');
insert into brands(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019618','00000000-0000-0000-0000-000000019108','Target Brand','active',now()-interval'2 days',now()-interval'2 days');
insert into units(id,organization_id,name,short_name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019619','00000000-0000-0000-0000-000000019108','Target Unit','tu','active',now()-interval'2 days',now()-interval'2 days');
insert into product_types(id,organization_id,name,code,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019620','00000000-0000-0000-0000-000000019108','Target Type',null,'active',now()-interval'2 days',now()-interval'2 days');
insert into products(id,organization_id,category_id,name,unit,sale_price,status,brand_id,product_type_id,unit_id,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019718','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019518','Wrong Category Product','tu',10,'active','00000000-0000-0000-0000-000000019618','00000000-0000-0000-0000-000000019620','00000000-0000-0000-0000-000000019619',now()-interval'2 days',now()-interval'2 days'),
 ('00000000-0000-0000-0000-000000019719','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019518','Missing Reference Product','tu',20,'active','00000000-0000-0000-0000-000000019618','00000000-0000-0000-0000-000000019620','00000000-0000-0000-0000-000000019619',now()-interval'2 days',now()-interval'2 days');
insert into categories_v2(id,organization_id,legacy_category_id,name,status)values
 ('00000000-0000-0000-0000-000000019528','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019518','Expected Category','active'),
 ('00000000-0000-0000-0000-000000019529','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019519','Wrong Category','active');
insert into brands_v2(id,organization_id,legacy_brand_id,name,status)values
 ('00000000-0000-0000-0000-000000019628','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019618','Target Brand','active');
insert into units_v2(id,organization_id,legacy_unit_id,code,name,short_name,status)values
 ('00000000-0000-0000-0000-000000019629','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019619','MIG-U-000000019619','Target Unit','tu','active');
insert into product_types_v2(id,organization_id,legacy_product_type_id,code,name,status)values
 ('00000000-0000-0000-0000-000000019630','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019620','MIG-T-000000019620','Target Type','active');
insert into products_v2(id,organization_id,legacy_product_id,name,category_id,brand_id,product_type_id,base_unit_id,status)values
 ('00000000-0000-0000-0000-000000019728','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019718','Wrong Category Product','00000000-0000-0000-0000-000000019529','00000000-0000-0000-0000-000000019628','00000000-0000-0000-0000-000000019630','00000000-0000-0000-0000-000000019629','active'),
 ('00000000-0000-0000-0000-000000019729','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019719','Missing Reference Product','00000000-0000-0000-0000-000000019528',null,null,'00000000-0000-0000-0000-000000019629','active');
insert into customers(id,store_id,full_name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019818','00000000-0000-0000-0000-000000019408','Missing Customer Role','active',now()-interval'2 days',now()-interval'2 days');
insert into suppliers(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019819','00000000-0000-0000-0000-000000019108','Compatible Supplier','active',now()-interval'2 days',now()-interval'2 days');
select set_config('market_pos.counterparty_command','on',true);
insert into counterparties(id,organization_id,legacy_customer_id,display_name,status)values
 ('00000000-0000-0000-0000-000000019918','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019818','Missing Customer Role','active');
insert into counterparties(id,organization_id,legacy_supplier_id,display_name,status)values
 ('00000000-0000-0000-0000-000000019919','00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019819','Compatible Supplier','active');
insert into counterparty_roles(organization_id,counterparty_id,role_code,started_at)values
 ('00000000-0000-0000-0000-000000019108','00000000-0000-0000-0000-000000019919','supplier',now()-interval'2 days');
select set_config('market_pos.counterparty_command','off',true);

insert into test_runs values('target_dry',v2_start_backfill_run('00000000-0000-0000-0000-000000019108','dry_run'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='target_dry')),'dry-run evaluates existing target compatibility');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='target_dry')and error_code='V2_BACKFILL_TARGET_DIVERGED'),3::bigint,'dry-run predicts two product and one role divergence');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019108'),0::bigint,'target-validation dry-run creates no mappings');
select is((select count(*)from migration_exceptions where organization_id='00000000-0000-0000-0000-000000019108'and migration_name='0019_v2_backfill'),0::bigint,'target-validation dry-run creates no canonical exceptions');

insert into test_runs values('target_apply',v2_start_backfill_run('00000000-0000-0000-0000-000000019108','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='target_apply')),'apply isolates divergent existing targets');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='target_apply')and error_code='V2_BACKFILL_TARGET_DIVERGED'and legacy_id='00000000-0000-0000-0000-000000019718'),1::bigint,'existing product with wrong category is blocked');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='target_apply')and error_code='V2_BACKFILL_TARGET_DIVERGED'and legacy_id='00000000-0000-0000-0000-000000019719'),1::bigint,'existing product missing brand and type is blocked');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='target_apply')and error_code='V2_BACKFILL_TARGET_DIVERGED'and legacy_id='00000000-0000-0000-0000-000000019818'),1::bigint,'existing customer without customer role is blocked');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019108'and legacy_table='products'),0::bigint,'divergent products never receive mapping evidence');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019108'and legacy_table='suppliers'and legacy_key='00000000-0000-0000-0000-000000019819'),1::bigint,'compatible existing counterparty maps idempotently');
select is((select count(*)from counterparties where organization_id='00000000-0000-0000-0000-000000019108'and legacy_supplier_id='00000000-0000-0000-0000-000000019819'),1::bigint,'compatible counterparty target is not duplicated');
select results_eq($$select legacy_id,error_code from migration_backfill_findings where run_id=(select id from test_runs where name='target_dry')and error_code='V2_BACKFILL_TARGET_DIVERGED'order by legacy_id$$,$$select legacy_id,error_code from migration_backfill_findings where run_id=(select id from test_runs where name='target_apply')and error_code='V2_BACKFILL_TARGET_DIVERGED'order by legacy_id$$,'dry-run and apply report identical target divergence codes');
insert into test_runs values('target_retry',v2_start_backfill_run('00000000-0000-0000-0000-000000019108','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='target_retry')),'fresh apply does not accept incomplete prior targets');
select is((select count(*)from migration_backfill_findings where run_id=(select id from test_runs where name='target_retry')and error_code='V2_BACKFILL_TARGET_DIVERGED'),3::bigint,'fresh apply retains every deterministic divergence');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019108'and legacy_table='products'),0::bigint,'blocked run cannot seed incomplete product mappings for retry');
select is(v2_finalize_backfill_run((select id from test_runs where name='target_retry'))->>'status','blocked','fresh run with unresolved target divergence remains blocked');

insert into test_runs values('incomplete',v2_start_backfill_run('00000000-0000-0000-0000-000000019106','dry_run'));
select throws_ok(format('select v2_finalize_backfill_run(%L)',(select id from test_runs where name='incomplete')),'P0001','V2_BACKFILL_PHASES_INCOMPLETE','finalize requires every phase complete');

-- A clean organization can be prepared, but no feature authority changes.
insert into test_runs values('clean',v2_start_backfill_run('00000000-0000-0000-0000-000000019103','apply'));
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='clean')),'clean empty apply scans all phases');
select is((select count(*)from organization_settings where organization_id='00000000-0000-0000-0000-000000019103'),1::bigint,'clean organization receives default settings');
select is(v2_finalize_backfill_run((select id from test_runs where name='clean'))->>'status','prepared','clean apply becomes prepared');
select is((select status from migration_backfill_runs where id=(select id from test_runs where name='clean')),'prepared','prepared status persisted');
select is(v2_finalize_backfill_run((select id from test_runs where name='clean'))->>'replayed','true','prepared finalize replay is stable');
select ok(not exists(select 1 from information_schema.columns where table_schema='public'and table_name='organizations'and column_name like'%feature%'),'prepared does not add feature flag');

-- A relevant V1 change after logical snapshot makes an apply run stale.
insert into test_runs values('stale',v2_start_backfill_run('00000000-0000-0000-0000-000000019104','apply'));
insert into stores(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019404','00000000-0000-0000-0000-000000019104','Changed after snapshot','active',clock_timestamp()+interval'1 second',clock_timestamp()+interval'1 second');
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='stale')),'stale apply still completes scan');
select is(v2_finalize_backfill_run((select id from test_runs where name='stale'))->>'error_code','V2_BACKFILL_SOURCE_CHANGED_AFTER_SNAPSHOT','source change returns stable stale error');
select is((select status from migration_backfill_runs where id=(select id from test_runs where name='stale')),'stale','source change persists stale status');
select ok((select summary ? 'final_error'from migration_backfill_runs where id=(select id from test_runs where name='stale')),'stale summary records final error');

-- Timestamp filters prevent post-snapshot master rows from being mapped, while
-- fingerprints close mutation/deletion blind spots in legacy rows without updated_at.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000019209','authenticated','authenticated','snapshot-19@test.local','',now(),now()-interval'3 days',now()-interval'3 days');
insert into organizations(id,name,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019109','Snapshot Discipline',now()-interval'3 days',now()-interval'3 days');
insert into users(id,auth_user_id,organization_id,full_name,email,role,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019309','00000000-0000-0000-0000-000000019209','00000000-0000-0000-0000-000000019109','Snapshot Seller','snapshot-19@test.local','seller','active',now()-interval'2 days',now()-interval'2 days');
insert into stores(id,organization_id,name,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019409','00000000-0000-0000-0000-000000019109','Snapshot Store','active',now()-interval'2 days',now()-interval'2 days');
insert into user_store_access(id,user_id,store_id,role_in_store,created_at)values
 ('00000000-0000-0000-0000-000000019419','00000000-0000-0000-0000-000000019309','00000000-0000-0000-0000-000000019409','seller',now()-interval'2 days');
insert into products(id,organization_id,name,unit,sale_price,current_quantity,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019709','00000000-0000-0000-0000-000000019109','Snapshot Product','sp',10,2,'active',now()-interval'2 days',now()-interval'2 days');
insert into product_batches(id,store_id,product_id,initial_quantity,remaining_quantity,purchase_price,sale_price_at_arrival,created_at)values
 ('00000000-0000-0000-0000-000000019819','00000000-0000-0000-0000-000000019409','00000000-0000-0000-0000-000000019709',2,2,5,10,now()-interval'2 days');
insert into sales(id,store_id,seller_id,type,payment_status,total_amount,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019839','00000000-0000-0000-0000-000000019409','00000000-0000-0000-0000-000000019309','regular','paid',10,'completed',now()-interval'2 days',now()-interval'2 days');
insert into sale_items(id,sale_id,product_id,quantity,purchase_price,sale_price,total_price,profit_amount)values
 ('00000000-0000-0000-0000-000000019849','00000000-0000-0000-0000-000000019839','00000000-0000-0000-0000-000000019709',1,5,10,10,5);
insert into test_runs values('snapshot',v2_start_backfill_run('00000000-0000-0000-0000-000000019109','apply'));
select is((select count(*)from jsonb_object_keys((select summary->'source_fingerprint'from migration_backfill_runs where id=(select id from test_runs where name='snapshot')))),3::bigint,'run captures all three tenant-scoped source fingerprints');
insert into products(id,organization_id,name,unit,sale_price,status,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000019710','00000000-0000-0000-0000-000000019109','Created After Snapshot','sp',12,'active',clock_timestamp()+interval'1 second',clock_timestamp()+interval'1 second');
alter table products disable trigger trg_products_updated_at;
update products set name='Post Snapshot Name',updated_at=clock_timestamp()+interval'1 second'
where id='00000000-0000-0000-0000-000000019709';
alter table products enable trigger trg_products_updated_at;
update product_batches set remaining_quantity=1 where id='00000000-0000-0000-0000-000000019819';
update sale_items set total_price=9,profit_amount=4 where id='00000000-0000-0000-0000-000000019849';
delete from user_store_access where id='00000000-0000-0000-0000-000000019419';
select lives_ok(format('select pg_temp.run_backfill(%L,200)',(select id from test_runs where name='snapshot')),'stale snapshot scan keeps checkpoints and evidence');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019109'and legacy_table='products'and legacy_key='00000000-0000-0000-0000-000000019710'),0::bigint,'product created after snapshot is not mapped');
select is((select count(*)from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019710'),0::bigint,'post-snapshot product creates no V2 target');
select is((select count(*)from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019109'and legacy_table='products'and legacy_key='00000000-0000-0000-0000-000000019709'),0::bigint,'product updated after snapshot is not mapped');
select is((select count(*)from products_v2 where legacy_product_id='00000000-0000-0000-0000-000000019709'),0::bigint,'post-snapshot product values are not copied');
select isnt((select summary->'source_fingerprint'->>'product_batches'from migration_backfill_runs where id=(select id from test_runs where name='snapshot')),(v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000019109')->>'product_batches'),'remaining quantity mutation changes batch fingerprint');
select isnt((select summary->'source_fingerprint'->>'sale_items'from migration_backfill_runs where id=(select id from test_runs where name='snapshot')),(v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000019109')->>'sale_items'),'sale item financial mutation changes history fingerprint');
select isnt((select summary->'source_fingerprint'->>'user_store_access'from migration_backfill_runs where id=(select id from test_runs where name='snapshot')),(v2_backfill_source_fingerprint('00000000-0000-0000-0000-000000019109')->>'user_store_access'),'access removal changes identity-set fingerprint');
select is((select count(*)from branch_access where organization_id='00000000-0000-0000-0000-000000019109'),0::bigint,'changed access set creates no branch access target');
select is(v2_finalize_backfill_run((select id from test_runs where name='snapshot'))->>'error_code','V2_BACKFILL_SOURCE_CHANGED_AFTER_SNAPSHOT','fingerprint or timestamp change returns stable stale error');
select is((select status from migration_backfill_runs where id=(select id from test_runs where name='snapshot')),'stale','snapshot discipline persists stale run status');

-- Evidence is append-only and API inputs remain defensive.
select throws_ok(format('delete from migration_entity_mappings where id=%L',(select id from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'limit 1)),'P0001','V2_BACKFILL_HARD_DELETE_FORBIDDEN','mapping hard delete guarded');
select throws_ok(format('update migration_entity_mappings set target_id=gen_random_uuid() where id=%L',(select id from migration_entity_mappings where organization_id='00000000-0000-0000-0000-000000019101'limit 1)),'P0001','V2_BACKFILL_EVIDENCE_IMMUTABLE','mapping update guarded');
select throws_ok(format('update migration_backfill_findings set details=%L where id=%L','{}',(select id from migration_backfill_findings where run_id=(select id from test_runs where name='apply')limit 1)),'P0001','V2_BACKFILL_EVIDENCE_IMMUTABLE','finding update guarded');
select throws_ok(format('update migration_backfill_runs set organization_id=%L where id=%L','00000000-0000-0000-0000-000000019103',(select id from test_runs where name='apply')),'P0001','V2_BACKFILL_RUN_IDENTITY_IMMUTABLE','run identity guarded');
select throws_ok(format('update migration_backfill_checkpoints set phase=%L where id=%L','changed',(select id from migration_backfill_checkpoints where run_id=(select id from test_runs where name='apply')limit 1)),'P0001','V2_BACKFILL_CHECKPOINT_IDENTITY_IMMUTABLE','checkpoint identity guarded');

-- V1 evidence values are unchanged by apply.
select is((select password_hash from users where id='00000000-0000-0000-0000-000000019301'),'never-copy-owner','legacy password hash untouched');
select is((select current_quantity from products where id='00000000-0000-0000-0000-000000019701'),5::numeric,'legacy current quantity untouched');
select is((select current_debt from customers where id='00000000-0000-0000-0000-000000019802'),75::numeric,'legacy debt untouched');
select is((select status::text from shifts where id='00000000-0000-0000-0000-000000019821'),'open','legacy shift untouched');
select is((select status::text from sync_operations where id='00000000-0000-0000-0000-000000019841'),'pending','legacy sync operation untouched');

rollback;
