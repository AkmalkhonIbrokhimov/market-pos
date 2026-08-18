begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(262);

-- Final matrix inventory: every tenant-owned V2 relation uses standard RLS.
select ok(c.relrowsecurity and not c.relforcerowsecurity,t||' uses standard RLS')
from(values
 ('command_log'),('outbox_events'),('audit_events'),('migration_exceptions'),
 ('user_profiles'),('organization_memberships'),('permissions'),('permission_profiles'),
 ('permission_profile_permissions'),('membership_permission_profiles'),('branch_access'),
 ('approval_requests'),('support_access_grants'),('branches'),('warehouses'),('registers'),
 ('devices_v2'),('organization_settings'),('categories_v2'),('brands_v2'),('units_v2'),
 ('product_types_v2'),('products_v2'),('unit_conversions'),('product_barcodes'),
 ('product_images'),('price_lists'),('price_change_requests'),('product_prices'),
 ('price_history'),('price_recommendations'),('counterparties'),('counterparty_roles'),
 ('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'),
 ('purchase_documents'),('purchase_lines'),('purchase_additional_costs'),
 ('purchase_cost_allocations'),('product_batches_v2'),('daily_delivery_templates'),
 ('daily_delivery_documents'),('inventory_documents'),('inventory_document_lines'),
 ('warehouse_transfers'),('warehouse_transfer_lines'),('inventory_movements'),
 ('inventory_balances'),('shifts_v2'),('shift_totals'),('sales_v2'),('sale_lines_v2'),
 ('sale_line_batch_allocations'),('held_sales'),('payments_v2'),('sale_returns'),
 ('sale_return_lines'),('fiscal_documents'),('fiscal_attempts'),('receivables'),
 ('debt_payments_v2'),('debt_allocations'),('settlement_entries'),('settlement_periods'),
 ('settlement_acts'),('settlement_act_lines'),('cash_movements'),('shift_cash_counts'),
 ('supplier_payments'),('sync_commands'),('sync_cursor_state')
)x(t) join pg_class c on c.oid=format('public.%I',t)::regclass;

select is((select count(*)from permissions),54::bigint,'permission registry remains 54');
select is((select count(*)from permissions where critical),10::bigint,'critical permission count remains 10');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000101'),54::bigint,'owner profile remains 54');
select is((select count(*)from permission_profile_permissions where permission_profile_id='00000000-0000-0000-0000-000000000102'),16::bigint,'seller profile remains 16');
select is((select count(*)from supabase_migrations.schema_migrations where version between'0001'and'0018'),18::bigint,'migrations 0001 through 0018 recorded');

with f(sig)as(values
 ('public.v2_device_directory(uuid,uuid)'),
 ('public.v2_member_directory(uuid)'),
 ('public.v2_customer_directory(uuid,text,integer)'),
 ('public.v2_can_view_pricing_history(uuid,uuid)'),
 ('public.v2_my_activity_journal(uuid,integer)'),
 ('public.v2_sync_command_journal(uuid,uuid)'))
select ok(to_regprocedure(sig)is not null,sig||' exists')from f;
with f(sig)as(values
 ('public.v2_device_directory(uuid,uuid)'),
 ('public.v2_member_directory(uuid)'),
 ('public.v2_customer_directory(uuid,text,integer)'),
 ('public.v2_can_view_pricing_history(uuid,uuid)'),
 ('public.v2_my_activity_journal(uuid,integer)'),
 ('public.v2_sync_command_journal(uuid,uuid)'))
select ok((select prosecdef and array_to_string(proconfig,',')='search_path=""'from pg_proc where oid=sig::regprocedure),sig||' is safe definer with empty search_path')from f;
with f(sig)as(values
 ('public.v2_device_directory(uuid,uuid)'),
 ('public.v2_member_directory(uuid)'),
 ('public.v2_customer_directory(uuid,text,integer)'),
 ('public.v2_can_view_pricing_history(uuid,uuid)'),
 ('public.v2_my_activity_journal(uuid,integer)'))
select ok(has_function_privilege('authenticated',sig,'EXECUTE'),'authenticated executes '||sig)from f;
with f(sig)as(values
 ('public.v2_device_directory(uuid,uuid)'),
 ('public.v2_member_directory(uuid)'),
 ('public.v2_customer_directory(uuid,text,integer)'),
 ('public.v2_can_view_pricing_history(uuid,uuid)'),
 ('public.v2_my_activity_journal(uuid,integer)'))
select ok(not has_function_privilege(r,sig,'EXECUTE'),r||' denied '||sig)
from f cross join(values('public'),('anon'))roles(r);

select ok(not has_table_privilege(r,'public.sync_cursor_state',p),r||' denied cursor state '||p)
from(values('anon'),('authenticated'))roles(r)
cross join(values('SELECT'),('INSERT'),('UPDATE'),('DELETE'))privs(p);

select ok(not has_table_privilege('authenticated',format('public.%I',t),p),'authenticated denied '||t||' '||p)
from(values
 ('command_log'),('outbox_events'),('audit_events'),('sync_commands'),('sync_cursor_state'),
 ('purchase_documents'),('purchase_lines'),('inventory_movements'),('inventory_balances'),
 ('product_batches_v2'),('sales_v2'),('sale_lines_v2'),('sale_returns'),('sale_return_lines'),
 ('payments_v2'),('receivables'),('debt_payments_v2'),('debt_allocations'),
 ('settlement_entries'),('settlement_periods'),('settlement_acts'),('settlement_act_lines'),
 ('cash_movements'),('shift_cash_counts'),('supplier_payments')
)tables(t)cross join(values('INSERT'),('UPDATE'),('DELETE'))privs(p);

-- The legacy V1 contract remains present and its browser policies are untouched.
select has_table('public','devices','legacy V1 devices remains');
select has_table('public','products','legacy V1 products remains');
select has_table('public','sales','legacy V1 sales remains');
select has_table('public','sync_operations','legacy V1 sync operations remains');
select ok(exists(select 1 from pg_policies where schemaname='public'and tablename='products'and policyname='products_select_organization'),'legacy products SELECT policy remains');
select ok(exists(select 1 from pg_policies where schemaname='public'and tablename='categories'and policyname='categories_select_organization'),'legacy categories SELECT policy remains');

-- Real tenant/auth fixture.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018001','authenticated','authenticated','owner-a-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018002','authenticated','authenticated','seller-a1-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018003','authenticated','authenticated','seller-a2-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018004','authenticated','authenticated','owner-b-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018005','authenticated','authenticated','support-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018006','authenticated','authenticated','blocked-profile-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018007','authenticated','authenticated','blocked-member-18@test.local','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000018008','authenticated','authenticated','ops-18@test.local','',now(),now(),now());
insert into organizations(id,name)values
 ('00000000-0000-0000-0000-000000018101','RLS tenant A'),
 ('00000000-0000-0000-0000-000000018102','RLS tenant B');
insert into user_profiles(id,auth_user_id,full_name,email_snapshot,status)values
 ('00000000-0000-0000-0000-000000018201','00000000-0000-0000-0000-000000018001','Owner A','owner-a@example.test','active'),
 ('00000000-0000-0000-0000-000000018202','00000000-0000-0000-0000-000000018002','Seller A1','seller-a1@example.test','active'),
 ('00000000-0000-0000-0000-000000018203','00000000-0000-0000-0000-000000018003','Seller A2','seller-a2@example.test','active'),
 ('00000000-0000-0000-0000-000000018204','00000000-0000-0000-0000-000000018004','Owner B','owner-b@example.test','active'),
 ('00000000-0000-0000-0000-000000018205','00000000-0000-0000-0000-000000018005','Support','support@example.test','active'),
 ('00000000-0000-0000-0000-000000018206','00000000-0000-0000-0000-000000018006','Blocked Profile','blocked-profile@example.test','blocked'),
 ('00000000-0000-0000-0000-000000018207','00000000-0000-0000-0000-000000018007','Blocked Membership','blocked-member@example.test','active'),
 ('00000000-0000-0000-0000-000000018208','00000000-0000-0000-0000-000000018008','Inventory Operator','ops@example.test','active');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at)values
 ('00000000-0000-0000-0000-000000018301','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018201','owner','active',now()),
 ('00000000-0000-0000-0000-000000018302','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018202','seller','active',now()),
 ('00000000-0000-0000-0000-000000018303','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018203','seller','active',now()),
 ('00000000-0000-0000-0000-000000018304','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018204','owner','active',now()),
 ('00000000-0000-0000-0000-000000018306','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018206','seller','active',now()),
 ('00000000-0000-0000-0000-000000018307','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018207','seller','blocked',now()),
 ('00000000-0000-0000-0000-000000018308','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018208','seller','active',now());
insert into membership_permission_profiles(membership_id,permission_profile_id,assigned_by)values
 ('00000000-0000-0000-0000-000000018302','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018303','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018306','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018307','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018308','00000000-0000-0000-0000-000000000101','00000000-0000-0000-0000-000000018301');
insert into branches(id,organization_id,code,name)values
 ('00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018101','A1','Branch A1'),
 ('00000000-0000-0000-0000-000000018402','00000000-0000-0000-0000-000000018101','A2','Branch A2'),
 ('00000000-0000-0000-0000-000000018403','00000000-0000-0000-0000-000000018102','B1','Branch B1');
insert into warehouses(id,organization_id,branch_id,code,name,is_primary)values
 ('00000000-0000-0000-0000-000000018501','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','WA1','Warehouse A1',true),
 ('00000000-0000-0000-0000-000000018502','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018402','WA2','Warehouse A2',true),
 ('00000000-0000-0000-0000-000000018503','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018403','WB1','Warehouse B1',true),
 ('00000000-0000-0000-0000-000000018504','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','WA1B','Warehouse A1 secondary',false);
insert into registers(id,organization_id,branch_id,default_warehouse_id,code,name)values
 ('00000000-0000-0000-0000-000000018601','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018501','RA1','Register A1'),
 ('00000000-0000-0000-0000-000000018602','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018402','00000000-0000-0000-0000-000000018502','RA2','Register A2'),
 ('00000000-0000-0000-0000-000000018603','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018403','00000000-0000-0000-0000-000000018503','RB1','Register B1');
insert into devices_v2(id,organization_id,branch_id,register_id,name,device_type,fingerprint_hash,status,last_seen_at)values
 ('00000000-0000-0000-0000-000000018701','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018601','Device A1','desktop','secret-fingerprint-a1','trusted',now()),
 ('00000000-0000-0000-0000-000000018702','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018402','00000000-0000-0000-0000-000000018602','Device A2','tablet','secret-fingerprint-a2','trusted',now()),
 ('00000000-0000-0000-0000-000000018703','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018403','00000000-0000-0000-0000-000000018603','Device B1','mobile','secret-fingerprint-b1','trusted',now());
insert into branch_access(organization_id,membership_id,branch_id)values
 ('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018302','00000000-0000-0000-0000-000000018401'),
 ('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018303','00000000-0000-0000-0000-000000018402'),
 ('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018306','00000000-0000-0000-0000-000000018401'),
 ('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018307','00000000-0000-0000-0000-000000018401'),
 ('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018308','00000000-0000-0000-0000-000000018401');

-- Counterparty private row and safe customer projection.
select set_config('market_pos.counterparty_command','on',true);
insert into counterparties(id,organization_id,display_name,legal_name,tax_id,notes)values
 ('00000000-0000-0000-0000-000000018801','00000000-0000-0000-0000-000000018101','Customer A','Customer A Legal','TIN-PRIVATE','private notes'),
 ('00000000-0000-0000-0000-000000018802','00000000-0000-0000-0000-000000018102','Customer B','Customer B Legal','TIN-B','tenant B notes');
insert into counterparty_roles(id,organization_id,counterparty_id,role_code)values
 ('00000000-0000-0000-0000-000000018811','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018801','customer'),
 ('00000000-0000-0000-0000-000000018812','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018802','customer');
insert into counterparty_contacts(id,organization_id,counterparty_id,contact_type,value,is_primary)values
 ('00000000-0000-0000-0000-000000018821','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018801','phone','+998900001818',true),
 ('00000000-0000-0000-0000-000000018822','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018801','email','private@example.test',true);
insert into counterparty_addresses(id,organization_id,counterparty_id,address_type,address_text,is_primary)values
 ('00000000-0000-0000-0000-000000018831','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018801','legal','Private address',true);
select set_config('market_pos.counterparty_command','off',true);

-- Pricing/current-history fixture.
insert into units_v2(id,organization_id,code,name,short_name)values
 ('00000000-0000-0000-0000-000000018901','00000000-0000-0000-0000-000000018101','EA','Each','ea');
insert into products_v2(id,organization_id,sku,name,base_unit_id)values
 ('00000000-0000-0000-0000-000000018902','00000000-0000-0000-0000-000000018101','SKU18','Product 18','00000000-0000-0000-0000-000000018901');
select set_config('market_pos.pricing_command','on',true);
insert into price_lists(id,organization_id,branch_id,code,name,currency_code,status)values
 ('00000000-0000-0000-0000-000000018911','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','ACTIVE','Active list','UZS','active'),
 ('00000000-0000-0000-0000-000000018912','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','INACTIVE','Inactive list','UZS','inactive');
insert into product_prices(id,organization_id,price_list_id,product_id,amount,currency_code,valid_from,valid_to,confirmed_by)values
 ('00000000-0000-0000-0000-000000018921','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018911','00000000-0000-0000-0000-000000018902',10,'UZS',now()-interval'20 days',now()-interval'10 days','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018922','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018911','00000000-0000-0000-0000-000000018902',20,'UZS',now()-interval'1 day',now()+interval'1 day','00000000-0000-0000-0000-000000018301'),
 ('00000000-0000-0000-0000-000000018923','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018911','00000000-0000-0000-0000-000000018902',30,'UZS',now()+interval'2 days',null,'00000000-0000-0000-0000-000000018301');
insert into price_history(id,organization_id,product_price_id,price_list_id,product_id,old_amount,new_amount,reason_code,source_type,changed_by)values
 ('00000000-0000-0000-0000-000000018931','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018921','00000000-0000-0000-0000-000000018911','00000000-0000-0000-0000-000000018902',null,10,'initial','initial','00000000-0000-0000-0000-000000018301');
select set_config('market_pos.pricing_command','off',true);

-- Inventory projection/raw fixture.
select set_config('market_pos.inventory_command','on',true);
insert into inventory_documents(id,organization_id,branch_id,warehouse_id,document_type,document_number,business_date,reason_code)values
 ('00000000-0000-0000-0000-000000018941','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018501','adjustment','I18-A1',current_date,'count');
insert into inventory_document_lines(id,organization_id,inventory_document_id,line_number,product_id,unit_id,quantity,unit_factor,base_quantity_delta)values
 ('00000000-0000-0000-0000-000000018942','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018941',1,'00000000-0000-0000-0000-000000018902','00000000-0000-0000-0000-000000018901',5,1,5);
insert into warehouse_transfers(id,organization_id,branch_id,source_warehouse_id,destination_warehouse_id,document_number,business_date)values
 ('00000000-0000-0000-0000-000000018943','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018501','00000000-0000-0000-0000-000000018504','T18-A1',current_date);
insert into inventory_balances(id,organization_id,warehouse_id,product_id,on_hand_quantity)values
 ('00000000-0000-0000-0000-000000018944','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018501','00000000-0000-0000-0000-000000018902',5);
insert into command_log(id,organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,local_operation_id,command_type,payload_hash)values
 ('00000000-0000-0000-0000-000000018951','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018701','00000000-0000-0000-0000-000000018001','00000000-0000-0000-0000-000000018301','00000000-0000-0000-0000-000000018951','inventory.test','hash18');
insert into inventory_movements(id,organization_id,branch_id,warehouse_id,product_id,movement_type,quantity_delta,source_document_type,source_document_id,source_line_id,command_id,created_by)values
 ('00000000-0000-0000-0000-000000018952','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018501','00000000-0000-0000-0000-000000018902','adjustment',5,'inventory_document','00000000-0000-0000-0000-000000018941','00000000-0000-0000-0000-000000018942','00000000-0000-0000-0000-000000018951','00000000-0000-0000-0000-000000018301');
select set_config('market_pos.inventory_command','off',true);

-- Safe sync/audit fixtures for two actors.
insert into sync_commands(id,organization_id,device_id,actor_membership_id,local_operation_id,command_type,schema_version,payload,payload_hash,client_created_at)values
 ('00000000-0000-0000-0000-000000018961','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018701','00000000-0000-0000-0000-000000018302','00000000-0000-0000-0000-000000018961','sale.post',1,'{"secret":"seller"}','payload-hash-seller',now()),
 ('00000000-0000-0000-0000-000000018962','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018701','00000000-0000-0000-0000-000000018301','00000000-0000-0000-0000-000000018962','sale.post',1,'{"secret":"owner"}','payload-hash-owner',now());
insert into audit_events(id,organization_id,branch_id,actor_auth_user_id,actor_membership_id,correlation_id,action,entity_type,entity_id,metadata,before_data,after_data)values
 ('00000000-0000-0000-0000-000000018971','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018002','00000000-0000-0000-0000-000000018302','00000000-0000-0000-0000-000000018971','seller.action','test','00000000-0000-0000-0000-000000018801','{"secret":"metadata"}','{"secret":"before"}','{"secret":"after"}'),
 ('00000000-0000-0000-0000-000000018972','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018401','00000000-0000-0000-0000-000000018001','00000000-0000-0000-0000-000000018301','00000000-0000-0000-0000-000000018972','owner.action','test','00000000-0000-0000-0000-000000018801','{"secret":"owner metadata"}',null,null);

-- Owner/tenant and device projection behavior.
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018001',true);set local role authenticated;
select is((select count(*)from devices_v2 where organization_id='00000000-0000-0000-0000-000000018101'),2::bigint,'owner A reads own raw devices');
select is((select count(*)from devices_v2 where organization_id='00000000-0000-0000-0000-000000018102'),0::bigint,'owner A cannot read organization B devices');
select is((select count(*)from v2_member_directory('00000000-0000-0000-0000-000000018101')),6::bigint,'owner enumerates own organization members through safe directory');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018004',true);set local role authenticated;
select is((select count(*)from devices_v2 where organization_id='00000000-0000-0000-0000-000000018101'),0::bigint,'owner B cannot read organization A');
select is((select count(*)from devices_v2 where organization_id='00000000-0000-0000-0000-000000018102'),1::bigint,'owner B reads organization B');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018002',true);set local role authenticated;
select is((select count(*)from devices_v2),0::bigint,'seller raw devices are hidden');
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018101',null)),1::bigint,'seller device directory returns assigned branch only');
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018402')),0::bigint,'seller device directory hides unauthorized branch');
select ok(not(to_jsonb(d)?'fingerprint_hash'),'device projection omits fingerprint')from v2_device_directory('00000000-0000-0000-0000-000000018101',null)d;
select ok(not(to_jsonb(d)?'legacy_device_id'),'device projection omits legacy mapping')from v2_device_directory('00000000-0000-0000-0000-000000018101',null)d;
select ok(not(to_jsonb(d)?'last_sync_cursor'),'device projection omits sync cursor')from v2_device_directory('00000000-0000-0000-0000-000000018101',null)d;
select throws_ok($$select * from v2_member_directory('00000000-0000-0000-0000-000000018101')$$,'P0001','V2_USERS_MANAGE_REQUIRED','seller cannot enumerate members');

-- Customer raw/private versus safe directory.
select is((select count(*)from counterparties),0::bigint,'customer.view seller cannot read raw counterparty');
select is((select count(*)from counterparty_contacts),0::bigint,'customer.view seller cannot read raw contacts');
select is((select count(*)from counterparty_addresses),0::bigint,'customer.view seller cannot read raw addresses');
select is((select count(*)from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,50)),1::bigint,'safe customer directory returns active tenant customer');
select is((select primary_phone from v2_customer_directory('00000000-0000-0000-0000-000000018101','90000',50)),'+998900001818','customer search matches primary phone');
select ok(not(to_jsonb(c)?'legal_name'),'customer projection omits legal name')from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,50)c;
select ok(not(to_jsonb(c)?'tax_id'),'customer projection omits tax id')from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,50)c;
select ok(not(to_jsonb(c)?'notes'),'customer projection omits notes')from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,50)c;
select throws_ok($$select * from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,101)$$,'P0001','V2_CUSTOMER_DIRECTORY_LIMIT_INVALID','customer directory enforces limit');

-- Current-only pricing and projection-only inventory for seller_default.
select is((select count(*)from price_lists),1::bigint,'pricing.view sees only active usable list');
select is((select count(*)from product_prices),1::bigint,'pricing.view sees only current effective price');
select is((select amount from product_prices),20.0000::numeric,'seller sees current price amount');
select is((select count(*)from price_history),0::bigint,'seller cannot read pricing history');
select is((select count(*)from inventory_balances),1::bigint,'inventory.view reads authorized balance projection');
select is((select count(*)from inventory_documents),0::bigint,'inventory.view cannot read raw inventory document');
select is((select count(*)from inventory_document_lines),0::bigint,'inventory.view cannot read raw inventory lines');
select is((select count(*)from inventory_movements),0::bigint,'inventory.view cannot read raw movement ledger');
select is((select count(*)from warehouse_transfers),0::bigint,'inventory.view cannot read raw transfer');
select is((select count(*)from product_batches_v2),0::bigint,'inventory permission does not expose purchase cost batches');

-- Sync and audit projections.
select is((select count(*)from v2_sync_command_journal('00000000-0000-0000-0000-000000018101',null)),1::bigint,'seller sync journal returns own actor rows only');
select ok(not(to_jsonb(j)?'payload'),'sync journal omits payload')from v2_sync_command_journal('00000000-0000-0000-0000-000000018101',null)j;
select is((select count(*)from v2_my_activity_journal('00000000-0000-0000-0000-000000018101',100)),1::bigint,'seller activity journal returns own events only');
select ok(not(to_jsonb(j)?'metadata'),'activity projection omits metadata')from v2_my_activity_journal('00000000-0000-0000-0000-000000018101',100)j;
select ok(not(to_jsonb(j)?'before_data'),'activity projection omits before data')from v2_my_activity_journal('00000000-0000-0000-0000-000000018101',100)j;
select ok(not(to_jsonb(j)?'after_data'),'activity projection omits after data')from v2_my_activity_journal('00000000-0000-0000-0000-000000018101',100)j;
select throws_ok($$select * from v2_audit_journal('00000000-0000-0000-0000-000000018101')$$,'P0001','V2_AUDIT_VIEW_REQUIRED','seller cannot use full audit journal');

-- Blocked profile and membership lose access immediately.
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018006',true);set local role authenticated;
select is((select count(*)from branches),0::bigint,'blocked profile sees no tenant branches');
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018101',null)),0::bigint,'blocked profile gets no device projection');
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018007',true);set local role authenticated;
select is((select count(*)from branches),0::bigint,'blocked membership sees no tenant branches');
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018101',null)),0::bigint,'blocked membership gets no device projection');

-- A custom branch-scoped operator proves adjust/transfer raw policy separation.
reset role;select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018008',true);set local role authenticated;
select is((select count(*)from inventory_documents),1::bigint,'inventory.adjust operator reads scoped raw document');
select is((select count(*)from inventory_movements),1::bigint,'inventory.adjust operator reads scoped raw movement');
select is((select count(*)from warehouse_transfers),1::bigint,'inventory.transfer operator reads scoped transfer');
select is((select count(*)from devices_v2),1::bigint,'devices.manage operator reads scoped raw device');
select is((select count(*)from price_history),1::bigint,'pricing manager reads history');

-- Exact support grants, lifecycle and tenant boundaries. No support membership exists.
reset role;
insert into support_access_grants(id,organization_id,service_admin_profile_id,scopes,reason,status,approved_by_membership_id,starts_at,expires_at,revoked_at)values
 ('00000000-0000-0000-0000-000000018981','00000000-0000-0000-0000-000000018101','00000000-0000-0000-0000-000000018205',array['devices.manage'],'active devices','active','00000000-0000-0000-0000-000000018301',now()-interval'1 hour',now()+interval'1 hour',null),
 ('00000000-0000-0000-0000-000000018982','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018205',array['devices.manage'],'expired devices','active','00000000-0000-0000-0000-000000018304',now()-interval'2 hours',now()-interval'1 hour',null),
 ('00000000-0000-0000-0000-000000018983','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018205',array['audit.view'],'pending audit','pending',null,now(),now()+interval'1 hour',null),
 ('00000000-0000-0000-0000-000000018984','00000000-0000-0000-0000-000000018102','00000000-0000-0000-0000-000000018205',array['counterparties.view'],'revoked counterparties','revoked','00000000-0000-0000-0000-000000018304',now()-interval'2 hours',now()+interval'1 hour',now()-interval'1 hour');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000018005',true);set local role authenticated;
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018101',null)),2::bigint,'active exact devices grant enables safe device directory');
select is((select count(*)from v2_sync_command_journal('00000000-0000-0000-0000-000000018101',null)),2::bigint,'devices grant enables safe support sync journal');
select is((select count(*)from v2_device_directory('00000000-0000-0000-0000-000000018102',null)),0::bigint,'expired cross-tenant devices grant denied');
select throws_ok($$select * from v2_audit_journal('00000000-0000-0000-0000-000000018101')$$,'P0001','V2_AUDIT_VIEW_REQUIRED','devices grant does not imply audit view');
select throws_ok($$select * from v2_customer_directory('00000000-0000-0000-0000-000000018101',null,50)$$,'P0001','V2_CUSTOMER_DIRECTORY_REQUIRED','devices grant does not imply counterparty view');
select is((select count(*)from cash_movements),0::bigint,'devices grant does not imply cash view');
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000018101','purchases.cost.view'),'devices grant does not imply purchase cost');
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000018102','devices.manage'),'expired grant is inactive');
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000018102','audit.view'),'pending grant is inactive');
select ok(not public.v2_has_support_grant('00000000-0000-0000-0000-000000018102','counterparties.view'),'revoked grant is inactive');
select throws_ok($$select * from v2_my_activity_journal('00000000-0000-0000-0000-000000018101',100)$$,'P0001','V2_ACTIVITY_ACTIVE_MEMBERSHIP_REQUIRED','service admin cannot use member activity surface');

-- Anonymous has no tenant data and no safe RPC execution.
reset role;select set_config('request.jwt.claim.sub','',true);set local role anon;
select throws_ok($$select count(*)from branches$$,'42501',null,'anonymous cannot read V2 branches');
select throws_ok($$select count(*)from products_v2$$,'42501',null,'anonymous cannot read V2 products');
select throws_ok($$select count(*)from devices_v2$$,'42501',null,'anonymous cannot read V2 devices');
select throws_ok($$select * from v2_device_directory('00000000-0000-0000-0000-000000018101',null)$$,'42501',null,'anonymous cannot execute device directory');
reset role;

-- Existing sales/debt/cash protections remain represented by their restrictive
-- raw policies and safe projections; 0018 does not replace these functions.
select ok(position('v2_can_view_sale'in coalesce((select qual from pg_policies where tablename='sales_v2'and policyname='sales_v2_select'),''))>0,'seller sale visibility remains shift-aware');
select ok(position('sales.cost.view'in pg_get_functiondef('public.v2_can_view_sale(uuid,uuid,uuid,boolean)'::regprocedure))>0,'raw sale cost still requires sales.cost.view');
select ok(position('system_role = ''owner'''in coalesce((select qual from pg_policies where tablename='cash_movements'and policyname='cash_movements_owner_select'),''))>0,'raw cash remains owner-only');
select ok(to_regprocedure('public.v2_cash_journal(uuid,uuid,uuid)')is not null,'seller own-shift cash safe journal remains');
select ok(position('debts.view'in pg_get_functiondef('public.v2_can_view_debt(uuid,uuid)'::regprocedure))>0,'debt access remains permission driven');
select ok(position('purchases.cost.view'in pg_get_functiondef('public.v2_can_view_settlement(uuid,uuid,text)'::regprocedure))>0,'purchase settlement entries remain cost protected');
select ok(position('v2_can_view_settlement_period'in coalesce((select qual from pg_policies where tablename='settlement_acts'and policyname='settlement_acts_select'),''))>0
  and position('v2_can_view_full_settlement_scope'in pg_get_functiondef('public.v2_can_view_settlement_period(uuid)'::regprocedure))>0,
  'settlement act remains full-scope protected');

select * from finish();
rollback;
