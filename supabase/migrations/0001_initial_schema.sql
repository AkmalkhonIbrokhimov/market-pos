-- Market POS initial schema v1
-- Target: Supabase PostgreSQL
-- Sprint 0 / Database v1

create extension if not exists "pgcrypto";

-- =========================================================
-- ENUMS
-- =========================================================

do $$
begin
  if not exists (select 1 from pg_type where typname = 'user_role') then
    create type user_role as enum ('owner', 'seller', 'service_admin');
  end if;

  if not exists (select 1 from pg_type where typname = 'record_status') then
    create type record_status as enum ('active', 'inactive', 'blocked', 'deleted');
  end if;

  if not exists (select 1 from pg_type where typname = 'stock_movement_type') then
    create type stock_movement_type as enum (
      'income',
      'sale',
      'debt_sale',
      'return',
      'correction',
      'write_off',
      'inventory'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'sale_type') then
    create type sale_type as enum ('regular', 'debt', 'mixed');
  end if;

  if not exists (select 1 from pg_type where typname = 'payment_method') then
    create type payment_method as enum (
      'cash',
      'card',
      'transfer',
      'click',
      'payme',
      'debt',
      'mixed'
    );
  end if;

  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type payment_status as enum ('paid', 'unpaid', 'partial', 'cancelled');
  end if;

  if not exists (select 1 from pg_type where typname = 'sale_status') then
    create type sale_status as enum ('completed', 'cancelled', 'refunded');
  end if;

  if not exists (select 1 from pg_type where typname = 'debt_entry_type') then
    create type debt_entry_type as enum ('debt_added', 'payment', 'correction', 'write_off');
  end if;

  if not exists (select 1 from pg_type where typname = 'shift_status') then
    create type shift_status as enum ('open', 'closed', 'checked');
  end if;

  if not exists (select 1 from pg_type where typname = 'sync_operation_status') then
    create type sync_operation_status as enum ('pending', 'syncing', 'synced', 'error', 'conflict');
  end if;

  if not exists (select 1 from pg_type where typname = 'subscription_status') then
    create type subscription_status as enum ('trial', 'active', 'overdue', 'cancelled', 'blocked');
  end if;
end $$;

-- =========================================================
-- UPDATED_AT TRIGGER
-- =========================================================

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- =========================================================
-- CORE BUSINESS TABLES
-- =========================================================

create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_user_id uuid,
  phone text,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists stores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  address text,
  phone text,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid,
  organization_id uuid references organizations(id) on delete set null,
  full_name text not null,
  phone text,
  email text,
  password_hash text,
  role user_role not null,
  status record_status not null default 'active',
  last_login_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_phone_unique unique (phone)
);

alter table organizations
  drop constraint if exists organizations_owner_user_id_fkey;

alter table organizations
  add constraint organizations_owner_user_id_fkey
  foreign key (owner_user_id) references users(id) on delete set null;

create table if not exists user_store_access (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  store_id uuid not null references stores(id) on delete cascade,
  role_in_store user_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, store_id)
);

-- =========================================================
-- PRODUCTS AND STOCK
-- =========================================================

create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, name)
);

create table if not exists suppliers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  name text not null,
  phone text,
  comment text,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  name text not null,
  barcode text,
  unit text not null default 'шт',
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  current_quantity numeric(14,3) not null default 0,
  min_quantity numeric(14,3) not null default 0,
  is_expirable boolean not null default false,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, barcode)
);

create table if not exists product_batches (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  supplier_id uuid references suppliers(id) on delete set null,
  received_date date not null default current_date,
  initial_quantity numeric(14,3) not null check (initial_quantity > 0),
  remaining_quantity numeric(14,3) not null check (remaining_quantity >= 0),
  purchase_price numeric(14,2) not null check (purchase_price >= 0),
  sale_price_at_arrival numeric(14,2) not null check (sale_price_at_arrival >= 0),
  expiration_date date,
  comment text,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists stock_movements (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  batch_id uuid references product_batches(id) on delete set null,
  type stock_movement_type not null,
  quantity numeric(14,3) not null,
  old_quantity numeric(14,3),
  new_quantity numeric(14,3),
  reason text,
  comment text,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- =========================================================
-- CUSTOMERS AND DEBTS
-- =========================================================

create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  full_name text not null,
  phone text,
  comment text,
  current_debt numeric(14,2) not null default 0 check (current_debt >= 0),
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- SHIFTS
-- =========================================================

create table if not exists shifts (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  seller_id uuid not null references users(id) on delete restrict,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  opening_cash_amount numeric(14,2) not null default 0,
  expected_cash_amount numeric(14,2) not null default 0,
  actual_cash_amount numeric(14,2),
  difference_amount numeric(14,2),
  status shift_status not null default 'open',
  comment text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- one open shift per seller/store
create unique index if not exists shifts_one_open_shift_per_seller_store
on shifts (store_id, seller_id)
where status = 'open';

-- =========================================================
-- SALES AND PAYMENTS
-- =========================================================

create table if not exists sales (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  seller_id uuid not null references users(id) on delete restrict,
  shift_id uuid references shifts(id) on delete set null,
  customer_id uuid references customers(id) on delete set null,
  type sale_type not null default 'regular',
  payment_status payment_status not null default 'paid',
  subtotal_amount numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  total_amount numeric(14,2) not null default 0,
  profit_amount numeric(14,2) not null default 0,
  fiscal_status text,
  fiscal_receipt_id text,
  status sale_status not null default 'completed',
  local_operation_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, local_operation_id)
);

create table if not exists sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references sales(id) on delete cascade,
  product_id uuid not null references products(id) on delete restrict,
  batch_id uuid references product_batches(id) on delete set null,
  quantity numeric(14,3) not null check (quantity > 0),
  purchase_price numeric(14,2) not null default 0,
  sale_price numeric(14,2) not null default 0,
  discount_amount numeric(14,2) not null default 0,
  total_price numeric(14,2) not null default 0,
  profit_amount numeric(14,2) not null default 0
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  sale_id uuid references sales(id) on delete cascade,
  method payment_method not null,
  amount numeric(14,2) not null check (amount > 0),
  status payment_status not null default 'paid',
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists debt_payments (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  shift_id uuid references shifts(id) on delete set null,
  amount numeric(14,2) not null check (amount > 0),
  method payment_method not null default 'cash',
  comment text,
  local_operation_id text,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (store_id, local_operation_id)
);

create table if not exists debt_entries (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  sale_id uuid references sales(id) on delete set null,
  debt_payment_id uuid references debt_payments(id) on delete set null,
  type debt_entry_type not null,
  amount numeric(14,2) not null check (amount >= 0),
  balance_after numeric(14,2) not null default 0,
  comment text,
  created_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now()
);

-- =========================================================
-- LOGS, DEVICES, SYNC
-- =========================================================

create table if not exists operation_logs (
  id uuid primary key default gen_random_uuid(),
  store_id uuid references stores(id) on delete cascade,
  user_id uuid references users(id) on delete set null,
  action text not null,
  entity_type text,
  entity_id uuid,
  old_value jsonb,
  new_value jsonb,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists devices (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  name text not null,
  device_type text,
  last_sync_at timestamptz,
  status record_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists sync_operations (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references stores(id) on delete cascade,
  device_id uuid references devices(id) on delete set null,
  user_id uuid references users(id) on delete set null,
  shift_id uuid references shifts(id) on delete set null,
  local_operation_id text not null,
  operation_type text not null,
  payload jsonb not null,
  status sync_operation_status not null default 'pending',
  created_at_local timestamptz,
  received_at_server timestamptz not null default now(),
  processed_at timestamptz,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, local_operation_id)
);

-- =========================================================
-- FUTURE SaaS TABLES
-- =========================================================

create table if not exists tariffs (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  price_monthly numeric(14,2) not null default 0,
  max_stores int,
  max_users int,
  max_products int,
  features jsonb not null default '{}'::jsonb,
  status record_status not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  tariff_id uuid references tariffs(id) on delete set null,
  status subscription_status not null default 'trial',
  start_date date not null default current_date,
  end_date date,
  next_payment_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists idx_stores_organization_id on stores(organization_id);
create index if not exists idx_users_organization_id on users(organization_id);
create index if not exists idx_user_store_access_user_id on user_store_access(user_id);
create index if not exists idx_user_store_access_store_id on user_store_access(store_id);

create index if not exists idx_categories_organization_id on categories(organization_id);
create index if not exists idx_products_organization_id on products(organization_id);
create index if not exists idx_products_category_id on products(category_id);
create index if not exists idx_products_barcode on products(barcode);
create index if not exists idx_products_name on products using gin (to_tsvector('simple', name));

create index if not exists idx_product_batches_store_product on product_batches(store_id, product_id);
create index if not exists idx_product_batches_expiration_date on product_batches(expiration_date);
create index if not exists idx_stock_movements_store_product on stock_movements(store_id, product_id);

create index if not exists idx_customers_store_id on customers(store_id);
create index if not exists idx_customers_phone on customers(phone);

create index if not exists idx_sales_store_created_at on sales(store_id, created_at);
create index if not exists idx_sales_shift_id on sales(shift_id);
create index if not exists idx_sales_customer_id on sales(customer_id);
create index if not exists idx_sale_items_sale_id on sale_items(sale_id);
create index if not exists idx_sale_items_product_id on sale_items(product_id);
create index if not exists idx_payments_sale_id on payments(sale_id);

create index if not exists idx_debt_entries_customer_id on debt_entries(customer_id);
create index if not exists idx_debt_payments_customer_id on debt_payments(customer_id);

create index if not exists idx_shifts_store_seller on shifts(store_id, seller_id);
create index if not exists idx_operation_logs_store_created_at on operation_logs(store_id, created_at);
create index if not exists idx_sync_operations_store_status on sync_operations(store_id, status);
create index if not exists idx_devices_store_id on devices(store_id);

-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

drop trigger if exists trg_organizations_updated_at on organizations;
create trigger trg_organizations_updated_at
before update on organizations
for each row execute function set_updated_at();

drop trigger if exists trg_stores_updated_at on stores;
create trigger trg_stores_updated_at
before update on stores
for each row execute function set_updated_at();

drop trigger if exists trg_users_updated_at on users;
create trigger trg_users_updated_at
before update on users
for each row execute function set_updated_at();

drop trigger if exists trg_categories_updated_at on categories;
create trigger trg_categories_updated_at
before update on categories
for each row execute function set_updated_at();

drop trigger if exists trg_suppliers_updated_at on suppliers;
create trigger trg_suppliers_updated_at
before update on suppliers
for each row execute function set_updated_at();

drop trigger if exists trg_products_updated_at on products;
create trigger trg_products_updated_at
before update on products
for each row execute function set_updated_at();

drop trigger if exists trg_customers_updated_at on customers;
create trigger trg_customers_updated_at
before update on customers
for each row execute function set_updated_at();

drop trigger if exists trg_shifts_updated_at on shifts;
create trigger trg_shifts_updated_at
before update on shifts
for each row execute function set_updated_at();

drop trigger if exists trg_sales_updated_at on sales;
create trigger trg_sales_updated_at
before update on sales
for each row execute function set_updated_at();

drop trigger if exists trg_devices_updated_at on devices;
create trigger trg_devices_updated_at
before update on devices
for each row execute function set_updated_at();

drop trigger if exists trg_sync_operations_updated_at on sync_operations;
create trigger trg_sync_operations_updated_at
before update on sync_operations
for each row execute function set_updated_at();

drop trigger if exists trg_subscriptions_updated_at on subscriptions;
create trigger trg_subscriptions_updated_at
before update on subscriptions
for each row execute function set_updated_at();

-- =========================================================
-- NOTES
-- =========================================================
-- RLS policies are intentionally not finalized in Sprint 0.
-- They must be added after the final auth approach is selected:
-- 1) Supabase Auth + public.users profile table, or
-- 2) custom auth for early MVP.
--
-- Important:
-- - Seller must not see purchase prices or full profit.
-- - Owner can access only own organization/store data.
-- - Service admin is future SaaS role.
