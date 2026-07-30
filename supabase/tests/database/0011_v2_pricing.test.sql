begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(257);

select has_table('public',t,t||' exists') from (values
('price_lists'),('price_change_requests'),('product_prices'),('price_history'),
('price_recommendations'),('products'))x(t);

select has_column('public',t,c,t||'.'||c||' exists') from (values
('price_lists','id'),('price_lists','organization_id'),('price_lists','branch_id'),
('price_lists','code'),('price_lists','name'),('price_lists','currency_code'),
('price_lists','is_default'),('price_lists','status'),('price_lists','created_at'),
('price_lists','updated_at'),('price_lists','archived_at'),
('price_change_requests','id'),('price_change_requests','organization_id'),
('price_change_requests','product_id'),('price_change_requests','price_list_id'),
('price_change_requests','current_amount'),('price_change_requests','requested_amount'),
('price_change_requests','source_type'),('price_change_requests','source_id'),
('price_change_requests','status'),('price_change_requests','requested_by'),
('price_change_requests','decided_by'),('price_change_requests','decided_at'),
('price_change_requests','expires_at'),('price_change_requests','created_at'),
('product_prices','id'),('product_prices','organization_id'),('product_prices','price_list_id'),
('product_prices','product_id'),('product_prices','amount'),('product_prices','currency_code'),
('product_prices','valid_from'),('product_prices','valid_to'),('product_prices','confirmed_by'),
('product_prices','price_change_request_id'),('product_prices','created_at'),
('price_history','id'),('price_history','organization_id'),('price_history','product_price_id'),
('price_history','price_list_id'),('price_history','product_id'),('price_history','old_amount'),
('price_history','new_amount'),('price_history','reason_code'),('price_history','source_type'),
('price_history','source_id'),('price_history','changed_by'),('price_history','created_at'),
('price_recommendations','id'),('price_recommendations','organization_id'),
('price_recommendations','price_change_request_id'),('price_recommendations','product_id'),
('price_recommendations','purchase_price'),('price_recommendations','previous_purchase_price'),
('price_recommendations','margin_percent'),('price_recommendations','recommended_amount'),
('price_recommendations','calculation'),('price_recommendations','created_at')
)x(t,c);

select col_type_is('public',t,c,typ,t||'.'||c||' type') from (values
('price_lists','currency_code','character(3)'),
('price_change_requests','current_amount','numeric(18,4)'),
('price_change_requests','requested_amount','numeric(18,4)'),
('product_prices','amount','numeric(18,4)'),
('product_prices','valid_from','timestamp with time zone'),
('price_history','old_amount','numeric(18,4)'),
('price_history','new_amount','numeric(18,4)'),
('price_recommendations','margin_percent','numeric(9,4)')
)x(t,c,typ);

select ok((select relrowsecurity from pg_class where oid=format('public.%I',t)::regclass),t||' RLS enabled')
from (values('price_lists'),('price_change_requests'),('product_prices'),('price_history'),('price_recommendations'))x(t);
select ok(not has_table_privilege('anon',format('public.%I',t),'SELECT,INSERT,UPDATE,DELETE'),'anon denied '||t)
from (values('price_lists'),('price_change_requests'),('product_prices'),('price_history'),('price_recommendations'))x(t);
select ok(not has_table_privilege('authenticated',format('public.%I',t),'INSERT,UPDATE,DELETE'),'browser writes denied '||t)
from (values('price_lists'),('price_change_requests'),('product_prices'),('price_history'),('price_recommendations'))x(t);
select ok(has_table_privilege('authenticated',format('public.%I',t),'SELECT'),'authenticated select '||t)
from (values('price_lists'),('price_change_requests'),('product_prices'),('price_history'),('price_recommendations'))x(t);

select has_index('public',t,i,i||' exists') from (values
('price_lists','price_lists_organization_code_key'),
('price_lists','price_lists_organization_default_key'),
('price_lists','price_lists_branch_default_key'),
('price_lists','price_lists_organization_status_idx'),
('price_lists','price_lists_branch_status_idx'),
('price_change_requests','price_change_requests_pending_source_key'),
('price_change_requests','price_change_requests_pending_null_source_key'),
('price_change_requests','price_change_requests_organization_status_idx'),
('price_change_requests','price_change_requests_product_idx'),
('price_change_requests','price_change_requests_list_status_idx'),
('price_change_requests','price_change_requests_requested_by_idx'),
('price_change_requests','price_change_requests_decided_by_idx'),
('product_prices','product_prices_active_lookup_idx'),
('product_prices','product_prices_organization_product_idx'),
('product_prices','product_prices_request_key'),
('price_history','price_history_organization_product_idx'),
('price_history','price_history_list_product_idx'),
('price_recommendations','price_recommendations_request_idx'),
('price_recommendations','price_recommendations_organization_product_idx')
)x(t,i);

select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass
  and conname=n and contype='f'),n||' FK exists') from (values
('price_lists','price_lists_organization_id_fkey'),('price_lists','price_lists_branch_id_fkey'),
('price_change_requests','price_change_requests_organization_id_fkey'),
('price_change_requests','price_change_requests_product_id_fkey'),
('price_change_requests','price_change_requests_price_list_id_fkey'),
('price_change_requests','price_change_requests_requested_by_fkey'),
('price_change_requests','price_change_requests_decided_by_fkey'),
('product_prices','product_prices_organization_id_fkey'),
('product_prices','product_prices_price_list_id_fkey'),
('product_prices','product_prices_product_id_fkey'),
('product_prices','product_prices_confirmed_by_fkey'),
('product_prices','product_prices_price_change_request_id_fkey'),
('price_history','price_history_organization_id_fkey'),
('price_history','price_history_product_price_id_fkey'),
('price_history','price_history_price_list_id_fkey'),
('price_history','price_history_product_id_fkey'),
('price_history','price_history_changed_by_fkey'),
('price_recommendations','price_recommendations_organization_id_fkey'),
('price_recommendations','price_recommendations_price_change_request_id_fkey'),
('price_recommendations','price_recommendations_product_id_fkey')
)x(t,n);

select has_function('public',f,args,f||' exists') from (values
('v2_prevent_pricing_delete',array[]::text[]),
('v2_guard_price_list',array[]::text[]),
('v2_guard_price_request',array[]::text[]),
('v2_guard_product_price',array[]::text[]),
('v2_guard_price_history',array[]::text[]),
('v2_guard_price_recommendation',array[]::text[]),
('v2_create_price_change_request',array['uuid','uuid','uuid','numeric','text','uuid']),
('v2_confirm_price_change',array['uuid']),
('v2_reject_price_change',array['uuid'])
)x(f,args);
select ok(not has_function_privilege('anon',format('public.%I()',f),'EXECUTE')
  and not has_function_privilege('authenticated',format('public.%I()',f),'EXECUTE'),
  f||' trigger function closed') from (values
('v2_prevent_pricing_delete'),('v2_guard_price_list'),('v2_guard_price_request'),
('v2_guard_product_price'),('v2_guard_price_history'),('v2_guard_price_recommendation'))x(f);
select ok(exists(select 1 from pg_trigger where tgrelid=format('public.%I',t)::regclass
  and tgname=n and not tgisinternal),n||' trigger exists') from (values
('price_lists','v2_price_lists_guard'),('price_lists','v2_price_lists_updated_at'),
('price_lists','v2_price_lists_prevent_delete'),
('price_change_requests','v2_price_change_requests_guard'),
('price_change_requests','v2_price_change_requests_prevent_delete'),
('product_prices','v2_product_prices_guard'),('product_prices','v2_product_prices_prevent_delete'),
('price_history','v2_price_history_guard'),('price_history','v2_price_history_prevent_delete'),
('price_recommendations','v2_price_recommendations_guard'),
('price_recommendations','v2_price_recommendations_prevent_delete')
)x(t,n);

select is((select count(*) from supabase_migrations.schema_migrations where version between '0001' and '0011'),11::bigint,'migrations 0001-0011 recorded');
select has_column('public','products','sale_price','legacy sale_price preserved');
select col_type_is('public','products','sale_price','numeric(14,2)','legacy sale_price type preserved');
select col_not_null('public','products','sale_price','legacy sale_price remains not null');
select is((select column_default from information_schema.columns
  where table_schema='public' and table_name='products' and column_name='sale_price'),
  '0','legacy sale_price default preserved');
select ok(not exists(select 1 from pg_constraint where contype='f' and conrelid in
  ('public.price_lists'::regclass,'public.price_change_requests'::regclass,'public.product_prices'::regclass,
   'public.price_history'::regclass,'public.price_recommendations'::regclass)
  and confrelid='public.products'::regclass),'no pricing FK targets legacy products');
select ok(exists(select 1 from pg_constraint where conname='product_prices_period_excl' and contype='x'),
  'concurrency-safe period exclusion exists');
select ok(exists(select 1 from pg_extension where extname='btree_gist'),'btree_gist installed');

-- Real auth and tenant fixtures.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000011001','authenticated','authenticated','owner11a@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000011002','authenticated','authenticated','owner11b@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000011003','authenticated','authenticated','seller11@test','','now','now','now');
insert into organizations(id,name) values
('00000000-0000-0000-0000-000000011101','Pricing A'),
('00000000-0000-0000-0000-000000011102','Pricing B');
insert into user_profiles(id,auth_user_id,full_name) values
('00000000-0000-0000-0000-000000011201','00000000-0000-0000-0000-000000011001','Owner A'),
('00000000-0000-0000-0000-000000011202','00000000-0000-0000-0000-000000011002','Owner B'),
('00000000-0000-0000-0000-000000011203','00000000-0000-0000-0000-000000011003','Seller A');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at) values
('00000000-0000-0000-0000-000000011301','00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011201','owner','active',now()),
('00000000-0000-0000-0000-000000011302','00000000-0000-0000-0000-000000011102','00000000-0000-0000-0000-000000011202','owner','active',now()),
('00000000-0000-0000-0000-000000011303','00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011203','seller','active',now());
insert into branches(id,organization_id,code,name) values
('00000000-0000-0000-0000-000000011401','00000000-0000-0000-0000-000000011101','A1','Branch A1'),
('00000000-0000-0000-0000-000000011402','00000000-0000-0000-0000-000000011102','B1','Branch B1');
insert into units_v2(id,organization_id,code,name,short_name) values
('00000000-0000-0000-0000-000000011501','00000000-0000-0000-0000-000000011101','EA','Each','ea'),
('00000000-0000-0000-0000-000000011502','00000000-0000-0000-0000-000000011102','EA','Each','ea');
insert into products_v2(id,organization_id,name,base_unit_id) values
('00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011101','Product A','00000000-0000-0000-0000-000000011501'),
('00000000-0000-0000-0000-000000011602','00000000-0000-0000-0000-000000011102','Product B','00000000-0000-0000-0000-000000011502'),
('00000000-0000-0000-0000-000000011603','00000000-0000-0000-0000-000000011101','First Manual','00000000-0000-0000-0000-000000011501'),
('00000000-0000-0000-0000-000000011604','00000000-0000-0000-0000-000000011101','First Purchase','00000000-0000-0000-0000-000000011501'),
('00000000-0000-0000-0000-000000011605','00000000-0000-0000-0000-000000011101','First Import','00000000-0000-0000-0000-000000011501'),
('00000000-0000-0000-0000-000000011606','00000000-0000-0000-0000-000000011101','First System','00000000-0000-0000-0000-000000011501'),
('00000000-0000-0000-0000-000000011607','00000000-0000-0000-0000-000000011101','Request Unique','00000000-0000-0000-0000-000000011501');

select throws_ok($$insert into price_lists(organization_id,branch_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011402','BAD','Bad','USD')$$,
 'P0001','V2_PRICE_LIST_BRANCH_TENANT_MISMATCH','cross-tenant list branch rejected');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','','Bad','USD')$$,'23514',null,'blank list code rejected');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','BAD','','USD')$$,'23514',null,'blank list name rejected');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','BAD','Bad','usd')$$,'23514',null,'lowercase currency rejected');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code,status)
 values('00000000-0000-0000-0000-000000011101','BAD','Bad','USD','unknown')$$,'23514',null,'unknown list status rejected');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code,status)
 values('00000000-0000-0000-0000-000000011101','BAD','Bad','USD','archived')$$,'23514',null,'archived list needs timestamp');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code,status,archived_at,is_default)
 values('00000000-0000-0000-0000-000000011101','BAD','Bad','USD','archived',now(),true)$$,'23514',null,'archived list cannot default');

insert into price_lists(id,organization_id,code,name,currency_code,is_default) values
('00000000-0000-0000-0000-000000011701','00000000-0000-0000-0000-000000011101','BASE','Base A','USD',true),
('00000000-0000-0000-0000-000000011702','00000000-0000-0000-0000-000000011102','BASE','Base B','USD',true);
insert into price_lists(id,organization_id,branch_id,code,name,currency_code,is_default) values
('00000000-0000-0000-0000-000000011703','00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011401','BRANCH','Branch Price','USD',true);
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code,is_default)
 values('00000000-0000-0000-0000-000000011101','OTHER','Other','USD',true)$$,'23505',null,'one organization default');
select throws_ok($$insert into price_lists(organization_id,branch_id,code,name,currency_code,is_default)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011401','OTHER','Other','USD',true)$$,'23505',null,'one branch default');
select lives_ok($$insert into price_lists(organization_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','SECOND','Second','USD')$$,'multiple non-default lists allowed');
select throws_ok($$insert into price_lists(organization_id,code,name,currency_code)
 values('00000000-0000-0000-0000-000000011101','base','Duplicate','USD')$$,'23505',null,'list code unique case-insensitive');
select throws_ok($$update price_lists set code='CHANGED' where id='00000000-0000-0000-0000-000000011701'$$,
 'P0001','V2_PRICE_LIST_IDENTITY_MUTATION_FORBIDDEN','list code immutable');
select throws_ok($$update price_lists set currency_code='EUR' where id='00000000-0000-0000-0000-000000011701'$$,
 'P0001','V2_PRICE_LIST_CURRENCY_MUTATION_FORBIDDEN','list currency immutable');

select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',10,'manual','00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRICING_COMMAND_CONTEXT_REQUIRED','direct request insert requires pricing context');
select set_config('market_pos.pricing_command','on',true);
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011602',
 '00000000-0000-0000-0000-000000011701',10,'manual','00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRICE_REQUEST_TENANT_MISMATCH','cross-tenant request product rejected');
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011702',10,'manual','00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRICE_REQUEST_TENANT_MISMATCH','cross-tenant request list rejected');
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',10,'manual','00000000-0000-0000-0000-000000011302')$$,
 'P0001','V2_PRICE_REQUEST_TENANT_MISMATCH','cross-tenant requester rejected');
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',-1,'manual','00000000-0000-0000-0000-000000011301')$$,
 '23514',null,'negative requested amount rejected');
select set_config('market_pos.pricing_command','off',true);

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000011001',true);
set local role authenticated;
select lives_ok($$select v2_create_price_change_request(
 '00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',10,'initial',null)$$,'initial request created');
reset role;
select is((select current_amount from price_change_requests where product_id='00000000-0000-0000-0000-000000011601'
 and price_list_id='00000000-0000-0000-0000-000000011701' and status='pending'),null::numeric,'initial current amount is NULL');
select is((select requested_amount from price_change_requests where status='pending'),10.0000::numeric,'requested amount scale value preserved');
select is((select count(*) from audit_events where action='price_change.requested'),1::bigint,'request audit emitted atomically');
select is((select count(*) from outbox_events where event_type='PriceChangeRequested'),1::bigint,'request outbox emitted atomically');
select set_config('market_pos.pricing_command','on',true);
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',null,11,'initial','00000000-0000-0000-0000-000000011301')$$,
 '23505',null,'duplicate pending NULL source rejected');
select lives_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011703',null,12,'manual','00000000-0000-0000-0000-000000011901',
 '00000000-0000-0000-0000-000000011301')$$,'pending non-null source accepted');
select throws_ok($$insert into price_change_requests(organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011703',null,13,'manual','00000000-0000-0000-0000-000000011901',
 '00000000-0000-0000-0000-000000011301')$$,'23505',null,'duplicate pending non-null source rejected');
select set_config('market_pos.pricing_command','off',true);

set local role authenticated;
select lives_ok(format('select v2_confirm_price_change(%L)',
 (select id from price_change_requests where price_list_id='00000000-0000-0000-0000-000000011701' and status='pending')),
 'initial confirmation succeeds');
reset role;
select is((select count(*) from product_prices where price_list_id='00000000-0000-0000-0000-000000011701'),1::bigint,'confirmation creates one price');
select is((select count(*) from price_history where price_list_id='00000000-0000-0000-0000-000000011701'),1::bigint,'confirmation creates one history');
select is((select amount from product_prices where valid_to is null),10.0000::numeric,'initial current price is 10');
select is((select old_amount from price_history where price_list_id='00000000-0000-0000-0000-000000011701'),null::numeric,'initial history old amount NULL');
select is((select status from price_change_requests where price_list_id='00000000-0000-0000-0000-000000011701'),'confirmed','request confirmed');
select is((select count(*) from audit_events where action='price_change.confirmed'),1::bigint,'confirmation audit emitted');
select is((select count(*) from outbox_events where event_type='SalePriceConfirmed'),1::bigint,'confirmation outbox emitted');
select is((select currency_code from product_prices where amount=10),'USD'::char(3),'existing price remains list-currency consistent');

set local role authenticated;
select lives_ok($$select v2_create_price_change_request('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011603','00000000-0000-0000-0000-000000011701',11,'manual','00000000-0000-0000-0000-000000011911')$$,'first manual request created');
select lives_ok($$select v2_create_price_change_request('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011604','00000000-0000-0000-0000-000000011701',12,'purchase','00000000-0000-0000-0000-000000011912')$$,'first purchase request created');
select lives_ok($$select v2_create_price_change_request('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011605','00000000-0000-0000-0000-000000011701',13,'import','00000000-0000-0000-0000-000000011913')$$,'first import request created');
select lives_ok($$select v2_create_price_change_request('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011606','00000000-0000-0000-0000-000000011701',14,'system','00000000-0000-0000-0000-000000011914')$$,'first system request created');
select lives_ok(format('select v2_confirm_price_change(%L)',(select id from price_change_requests where product_id='00000000-0000-0000-0000-000000011603' and status='pending')),'first manual price confirms');
select lives_ok(format('select v2_confirm_price_change(%L)',(select id from price_change_requests where product_id='00000000-0000-0000-0000-000000011604' and status='pending')),'first purchase price confirms');
select lives_ok(format('select v2_confirm_price_change(%L)',(select id from price_change_requests where product_id='00000000-0000-0000-0000-000000011605' and status='pending')),'first import price confirms');
select lives_ok(format('select v2_confirm_price_change(%L)',(select id from price_change_requests where product_id='00000000-0000-0000-0000-000000011606' and status='pending')),'first system price confirms');
select throws_ok($$select v2_create_price_change_request(
 '00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',99,'initial','00000000-0000-0000-0000-000000011915')$$,
 'P0001','V2_PRICE_REQUEST_INITIAL_SOURCE_MISMATCH','initial source forbidden when current price exists');
reset role;
select is((select count(*) from price_history where product_id in(
 '00000000-0000-0000-0000-000000011603','00000000-0000-0000-0000-000000011604',
 '00000000-0000-0000-0000-000000011605','00000000-0000-0000-0000-000000011606')
 and old_amount is null),4::bigint,'all non-initial first-price histories use NULL old_amount');
select is((select count(distinct source_type) from price_history where product_id in(
 '00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011603',
 '00000000-0000-0000-0000-000000011604','00000000-0000-0000-0000-000000011605',
 '00000000-0000-0000-0000-000000011606')),5::bigint,'all five first-price source types confirmed');

set local role authenticated;
select lives_ok($$select v2_create_price_change_request(
 '00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011601',
 '00000000-0000-0000-0000-000000011701',20,'manual','00000000-0000-0000-0000-000000011902')$$,'second request created');
select lives_ok(format('select v2_confirm_price_change(%L)',
 (select id from price_change_requests where requested_amount=20 and status='pending')),'second confirmation succeeds');
reset role;
select is((select count(*) from product_prices where price_list_id='00000000-0000-0000-0000-000000011701'
 and product_id='00000000-0000-0000-0000-000000011601'),2::bigint,'second confirmation creates second version');
select is((select count(*) from product_prices where price_list_id='00000000-0000-0000-0000-000000011701'
 and product_id='00000000-0000-0000-0000-000000011601' and valid_to is null),1::bigint,'only one open price');
select is((select valid_to from product_prices where amount=10),(select valid_from from product_prices where amount=20),'previous end equals next start');
select is((select old_amount from price_history where new_amount=20),10.0000::numeric,'history records previous amount');
select throws_ok($$update product_prices set amount=99 where amount=20$$,'P0001','V2_PRICING_COMMAND_CONTEXT_REQUIRED','price amount update requires context');
select throws_ok($$update product_prices set valid_to=now() where amount=20$$,'P0001','V2_PRICING_COMMAND_CONTEXT_REQUIRED','direct valid_to closure requires context');
select throws_ok($$update price_history set reason_code='changed'$$,'P0001','V2_PRICE_HISTORY_IMMUTABLE','history immutable');

select set_config('market_pos.pricing_command','on',true);
insert into price_change_requests(id,organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
values('00000000-0000-0000-0000-000000011801','00000000-0000-0000-0000-000000011101',
'00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011701',20,30,'manual',
'00000000-0000-0000-0000-000000011903','00000000-0000-0000-0000-000000011301');
insert into price_change_requests(id,organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
values('00000000-0000-0000-0000-000000011802','00000000-0000-0000-0000-000000011101',
'00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011701',20,40,'manual',
'00000000-0000-0000-0000-000000011904','00000000-0000-0000-0000-000000011301');
select set_config('market_pos.pricing_command','off',true);
set local role authenticated;
select lives_ok($$select v2_confirm_price_change('00000000-0000-0000-0000-000000011801')$$,'one concurrent-style request confirms');
select throws_ok($$select v2_confirm_price_change('00000000-0000-0000-0000-000000011802')$$,
 'P0001','V2_PRICE_REQUEST_STALE','stale request rejected deterministically');
reset role;
select is((select status from price_change_requests where id='00000000-0000-0000-0000-000000011802'),'pending','stale request remains pending');
select is((select count(*) from product_prices where amount=40),0::bigint,'stale request inserts no price');
select is((select count(*) from price_history where new_amount=40),0::bigint,'stale request inserts no history');

select set_config('market_pos.pricing_command','on',true);
insert into price_change_requests(id,organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
values('00000000-0000-0000-0000-000000011803','00000000-0000-0000-0000-000000011101',
'00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011701',30,50,'manual',
'00000000-0000-0000-0000-000000011905','00000000-0000-0000-0000-000000011301');
select set_config('market_pos.pricing_command','off',true);
set local role authenticated;
select lives_ok($$select v2_reject_price_change('00000000-0000-0000-0000-000000011803')$$,'rejection succeeds');
select throws_ok($$select v2_reject_price_change('00000000-0000-0000-0000-000000011803')$$,
 'P0001','V2_PRICE_REQUEST_NOT_PENDING','repeat rejection rejected');
reset role;
select is((select status from price_change_requests where id='00000000-0000-0000-0000-000000011803'),'rejected','request rejected');
select is((select amount from product_prices where product_id='00000000-0000-0000-0000-000000011601'
 and price_list_id='00000000-0000-0000-0000-000000011701' and valid_to is null),30.0000::numeric,'rejection leaves current price');
select is((select count(*) from price_history where new_amount=50),0::bigint,'rejection creates no price history');
select is((select count(*) from outbox_events where event_type='PriceChangeRejected'),1::bigint,'rejection outbox emitted');
select set_config('market_pos.pricing_command','on',true);
select throws_ok($$update price_change_requests set requested_amount=99 where id='00000000-0000-0000-0000-000000011803'$$,
 'P0001','V2_PRICE_REQUEST_TERMINAL_IMMUTABLE','terminal request immutable');
select set_config('market_pos.pricing_command','off',true);

select set_config('market_pos.pricing_command','on',true);
insert into price_change_requests(id,organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
values('00000000-0000-0000-0000-000000011804','00000000-0000-0000-0000-000000011101',
'00000000-0000-0000-0000-000000011601','00000000-0000-0000-0000-000000011703',null,15,'purchase',
'00000000-0000-0000-0000-000000011906','00000000-0000-0000-0000-000000011301');
select set_config('market_pos.pricing_command','off',true);
select lives_ok($$insert into price_recommendations(organization_id,price_change_request_id,product_id,purchase_price,
 previous_purchase_price,margin_percent,recommended_amount,calculation) values(
 '00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011804',
 '00000000-0000-0000-0000-000000011601',10,null,50,15,'{"formula":"margin"}')$$,'pending recommendation allowed');
select throws_ok($$update price_recommendations set recommended_amount=16$$,
 'P0001','V2_PRICE_RECOMMENDATION_IMMUTABLE','recommendation immutable');
select throws_ok($$insert into price_recommendations(organization_id,price_change_request_id,product_id,purchase_price,recommended_amount)
 values('00000000-0000-0000-0000-000000011102','00000000-0000-0000-0000-000000011804',
 '00000000-0000-0000-0000-000000011602',10,15)$$,
 'P0001','V2_PRICE_RECOMMENDATION_TENANT_MISMATCH','recommendation tenant mismatch rejected');
select throws_ok($$insert into price_recommendations(organization_id,price_change_request_id,product_id,purchase_price,recommended_amount,calculation)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011804',
 '00000000-0000-0000-0000-000000011601',10,15,'[]')$$,'23514',null,'recommendation calculation object required');

select throws_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,confirmed_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
 '00000000-0000-0000-0000-000000011601',1,'USD','2025-01-01',
 '00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRICING_COMMAND_CONTEXT_REQUIRED','direct product price insert requires context');
select throws_ok($$insert into price_history(organization_id,product_price_id,price_list_id,product_id,old_amount,new_amount,reason_code,source_type,changed_by)
 select organization_id,id,price_list_id,product_id,null,amount,'fake','manual',confirmed_by from product_prices limit 1$$,
 'P0001','V2_PRICING_COMMAND_CONTEXT_REQUIRED','direct history insert requires context');
select set_config('market_pos.pricing_command','on',true);
select throws_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,valid_to,confirmed_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
 '00000000-0000-0000-0000-000000011601',1,'USD','2026-01-01','2026-01-10',
 '00000000-0000-0000-0000-000000011301'),
 ('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
 '00000000-0000-0000-0000-000000011601',2,'USD','2026-01-05','2026-01-15',
 '00000000-0000-0000-0000-000000011301')$$,'23P01',null,'overlapping intervals rejected');
select lives_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,valid_to,confirmed_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
 '00000000-0000-0000-0000-000000011601',1,'USD','2026-01-01','2026-01-10',
 '00000000-0000-0000-0000-000000011301'),
 ('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
 '00000000-0000-0000-0000-000000011601',2,'USD','2026-01-10','2026-01-15',
 '00000000-0000-0000-0000-000000011301')$$,'adjacent intervals allowed');
select throws_ok($$insert into price_history(organization_id,product_price_id,price_list_id,product_id,old_amount,new_amount,reason_code,source_type,changed_by)
 select organization_id,id,price_list_id,product_id,99,amount,'forged','manual',confirmed_by
 from product_prices where price_list_id='00000000-0000-0000-0000-000000011703' and valid_from='2026-01-10'$$,
 'P0001','V2_PRICE_HISTORY_PREVIOUS_AMOUNT_MISMATCH','forged previous history amount rejected');
insert into price_change_requests(id,organization_id,product_id,price_list_id,current_amount,requested_amount,source_type,source_id,requested_by)
values('00000000-0000-0000-0000-000000011805','00000000-0000-0000-0000-000000011101',
'00000000-0000-0000-0000-000000011607','00000000-0000-0000-0000-000000011703',null,7,'manual',
'00000000-0000-0000-0000-000000011916','00000000-0000-0000-0000-000000011301');
insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,valid_to,confirmed_by,price_change_request_id)
values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
'00000000-0000-0000-0000-000000011607',7,'USD','2027-01-01','2027-01-02',
'00000000-0000-0000-0000-000000011301','00000000-0000-0000-0000-000000011805');
select throws_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,valid_to,confirmed_by,price_change_request_id)
values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011703',
'00000000-0000-0000-0000-000000011607',7,'USD','2027-01-02','2027-01-03',
'00000000-0000-0000-0000-000000011301','00000000-0000-0000-0000-000000011805')$$,
'23505',null,'one request cannot link two product prices');
select throws_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,confirmed_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011701',
 '00000000-0000-0000-0000-000000011601',1,'EUR',now(),'00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRODUCT_PRICE_CURRENCY_MISMATCH','price currency must match list');
select throws_ok($$insert into product_prices(organization_id,price_list_id,product_id,amount,currency_code,valid_from,confirmed_by)
 values('00000000-0000-0000-0000-000000011101','00000000-0000-0000-0000-000000011701',
 '00000000-0000-0000-0000-000000011602',1,'USD',now(),'00000000-0000-0000-0000-000000011301')$$,
 'P0001','V2_PRODUCT_PRICE_TENANT_MISMATCH','price tenant mismatch rejected');
select set_config('market_pos.pricing_command','off',true);

select throws_ok($$delete from price_lists where id='00000000-0000-0000-0000-000000011702'$$,
 'P0001','V2_PRICING_HARD_DELETE_FORBIDDEN','list hard delete rejected');
select throws_ok($$delete from price_change_requests where id='00000000-0000-0000-0000-000000011803'$$,
 'P0001','V2_PRICING_HARD_DELETE_FORBIDDEN','request hard delete rejected');
select throws_ok($$delete from product_prices where amount=30$$,
 'P0001','V2_PRICING_HARD_DELETE_FORBIDDEN','price hard delete rejected');
select throws_ok($$delete from price_history where new_amount=30$$,
 'P0001','V2_PRICING_HARD_DELETE_FORBIDDEN','history hard delete rejected');
select throws_ok($$delete from price_recommendations$$,
 'P0001','V2_PRICING_HARD_DELETE_FORBIDDEN','recommendation hard delete rejected');

-- RLS: owner has pricing.view; unassigned seller and foreign owner are isolated.
set local role authenticated;
select is((select count(*) from price_lists where organization_id='00000000-0000-0000-0000-000000011101'),3::bigint,'owner sees tenant price lists');
select ok((select count(*) from product_prices where organization_id='00000000-0000-0000-0000-000000011101')>0,'owner sees tenant prices');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000011003',true);
set local role authenticated;
select is((select count(*) from price_lists),0::bigint,'seller without pricing permission sees no lists');
select is((select count(*) from product_prices),0::bigint,'seller without pricing permission sees no prices');
select is((select count(*) from price_history),0::bigint,'seller without manage permission sees no history');
select throws_ok($$select v2_confirm_price_change('00000000-0000-0000-0000-000000011802')$$,
 'P0001','V2_PRICING_CONFIRM_REQUIRED','actor without pricing.confirm rejected');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000011002',true);
set local role authenticated;
select is((select count(*) from price_lists where organization_id='00000000-0000-0000-0000-000000011101'),0::bigint,'foreign owner cannot read tenant A');
reset role;

select is((select sale_price from products where id is null),null::numeric,'legacy and V2 pricing remain independent');
select * from finish();
rollback;
