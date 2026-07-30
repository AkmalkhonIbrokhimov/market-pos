-- MARKET POS V2: CATALOG COMPATIBILITY
-- Legacy public.categories/public.products and all operational FK remain untouched.

create or replace function public.v2_normalize_barcode(p_barcode text)
returns text language sql immutable strict set search_path = ''
as $$ select upper(regexp_replace(btrim(p_barcode), '\s+', '', 'g')) $$;

create table public.categories_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  parent_id uuid references public.categories_v2(id) on delete restrict,
  legacy_category_id uuid references public.categories(id) on delete restrict,
  name text not null, description text, sort_order integer not null default 0,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), archived_at timestamptz,
  constraint categories_v2_name_check check (btrim(name) <> ''),
  constraint categories_v2_sort_check check (sort_order >= 0),
  constraint categories_v2_status_check check (status in ('active','inactive','archived')),
  constraint categories_v2_lifecycle_check check (
    (status='archived' and archived_at is not null) or
    (status in ('active','inactive') and archived_at is null)),
  constraint categories_v2_self_parent_check check (parent_id is null or parent_id <> id)
);
create index categories_v2_parent_sort_idx on public.categories_v2(organization_id,parent_id,sort_order);
create index categories_v2_status_name_idx on public.categories_v2(organization_id,status,name);
create unique index categories_v2_active_name_key on public.categories_v2(
  organization_id,coalesce(parent_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(name))
  where archived_at is null;
create unique index categories_v2_legacy_key on public.categories_v2(legacy_category_id)
  where legacy_category_id is not null;

create table public.brands_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  legacy_brand_id uuid references public.brands(id) on delete restrict,
  name text not null, description text, status text not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint brands_v2_name_check check (btrim(name) <> ''),
  constraint brands_v2_status_check check (status in ('active','inactive','archived')),
  constraint brands_v2_lifecycle_check check (
    (status='archived' and archived_at is not null) or
    (status in ('active','inactive') and archived_at is null))
);
create index brands_v2_status_name_idx on public.brands_v2(organization_id,status,name);
create unique index brands_v2_active_name_key on public.brands_v2(organization_id,lower(name))
  where archived_at is null;
create unique index brands_v2_legacy_key on public.brands_v2(legacy_brand_id) where legacy_brand_id is not null;

create table public.units_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  legacy_unit_id uuid references public.units(id) on delete restrict,
  code text not null, name text not null, short_name text not null,
  precision_scale smallint not null default 0, status text not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint units_v2_code_check check (btrim(code)<>''), constraint units_v2_name_check check (btrim(name)<>''),
  constraint units_v2_short_check check (btrim(short_name)<>''), constraint units_v2_scale_check check (precision_scale between 0 and 6),
  constraint units_v2_status_check check(status in ('active','inactive','archived')),
  constraint units_v2_lifecycle_check check((status='archived' and archived_at is not null) or (status in ('active','inactive') and archived_at is null))
);
create unique index units_v2_code_key on public.units_v2(organization_id,lower(code));
create unique index units_v2_active_short_key on public.units_v2(organization_id,lower(short_name)) where archived_at is null;
create index units_v2_status_name_idx on public.units_v2(organization_id,status,name);
create unique index units_v2_legacy_key on public.units_v2(legacy_unit_id) where legacy_unit_id is not null;

create table public.product_types_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  legacy_product_type_id uuid references public.product_types(id) on delete restrict,
  code text not null, name text not null, description text, behavior jsonb not null default '{}',
  status text not null default 'active', created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), archived_at timestamptz,
  constraint product_types_v2_code_check check(btrim(code)<>''), constraint product_types_v2_name_check check(btrim(name)<>''),
  constraint product_types_v2_behavior_check check(jsonb_typeof(behavior)='object'),
  constraint product_types_v2_status_check check(status in ('active','inactive','archived')),
  constraint product_types_v2_lifecycle_check check((status='archived' and archived_at is not null) or(status in ('active','inactive') and archived_at is null))
);
create unique index product_types_v2_code_key on public.product_types_v2(organization_id,lower(code));
create unique index product_types_v2_active_name_key on public.product_types_v2(organization_id,lower(name)) where archived_at is null;
create index product_types_v2_status_name_idx on public.product_types_v2(organization_id,status,name);
create unique index product_types_v2_legacy_key on public.product_types_v2(legacy_product_type_id) where legacy_product_type_id is not null;

create table public.products_v2 (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  legacy_product_id uuid references public.products(id) on delete restrict,
  sku text, name text not null,
  category_id uuid references public.categories_v2(id) on delete restrict,
  brand_id uuid references public.brands_v2(id) on delete restrict,
  product_type_id uuid references public.product_types_v2(id) on delete restrict,
  base_unit_id uuid not null references public.units_v2(id) on delete restrict,
  description text, is_expirable boolean not null default false, is_weighted boolean not null default false,
  min_quantity numeric(18,6) not null default 0, status text not null default 'active',
  version bigint not null default 1, created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), archived_at timestamptz,
  constraint products_v2_name_check check(btrim(name)<>''), constraint products_v2_sku_check check(sku is null or btrim(sku)<>''),
  constraint products_v2_min_check check(min_quantity>=0), constraint products_v2_version_check check(version>0),
  constraint products_v2_status_check check(status in ('active','inactive','archived')),
  constraint products_v2_lifecycle_check check((status='archived' and archived_at is not null) or(status in ('active','inactive') and archived_at is null))
);
create index products_v2_status_name_idx on public.products_v2(organization_id,status,name);
create index products_v2_category_idx on public.products_v2(organization_id,category_id,status);
create index products_v2_brand_idx on public.products_v2(organization_id,brand_id,status);
create index products_v2_search_idx on public.products_v2 using gin(to_tsvector('simple',coalesce(name,'')||' '||coalesce(sku,'')));
create unique index products_v2_active_sku_key on public.products_v2(organization_id,lower(sku)) where sku is not null and archived_at is null;
create unique index products_v2_legacy_key on public.products_v2(legacy_product_id) where legacy_product_id is not null;

create table public.unit_conversions (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  from_unit_id uuid not null references public.units_v2(id) on delete restrict,
  to_unit_id uuid not null references public.units_v2(id) on delete restrict,
  factor numeric(20,10) not null, status text not null default 'active',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint unit_conversions_factor_check check(factor>0), constraint unit_conversions_units_check check(from_unit_id<>to_unit_id),
  constraint unit_conversions_status_check check(status in ('active','inactive')),
  constraint unit_conversions_key unique(product_id,from_unit_id,to_unit_id)
);
create index unit_conversions_org_product_idx on public.unit_conversions(organization_id,product_id);

create table public.product_barcodes (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict, barcode text not null,
  normalized_barcode text generated always as (public.v2_normalize_barcode(barcode)) stored,
  is_primary boolean not null default false, status text not null default 'active',
  created_at timestamptz not null default now(), archived_at timestamptz,
  constraint product_barcodes_nonblank_check check(public.v2_normalize_barcode(barcode)<>''),
  constraint product_barcodes_status_check check(status in ('active','inactive','archived')),
  constraint product_barcodes_lifecycle_check check((status='archived' and archived_at is not null and not is_primary) or(status in ('active','inactive') and archived_at is null))
);
create unique index product_barcodes_active_key on public.product_barcodes(organization_id,normalized_barcode) where archived_at is null;
create unique index product_barcodes_primary_key on public.product_barcodes(product_id) where is_primary and archived_at is null;
create index product_barcodes_product_status_idx on public.product_barcodes(product_id,status);
create index product_barcodes_lookup_idx on public.product_barcodes(normalized_barcode);

create table public.product_images (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  storage_bucket text not null, storage_path text not null, content_type text not null, size_bytes bigint not null,
  sort_order integer not null default 0, is_primary boolean not null default false,
  created_at timestamptz not null default now(), archived_at timestamptz,
  constraint product_images_bucket_check check(btrim(storage_bucket)<>''), constraint product_images_path_check check(btrim(storage_path)<>''),
  constraint product_images_content_check check(content_type in ('image/jpeg','image/png','image/webp','image/avif')),
  constraint product_images_size_check check(size_bytes>0), constraint product_images_sort_check check(sort_order>=0),
  constraint product_images_archived_check check(archived_at is null or not is_primary),
  constraint product_images_storage_key unique(storage_bucket,storage_path)
);
create unique index product_images_primary_key on public.product_images(product_id) where is_primary and archived_at is null;
create index product_images_product_sort_idx on public.product_images(product_id,sort_order);

-- Guards.
create or replace function public.v2_prevent_catalog_delete() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='P0001',message='V2_CATALOG_HARD_DELETE_FORBIDDEN'; end $$;

create or replace function public.v2_guard_category() returns trigger language plpgsql set search_path='' as $$
declare v_org uuid; v_cycle boolean; begin
 if new.parent_id is not null then
  select organization_id into v_org from public.categories_v2 where id=new.parent_id;
  if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_CATEGORY_PARENT_TENANT_MISMATCH'; end if;
  with recursive ancestors(id,parent_id) as (
   select id,parent_id from public.categories_v2 where id=new.parent_id
   union all select c.id,c.parent_id from public.categories_v2 c join ancestors a on c.id=a.parent_id)
  select exists(select 1 from ancestors where id=new.id) into v_cycle;
  if v_cycle then raise exception using errcode='P0001',message='V2_CATEGORY_HIERARCHY_CYCLE'; end if;
 end if;
 if new.legacy_category_id is not null then select organization_id into v_org from public.categories where id=new.legacy_category_id;
  if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_CATEGORY_LEGACY_TENANT_MISMATCH'; end if; end if;
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.legacy_category_id is distinct from old.legacy_category_id or new.created_at is distinct from old.created_at)
 then raise exception using errcode='P0001',message='V2_CATEGORY_IDENTITY_MUTATION_FORBIDDEN'; end if; return new; end $$;

create or replace function public.v2_guard_catalog_reference() returns trigger language plpgsql set search_path='' as $$
declare v_org uuid; jnew jsonb:=to_jsonb(new); jold jsonb:=to_jsonb(old); begin
 if tg_table_name='brands_v2' and jnew->>'legacy_brand_id' is not null then
  select organization_id into v_org from public.brands where id=(jnew->>'legacy_brand_id')::uuid;
  if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_BRAND_LEGACY_TENANT_MISMATCH'; end if;
 end if;
 if tg_table_name='units_v2' and jnew->>'legacy_unit_id' is not null then
  select organization_id into v_org from public.units where id=(jnew->>'legacy_unit_id')::uuid;
  if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_UNIT_LEGACY_TENANT_MISMATCH'; end if;
 end if;
 if tg_table_name='product_types_v2' and jnew->>'legacy_product_type_id' is not null then
  select organization_id into v_org from public.product_types where id=(jnew->>'legacy_product_type_id')::uuid;
  if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_TYPE_LEGACY_TENANT_MISMATCH'; end if;
 end if;
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.created_at is distinct from old.created_at
   or (tg_table_name='brands_v2' and jnew->>'legacy_brand_id' is distinct from jold->>'legacy_brand_id')
   or (tg_table_name='units_v2' and (jnew->>'code' is distinct from jold->>'code' or jnew->>'precision_scale' is distinct from jold->>'precision_scale' or jnew->>'legacy_unit_id' is distinct from jold->>'legacy_unit_id'))
   or (tg_table_name='product_types_v2' and (jnew->>'code' is distinct from jold->>'code' or jnew->>'legacy_product_type_id' is distinct from jold->>'legacy_product_type_id')))
 then raise exception using errcode='P0001',message='V2_CATALOG_REFERENCE_IDENTITY_MUTATION_FORBIDDEN'; end if; return new; end $$;

create or replace function public.v2_guard_product() returns trigger language plpgsql set search_path='' as $$
declare v_org uuid; begin
 if new.category_id is not null then select organization_id into v_org from public.categories_v2 where id=new.category_id; if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_CATEGORY_TENANT_MISMATCH'; end if; end if;
 if new.brand_id is not null then select organization_id into v_org from public.brands_v2 where id=new.brand_id; if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_BRAND_TENANT_MISMATCH'; end if; end if;
 if new.product_type_id is not null then select organization_id into v_org from public.product_types_v2 where id=new.product_type_id; if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_TYPE_TENANT_MISMATCH'; end if; end if;
 select organization_id into v_org from public.units_v2 where id=new.base_unit_id; if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_UNIT_TENANT_MISMATCH'; end if;
 if new.legacy_product_id is not null then select organization_id into v_org from public.products where id=new.legacy_product_id; if v_org is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PRODUCT_LEGACY_TENANT_MISMATCH'; end if; end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.legacy_product_id is distinct from old.legacy_product_id or new.created_at is distinct from old.created_at then raise exception using errcode='P0001',message='V2_PRODUCT_IDENTITY_MUTATION_FORBIDDEN'; end if;
  if new.version is distinct from old.version then raise exception using errcode='P0001',message='V2_PRODUCT_VERSION_MUTATION_FORBIDDEN'; end if;
  new.version:=old.version+1;
 end if; return new; end $$;

create or replace function public.v2_guard_conversion() returns trigger language plpgsql set search_path='' as $$
declare po uuid; pu uuid; fu uuid; tu uuid; begin
 select organization_id,base_unit_id into po,pu from public.products_v2 where id=new.product_id;
 select organization_id into fu from public.units_v2 where id=new.from_unit_id; select organization_id into tu from public.units_v2 where id=new.to_unit_id;
 if po is distinct from new.organization_id or fu is distinct from new.organization_id or tu is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_CONVERSION_TENANT_MISMATCH'; end if;
 if new.to_unit_id is distinct from pu then raise exception using errcode='P0001',message='V2_CONVERSION_TARGET_NOT_BASE_UNIT'; end if;
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.product_id is distinct from old.product_id or new.from_unit_id is distinct from old.from_unit_id or new.to_unit_id is distinct from old.to_unit_id or new.created_at is distinct from old.created_at) then raise exception using errcode='P0001',message='V2_CONVERSION_IDENTITY_MUTATION_FORBIDDEN'; end if; return new; end $$;

create or replace function public.v2_guard_barcode() returns trigger language plpgsql set search_path='' as $$
declare po uuid; begin select organization_id into po from public.products_v2 where id=new.product_id;
 if po is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_BARCODE_PRODUCT_TENANT_MISMATCH'; end if;
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.product_id is distinct from old.product_id or new.barcode is distinct from old.barcode or new.created_at is distinct from old.created_at) then raise exception using errcode='P0001',message='V2_BARCODE_IDENTITY_MUTATION_FORBIDDEN'; end if; return new; end $$;

create or replace function public.v2_guard_image() returns trigger language plpgsql set search_path='' as $$
declare po uuid; begin select organization_id into po from public.products_v2 where id=new.product_id;
 if po is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_IMAGE_PRODUCT_TENANT_MISMATCH'; end if;
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.product_id is distinct from old.product_id or new.storage_bucket is distinct from old.storage_bucket or new.storage_path is distinct from old.storage_path or new.content_type is distinct from old.content_type or new.size_bytes is distinct from old.size_bytes or new.created_at is distinct from old.created_at) then raise exception using errcode='P0001',message='V2_IMAGE_IDENTITY_MUTATION_FORBIDDEN'; end if; return new; end $$;

-- Trigger wiring.
create trigger v2_categories_v2_guard before insert or update on public.categories_v2 for each row execute function public.v2_guard_category();
create trigger v2_products_v2_guard before insert or update on public.products_v2 for each row execute function public.v2_guard_product();
create trigger v2_brands_v2_guard before insert or update on public.brands_v2 for each row execute function public.v2_guard_catalog_reference();
create trigger v2_units_v2_guard before insert or update on public.units_v2 for each row execute function public.v2_guard_catalog_reference();
create trigger v2_product_types_v2_guard before insert or update on public.product_types_v2 for each row execute function public.v2_guard_catalog_reference();
create trigger v2_conversions_guard before insert or update on public.unit_conversions for each row execute function public.v2_guard_conversion();
create trigger v2_barcodes_guard before insert or update on public.product_barcodes for each row execute function public.v2_guard_barcode();
create trigger v2_images_guard before insert or update on public.product_images for each row execute function public.v2_guard_image();

create trigger v2_categories_v2_updated before update on public.categories_v2 for each row execute function public.set_updated_at();
create trigger v2_brands_v2_updated before update on public.brands_v2 for each row execute function public.set_updated_at();
create trigger v2_units_v2_updated before update on public.units_v2 for each row execute function public.set_updated_at();
create trigger v2_product_types_v2_updated before update on public.product_types_v2 for each row execute function public.set_updated_at();
create trigger v2_products_v2_updated before update on public.products_v2 for each row execute function public.set_updated_at();
create trigger v2_conversions_updated before update on public.unit_conversions for each row execute function public.set_updated_at();

create trigger v2_categories_v2_delete before delete on public.categories_v2 for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_brands_v2_delete before delete on public.brands_v2 for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_units_v2_delete before delete on public.units_v2 for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_product_types_v2_delete before delete on public.product_types_v2 for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_products_v2_delete before delete on public.products_v2 for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_conversions_delete before delete on public.unit_conversions for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_barcodes_delete before delete on public.product_barcodes for each row execute function public.v2_prevent_catalog_delete();
create trigger v2_images_delete before delete on public.product_images for each row execute function public.v2_prevent_catalog_delete();

-- RLS: catalog.view permission or exact support grant.
alter table public.categories_v2 enable row level security; alter table public.brands_v2 enable row level security;
alter table public.units_v2 enable row level security; alter table public.product_types_v2 enable row level security;
alter table public.products_v2 enable row level security; alter table public.unit_conversions enable row level security;
alter table public.product_barcodes enable row level security; alter table public.product_images enable row level security;
create policy categories_v2_select on public.categories_v2 for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy brands_v2_select on public.brands_v2 for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy units_v2_select on public.units_v2 for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy product_types_v2_select on public.product_types_v2 for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy products_v2_select on public.products_v2 for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy conversions_select on public.unit_conversions for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy barcodes_select on public.product_barcodes for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));
create policy images_select on public.product_images for select to authenticated using(public.v2_has_permission(organization_id,'catalog.view') or public.v2_has_support_grant(organization_id,'catalog.manage'));

revoke all privileges on table public.categories_v2,public.brands_v2,public.units_v2,public.product_types_v2,public.products_v2,public.unit_conversions,public.product_barcodes,public.product_images from public,anon,authenticated;
grant select on table public.categories_v2,public.brands_v2,public.units_v2,public.product_types_v2,public.products_v2,public.unit_conversions,public.product_barcodes,public.product_images to authenticated;
revoke all privileges on function public.v2_normalize_barcode(text) from public,anon,authenticated;
revoke all privileges on function public.v2_prevent_catalog_delete() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_category() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_catalog_reference() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_product() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_conversion() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_barcode() from public,anon,authenticated;
revoke all privileges on function public.v2_guard_image() from public,anon,authenticated;
