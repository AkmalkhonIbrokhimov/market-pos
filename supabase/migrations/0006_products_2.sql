-- =========================================================
-- SPRINT 4B.2: COMMERCIAL PRODUCT CATALOG
-- =========================================================

create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  description text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.units (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  short_name text not null,
  status text not null default 'active' check (status in ('active', 'inactive')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.product_types (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text,
  description text,
  status text not null default 'active' check (status in ('active', 'inactive')),
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products
  add column if not exists sku text,
  add column if not exists brand_id uuid references public.brands(id) on delete set null,
  add column if not exists product_type_id uuid references public.product_types(id) on delete set null,
  add column if not exists unit_id uuid references public.units(id) on delete set null,
  add column if not exists description text,
  add column if not exists image_url text,
  add column if not exists weight numeric(12,3),
  add column if not exists weight_unit text default 'kg',
  add column if not exists volume numeric(12,3),
  add column if not exists volume_unit text default 'l',
  add column if not exists size_text text,
  add column if not exists color text,
  add column if not exists package_size text,
  add column if not exists archived_at timestamptz,
  add column if not exists deleted_at timestamptz;

create index if not exists brands_organization_idx on public.brands (organization_id);
create index if not exists units_organization_idx on public.units (organization_id);
create index if not exists product_types_organization_idx on public.product_types (organization_id);
create index if not exists products_organization_category_idx on public.products (organization_id, category_id);
create index if not exists products_organization_brand_idx on public.products (organization_id, brand_id);
create index if not exists products_organization_type_idx on public.products (organization_id, product_type_id);
create index if not exists products_sku_idx on public.products (sku);
create index if not exists products_archived_at_idx on public.products (archived_at);

do $$
begin
  if to_regclass('public.brands_organization_name_active_unique') is null
    and not exists (
      select 1 from public.brands where archived_at is null
      group by organization_id, lower(name) having count(*) > 1
    ) then
    create unique index brands_organization_name_active_unique
      on public.brands (organization_id, lower(name)) where archived_at is null;
  end if;

  if to_regclass('public.units_organization_short_name_active_unique') is null
    and not exists (
      select 1 from public.units where archived_at is null
      group by organization_id, lower(short_name) having count(*) > 1
    ) then
    create unique index units_organization_short_name_active_unique
      on public.units (organization_id, lower(short_name)) where archived_at is null;
  end if;

  if to_regclass('public.product_types_organization_name_active_unique') is null
    and not exists (
      select 1 from public.product_types where archived_at is null
      group by organization_id, lower(name) having count(*) > 1
    ) then
    create unique index product_types_organization_name_active_unique
      on public.product_types (organization_id, lower(name)) where archived_at is null;
  end if;

  if to_regclass('public.products_organization_sku_unique') is null
    and not exists (
      select 1 from public.products where sku is not null and deleted_at is null
      group by organization_id, sku having count(*) > 1
    ) then
    create unique index products_organization_sku_unique
      on public.products (organization_id, sku) where sku is not null and deleted_at is null;
  end if;
end $$;

drop trigger if exists trg_brands_updated_at on public.brands;
create trigger trg_brands_updated_at before update on public.brands
for each row execute function public.set_updated_at();

drop trigger if exists trg_units_updated_at on public.units;
create trigger trg_units_updated_at before update on public.units
for each row execute function public.set_updated_at();

drop trigger if exists trg_product_types_updated_at on public.product_types;
create trigger trg_product_types_updated_at before update on public.product_types
for each row execute function public.set_updated_at();

alter table public.brands enable row level security;
alter table public.units enable row level security;
alter table public.product_types enable row level security;

drop policy if exists brands_select_organization on public.brands;
create policy brands_select_organization on public.brands for select to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = brands.organization_id
    and profile.status = 'active'
));

drop policy if exists brands_insert_management on public.brands;
create policy brands_insert_management on public.brands for insert to authenticated
with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = brands.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

drop policy if exists brands_update_management on public.brands;
create policy brands_update_management on public.brands for update to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = brands.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
)) with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = brands.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

drop policy if exists units_select_organization on public.units;
create policy units_select_organization on public.units for select to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = units.organization_id
    and profile.status = 'active'
));

drop policy if exists units_insert_management on public.units;
create policy units_insert_management on public.units for insert to authenticated
with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = units.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

drop policy if exists units_update_management on public.units;
create policy units_update_management on public.units for update to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = units.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
)) with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = units.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

drop policy if exists product_types_select_organization on public.product_types;
create policy product_types_select_organization on public.product_types for select to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = product_types.organization_id
    and profile.status = 'active'
));

drop policy if exists product_types_insert_management on public.product_types;
create policy product_types_insert_management on public.product_types for insert to authenticated
with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = product_types.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

drop policy if exists product_types_update_management on public.product_types;
create policy product_types_update_management on public.product_types for update to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = product_types.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
)) with check (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = product_types.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
));

-- Product policies keep the existing organization and management checks while
-- validating all Product 2.0 references against the same organization.
drop policy if exists products_insert_management on public.products;
create policy products_insert_management on public.products for insert to authenticated
with check (
  exists (
    select 1 from public.users profile
    where profile.auth_user_id = (select auth.uid())
      and profile.organization_id = products.organization_id
      and profile.role in ('owner', 'service_admin')
      and profile.status = 'active'
  )
  and (products.category_id is null or exists (
    select 1 from public.categories category
    where category.id = products.category_id and category.organization_id = products.organization_id
  ))
  and (products.brand_id is null or exists (
    select 1 from public.brands brand
    where brand.id = products.brand_id and brand.organization_id = products.organization_id
  ))
  and (products.unit_id is null or exists (
    select 1 from public.units unit_record
    where unit_record.id = products.unit_id and unit_record.organization_id = products.organization_id
  ))
  and (products.product_type_id is null or exists (
    select 1 from public.product_types product_type
    where product_type.id = products.product_type_id and product_type.organization_id = products.organization_id
  ))
);

drop policy if exists products_update_management on public.products;
create policy products_update_management on public.products for update to authenticated
using (exists (
  select 1 from public.users profile
  where profile.auth_user_id = (select auth.uid())
    and profile.organization_id = products.organization_id
    and profile.role in ('owner', 'service_admin')
    and profile.status = 'active'
)) with check (
  exists (
    select 1 from public.users profile
    where profile.auth_user_id = (select auth.uid())
      and profile.organization_id = products.organization_id
      and profile.role in ('owner', 'service_admin')
      and profile.status = 'active'
  )
  and (products.category_id is null or exists (
    select 1 from public.categories category
    where category.id = products.category_id and category.organization_id = products.organization_id
  ))
  and (products.brand_id is null or exists (
    select 1 from public.brands brand
    where brand.id = products.brand_id and brand.organization_id = products.organization_id
  ))
  and (products.unit_id is null or exists (
    select 1 from public.units unit_record
    where unit_record.id = products.unit_id and unit_record.organization_id = products.organization_id
  ))
  and (products.product_type_id is null or exists (
    select 1 from public.product_types product_type
    where product_type.id = products.product_type_id and product_type.organization_id = products.organization_id
  ))
);

-- No delete policies are added for products or reference data.
