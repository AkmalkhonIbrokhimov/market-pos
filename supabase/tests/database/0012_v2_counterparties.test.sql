begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(282);

select has_table('public',t,t||' exists') from(values
('counterparties'),('counterparty_roles'),('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'),
('suppliers'),('customers'),('stores'),('product_batches'),('sales'),('debt_entries'),('debt_payments'))x(t);
select has_column('public',t,c,t||'.'||c)from(values
('counterparties','id'),('counterparties','organization_id'),('counterparties','legacy_supplier_id'),('counterparties','legacy_customer_id'),('counterparties','display_name'),('counterparties','legal_name'),('counterparties','tax_id'),('counterparties','notes'),('counterparties','status'),('counterparties','created_at'),('counterparties','updated_at'),('counterparties','archived_at'),
('counterparty_roles','id'),('counterparty_roles','organization_id'),('counterparty_roles','counterparty_id'),('counterparty_roles','role_code'),('counterparty_roles','started_at'),('counterparty_roles','ended_at'),
('counterparty_contacts','id'),('counterparty_contacts','organization_id'),('counterparty_contacts','counterparty_id'),('counterparty_contacts','contact_type'),('counterparty_contacts','value'),('counterparty_contacts','label'),('counterparty_contacts','is_primary'),('counterparty_contacts','created_at'),('counterparty_contacts','archived_at'),
('counterparty_addresses','id'),('counterparty_addresses','organization_id'),('counterparty_addresses','counterparty_id'),('counterparty_addresses','address_type'),('counterparty_addresses','address_text'),('counterparty_addresses','metadata'),('counterparty_addresses','is_primary'),('counterparty_addresses','created_at'),('counterparty_addresses','archived_at'),
('counterparty_credit_settings','counterparty_id'),('counterparty_credit_settings','organization_id'),('counterparty_credit_settings','credit_enabled'),('counterparty_credit_settings','credit_limit_amount'),('counterparty_credit_settings','max_due_days'),('counterparty_credit_settings','currency_code'),('counterparty_credit_settings','updated_by'),('counterparty_credit_settings','updated_at'))x(t,c);
select col_type_is('public',t,c,typ,t||'.'||c||' type')from(values
('counterparties','id','uuid'),('counterparties','organization_id','uuid'),('counterparties','legacy_supplier_id','uuid'),('counterparties','legacy_customer_id','uuid'),('counterparties','display_name','text'),('counterparties','legal_name','text'),('counterparties','tax_id','text'),('counterparties','notes','text'),('counterparties','status','text'),('counterparties','created_at','timestamp with time zone'),('counterparties','updated_at','timestamp with time zone'),('counterparties','archived_at','timestamp with time zone'),
('counterparty_roles','id','uuid'),('counterparty_roles','organization_id','uuid'),('counterparty_roles','counterparty_id','uuid'),('counterparty_roles','role_code','text'),('counterparty_roles','started_at','timestamp with time zone'),('counterparty_roles','ended_at','timestamp with time zone'),
('counterparty_contacts','id','uuid'),('counterparty_contacts','organization_id','uuid'),('counterparty_contacts','counterparty_id','uuid'),('counterparty_contacts','contact_type','text'),('counterparty_contacts','value','text'),('counterparty_contacts','label','text'),('counterparty_contacts','is_primary','boolean'),('counterparty_contacts','created_at','timestamp with time zone'),('counterparty_contacts','archived_at','timestamp with time zone'),
('counterparty_addresses','id','uuid'),('counterparty_addresses','organization_id','uuid'),('counterparty_addresses','counterparty_id','uuid'),('counterparty_addresses','address_type','text'),('counterparty_addresses','address_text','text'),('counterparty_addresses','metadata','jsonb'),('counterparty_addresses','is_primary','boolean'),('counterparty_addresses','created_at','timestamp with time zone'),('counterparty_addresses','archived_at','timestamp with time zone'),
('counterparty_credit_settings','counterparty_id','uuid'),('counterparty_credit_settings','organization_id','uuid'),('counterparty_credit_settings','credit_enabled','boolean'),('counterparty_credit_settings','credit_limit_amount','numeric(18,4)'),('counterparty_credit_settings','max_due_days','integer'),('counterparty_credit_settings','currency_code','character(3)'),('counterparty_credit_settings','updated_by','uuid'),('counterparty_credit_settings','updated_at','timestamp with time zone'))x(t,c,typ);
select col_not_null('public',t,c,t||'.'||c||' required')from(values
('counterparties','id'),('counterparties','organization_id'),('counterparties','display_name'),('counterparties','status'),('counterparties','created_at'),('counterparties','updated_at'),
('counterparty_roles','id'),('counterparty_roles','organization_id'),('counterparty_roles','counterparty_id'),('counterparty_roles','role_code'),('counterparty_roles','started_at'),
('counterparty_contacts','id'),('counterparty_contacts','organization_id'),('counterparty_contacts','counterparty_id'),('counterparty_contacts','contact_type'),('counterparty_contacts','value'),('counterparty_contacts','is_primary'),('counterparty_contacts','created_at'),
('counterparty_addresses','id'),('counterparty_addresses','organization_id'),('counterparty_addresses','counterparty_id'),('counterparty_addresses','address_type'),('counterparty_addresses','address_text'),('counterparty_addresses','metadata'),('counterparty_addresses','is_primary'),('counterparty_addresses','created_at'),
('counterparty_credit_settings','counterparty_id'),('counterparty_credit_settings','organization_id'),('counterparty_credit_settings','credit_enabled'),('counterparty_credit_settings','credit_limit_amount'),('counterparty_credit_settings','max_due_days'),('counterparty_credit_settings','currency_code'),('counterparty_credit_settings','updated_by'),('counterparty_credit_settings','updated_at'))x(t,c);
select ok((select relrowsecurity from pg_class where oid=format('public.%I',t)::regclass),t||' RLS')from(values('counterparties'),('counterparty_roles'),('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'))x(t);
select ok(not has_table_privilege('anon',format('public.%I',t),'SELECT,INSERT,UPDATE,DELETE'),'anon denied '||t)from(values('counterparties'),('counterparty_roles'),('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'))x(t);
select ok(has_table_privilege('authenticated',format('public.%I',t),'SELECT'),'auth select '||t)from(values('counterparties'),('counterparty_roles'),('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'))x(t);
select ok(not has_table_privilege('authenticated',format('public.%I',t),'INSERT,UPDATE,DELETE'),'auth writes denied '||t)from(values('counterparties'),('counterparty_roles'),('counterparty_contacts'),('counterparty_addresses'),('counterparty_credit_settings'))x(t);

select has_index('public',t,i,i)from(values
('counterparties','counterparties_org_status_name_idx'),('counterparties','counterparties_active_name_idx'),('counterparties','counterparties_tax_key'),('counterparties','counterparties_legacy_supplier_key'),('counterparties','counterparties_legacy_customer_key'),
('counterparty_roles','counterparty_roles_active_key'),('counterparty_roles','counterparty_roles_org_code_idx'),
('counterparty_contacts','counterparty_contacts_primary_key'),('counterparty_contacts','counterparty_contacts_lookup_idx'),('counterparty_contacts','counterparty_contacts_party_idx'),
('counterparty_addresses','counterparty_addresses_primary_key'),('counterparty_addresses','counterparty_addresses_party_idx'),
('counterparty_credit_settings','counterparty_credit_org_enabled_idx'))x(t,i);
select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and conname=n and contype='f'),n)from(values
('counterparties','counterparties_organization_id_fkey'),('counterparties','counterparties_legacy_supplier_id_fkey'),('counterparties','counterparties_legacy_customer_id_fkey'),
('counterparty_roles','counterparty_roles_organization_id_fkey'),('counterparty_roles','counterparty_roles_counterparty_id_fkey'),
('counterparty_contacts','counterparty_contacts_organization_id_fkey'),('counterparty_contacts','counterparty_contacts_counterparty_id_fkey'),
('counterparty_addresses','counterparty_addresses_organization_id_fkey'),('counterparty_addresses','counterparty_addresses_counterparty_id_fkey'),
('counterparty_credit_settings','counterparty_credit_settings_counterparty_id_fkey'),('counterparty_credit_settings','counterparty_credit_settings_organization_id_fkey'),('counterparty_credit_settings','counterparty_credit_settings_updated_by_fkey'),
('product_batches','product_batches_supplier_id_fkey'),('sales','sales_customer_id_fkey'),('debt_entries','debt_entries_customer_id_fkey'),('debt_payments','debt_payments_customer_id_fkey'))x(t,n);
select has_function('public',f,args,f)from(values
('v2_can_view_counterparty',array['uuid','uuid']),('v2_can_view_counterparty_credit',array['uuid','uuid']),
('v2_create_counterparty',array['uuid','text','text','text','text','boolean','boolean','uuid','uuid']),
('v2_create_quick_customer',array['uuid','text','text']),('v2_update_counterparty',array['uuid','text','text','text','text','text']),
('v2_add_counterparty_role',array['uuid','text']),('v2_end_counterparty_role',array['uuid']),
('v2_upsert_counterparty_contact',array['uuid','uuid','text','text','text','boolean','boolean']),
('v2_upsert_counterparty_address',array['uuid','uuid','text','text','jsonb','boolean','boolean']),
('v2_set_counterparty_credit_settings',array['uuid','boolean','numeric','integer','character']),
('v2_archive_counterparty',array['uuid']))x(f,args);

select is((select count(*) from permissions where code like 'counterparties.%'),6::bigint,'six permissions');
select is((select count(*) from permissions where code like 'counterparties.%' and module='counterparties' and not critical),6::bigint,'permission metadata');
select is((select count(*) from permission_profile_permissions ppp join permissions p on p.id=ppp.permission_id where ppp.permission_profile_id='00000000-0000-0000-0000-000000000101' and p.code like 'counterparties.%'),6::bigint,'owner six');
select is((select count(*) from permission_profile_permissions ppp join permissions p on p.id=ppp.permission_id where ppp.permission_profile_id='00000000-0000-0000-0000-000000000102' and p.code like 'counterparties.%'),3::bigint,'seller three');
select is((select count(*) from permission_profile_permissions ppp join permissions p on p.id=ppp.permission_id where ppp.permission_profile_id='00000000-0000-0000-0000-000000000102' and p.code in('counterparties.view','counterparties.manage','counterparties.credit.manage')),0::bigint,'seller no elevated');
select ok((select tgenabled='O' from pg_trigger where tgrelid='public.permissions'::regclass and tgname='v2_permissions_prevent_insert'),'permission insert trigger enabled');
select throws_ok($$insert into permissions(code,module,description,critical)values('bad','bad','bad',false)$$,'P0001','V2_PERMISSION_REGISTRY_MUTATION_FORBIDDEN','runtime permission insert denied');
select throws_ok($$update permissions set module='bad' where code='counterparties.view'$$,'P0001','V2_PERMISSION_REGISTRY_MUTATION_FORBIDDEN','permission update denied');
select throws_ok($$delete from permissions where code='counterparties.view'$$,'P0001','V2_PERMISSION_REGISTRY_MUTATION_FORBIDDEN','permission delete denied');
select is((select count(*) from counterparties),0::bigint,'no backfill');
select is((select count(*) from supabase_migrations.schema_migrations where version between '0001' and '0012'),12::bigint,'migrations 1-12');

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)values
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000012001','authenticated','authenticated','o12@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000012002','authenticated','authenticated','s12@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000012003','authenticated','authenticated','x12@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000012004','authenticated','authenticated','inactive12@test','','now','now','now');
insert into organizations(id,name)values('00000000-0000-0000-0000-000000012101','A12'),('00000000-0000-0000-0000-000000012102','B12');
insert into stores(id,organization_id,name)values('00000000-0000-0000-0000-000000012111','00000000-0000-0000-0000-000000012101','SA'),('00000000-0000-0000-0000-000000012112','00000000-0000-0000-0000-000000012102','SB');
insert into suppliers(id,organization_id,name)values('00000000-0000-0000-0000-000000012121','00000000-0000-0000-0000-000000012101','SupA'),('00000000-0000-0000-0000-000000012122','00000000-0000-0000-0000-000000012102','SupB');
insert into customers(id,store_id,full_name)values('00000000-0000-0000-0000-000000012131','00000000-0000-0000-0000-000000012111','CusA'),('00000000-0000-0000-0000-000000012132','00000000-0000-0000-0000-000000012112','CusB');
insert into user_profiles(id,auth_user_id,full_name)values('00000000-0000-0000-0000-000000012201','00000000-0000-0000-0000-000000012001','Owner'),('00000000-0000-0000-0000-000000012202','00000000-0000-0000-0000-000000012002','Seller'),('00000000-0000-0000-0000-000000012203','00000000-0000-0000-0000-000000012003','Service'),('00000000-0000-0000-0000-000000012204','00000000-0000-0000-0000-000000012004','Inactive');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at)values
('00000000-0000-0000-0000-000000012301','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012201','owner','active',now()),
('00000000-0000-0000-0000-000000012302','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012202','seller','active',now()),
('00000000-0000-0000-0000-000000012303','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012203','service_admin','active',now()),
('00000000-0000-0000-0000-000000012304','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012204','seller','inactive',null);
insert into membership_permission_profiles(membership_id,permission_profile_id,assigned_by)values
('00000000-0000-0000-0000-000000012302','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000012301'),
('00000000-0000-0000-0000-000000012304','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000012301');
select is((select count(*) from permission_profile_permissions ppp join permissions p on p.id=ppp.permission_id where ppp.permission_profile_id='00000000-0000-0000-0000-000000000102' and p.code in('counterparties.customer.view','counterparties.customer.create','counterparties.credit.view')),3::bigint,'seller cache set has three permissions');
update organization_memberships om set permission_version=om.permission_version+1 where om.status='active' and exists(select 1 from membership_permission_profiles mpp where mpp.membership_id=om.id and mpp.permission_profile_id='00000000-0000-0000-0000-000000000102');
select is((select permission_version from organization_memberships where id='00000000-0000-0000-0000-000000012302'),3::bigint,'active seller cache version bumped once by path');
select is((select permission_version from organization_memberships where id='00000000-0000-0000-0000-000000012301'),1::bigint,'membership without seller default unchanged');
select is((select permission_version from organization_memberships where id='00000000-0000-0000-0000-000000012304'),2::bigint,'inactive seller membership unchanged by cache path');

select throws_ok($$insert into counterparties(organization_id,display_name)values('00000000-0000-0000-0000-000000012101','Direct')$$,'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct party denied');
select throws_ok($$insert into counterparty_roles(organization_id,counterparty_id,role_code)values('00000000-0000-0000-0000-000000012101',gen_random_uuid(),'customer')$$,'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct role denied');
select throws_ok($$insert into counterparty_contacts(organization_id,counterparty_id,contact_type,value)values('00000000-0000-0000-0000-000000012101',gen_random_uuid(),'phone','1')$$,'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct contact denied');
select throws_ok($$insert into counterparty_addresses(organization_id,counterparty_id,address_type,address_text)values('00000000-0000-0000-0000-000000012101',gen_random_uuid(),'legal','x')$$,'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct address denied');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012001',true);set local role authenticated;
select lives_ok($$select v2_create_counterparty('00000000-0000-0000-0000-000000012101','Dual','Legal','TIN12','note',true,true,'00000000-0000-0000-0000-000000012121','00000000-0000-0000-0000-000000012131')$$,'owner creates dual');
reset role;
select is((select count(*) from counterparties where display_name='Dual'),1::bigint,'party created');
select is((select count(*) from counterparty_roles where ended_at is null),2::bigint,'two roles');
select is((select count(*) from audit_events where action='counterparty.created'),1::bigint,'create audit');
select is((select count(*) from outbox_events where event_type='CounterpartyCreated'),1::bigint,'create outbox');
select throws_ok($$update counterparties set organization_id='00000000-0000-0000-0000-000000012102' where display_name='Dual'$$,'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct update denied');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012002',true);set local role authenticated;
select lives_ok($$select v2_create_quick_customer('00000000-0000-0000-0000-000000012101','Quick','99890')$$,'seller quick customer');
select throws_ok($$select v2_create_counterparty('00000000-0000-0000-0000-000000012101','Bad',null,null,null,true,false,null,null)$$,'P0001','V2_COUNTERPARTIES_MANAGE_REQUIRED','seller cannot supplier');
reset role;
select is((select count(*) from counterparties where display_name='Quick'),1::bigint,'quick party');
select is((select count(*) from counterparty_roles r join counterparties p on p.id=r.counterparty_id where p.display_name='Quick' and r.role_code='customer' and r.ended_at is null),1::bigint,'quick customer role');
select is((select count(*) from counterparty_contacts c join counterparties p on p.id=c.counterparty_id where p.display_name='Quick' and c.value='99890'),1::bigint,'quick phone');
select is((select count(*) from counterparties where display_name='Quick' and tax_id is null and legal_name is null and notes is null),1::bigint,'quick restricted fields');

select set_config('market_pos.counterparty_command','on',true);
select throws_ok($$insert into counterparties(organization_id,legacy_supplier_id,display_name)values('00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012122','bad')$$,'P0001','V2_COUNTERPARTY_SUPPLIER_TENANT_MISMATCH','supplier tenant');
select throws_ok($$insert into counterparties(organization_id,legacy_customer_id,display_name)values('00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012132','bad')$$,'P0001','V2_COUNTERPARTY_CUSTOMER_TENANT_MISMATCH','customer tenant');
select throws_ok($$insert into counterparties(organization_id,legacy_supplier_id,display_name)values('00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012121','dup')$$,'23505',null,'supplier mapping unique');
select throws_ok($$insert into counterparties(organization_id,legacy_customer_id,display_name)values('00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012131','dup')$$,'23505',null,'customer mapping unique');
select lives_ok($$insert into counterparties(organization_id,display_name)values('00000000-0000-0000-0000-000000012101','Null1'),('00000000-0000-0000-0000-000000012101','Null2')$$,'multiple null mappings');
select throws_ok($$insert into counterparties(organization_id,display_name,tax_id)values('00000000-0000-0000-0000-000000012101','Tax Dup',' tin12 ')$$,'23505',null,'normalized tax unique');
select set_config('market_pos.counterparty_command','off',true);

set local role authenticated;
select is((select count(*) from counterparties),0::bigint,'seller customer permission uses the safe directory instead of raw parties');
select is((select count(*) from counterparties where display_name='Null1'),0::bigint,'seller hides supplierless');
select is((select count(*) from counterparty_roles where role_code='supplier'),0::bigint,'seller hides supplier roles');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012003',true);set local role authenticated;
select is((select count(*) from counterparties),0::bigint,'service admin alone denied');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012001',true);set local role authenticated;
select ok((select count(*) from counterparties)>=4,'owner full directory');
select lives_ok(format('select v2_set_counterparty_credit_settings(%L,true,100,30,%L)',(select id from counterparties where display_name='Dual'),'USD'),'owner credit');
reset role;
select is((select count(*) from counterparty_credit_settings where credit_enabled),1::bigint,'credit enabled');
select throws_ok($$insert into counterparty_credit_settings(counterparty_id,organization_id,currency_code,updated_by)
select id,organization_id,'USD','00000000-0000-0000-0000-000000012301' from counterparties where display_name='Quick'$$,
'P0001','V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED','direct credit denied');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012002',true);set local role authenticated;
select is((select count(*) from counterparty_credit_settings),1::bigint,'seller credit view works');
select throws_ok(format('select v2_set_counterparty_credit_settings(%L,false,0,0,%L)',(select id from counterparties where display_name='Dual'),'USD'),
'P0001','V2_COUNTERPARTY_CREDIT_MANAGE_REQUIRED','seller cannot manage credit');
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012001',true);set local role authenticated;
select lives_ok(format('select v2_upsert_counterparty_contact(null::uuid,%L,%L,%L,null,true,false)',(select id from counterparties where display_name='Dual'),'email','dual@test'),'contact command');
select throws_ok(format('select v2_upsert_counterparty_contact(null::uuid,%L,%L,%L,null,true,false)',(select id from counterparties where display_name='Dual'),'email','other@test'),'23505',null,'one primary contact type');
select lives_ok(format('select v2_upsert_counterparty_address(null::uuid,%L,%L,%L,%L::jsonb,true,false)',(select id from counterparties where display_name='Dual'),'delivery','Street','{}'),'address command');
select throws_ok(format('select v2_upsert_counterparty_address(null::uuid,%L,%L,%L,%L::jsonb,false,false)',(select id from counterparties where display_name='Dual'),'other','Bad','[]'),'23514',null,'address metadata object');
select throws_ok(format('select v2_end_counterparty_role(%L)',(select r.id from counterparty_roles r join counterparties p on p.id=r.counterparty_id where p.display_name='Dual' and r.role_code='customer' and r.ended_at is null)),
'P0001','V2_COUNTERPARTY_CUSTOMER_ROLE_ACTIVE_CREDIT','customer role blocked by credit');
select lives_ok(format('select v2_set_counterparty_credit_settings(%L,false,0,0,%L)',(select id from counterparties where display_name='Dual'),'USD'),'credit disabled');
select lives_ok(format('select v2_end_counterparty_role(%L)',(select r.id from counterparty_roles r join counterparties p on p.id=r.counterparty_id where p.display_name='Dual' and r.role_code='customer' and r.ended_at is null)),'customer role ends');
reset role;
select is((select count(*) from counterparty_roles r join counterparties p on p.id=r.counterparty_id where p.display_name='Dual' and r.role_code='customer' and r.ended_at is not null),1::bigint,'customer role ended');

set local role authenticated;
select lives_ok(format('select v2_archive_counterparty(%L)',(select id from counterparties where display_name='Dual')),'archive command');
reset role;
select is((select status from counterparties where display_name='Dual'),'archived','party archived');
select is((select count(*) from counterparty_roles r join counterparties p on p.id=r.counterparty_id where p.display_name='Dual' and r.ended_at is null),0::bigint,'roles ended on archive');
select is((select count(*) from counterparty_contacts c join counterparties p on p.id=c.counterparty_id where p.display_name='Dual' and c.archived_at is null),0::bigint,'contacts archived');
select is((select count(*) from counterparty_addresses a join counterparties p on p.id=a.counterparty_id where p.display_name='Dual' and a.archived_at is null),0::bigint,'addresses archived');
select is((select credit_enabled from counterparty_credit_settings c join counterparties p on p.id=c.counterparty_id where p.display_name='Dual'),false,'credit disabled on archive');

insert into support_access_grants(organization_id,service_admin_profile_id,scopes,reason,status,approved_by_membership_id,starts_at,expires_at)
values('00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012203',array['counterparties.view'],'support','active','00000000-0000-0000-0000-000000012301',now()-interval '1 minute',now()+interval '1 hour');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012003',true);set local role authenticated;
select ok((select count(*) from counterparties)>0,'exact support view grant works');
select throws_ok($$select v2_create_quick_customer('00000000-0000-0000-0000-000000012101','Support Bad',null)$$,'P0001','V2_COUNTERPARTY_CUSTOMER_CREATE_REQUIRED','support grant gives no writes');
reset role;
select throws_ok($$delete from counterparties where display_name='Null1'$$,'P0001','V2_COUNTERPARTY_HARD_DELETE_FORBIDDEN','hard delete denied');

-- Scope-safe child command fixtures.
select set_config('market_pos.counterparty_command','on',true);
insert into counterparties(id,organization_id,display_name)values
('00000000-0000-0000-0000-000000012501','00000000-0000-0000-0000-000000012101','Scope A'),
('00000000-0000-0000-0000-000000012502','00000000-0000-0000-0000-000000012102','Scope B'),
('00000000-0000-0000-0000-000000012503','00000000-0000-0000-0000-000000012101','Scope A2');
insert into counterparty_contacts(id,organization_id,counterparty_id,contact_type,value)values
('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012501','phone','A-old'),
('00000000-0000-0000-0000-000000012602','00000000-0000-0000-0000-000000012102','00000000-0000-0000-0000-000000012502','phone','B-old'),
('00000000-0000-0000-0000-000000012603','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012503','phone','A2-old');
insert into counterparty_addresses(id,organization_id,counterparty_id,address_type,address_text)values
('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012501','delivery','A-old'),
('00000000-0000-0000-0000-000000012702','00000000-0000-0000-0000-000000012102','00000000-0000-0000-0000-000000012502','delivery','B-old'),
('00000000-0000-0000-0000-000000012703','00000000-0000-0000-0000-000000012101','00000000-0000-0000-0000-000000012503','delivery','A2-old');
select set_config('market_pos.counterparty_command','off',true);

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000012001',true);set local role authenticated;
select throws_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012602','00000000-0000-0000-0000-000000012501','phone','hacked',null,false,false)$$,'P0001','V2_COUNTERPARTY_CONTACT_SCOPE_MISMATCH','cross-tenant contact id attack denied');
reset role;
select is((select value from counterparty_contacts where id='00000000-0000-0000-0000-000000012602'),'B-old','contact B unchanged');
select is((select count(*) from audit_events where entity_id='00000000-0000-0000-0000-000000012501'),0::bigint,'failed contact attack creates no audit');
select is((select count(*) from outbox_events where aggregate_id='00000000-0000-0000-0000-000000012501'),0::bigint,'failed contact attack creates no outbox');
set local role authenticated;
select throws_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012603','00000000-0000-0000-0000-000000012501','phone','hacked',null,false,false)$$,'P0001','V2_COUNTERPARTY_CONTACT_SCOPE_MISMATCH','same-tenant cross-party contact denied');
select throws_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012501','email','x',null,false,false)$$,'P0001','V2_COUNTERPARTY_CONTACT_TYPE_MUTATION_FORBIDDEN','contact type immutable');
select lives_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012501','phone','A-new','main',true,false)$$,'contact update works');
select lives_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012501','phone','ignored',null,true,true)$$,'contact archive works');
select throws_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012501','phone','restore',null,false,false)$$,'P0001','V2_COUNTERPARTY_CONTACT_ARCHIVED_IMMUTABLE','archived contact immutable');
select throws_ok($$select v2_upsert_counterparty_contact('00000000-0000-0000-0000-000000012601','00000000-0000-0000-0000-000000012501','phone','restore',null,false,true)$$,'P0001','V2_COUNTERPARTY_CONTACT_ARCHIVED_IMMUTABLE','archived contact cannot restore');
select throws_ok($$select v2_upsert_counterparty_contact(null,'00000000-0000-0000-0000-000000012501','phone','bad',null,false,true)$$,'P0001','V2_COUNTERPARTY_CONTACT_ARCHIVE_REQUIRES_EXISTING','contact cannot create archived');

select throws_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012702','00000000-0000-0000-0000-000000012501','delivery','hacked','{}',false,false)$$,'P0001','V2_COUNTERPARTY_ADDRESS_SCOPE_MISMATCH','cross-tenant address id attack denied');
reset role;
select is((select address_text from counterparty_addresses where id='00000000-0000-0000-0000-000000012702'),'B-old','address B unchanged');
set local role authenticated;
select throws_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012703','00000000-0000-0000-0000-000000012501','delivery','hacked','{}',false,false)$$,'P0001','V2_COUNTERPARTY_ADDRESS_SCOPE_MISMATCH','same-tenant cross-party address denied');
select throws_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012501','legal','x','{}',false,false)$$,'P0001','V2_COUNTERPARTY_ADDRESS_TYPE_MUTATION_FORBIDDEN','address type immutable');
select lives_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012501','delivery','A-new','{"city":"T"}',true,false)$$,'address update works');
select lives_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012501','delivery','ignored','{}',true,true)$$,'address archive works');
select throws_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012501','delivery','restore','{}',false,false)$$,'P0001','V2_COUNTERPARTY_ADDRESS_ARCHIVED_IMMUTABLE','archived address immutable');
select throws_ok($$select v2_upsert_counterparty_address('00000000-0000-0000-0000-000000012701','00000000-0000-0000-0000-000000012501','delivery','restore','{}',false,true)$$,'P0001','V2_COUNTERPARTY_ADDRESS_ARCHIVED_IMMUTABLE','archived address cannot restore');
select throws_ok($$select v2_upsert_counterparty_address(null,'00000000-0000-0000-0000-000000012501','delivery','bad','{}',false,true)$$,'P0001','V2_COUNTERPARTY_ADDRESS_ARCHIVE_REQUIRES_EXISTING','address cannot create archived');

select throws_ok(format('select v2_upsert_counterparty_contact(null,%L,%L,%L,null,false,false)',(select id from counterparties where display_name='Dual'),'phone','blocked'),'P0001','V2_COUNTERPARTY_ARCHIVED_SCOPE','archived party blocks contact create');
select throws_ok(format('select v2_upsert_counterparty_address(null,%L,%L,%L,%L::jsonb,false,false)',(select id from counterparties where display_name='Dual'),'other','blocked','{}'),'P0001','V2_COUNTERPARTY_ARCHIVED_SCOPE','archived party blocks address create');
select throws_ok(format('select v2_upsert_counterparty_contact(%L,%L,%L,%L,null,false,false)',(select c.id from counterparty_contacts c join counterparties p on p.id=c.counterparty_id where p.display_name='Dual' limit 1),(select id from counterparties where display_name='Dual'),'email','blocked'),'P0001','V2_COUNTERPARTY_ARCHIVED_SCOPE','archived party blocks contact update');
select throws_ok(format('select v2_upsert_counterparty_address(%L,%L,%L,%L,%L::jsonb,false,false)',(select a.id from counterparty_addresses a join counterparties p on p.id=a.counterparty_id where p.display_name='Dual' limit 1),(select id from counterparties where display_name='Dual'),'delivery','blocked','{}'),'P0001','V2_COUNTERPARTY_ARCHIVED_SCOPE','archived party blocks address update');
reset role;

select * from finish();
rollback;
