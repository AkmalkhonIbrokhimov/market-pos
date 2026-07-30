begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(247);

select has_table('public',t,t||' exists') from (values
('categories_v2'),('brands_v2'),('units_v2'),('product_types_v2'),('products_v2'),
('unit_conversions'),('product_barcodes'),('product_images'),
('categories'),('products'),('brands'),('units'),('product_types')) x(t);

select has_column('public',t,c,t||'.'||c||' exists') from (values
('categories_v2','id'),('categories_v2','organization_id'),('categories_v2','parent_id'),('categories_v2','legacy_category_id'),('categories_v2','name'),('categories_v2','description'),('categories_v2','sort_order'),('categories_v2','status'),('categories_v2','created_at'),('categories_v2','updated_at'),('categories_v2','archived_at'),
('brands_v2','id'),('brands_v2','organization_id'),('brands_v2','legacy_brand_id'),('brands_v2','name'),('brands_v2','description'),('brands_v2','status'),('brands_v2','created_at'),('brands_v2','updated_at'),('brands_v2','archived_at'),
('units_v2','id'),('units_v2','organization_id'),('units_v2','legacy_unit_id'),('units_v2','code'),('units_v2','name'),('units_v2','short_name'),('units_v2','precision_scale'),('units_v2','status'),('units_v2','created_at'),('units_v2','updated_at'),('units_v2','archived_at'),
('product_types_v2','id'),('product_types_v2','organization_id'),('product_types_v2','legacy_product_type_id'),('product_types_v2','code'),('product_types_v2','name'),('product_types_v2','description'),('product_types_v2','behavior'),('product_types_v2','status'),('product_types_v2','created_at'),('product_types_v2','updated_at'),('product_types_v2','archived_at'),
('products_v2','id'),('products_v2','organization_id'),('products_v2','legacy_product_id'),('products_v2','sku'),('products_v2','name'),('products_v2','category_id'),('products_v2','brand_id'),('products_v2','product_type_id'),('products_v2','base_unit_id'),('products_v2','description'),('products_v2','is_expirable'),('products_v2','is_weighted'),('products_v2','min_quantity'),('products_v2','status'),('products_v2','version'),('products_v2','created_at'),('products_v2','updated_at'),('products_v2','archived_at'),
('unit_conversions','id'),('unit_conversions','organization_id'),('unit_conversions','product_id'),('unit_conversions','from_unit_id'),('unit_conversions','to_unit_id'),('unit_conversions','factor'),('unit_conversions','status'),('unit_conversions','created_at'),('unit_conversions','updated_at'),
('product_barcodes','id'),('product_barcodes','organization_id'),('product_barcodes','product_id'),('product_barcodes','barcode'),('product_barcodes','normalized_barcode'),('product_barcodes','is_primary'),('product_barcodes','status'),('product_barcodes','created_at'),('product_barcodes','archived_at'),
('product_images','id'),('product_images','organization_id'),('product_images','product_id'),('product_images','storage_bucket'),('product_images','storage_path'),('product_images','content_type'),('product_images','size_bytes'),('product_images','sort_order'),('product_images','is_primary'),('product_images','created_at'),('product_images','archived_at')
) x(t,c);

select ok((select relrowsecurity from pg_class where oid=format('public.%I',t)::regclass),t||' RLS enabled')
from (values('categories_v2'),('brands_v2'),('units_v2'),('product_types_v2'),('products_v2'),('unit_conversions'),('product_barcodes'),('product_images'))x(t);
select ok(not has_table_privilege('anon',format('public.%I',t),'SELECT,INSERT,UPDATE,DELETE'),'anon denied '||t)
from (values('categories_v2'),('brands_v2'),('units_v2'),('product_types_v2'),('products_v2'),('unit_conversions'),('product_barcodes'),('product_images'))x(t);
select ok(not has_table_privilege('authenticated',format('public.%I',t),'INSERT,UPDATE,DELETE'),'browser writes denied '||t)
from (values('categories_v2'),('brands_v2'),('units_v2'),('product_types_v2'),('products_v2'),('unit_conversions'),('product_barcodes'),('product_images'))x(t);
select ok(has_table_privilege('authenticated',format('public.%I',t),'SELECT'),'authenticated select '||t)
from (values('categories_v2'),('brands_v2'),('units_v2'),('product_types_v2'),('products_v2'),('unit_conversions'),('product_barcodes'),('product_images'))x(t);

select has_column('public','products',c,'legacy products.'||c||' preserved')
from (values('barcode'),('sale_price'),('current_quantity'),('unit'),('brand_id'),('unit_id'),('product_type_id'))x(c);
select has_column('public','brands',c,'legacy brands.'||c||' preserved') from (values('id'),('organization_id'),('name'),('status'))x(c);
select has_column('public','units',c,'legacy units.'||c||' preserved') from (values('id'),('organization_id'),('name'),('short_name'))x(c);
select has_column('public','product_types',c,'legacy product_types.'||c||' preserved') from (values('id'),('organization_id'),('name'),('code'))x(c);
select hasnt_column('public','products_v2',c,'products_v2 excludes '||c) from (values('sale_price'),('current_quantity'),('barcode'),('unit'))x(c);

select has_index('public',t,i,i||' exists') from (values
('categories_v2','categories_v2_parent_sort_idx'),('categories_v2','categories_v2_status_name_idx'),('categories_v2','categories_v2_active_name_key'),('categories_v2','categories_v2_legacy_key'),
('brands_v2','brands_v2_status_name_idx'),('brands_v2','brands_v2_active_name_key'),('brands_v2','brands_v2_legacy_key'),
('units_v2','units_v2_code_key'),('units_v2','units_v2_active_short_key'),('units_v2','units_v2_status_name_idx'),('units_v2','units_v2_legacy_key'),
('product_types_v2','product_types_v2_code_key'),('product_types_v2','product_types_v2_active_name_key'),('product_types_v2','product_types_v2_status_name_idx'),('product_types_v2','product_types_v2_legacy_key'),
('products_v2','products_v2_status_name_idx'),('products_v2','products_v2_category_idx'),('products_v2','products_v2_brand_idx'),('products_v2','products_v2_search_idx'),('products_v2','products_v2_active_sku_key'),('products_v2','products_v2_legacy_key'),
('product_barcodes','product_barcodes_active_key'),('product_barcodes','product_barcodes_primary_key'),('product_images','product_images_primary_key')
)x(t,i);

select ok(exists(select 1 from pg_constraint where conrelid=format('public.%I',t)::regclass and conname=n and contype='f'),n||' exists') from (values
('categories_v2','categories_v2_organization_id_fkey'),('categories_v2','categories_v2_parent_id_fkey'),('categories_v2','categories_v2_legacy_category_id_fkey'),
('brands_v2','brands_v2_organization_id_fkey'),('brands_v2','brands_v2_legacy_brand_id_fkey'),
('units_v2','units_v2_organization_id_fkey'),('units_v2','units_v2_legacy_unit_id_fkey'),
('product_types_v2','product_types_v2_organization_id_fkey'),('product_types_v2','product_types_v2_legacy_product_type_id_fkey'),
('products_v2','products_v2_organization_id_fkey'),('products_v2','products_v2_legacy_product_id_fkey'),('products_v2','products_v2_category_id_fkey'),('products_v2','products_v2_brand_id_fkey'),('products_v2','products_v2_product_type_id_fkey'),('products_v2','products_v2_base_unit_id_fkey'),
('unit_conversions','unit_conversions_product_id_fkey'),('unit_conversions','unit_conversions_from_unit_id_fkey'),('unit_conversions','unit_conversions_to_unit_id_fkey'),
('product_barcodes','product_barcodes_product_id_fkey'),('product_images','product_images_product_id_fkey'),
('products','products_brand_id_fkey'),('products','products_unit_id_fkey'),('products','products_product_type_id_fkey')
)x(t,n);

select has_function('public',f,array[]::text[],f||' exists') from (values
('v2_prevent_catalog_delete'),('v2_guard_category'),('v2_guard_catalog_reference'),('v2_guard_product'),('v2_guard_conversion'),('v2_guard_barcode'),('v2_guard_image'))x(f);
select has_function('public','v2_normalize_barcode',array['text'],'barcode normalizer exists');
select is((select count(*) from supabase_migrations.schema_migrations where version between '0001' and '0010'),10::bigint,'migrations 0001-0010 recorded');
select is((select count(*) from public.products_v2),0::bigint,'no legacy products auto copied');

-- Fixtures.
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at) values
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000010001','authenticated','authenticated','owner10@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000010002','authenticated','authenticated','seller10@test','','now','now','now'),
('00000000-0000-0000-0000-000000000000','00000000-0000-0000-0000-000000010003','authenticated','authenticated','support10@test','','now','now','now');
insert into organizations(id,name) values('00000000-0000-0000-0000-000000010101','A'),('00000000-0000-0000-0000-000000010102','B');
insert into user_profiles(id,auth_user_id,full_name) values
('00000000-0000-0000-0000-000000010201','00000000-0000-0000-0000-000000010001','Owner'),
('00000000-0000-0000-0000-000000010202','00000000-0000-0000-0000-000000010002','Seller'),
('00000000-0000-0000-0000-000000010203','00000000-0000-0000-0000-000000010003','Support');
insert into organization_memberships(id,organization_id,user_profile_id,system_role,status,joined_at) values
('00000000-0000-0000-0000-000000010301','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010201','owner','active',now()),
('00000000-0000-0000-0000-000000010302','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010202','seller','active',now()),
('00000000-0000-0000-0000-000000010303','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010203','service_admin','active',now());
insert into membership_permission_profiles(membership_id,permission_profile_id,assigned_by) values('00000000-0000-0000-0000-000000010302','00000000-0000-0000-0000-000000000102','00000000-0000-0000-0000-000000010301');

insert into categories(id,organization_id,name) values('00000000-0000-0000-0000-000000010401','00000000-0000-0000-0000-000000010101','Legacy A'),('00000000-0000-0000-0000-000000010402','00000000-0000-0000-0000-000000010102','Legacy B');
insert into brands(id,organization_id,name) values('00000000-0000-0000-0000-000000010411','00000000-0000-0000-0000-000000010101','Legacy Brand A'),('00000000-0000-0000-0000-000000010412','00000000-0000-0000-0000-000000010102','Legacy Brand B');
insert into units(id,organization_id,name,short_name) values('00000000-0000-0000-0000-000000010421','00000000-0000-0000-0000-000000010101','Legacy Unit A','a'),('00000000-0000-0000-0000-000000010422','00000000-0000-0000-0000-000000010102','Legacy Unit B','b');
insert into product_types(id,organization_id,name,code) values('00000000-0000-0000-0000-000000010431','00000000-0000-0000-0000-000000010101','Legacy Type A','a'),('00000000-0000-0000-0000-000000010432','00000000-0000-0000-0000-000000010102','Legacy Type B','b');
insert into products(id,organization_id,name,unit) values('00000000-0000-0000-0000-000000010441','00000000-0000-0000-0000-000000010101','Legacy Product A','шт'),('00000000-0000-0000-0000-000000010442','00000000-0000-0000-0000-000000010102','Legacy Product B','шт');

insert into categories_v2(id,organization_id,legacy_category_id,name) values('00000000-0000-0000-0000-000000010501','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010401','Root A');
select throws_ok($$insert into categories_v2(organization_id,parent_id,name) values('00000000-0000-0000-0000-000000010102','00000000-0000-0000-0000-000000010501','Bad')$$,'P0001','V2_CATEGORY_PARENT_TENANT_MISMATCH','cross tenant parent rejected');
select throws_ok($$update categories_v2 set parent_id=id where id='00000000-0000-0000-0000-000000010501'$$,'P0001','V2_CATEGORY_HIERARCHY_CYCLE','self parent rejected');
insert into categories_v2(id,organization_id,parent_id,name) values('00000000-0000-0000-0000-000000010502','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010501','Child'),('00000000-0000-0000-0000-000000010503','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010502','Grandchild');
select throws_ok($$update categories_v2 set parent_id='00000000-0000-0000-0000-000000010503' where id='00000000-0000-0000-0000-000000010501'$$,'P0001','V2_CATEGORY_HIERARCHY_CYCLE','deep cycle rejected');
select throws_ok($$insert into categories_v2(organization_id,name) values('00000000-0000-0000-0000-000000010101','root a')$$,'23505',null,'root normalized name unique');
select lives_ok($$insert into categories_v2(organization_id,name) values('00000000-0000-0000-0000-000000010102','Root A')$$,'same category name different tenant allowed');
select throws_ok($$insert into categories_v2(organization_id,legacy_category_id,name) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010402','Bad')$$,'P0001','V2_CATEGORY_LEGACY_TENANT_MISMATCH','category legacy tenant checked');
select throws_ok($$insert into categories_v2(organization_id,legacy_category_id,name) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010401','Dup')$$,'23505',null,'category legacy mapping unique');

insert into brands_v2(id,organization_id,legacy_brand_id,name) values('00000000-0000-0000-0000-000000010511','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010411','Brand A');
select throws_ok($$insert into brands_v2(organization_id,legacy_brand_id,name) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010412','Bad')$$,'P0001','V2_BRAND_LEGACY_TENANT_MISMATCH','brand legacy tenant checked');
select throws_ok($$insert into brands_v2(organization_id,name) values('00000000-0000-0000-0000-000000010101','brand a')$$,'23505',null,'brand active name unique');
insert into units_v2(id,organization_id,legacy_unit_id,code,name,short_name) values('00000000-0000-0000-0000-000000010521','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010421','PCS','Pieces','pc'),('00000000-0000-0000-0000-000000010522','00000000-0000-0000-0000-000000010101',null,'BOX','Box','box');
select throws_ok($$insert into units_v2(organization_id,code,name,short_name,precision_scale) values('00000000-0000-0000-0000-000000010101','BAD','Bad','bad',7)$$,'23514',null,'unit scale checked');
select throws_ok($$insert into units_v2(organization_id,legacy_unit_id,code,name,short_name) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010422','BAD','Bad','bad')$$,'P0001','V2_UNIT_LEGACY_TENANT_MISMATCH','unit legacy tenant checked');
insert into product_types_v2(id,organization_id,legacy_product_type_id,code,name) values('00000000-0000-0000-0000-000000010531','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010431','GOODS','Goods');
select throws_ok($$insert into product_types_v2(organization_id,code,name,behavior) values('00000000-0000-0000-0000-000000010101','BAD','Bad','[]')$$,'23514',null,'product type behavior object required');

insert into products_v2(id,organization_id,legacy_product_id,sku,name,category_id,brand_id,product_type_id,base_unit_id) values('00000000-0000-0000-0000-000000010601','00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010441','SKU1','Product A','00000000-0000-0000-0000-000000010501','00000000-0000-0000-0000-000000010511','00000000-0000-0000-0000-000000010531','00000000-0000-0000-0000-000000010521');
select throws_ok($$insert into products_v2(organization_id,name,base_unit_id) values('00000000-0000-0000-0000-000000010102','Bad','00000000-0000-0000-0000-000000010521')$$,'P0001','V2_PRODUCT_UNIT_TENANT_MISMATCH','product unit tenant checked');
select throws_ok($$insert into products_v2(organization_id,legacy_product_id,name,base_unit_id) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010442','Bad','00000000-0000-0000-0000-000000010521')$$,'P0001','V2_PRODUCT_LEGACY_TENANT_MISMATCH','product legacy tenant checked');
select throws_ok($$insert into products_v2(organization_id,legacy_product_id,name,base_unit_id) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010441','Dup','00000000-0000-0000-0000-000000010521')$$,'23505',null,'product legacy mapping unique');
select throws_ok($$insert into products_v2(organization_id,sku,name,base_unit_id) values('00000000-0000-0000-0000-000000010101','sku1','Dup','00000000-0000-0000-0000-000000010521')$$,'23505',null,'active SKU unique');
select lives_ok($$update products_v2 set name='Changed' where id='00000000-0000-0000-0000-000000010601'$$,'product update succeeds');
select is((select version from products_v2 where id='00000000-0000-0000-0000-000000010601'),2::bigint,'product version increments exactly once');
select throws_ok($$update products_v2 set version=9 where id='00000000-0000-0000-0000-000000010601'$$,'P0001','V2_PRODUCT_VERSION_MUTATION_FORBIDDEN','direct version mutation rejected');

select throws_ok($$insert into unit_conversions(organization_id,product_id,from_unit_id,to_unit_id,factor) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','00000000-0000-0000-0000-000000010522','00000000-0000-0000-0000-000000010521',0)$$,'23514',null,'conversion factor positive');
select lives_ok($$insert into unit_conversions(organization_id,product_id,from_unit_id,to_unit_id,factor) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','00000000-0000-0000-0000-000000010522','00000000-0000-0000-0000-000000010521',10)$$,'conversion to base unit allowed');
select throws_ok($$insert into unit_conversions(organization_id,product_id,from_unit_id,to_unit_id,factor) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','00000000-0000-0000-0000-000000010521','00000000-0000-0000-0000-000000010522',2)$$,'P0001','V2_CONVERSION_TARGET_NOT_BASE_UNIT','conversion target must be base');

select lives_ok($$insert into product_barcodes(organization_id,product_id,barcode,is_primary) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601',' ab 12 ',true)$$,'barcode inserted');
select is((select normalized_barcode from product_barcodes limit 1),'AB12','barcode normalized');
select throws_ok($$insert into product_barcodes(organization_id,product_id,barcode) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','a b12')$$,'23505',null,'normalized barcode unique');
select throws_ok($$update product_barcodes set barcode='changed'$$,'P0001','V2_BARCODE_IDENTITY_MUTATION_FORBIDDEN','barcode identity immutable');

select throws_ok($$insert into product_images(organization_id,product_id,storage_bucket,storage_path,content_type,size_bytes) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','b','p','text/plain',1)$$,'23514',null,'image MIME checked');
select throws_ok($$insert into product_images(organization_id,product_id,storage_bucket,storage_path,content_type,size_bytes) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','b','p','image/png',0)$$,'23514',null,'image size positive');
insert into product_images(organization_id,product_id,storage_bucket,storage_path,content_type,size_bytes,is_primary) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','b','p1','image/png',10,true);
select throws_ok($$insert into product_images(organization_id,product_id,storage_bucket,storage_path,content_type,size_bytes,is_primary) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010601','b','p2','image/jpeg',10,true)$$,'23505',null,'one primary image');
select throws_ok($$delete from products_v2 where id='00000000-0000-0000-0000-000000010601'$$,'P0001','V2_CATALOG_HARD_DELETE_FORBIDDEN','catalog hard delete rejected');

select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000010001',true);
set local role authenticated;
select is((select count(*) from products_v2 where organization_id='00000000-0000-0000-0000-000000010101'),1::bigint,'owner catalog.view reads tenant');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000010003',true);
set local role authenticated;
select is((select count(*) from products_v2),0::bigint,'service admin membership alone denied');
reset role;
insert into support_access_grants(organization_id,service_admin_profile_id,scopes,reason,status,approved_by_membership_id,starts_at,expires_at) values('00000000-0000-0000-0000-000000010101','00000000-0000-0000-0000-000000010203',array['catalog.manage'],'support','active','00000000-0000-0000-0000-000000010301',now()-interval '1 minute',now()+interval '1 hour');
set local role authenticated;
select is((select count(*) from products_v2),1::bigint,'support catalog.manage exact access');
reset role;

select * from finish();
rollback;
