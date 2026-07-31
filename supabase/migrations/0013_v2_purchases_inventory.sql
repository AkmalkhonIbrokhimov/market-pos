-- MARKET POS V2: PURCHASES AND INVENTORY
-- Additive coexistence: legacy product_batches and stock_movements remain untouched.

-- Permission registry ---------------------------------------------------------
alter table public.permissions disable trigger v2_permissions_prevent_insert;
insert into public.permissions(code,module,description,critical) values
('purchases.draft.manage','purchases','Manage draft purchases, lines, additional costs and daily delivery templates.',false),
('purchases.cost.view','purchases','View purchase prices, cost allocations and batch acquisition costs.',false),
('purchases.post_daily','purchases','Post daily delivery purchases.',false)
on conflict(code) do update set module=excluded.module,description=excluded.description,critical=excluded.critical;
alter table public.permissions enable trigger v2_permissions_prevent_insert;

insert into public.permission_profile_permissions(permission_profile_id,permission_id)
select '00000000-0000-0000-0000-000000000101'::uuid,id
from public.permissions where code in('purchases.draft.manage','purchases.cost.view','purchases.post_daily')
on conflict do nothing;

-- Purchase graph --------------------------------------------------------------
create table public.purchase_documents(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 counterparty_id uuid references public.counterparties(id) on delete restrict,
 document_number text not null,
 business_date date not null,
 status text not null default 'draft',
 currency_code char(3) not null,
 subtotal_amount numeric(18,4) not null default 0,
 additional_cost_amount numeric(18,4) not null default 0,
 total_amount numeric(18,4) not null default 0,
 device_id uuid references public.devices_v2(id) on delete restrict,
 local_operation_id uuid,
 client_created_at timestamptz,
 posted_at timestamptz,
 posted_by uuid references public.organization_memberships(id) on delete restrict,
 reversal_of_id uuid references public.purchase_documents(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint purchase_documents_number_check check(btrim(document_number)<>''),
 constraint purchase_documents_currency_check check(currency_code ~ '^[A-Z]{3}$'),
 constraint purchase_documents_status_check check(status in('draft','posted','reversed','cancelled')),
 constraint purchase_documents_amounts_check check(subtotal_amount>=0 and additional_cost_amount>=0 and total_amount>=0 and total_amount=subtotal_amount+additional_cost_amount),
 constraint purchase_documents_post_state_check check((status='posted' and posted_at is not null and posted_by is not null) or(status<>'posted')),
 constraint purchase_documents_reversal_shape_check check(reversal_of_id is null or status in('draft','posted')),
 unique(organization_id,document_number)
);
create unique index purchase_documents_operation_key on public.purchase_documents(organization_id,device_id,local_operation_id) where device_id is not null and local_operation_id is not null;
create unique index purchase_documents_online_operation_key on public.purchase_documents(organization_id,local_operation_id) where device_id is null and local_operation_id is not null;
create unique index purchase_documents_one_reversal_key on public.purchase_documents(reversal_of_id) where reversal_of_id is not null;
create index purchase_documents_journal_idx on public.purchase_documents(branch_id,business_date desc,status);

create table public.purchase_lines(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 purchase_document_id uuid not null references public.purchase_documents(id) on delete restrict,
 line_number integer not null,product_id uuid not null references public.products_v2(id) on delete restrict,
 unit_id uuid not null references public.units_v2(id) on delete restrict,
 quantity numeric(18,6) not null,unit_factor numeric(20,10) not null,base_quantity numeric(18,6) not null,
 unit_purchase_price numeric(18,4) not null,line_amount numeric(18,4) not null,
 expiration_date date,supplier_batch_number text,created_at timestamptz not null default now(),
 constraint purchase_lines_number_check check(line_number>0),constraint purchase_lines_quantity_check check(quantity>0 and unit_factor>0 and base_quantity>0),
 constraint purchase_lines_price_check check(unit_purchase_price>=0 and line_amount>=0),
 unique(purchase_document_id,line_number)
);
create index purchase_lines_product_idx on public.purchase_lines(product_id,purchase_document_id);

create table public.purchase_additional_costs(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 purchase_document_id uuid not null references public.purchase_documents(id) on delete restrict,
 cost_type text not null,amount numeric(18,4) not null,currency_code char(3) not null,allocation_method text not null,created_at timestamptz not null default now(),
 constraint purchase_cost_type_check check(btrim(cost_type)<>''),constraint purchase_cost_amount_check check(amount>0),
 constraint purchase_cost_currency_check check(currency_code ~ '^[A-Z]{3}$'),constraint purchase_cost_method_check check(allocation_method in('amount','quantity'))
);
create index purchase_costs_document_idx on public.purchase_additional_costs(purchase_document_id);

create table public.purchase_cost_allocations(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 purchase_additional_cost_id uuid not null references public.purchase_additional_costs(id) on delete restrict,
 purchase_line_id uuid not null references public.purchase_lines(id) on delete restrict,
 allocated_amount numeric(18,4) not null check(allocated_amount>=0),created_at timestamptz not null default now(),
 unique(purchase_additional_cost_id,purchase_line_id)
);

create table public.product_batches_v2(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,product_id uuid not null references public.products_v2(id) on delete restrict,
 purchase_line_id uuid not null references public.purchase_lines(id) on delete restrict,batch_code text not null,supplier_batch_number text,
 received_date date not null,expiration_date date,initial_quantity numeric(18,6) not null,purchase_unit_cost numeric(18,4) not null,
 currency_code char(3) not null,status text not null default 'open',created_at timestamptz not null default now(),
 constraint product_batches_v2_code_check check(btrim(batch_code)<>''),constraint product_batches_v2_quantity_check check(initial_quantity>0),
 constraint product_batches_v2_cost_check check(purchase_unit_cost>=0),constraint product_batches_v2_currency_check check(currency_code ~ '^[A-Z]{3}$'),
 constraint product_batches_v2_status_check check(status in('open','depleted','blocked','reversed')),
 unique(warehouse_id,batch_code),unique(purchase_line_id)
);
create index product_batches_v2_fefo_idx on public.product_batches_v2(warehouse_id,product_id,expiration_date) where status='open';

create table public.daily_delivery_templates(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 name text not null,default_lines jsonb not null default '[]',status text not null default 'active',created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),archived_at timestamptz,
 constraint daily_templates_name_check check(btrim(name)<>''),constraint daily_templates_lines_check check(jsonb_typeof(default_lines)='array'),
 constraint daily_templates_status_check check(status in('active','inactive','archived')),
 constraint daily_templates_lifecycle_check check((status='archived' and archived_at is not null)or(status in('active','inactive')and archived_at is null))
);
create index daily_templates_scope_idx on public.daily_delivery_templates(organization_id,branch_id,status);

create table public.daily_delivery_documents(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 template_id uuid references public.daily_delivery_templates(id) on delete restrict,purchase_document_id uuid not null unique references public.purchase_documents(id) on delete restrict,
 delivery_date date not null,sequence_number integer not null check(sequence_number>0),created_at timestamptz not null default now(),
 unique(template_id,delivery_date,sequence_number)
);

-- Inventory documents and transfers ------------------------------------------
create table public.inventory_documents(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 document_type text not null,document_number text not null,business_date date not null,status text not null default 'draft',reason_code text not null,
 device_id uuid references public.devices_v2(id) on delete restrict,local_operation_id uuid,posted_by uuid references public.organization_memberships(id) on delete restrict,
 posted_at timestamptz,reversal_of_id uuid references public.inventory_documents(id) on delete restrict,created_at timestamptz not null default now(),
 constraint inventory_documents_type_check check(document_type in('opening','adjustment','write_off','reversal')),
 constraint inventory_documents_number_check check(btrim(document_number)<>''),constraint inventory_documents_reason_check check(btrim(reason_code)<>''),
 constraint inventory_documents_status_check check(status in('draft','posted','reversed','cancelled')),
 constraint inventory_documents_post_state_check check((status='posted' and posted_at is not null and posted_by is not null)or status<>'posted'),
 unique(organization_id,document_number)
);
create unique index inventory_documents_operation_key on public.inventory_documents(organization_id,device_id,local_operation_id) where device_id is not null and local_operation_id is not null;
create unique index inventory_documents_online_operation_key on public.inventory_documents(organization_id,local_operation_id) where device_id is null and local_operation_id is not null;
create unique index inventory_documents_one_reversal_key on public.inventory_documents(reversal_of_id) where reversal_of_id is not null;
create index inventory_documents_journal_idx on public.inventory_documents(branch_id,business_date desc,status);

create table public.inventory_document_lines(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 inventory_document_id uuid not null references public.inventory_documents(id) on delete restrict,line_number integer not null,
 product_id uuid not null references public.products_v2(id) on delete restrict,batch_id uuid references public.product_batches_v2(id) on delete restrict,
 unit_id uuid not null references public.units_v2(id) on delete restrict,quantity numeric(18,6) not null,unit_factor numeric(20,10) not null,
 base_quantity_delta numeric(18,6) not null,comment text,created_at timestamptz not null default now(),
 constraint inventory_lines_number_check check(line_number>0),constraint inventory_lines_quantity_check check(quantity>0 and unit_factor>0 and base_quantity_delta<>0),
 unique(inventory_document_id,line_number)
);

create table public.warehouse_transfers(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,source_warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 destination_warehouse_id uuid not null references public.warehouses(id) on delete restrict,document_number text not null,business_date date not null,
 status text not null default 'draft',device_id uuid references public.devices_v2(id) on delete restrict,local_operation_id uuid,
 posted_by uuid references public.organization_memberships(id) on delete restrict,posted_at timestamptz,
 reversal_of_id uuid references public.warehouse_transfers(id) on delete restrict,created_at timestamptz not null default now(),
 constraint transfers_warehouses_differ_check check(source_warehouse_id<>destination_warehouse_id),constraint transfers_number_check check(btrim(document_number)<>''),
 constraint transfers_status_check check(status in('draft','posted','reversed','cancelled')),
 constraint transfers_post_state_check check((status='posted' and posted_at is not null and posted_by is not null)or status<>'posted'),
 unique(organization_id,document_number)
);
create unique index transfers_operation_key on public.warehouse_transfers(organization_id,device_id,local_operation_id) where device_id is not null and local_operation_id is not null;
create unique index transfers_online_operation_key on public.warehouse_transfers(organization_id,local_operation_id) where device_id is null and local_operation_id is not null;
create unique index transfers_one_reversal_key on public.warehouse_transfers(reversal_of_id) where reversal_of_id is not null;
create index transfers_journal_idx on public.warehouse_transfers(branch_id,business_date desc,status);

create table public.warehouse_transfer_lines(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 warehouse_transfer_id uuid not null references public.warehouse_transfers(id) on delete restrict,line_number integer not null,
 product_id uuid not null references public.products_v2(id) on delete restrict,batch_id uuid references public.product_batches_v2(id) on delete restrict,
 unit_id uuid not null references public.units_v2(id) on delete restrict,quantity numeric(18,6) not null,unit_factor numeric(20,10) not null,
 base_quantity numeric(18,6) not null,created_at timestamptz not null default now(),
 constraint transfer_lines_number_check check(line_number>0),constraint transfer_lines_quantity_check check(quantity>0 and unit_factor>0 and base_quantity>0),
 unique(warehouse_transfer_id,line_number)
);

-- Ledger and projection -------------------------------------------------------
create table public.inventory_movements(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,warehouse_id uuid not null references public.warehouses(id) on delete restrict,
 product_id uuid not null references public.products_v2(id) on delete restrict,batch_id uuid references public.product_batches_v2(id) on delete restrict,
 movement_type text not null,quantity_delta numeric(18,6) not null,source_document_type text not null,source_document_id uuid not null,
 source_line_id uuid not null,movement_role text not null default 'primary',reversal_of_id uuid references public.inventory_movements(id) on delete restrict,
 command_id uuid not null references public.command_log(id) on delete restrict,created_by uuid not null references public.organization_memberships(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint inventory_movements_delta_check check(quantity_delta<>0),constraint inventory_movements_type_check check(btrim(movement_type)<>''),
 constraint inventory_movements_source_check check(source_document_type in('purchase','inventory_document','warehouse_transfer')),
 constraint inventory_movements_role_check check(movement_role in('primary','out','in','reversal')),
 unique(source_document_type,source_line_id,movement_role)
);
create index inventory_movements_scope_idx on public.inventory_movements(warehouse_id,product_id,batch_id,created_at,id);
create index inventory_movements_source_idx on public.inventory_movements(source_document_type,source_document_id,source_line_id);
create index inventory_movements_org_created_idx on public.inventory_movements(organization_id,created_at,id);

create table public.inventory_balances(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 warehouse_id uuid not null references public.warehouses(id) on delete restrict,product_id uuid not null references public.products_v2(id) on delete restrict,
 batch_id uuid references public.product_batches_v2(id) on delete restrict,on_hand_quantity numeric(18,6) not null default 0,
 reserved_quantity numeric(18,6) not null default 0,available_quantity numeric(18,6) generated always as(on_hand_quantity-reserved_quantity) stored,
 last_movement_id uuid references public.inventory_movements(id) on delete restrict,version bigint not null default 0,updated_at timestamptz not null default now(),
 constraint inventory_balances_reserved_check check(reserved_quantity>=0),constraint inventory_balances_version_check check(version>=0),
 unique nulls not distinct(warehouse_id,product_id,batch_id)
);
create index inventory_balances_org_warehouse_idx on public.inventory_balances(organization_id,warehouse_id,product_id);

-- Defensive guards ------------------------------------------------------------
create or replace function public.v2_purchase_context_required() returns trigger language plpgsql set search_path='' as $$
begin if coalesce(current_setting('market_pos.purchase_command',true),'')<>'on' then raise exception using errcode='P0001',message='V2_PURCHASE_COMMAND_CONTEXT_REQUIRED';end if;return coalesce(new,old);end$$;
create or replace function public.v2_inventory_context_required() returns trigger language plpgsql set search_path='' as $$
begin if coalesce(current_setting('market_pos.inventory_command',true),'')<>'on' then raise exception using errcode='P0001',message='V2_INVENTORY_COMMAND_CONTEXT_REQUIRED';end if;return coalesce(new,old);end$$;

create or replace function public.v2_guard_purchase_document() returns trigger language plpgsql set search_path='' as $$
declare bo uuid;wo uuid;wb uuid;co uuid;do_ uuid;db uuid;mo uuid;
begin
 select organization_id into bo from public.branches where id=new.branch_id;
 select organization_id,branch_id into wo,wb from public.warehouses where id=new.warehouse_id;
 if bo is distinct from new.organization_id or wo is distinct from new.organization_id or wb is distinct from new.branch_id then raise exception using errcode='P0001',message='V2_PURCHASE_LOCATION_TENANT_MISMATCH';end if;
 if new.counterparty_id is not null then select organization_id into co from public.counterparties where id=new.counterparty_id;
  if co is distinct from new.organization_id or not exists(select 1 from public.counterparty_roles where counterparty_id=new.counterparty_id and organization_id=new.organization_id and role_code='supplier' and ended_at is null) then raise exception using errcode='P0001',message='V2_PURCHASE_ACTIVE_SUPPLIER_REQUIRED';end if;end if;
 if new.device_id is not null then select organization_id,branch_id into do_,db from public.devices_v2 where id=new.device_id;if do_ is distinct from new.organization_id or db is distinct from new.branch_id then raise exception using errcode='P0001',message='V2_PURCHASE_DEVICE_SCOPE_MISMATCH';end if;end if;
 if new.posted_by is not null then select organization_id into mo from public.organization_memberships where id=new.posted_by;if mo is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PURCHASE_ACTOR_TENANT_MISMATCH';end if;end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.branch_id is distinct from old.branch_id or new.warehouse_id is distinct from old.warehouse_id or new.device_id is distinct from old.device_id or new.local_operation_id is distinct from old.local_operation_id or new.created_at is distinct from old.created_at or new.reversal_of_id is distinct from old.reversal_of_id then raise exception using errcode='P0001',message='V2_PURCHASE_IDENTITY_MUTATION_FORBIDDEN';end if;
  if old.status<>'draft' and not(old.status='posted' and new.status='reversed' and (to_jsonb(new)-'status')=(to_jsonb(old)-'status')) then raise exception using errcode='P0001',message='V2_PURCHASE_POSTED_IMMUTABLE';end if;
 end if;return new;
end$$;

create or replace function public.v2_guard_purchase_child() returns trigger language plpgsql set search_path='' as $$
declare d uuid;st text;po uuid;begin
 if tg_table_name='purchase_lines' then select organization_id,status into d,st from public.purchase_documents where id=new.purchase_document_id;
 elsif tg_table_name='purchase_additional_costs' then select organization_id,status into d,st from public.purchase_documents where id=new.purchase_document_id;
 else select pd.organization_id,pd.status into d,st from public.purchase_additional_costs pc join public.purchase_documents pd on pd.id=pc.purchase_document_id where pc.id=new.purchase_additional_cost_id;
  if not exists(select 1 from public.purchase_lines pl join public.purchase_additional_costs pc on pc.purchase_document_id=pl.purchase_document_id where pl.id=new.purchase_line_id and pc.id=new.purchase_additional_cost_id) then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATION_SCOPE_MISMATCH';end if;
 end if;
 if d is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PURCHASE_CHILD_TENANT_MISMATCH';end if;
 if st<>'draft' then raise exception using errcode='P0001',message='V2_PURCHASE_POSTED_IMMUTABLE';end if;
 if tg_op='UPDATE' then
  if tg_table_name='purchase_lines' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.purchase_document_id is distinct from old.purchase_document_id or new.created_at is distinct from old.created_at)then raise exception using errcode='P0001',message='V2_PURCHASE_LINE_SCOPE_MISMATCH';end if;
  if tg_table_name='purchase_additional_costs' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.purchase_document_id is distinct from old.purchase_document_id or new.created_at is distinct from old.created_at)then raise exception using errcode='P0001',message='V2_PURCHASE_COST_SCOPE_MISMATCH';end if;
 end if;
 if tg_table_name='purchase_lines' then
  select organization_id into po from public.products_v2 where id=new.product_id;if po is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_PURCHASE_PRODUCT_TENANT_MISMATCH';end if;
  if not exists(select 1 from public.units_v2 where id=new.unit_id and organization_id=new.organization_id) then raise exception using errcode='P0001',message='V2_PURCHASE_UNIT_TENANT_MISMATCH';end if;
 end if;return new;
end$$;

create or replace function public.v2_guard_product_batch_v2() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.purchase_lines l join public.purchase_documents d on d.id=l.purchase_document_id where l.id=new.purchase_line_id and l.organization_id=new.organization_id and l.product_id=new.product_id and d.organization_id=new.organization_id and d.warehouse_id=new.warehouse_id and d.status='posted') then raise exception using errcode='P0001',message='V2_BATCH_PURCHASE_SCOPE_MISMATCH';end if;
 if tg_op='UPDATE' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.warehouse_id is distinct from old.warehouse_id or new.product_id is distinct from old.product_id or new.purchase_line_id is distinct from old.purchase_line_id or new.batch_code is distinct from old.batch_code or new.initial_quantity is distinct from old.initial_quantity or new.purchase_unit_cost is distinct from old.purchase_unit_cost or new.currency_code is distinct from old.currency_code or new.created_at is distinct from old.created_at or old.status='reversed' or(new.status='reversed' and old.status not in('open','depleted','blocked'))) then raise exception using errcode='P0001',message='V2_BATCH_IDENTITY_MUTATION_FORBIDDEN';end if;return new;
end$$;

create or replace function public.v2_guard_daily_template() returns trigger language plpgsql set search_path='' as $$
begin if not exists(select 1 from public.branches where id=new.branch_id and organization_id=new.organization_id) or not exists(select 1 from public.counterparty_roles r join public.counterparties c on c.id=r.counterparty_id where c.id=new.counterparty_id and c.organization_id=new.organization_id and r.role_code='supplier' and r.ended_at is null) then raise exception using errcode='P0001',message='V2_DAILY_TEMPLATE_SCOPE_MISMATCH';end if;
 if tg_op='UPDATE' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.branch_id is distinct from old.branch_id or new.counterparty_id is distinct from old.counterparty_id or new.created_at is distinct from old.created_at or old.status='archived') then raise exception using errcode='P0001',message='V2_DAILY_TEMPLATE_IDENTITY_MUTATION_FORBIDDEN';end if;return new;end$$;

create or replace function public.v2_guard_inventory_document() returns trigger language plpgsql set search_path='' as $$
begin if not exists(select 1 from public.warehouses w where w.id=new.warehouse_id and w.organization_id=new.organization_id and w.branch_id=new.branch_id) then raise exception using errcode='P0001',message='V2_INVENTORY_LOCATION_TENANT_MISMATCH';end if;
 if new.device_id is not null and not exists(select 1 from public.devices_v2 where id=new.device_id and organization_id=new.organization_id and branch_id=new.branch_id) then raise exception using errcode='P0001',message='V2_INVENTORY_DEVICE_SCOPE_MISMATCH';end if;
 if new.posted_by is not null and not exists(select 1 from public.organization_memberships where id=new.posted_by and organization_id=new.organization_id) then raise exception using errcode='P0001',message='V2_INVENTORY_ACTOR_TENANT_MISMATCH';end if;
 if tg_op='UPDATE' then if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.branch_id is distinct from old.branch_id or new.warehouse_id is distinct from old.warehouse_id or new.document_type is distinct from old.document_type or new.device_id is distinct from old.device_id or new.local_operation_id is distinct from old.local_operation_id or new.reversal_of_id is distinct from old.reversal_of_id or new.created_at is distinct from old.created_at then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_IDENTITY_MUTATION_FORBIDDEN';end if;if old.status in('cancelled','reversed')or(old.status='posted'and not(new.status='reversed'and(to_jsonb(new)-'status')=(to_jsonb(old)-'status')))then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_POSTED_IMMUTABLE';end if;end if;return new;end$$;

create or replace function public.v2_guard_inventory_line() returns trigger language plpgsql set search_path='' as $$
declare o uuid;w uuid;st text;begin select organization_id,warehouse_id,status into o,w,st from public.inventory_documents where id=new.inventory_document_id;if o is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_INVENTORY_LINE_TENANT_MISMATCH';end if;if st<>'draft' then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_POSTED_IMMUTABLE';end if;
 if tg_op='UPDATE'and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.inventory_document_id is distinct from old.inventory_document_id or new.created_at is distinct from old.created_at)then raise exception using errcode='P0001',message='V2_INVENTORY_LINE_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.products_v2 where id=new.product_id and organization_id=o) or not exists(select 1 from public.units_v2 where id=new.unit_id and organization_id=o) or(new.batch_id is not null and not exists(select 1 from public.product_batches_v2 where id=new.batch_id and organization_id=o and warehouse_id=w and product_id=new.product_id)) then raise exception using errcode='P0001',message='V2_INVENTORY_LINE_SCOPE_MISMATCH';end if;return new;end$$;

create or replace function public.v2_guard_warehouse_transfer() returns trigger language plpgsql set search_path='' as $$
begin if not exists(select 1 from public.warehouses where id=new.source_warehouse_id and organization_id=new.organization_id and branch_id=new.branch_id) or not exists(select 1 from public.warehouses where id=new.destination_warehouse_id and organization_id=new.organization_id and branch_id=new.branch_id) then raise exception using errcode='P0001',message='V2_TRANSFER_WAREHOUSE_SCOPE_MISMATCH';end if;
 if new.device_id is not null and not exists(select 1 from public.devices_v2 where id=new.device_id and organization_id=new.organization_id and branch_id=new.branch_id) then raise exception using errcode='P0001',message='V2_TRANSFER_DEVICE_SCOPE_MISMATCH';end if;
 if new.posted_by is not null and not exists(select 1 from public.organization_memberships where id=new.posted_by and organization_id=new.organization_id) then raise exception using errcode='P0001',message='V2_TRANSFER_ACTOR_TENANT_MISMATCH';end if;
 if tg_op='UPDATE' then if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.branch_id is distinct from old.branch_id or new.source_warehouse_id is distinct from old.source_warehouse_id or new.destination_warehouse_id is distinct from old.destination_warehouse_id or new.device_id is distinct from old.device_id or new.local_operation_id is distinct from old.local_operation_id or new.reversal_of_id is distinct from old.reversal_of_id or new.created_at is distinct from old.created_at then raise exception using errcode='P0001',message='V2_TRANSFER_IDENTITY_MUTATION_FORBIDDEN';end if;if old.status in('cancelled','reversed')or(old.status='posted'and not(new.status='reversed'and(to_jsonb(new)-'status')=(to_jsonb(old)-'status')))then raise exception using errcode='P0001',message='V2_TRANSFER_POSTED_IMMUTABLE';end if;end if;return new;end$$;

create or replace function public.v2_guard_transfer_line() returns trigger language plpgsql set search_path='' as $$
declare o uuid;sw uuid;st text;begin select organization_id,source_warehouse_id,status into o,sw,st from public.warehouse_transfers where id=new.warehouse_transfer_id;if o is distinct from new.organization_id or st<>'draft' then raise exception using errcode='P0001',message='V2_TRANSFER_LINE_SCOPE_MISMATCH';end if;
 if tg_op='UPDATE'and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.warehouse_transfer_id is distinct from old.warehouse_transfer_id or new.created_at is distinct from old.created_at)then raise exception using errcode='P0001',message='V2_TRANSFER_LINE_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.products_v2 where id=new.product_id and organization_id=o) or not exists(select 1 from public.units_v2 where id=new.unit_id and organization_id=o) or(new.batch_id is not null and not exists(select 1 from public.product_batches_v2 where id=new.batch_id and organization_id=o and warehouse_id=sw and product_id=new.product_id)) then raise exception using errcode='P0001',message='V2_TRANSFER_LINE_SCOPE_MISMATCH';end if;return new;end$$;

create or replace function public.v2_guard_inventory_movement() returns trigger language plpgsql set search_path='' as $$
declare r public.inventory_movements%rowtype;begin
 if not exists(select 1 from public.warehouses where id=new.warehouse_id and organization_id=new.organization_id and branch_id=new.branch_id) or not exists(select 1 from public.products_v2 where id=new.product_id and organization_id=new.organization_id) or not exists(select 1 from public.command_log where id=new.command_id and organization_id=new.organization_id) or not exists(select 1 from public.organization_memberships where id=new.created_by and organization_id=new.organization_id) then raise exception using errcode='P0001',message='V2_INVENTORY_MOVEMENT_SCOPE_MISMATCH';end if;
 if new.batch_id is not null and not exists(select 1 from public.product_batches_v2 where id=new.batch_id and organization_id=new.organization_id and warehouse_id=new.warehouse_id and product_id=new.product_id) then raise exception using errcode='P0001',message='V2_INVENTORY_MOVEMENT_BATCH_SCOPE_MISMATCH';end if;
 if new.reversal_of_id is not null then select * into r from public.inventory_movements where id=new.reversal_of_id;if not found or r.organization_id<>new.organization_id or r.warehouse_id<>new.warehouse_id or r.product_id<>new.product_id or r.batch_id is distinct from new.batch_id or r.quantity_delta<>-new.quantity_delta then raise exception using errcode='P0001',message='V2_INVENTORY_REVERSAL_MISMATCH';end if;end if;return new;end$$;

create or replace function public.v2_guard_inventory_balance() returns trigger language plpgsql set search_path='' as $$
declare neg boolean;cur numeric;begin select allow_negative_stock into neg from public.warehouses where id=new.warehouse_id and organization_id=new.organization_id;if neg is null or not exists(select 1 from public.products_v2 where id=new.product_id and organization_id=new.organization_id) or(new.batch_id is not null and not exists(select 1 from public.product_batches_v2 where id=new.batch_id and warehouse_id=new.warehouse_id and product_id=new.product_id and organization_id=new.organization_id)) then raise exception using errcode='P0001',message='V2_INVENTORY_BALANCE_SCOPE_MISMATCH';end if;
 if tg_op='INSERT' then select on_hand_quantity into cur from public.inventory_balances where warehouse_id=new.warehouse_id and product_id=new.product_id and batch_id is not distinct from new.batch_id;if new.on_hand_quantity<0 and not neg and coalesce(cur,0)+new.on_hand_quantity<0 then raise exception using errcode='P0001',message='V2_INVENTORY_NEGATIVE_STOCK_FORBIDDEN';end if;elsif new.on_hand_quantity<0 and not neg then raise exception using errcode='P0001',message='V2_INVENTORY_NEGATIVE_STOCK_FORBIDDEN';end if;if tg_op='UPDATE' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.warehouse_id is distinct from old.warehouse_id or new.product_id is distinct from old.product_id or new.batch_id is distinct from old.batch_id) then raise exception using errcode='P0001',message='V2_INVENTORY_BALANCE_IDENTITY_MUTATION_FORBIDDEN';end if;return new;end$$;

create or replace function public.v2_prevent_posted_delete() returns trigger language plpgsql set search_path='' as $$
declare st text;begin if tg_table_name in('purchase_documents','inventory_documents','warehouse_transfers') then st:=old.status;
 elsif tg_table_name in('purchase_lines','purchase_additional_costs') then select status into st from public.purchase_documents where id=old.purchase_document_id;
 elsif tg_table_name='inventory_document_lines' then select status into st from public.inventory_documents where id=old.inventory_document_id;
 elsif tg_table_name='warehouse_transfer_lines' then select status into st from public.warehouse_transfers where id=old.warehouse_transfer_id;
 else raise exception using errcode='P0001',message='V2_LEDGER_DELETE_FORBIDDEN';end if;if st<>'draft' then raise exception using errcode='P0001',message='V2_POSTED_DELETE_FORBIDDEN';end if;return old;end$$;

-- Triggers -------------------------------------------------------------------
create trigger a_purchase_documents_context before insert or update or delete on public.purchase_documents for each row execute function public.v2_purchase_context_required();
create trigger b_purchase_documents_guard before insert or update on public.purchase_documents for each row execute function public.v2_guard_purchase_document();
create trigger c_purchase_documents_delete before delete on public.purchase_documents for each row execute function public.v2_prevent_posted_delete();
create trigger a_purchase_lines_context before insert or update or delete on public.purchase_lines for each row execute function public.v2_purchase_context_required();
create trigger b_purchase_lines_guard before insert or update on public.purchase_lines for each row execute function public.v2_guard_purchase_child();
create trigger c_purchase_lines_delete before delete on public.purchase_lines for each row execute function public.v2_prevent_posted_delete();
create trigger a_purchase_costs_context before insert or update or delete on public.purchase_additional_costs for each row execute function public.v2_purchase_context_required();
create trigger b_purchase_costs_guard before insert or update on public.purchase_additional_costs for each row execute function public.v2_guard_purchase_child();
create trigger c_purchase_costs_delete before delete on public.purchase_additional_costs for each row execute function public.v2_prevent_posted_delete();
create trigger a_purchase_allocations_context before insert or update or delete on public.purchase_cost_allocations for each row execute function public.v2_purchase_context_required();
create trigger b_purchase_allocations_guard before insert or update on public.purchase_cost_allocations for each row execute function public.v2_guard_purchase_child();
create trigger c_purchase_allocations_immutable before update or delete on public.purchase_cost_allocations for each row execute function public.v2_prevent_posted_delete();
create trigger a_batches_context before insert or update or delete on public.product_batches_v2 for each row execute function public.v2_inventory_context_required();
create trigger b_batches_guard before insert or update on public.product_batches_v2 for each row execute function public.v2_guard_product_batch_v2();
create trigger c_batches_delete before delete on public.product_batches_v2 for each row execute function public.v2_prevent_posted_delete();
create trigger a_daily_templates_context before insert or update or delete on public.daily_delivery_templates for each row execute function public.v2_purchase_context_required();
create trigger b_daily_templates_guard before insert or update on public.daily_delivery_templates for each row execute function public.v2_guard_daily_template();
create trigger c_daily_templates_delete before delete on public.daily_delivery_templates for each row execute function public.v2_prevent_posted_delete();
create trigger d_daily_templates_updated_at before update on public.daily_delivery_templates for each row execute function public.set_updated_at();
create trigger a_daily_documents_context before insert or update or delete on public.daily_delivery_documents for each row execute function public.v2_purchase_context_required();
create trigger c_daily_documents_immutable before update or delete on public.daily_delivery_documents for each row execute function public.v2_prevent_posted_delete();
create trigger a_inventory_documents_context before insert or update or delete on public.inventory_documents for each row execute function public.v2_inventory_context_required();
create trigger b_inventory_documents_guard before insert or update on public.inventory_documents for each row execute function public.v2_guard_inventory_document();
create trigger c_inventory_documents_delete before delete on public.inventory_documents for each row execute function public.v2_prevent_posted_delete();
create trigger a_inventory_lines_context before insert or update or delete on public.inventory_document_lines for each row execute function public.v2_inventory_context_required();
create trigger b_inventory_lines_guard before insert or update on public.inventory_document_lines for each row execute function public.v2_guard_inventory_line();
create trigger c_inventory_lines_delete before delete on public.inventory_document_lines for each row execute function public.v2_prevent_posted_delete();
create trigger a_transfers_context before insert or update or delete on public.warehouse_transfers for each row execute function public.v2_inventory_context_required();
create trigger b_transfers_guard before insert or update on public.warehouse_transfers for each row execute function public.v2_guard_warehouse_transfer();
create trigger c_transfers_delete before delete on public.warehouse_transfers for each row execute function public.v2_prevent_posted_delete();
create trigger a_transfer_lines_context before insert or update or delete on public.warehouse_transfer_lines for each row execute function public.v2_inventory_context_required();
create trigger b_transfer_lines_guard before insert or update on public.warehouse_transfer_lines for each row execute function public.v2_guard_transfer_line();
create trigger c_transfer_lines_delete before delete on public.warehouse_transfer_lines for each row execute function public.v2_prevent_posted_delete();
create trigger a_inventory_movements_context before insert or update or delete on public.inventory_movements for each row execute function public.v2_inventory_context_required();
create trigger b_inventory_movements_guard before insert on public.inventory_movements for each row execute function public.v2_guard_inventory_movement();
create trigger c_inventory_movements_immutable before update or delete on public.inventory_movements for each row execute function public.v2_prevent_row_mutation();
create trigger a_inventory_balances_context before insert or update or delete on public.inventory_balances for each row execute function public.v2_inventory_context_required();
create trigger b_inventory_balances_guard before insert or update on public.inventory_balances for each row execute function public.v2_guard_inventory_balance();
create trigger c_inventory_balances_delete before delete on public.inventory_balances for each row execute function public.v2_prevent_posted_delete();

-- Read authorization ----------------------------------------------------------
create or replace function public.v2_can_access_warehouse(o uuid,w uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.warehouses x where x.id=w and x.organization_id=o and public.v2_can_access_branch(o,x.branch_id))
$$;
create or replace function public.v2_can_view_purchase(o uuid,b uuid,cost boolean default false) returns boolean language sql stable security definer set search_path='' as $$
 select (public.v2_has_permission(o,'purchases.view',b) and(not cost or public.v2_has_permission(o,'purchases.cost.view',b)))
 or(public.v2_has_support_grant(o,'purchases.view')and(not cost or public.v2_has_support_grant(o,'purchases.cost.view')))
$$;
create or replace function public.v2_can_view_inventory(o uuid,b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.v2_has_permission(o,'inventory.view',b) or public.v2_has_support_grant(o,'inventory.view')
$$;

alter table public.purchase_documents enable row level security;alter table public.purchase_lines enable row level security;
alter table public.purchase_additional_costs enable row level security;alter table public.purchase_cost_allocations enable row level security;
alter table public.product_batches_v2 enable row level security;alter table public.daily_delivery_templates enable row level security;
alter table public.daily_delivery_documents enable row level security;alter table public.inventory_documents enable row level security;
alter table public.inventory_document_lines enable row level security;alter table public.warehouse_transfers enable row level security;
alter table public.warehouse_transfer_lines enable row level security;alter table public.inventory_movements enable row level security;
alter table public.inventory_balances enable row level security;

create policy purchase_documents_select on public.purchase_documents for select to authenticated using(public.v2_can_view_purchase(organization_id,branch_id,false));
create policy purchase_lines_cost_select on public.purchase_lines for select to authenticated using(exists(select 1 from public.purchase_documents d where d.id=purchase_document_id and public.v2_can_view_purchase(d.organization_id,d.branch_id,true)));
create policy purchase_costs_select on public.purchase_additional_costs for select to authenticated using(exists(select 1 from public.purchase_documents d where d.id=purchase_document_id and public.v2_can_view_purchase(d.organization_id,d.branch_id,true)));
create policy purchase_allocations_select on public.purchase_cost_allocations for select to authenticated using(exists(select 1 from public.purchase_additional_costs c join public.purchase_documents d on d.id=c.purchase_document_id where c.id=purchase_additional_cost_id and public.v2_can_view_purchase(d.organization_id,d.branch_id,true)));
create policy product_batches_v2_cost_select on public.product_batches_v2 for select to authenticated using(exists(select 1 from public.warehouses w where w.id=warehouse_id and public.v2_can_view_purchase(organization_id,w.branch_id,true)));
create policy daily_templates_select on public.daily_delivery_templates for select to authenticated using(public.v2_can_view_purchase(organization_id,branch_id,false));
create policy daily_documents_select on public.daily_delivery_documents for select to authenticated using(exists(select 1 from public.purchase_documents d where d.id=purchase_document_id and public.v2_can_view_purchase(d.organization_id,d.branch_id,false)));
create policy inventory_documents_select on public.inventory_documents for select to authenticated using(public.v2_can_view_inventory(organization_id,branch_id));
create policy inventory_lines_select on public.inventory_document_lines for select to authenticated using(exists(select 1 from public.inventory_documents d where d.id=inventory_document_id and public.v2_can_view_inventory(d.organization_id,d.branch_id)));
create policy transfers_select on public.warehouse_transfers for select to authenticated using(public.v2_can_view_inventory(organization_id,branch_id));
create policy transfer_lines_select on public.warehouse_transfer_lines for select to authenticated using(exists(select 1 from public.warehouse_transfers t where t.id=warehouse_transfer_id and public.v2_can_view_inventory(t.organization_id,t.branch_id)));
create policy inventory_movements_select on public.inventory_movements for select to authenticated using(public.v2_can_view_inventory(organization_id,branch_id));
create policy inventory_balances_select on public.inventory_balances for select to authenticated using(public.v2_can_access_warehouse(organization_id,warehouse_id) and public.v2_can_view_inventory(organization_id,(select branch_id from public.warehouses where id=warehouse_id)));

create or replace function public.v2_purchase_journal(o uuid,b uuid default null)
returns table(id uuid,branch_id uuid,warehouse_id uuid,counterparty_id uuid,document_number text,business_date date,status text,currency_code char(3),created_at timestamptz)
language sql stable security definer set search_path='' as $$
 select d.id,d.branch_id,d.warehouse_id,d.counterparty_id,d.document_number,d.business_date,d.status,d.currency_code,d.created_at
 from public.purchase_documents d where d.organization_id=o and(b is null or d.branch_id=b) and public.v2_can_view_purchase(o,d.branch_id,false)
 order by d.business_date desc,d.created_at desc
$$;

revoke all on public.purchase_documents,public.purchase_lines,public.purchase_additional_costs,public.purchase_cost_allocations,public.product_batches_v2,public.daily_delivery_templates,public.daily_delivery_documents,public.inventory_documents,public.inventory_document_lines,public.warehouse_transfers,public.warehouse_transfer_lines,public.inventory_movements,public.inventory_balances from anon,authenticated;
grant select on public.purchase_documents,public.purchase_lines,public.purchase_additional_costs,public.purchase_cost_allocations,public.product_batches_v2,public.daily_delivery_templates,public.daily_delivery_documents,public.inventory_documents,public.inventory_document_lines,public.warehouse_transfers,public.warehouse_transfer_lines,public.inventory_movements,public.inventory_balances to authenticated;
revoke execute on function public.v2_purchase_journal(uuid,uuid),public.v2_can_access_warehouse(uuid,uuid),public.v2_can_view_purchase(uuid,uuid,boolean),public.v2_can_view_inventory(uuid,uuid) from public,anon;
grant execute on function public.v2_purchase_journal(uuid,uuid),public.v2_can_access_warehouse(uuid,uuid),public.v2_can_view_purchase(uuid,uuid,boolean),public.v2_can_view_inventory(uuid,uuid) to authenticated;

-- Command infrastructure ------------------------------------------------------
create or replace function public.v2_begin_inventory_command(o uuid,b uuid,d uuid,op uuid,ct text,p jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare c public.command_log%rowtype;a uuid;h text:=encode(extensions.digest(p::text,'sha256'),'hex');begin
 a:=public.v2_current_membership_id(o);if a is null then raise exception using errcode='P0001',message='V2_ACTIVE_MEMBERSHIP_REQUIRED';end if;
 select * into c from public.command_log where organization_id=o and local_operation_id=op and device_id is not distinct from d for update;
 if found then if c.payload_hash<>h then raise exception using errcode='P0001',message='V2_IDEMPOTENCY_PAYLOAD_MISMATCH';end if;return c.id;end if;
 insert into public.command_log(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,local_operation_id,command_type,payload_hash)
 values(o,b,d,auth.uid(),a,op,ct,h) returning id into c.id;return c.id;
end$$;
create or replace function public.v2_complete_inventory_command(c uuid,et text,e uuid,r jsonb) returns void language plpgsql security definer set search_path='' as $$
begin update public.command_log set status='succeeded',entity_type=et,entity_id=e,result=r,completed_at=clock_timestamp() where id=c and status='processing';end$$;
create or replace function public.v2_require_domain_approval(aid uuid,c uuid,o uuid,pc text) returns void language plpgsql security definer set search_path='' as $$
begin if aid is null or not exists(select 1 from public.approval_requests a where a.id=aid and a.command_id=c and a.organization_id=o and a.permission_code=pc and a.status='approved' and a.expires_at>now()) then raise exception using errcode='P0001',message='V2_APPROVED_REQUEST_REQUIRED';end if;end$$;
create or replace function public.v2_use_approved_command(aid uuid,o uuid,pc text,op uuid,p jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare c uuid;h text:=encode(extensions.digest(p::text,'sha256'),'hex');begin select a.command_id into c from public.approval_requests a join public.command_log l on l.id=a.command_id where a.id=aid and a.organization_id=o and a.permission_code=pc and a.status='approved' and a.expires_at>now() and l.organization_id=o and l.local_operation_id=op and l.payload_hash=h and l.status in('processing','succeeded');if c is null then raise exception using errcode='P0001',message='V2_APPROVED_REQUEST_REQUIRED';end if;return c;end$$;
create or replace function public.v2_emit_domain_event(o uuid,b uuid,d uuid,a uuid,c uuid,aid uuid,et text,e uuid,act text,ev text,p jsonb) returns void language plpgsql security definer set search_path='' as $$
begin insert into public.audit_events(organization_id,branch_id,device_id,actor_auth_user_id,actor_membership_id,command_log_id,local_operation_id,correlation_id,action,entity_type,entity_id,approval_request_id,metadata)
 select o,b,d,auth.uid(),a,c,local_operation_id,c,act,et,e,aid,p from public.command_log where id=c;
 insert into public.outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)values(o,et,e,ev,p,c);end$$;

create or replace function public.v2_lock_inventory_scopes(o uuid,scopes jsonb)returns void language plpgsql set search_path='' as $$
declare s jsonb;begin for s in select value from jsonb_array_elements(scopes)order by value->>'warehouse_id',value->>'product_id',coalesce(value->>'batch_id','')loop perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(o::text||':'||(s->>'warehouse_id')||':'||(s->>'product_id')||':'||coalesce(s->>'batch_id','NULL'),0));end loop;end$$;

create or replace function public.v2_apply_inventory_movement(o uuid,b uuid,w uuid,p uuid,bt uuid,mt text,q numeric,st text,sd uuid,sl uuid,mr text,rev uuid,c uuid,a uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare m uuid:=gen_random_uuid();begin
 insert into public.inventory_movements(id,organization_id,branch_id,warehouse_id,product_id,batch_id,movement_type,quantity_delta,source_document_type,source_document_id,source_line_id,movement_role,reversal_of_id,command_id,created_by)
 values(m,o,b,w,p,bt,mt,q,st,sd,sl,mr,rev,c,a);
 insert into public.inventory_balances(organization_id,warehouse_id,product_id,batch_id,on_hand_quantity,last_movement_id,version)
 values(o,w,p,bt,q,m,1) on conflict(warehouse_id,product_id,batch_id) do update set on_hand_quantity=public.inventory_balances.on_hand_quantity+excluded.on_hand_quantity,last_movement_id=excluded.last_movement_id,version=public.inventory_balances.version+1,updated_at=now();
 if bt is not null then insert into public.inventory_balances(organization_id,warehouse_id,product_id,batch_id,on_hand_quantity,last_movement_id,version)
  values(o,w,p,null,q,m,1) on conflict(warehouse_id,product_id,batch_id) do update set on_hand_quantity=public.inventory_balances.on_hand_quantity+excluded.on_hand_quantity,last_movement_id=excluded.last_movement_id,version=public.inventory_balances.version+1,updated_at=now();end if;
 insert into public.outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)values(o,'inventory_movement',m,'StockMoved',jsonb_build_object('warehouse_id',w,'product_id',p,'batch_id',bt,'quantity_delta',q),c);return m;end$$;

-- Purchase draft and template commands ---------------------------------------
create or replace function public.v2_create_purchase_draft(o uuid,b uuid,w uuid,cp uuid,n text,bd date,cur char(3),d uuid,op uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid:=public.v2_current_membership_id(o);i uuid:=gen_random_uuid();c uuid;p jsonb:=jsonb_build_object('document_number',n,'warehouse_id',w,'counterparty_id',cp,'business_date',bd);begin
 if a is null or not public.v2_has_permission(o,'purchases.draft.manage',b) then raise exception using errcode='P0001',message='V2_PURCHASE_DRAFT_MANAGE_REQUIRED';end if;c:=public.v2_begin_inventory_command(o,b,d,op,'purchase.create_draft',p);
 if(select status='succeeded' from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform set_config('market_pos.purchase_command','on',true);insert into public.purchase_documents(id,organization_id,branch_id,warehouse_id,counterparty_id,document_number,business_date,currency_code,device_id,local_operation_id)values(i,o,b,w,cp,n,bd,cur,d,op);
 perform public.v2_emit_domain_event(o,b,d,a,c,null,'purchase',i,'purchase.draft_created','PurchaseDraftCreated',p);perform public.v2_complete_inventory_command(c,'purchase',i,jsonb_build_object('id',i,'status','draft'));perform set_config('market_pos.purchase_command','off',true);return i;end$$;
create or replace function public.v2_upsert_purchase_line(i uuid,doc uuid,ln integer,p uuid,u uuid,q numeric,f numeric,price numeric,exp date,sbn text)
returns uuid language plpgsql security definer set search_path='' as $$
declare d public.purchase_documents%rowtype;e public.purchase_lines%rowtype;x uuid;begin select * into d from public.purchase_documents where id=doc for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_NOT_FOUND';end if;if d.status<>'draft' or not public.v2_has_permission(d.organization_id,'purchases.draft.manage',d.branch_id)then raise exception using errcode='P0001',message='V2_PURCHASE_DRAFT_MANAGE_REQUIRED';end if;perform set_config('market_pos.purchase_command','on',true);
 if i is null then x:=gen_random_uuid();insert into public.purchase_lines(id,organization_id,purchase_document_id,line_number,product_id,unit_id,quantity,unit_factor,base_quantity,unit_purchase_price,line_amount,expiration_date,supplier_batch_number)values(x,d.organization_id,doc,ln,p,u,q,f,q*f,price,round(q*price,4),exp,sbn);
 else select * into e from public.purchase_lines where id=i for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_LINE_NOT_FOUND';end if;if e.organization_id<>d.organization_id or e.purchase_document_id<>doc then raise exception using errcode='P0001',message='V2_PURCHASE_LINE_SCOPE_MISMATCH';end if;x:=e.id;update public.purchase_lines set line_number=ln,product_id=p,unit_id=u,quantity=q,unit_factor=f,base_quantity=q*f,unit_purchase_price=price,line_amount=round(q*price,4),expiration_date=exp,supplier_batch_number=sbn where id=e.id;end if;perform set_config('market_pos.purchase_command','off',true);return x;end$$;
create or replace function public.v2_upsert_purchase_cost(i uuid,doc uuid,ct text,amt numeric,cur char(3),m text)
returns uuid language plpgsql security definer set search_path='' as $$
declare d public.purchase_documents%rowtype;e public.purchase_additional_costs%rowtype;x uuid;begin select * into d from public.purchase_documents where id=doc for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_NOT_FOUND';end if;if d.status<>'draft' or not public.v2_has_permission(d.organization_id,'purchases.draft.manage',d.branch_id)then raise exception using errcode='P0001',message='V2_PURCHASE_DRAFT_MANAGE_REQUIRED';end if;if cur<>d.currency_code then raise exception using errcode='P0001',message='V2_PURCHASE_COST_CURRENCY_MISMATCH';end if;if m not in('amount','quantity')then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATION_METHOD_UNSUPPORTED';end if;perform set_config('market_pos.purchase_command','on',true);
 if i is null then x:=gen_random_uuid();insert into public.purchase_additional_costs(id,organization_id,purchase_document_id,cost_type,amount,currency_code,allocation_method)values(x,d.organization_id,doc,ct,amt,cur,m);
 else select * into e from public.purchase_additional_costs where id=i for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_COST_NOT_FOUND';end if;if e.organization_id<>d.organization_id or e.purchase_document_id<>doc then raise exception using errcode='P0001',message='V2_PURCHASE_COST_SCOPE_MISMATCH';end if;x:=e.id;update public.purchase_additional_costs set cost_type=ct,amount=amt,currency_code=cur,allocation_method=m where id=e.id;end if;perform set_config('market_pos.purchase_command','off',true);return x;end$$;
create or replace function public.v2_cancel_purchase_draft(i uuid)returns void language plpgsql security definer set search_path='' as $$
declare o uuid;b uuid;begin select organization_id,branch_id into o,b from public.purchase_documents where id=i;if not public.v2_has_permission(o,'purchases.draft.manage',b)then raise exception using errcode='P0001',message='V2_PURCHASE_DRAFT_MANAGE_REQUIRED';end if;perform set_config('market_pos.purchase_command','on',true);update public.purchase_documents set status='cancelled' where id=i;perform set_config('market_pos.purchase_command','off',true);end$$;

create or replace function public.v2_upsert_daily_delivery_template(i uuid,o uuid,b uuid,cp uuid,n text,l jsonb,archive boolean default false)returns uuid language plpgsql security definer set search_path='' as $$
declare x uuid;e public.daily_delivery_templates%rowtype;begin if not public.v2_has_permission(o,'purchases.draft.manage',b)then raise exception using errcode='P0001',message='V2_PURCHASE_DRAFT_MANAGE_REQUIRED';end if;perform set_config('market_pos.purchase_command','on',true);
 if i is null then x:=gen_random_uuid();insert into public.daily_delivery_templates(id,organization_id,branch_id,counterparty_id,name,default_lines)values(x,o,b,cp,n,l);
 else select * into e from public.daily_delivery_templates where id=i for update;if not found then raise exception using errcode='P0001',message='V2_DAILY_TEMPLATE_NOT_FOUND';end if;if e.organization_id<>o or e.branch_id<>b or e.counterparty_id<>cp then raise exception using errcode='P0001',message='V2_DAILY_TEMPLATE_SCOPE_MISMATCH';end if;if e.status='archived'then raise exception using errcode='P0001',message='V2_DAILY_TEMPLATE_ARCHIVED_TERMINAL';end if;x:=e.id;if archive then update public.daily_delivery_templates set status='archived',archived_at=clock_timestamp()where id=e.id;else update public.daily_delivery_templates set name=n,default_lines=l where id=e.id;end if;end if;perform set_config('market_pos.purchase_command','off',true);return x;end$$;

-- Posting commands ------------------------------------------------------------
create or replace function public.v2_post_purchase(i uuid,op uuid,payload jsonb default '{}'::jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare d public.purchase_documents%rowtype;a uuid;c uuid;l public.purchase_lines%rowtype;pc public.purchase_additional_costs%rowtype;bt uuid;sub numeric;cost numeric;alloc numeric;basis numeric;given numeric;share numeric;last_line uuid;begin
 select * into d from public.purchase_documents where id=i for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_NOT_FOUND';end if;
 if not public.v2_has_permission(d.organization_id,'purchases.post',d.branch_id) and not(coalesce(current_setting('market_pos.daily_purchase_command',true),'')='on' and public.v2_has_permission(d.organization_id,'purchases.post_daily',d.branch_id))then raise exception using errcode='P0001',message='V2_PURCHASE_POST_REQUIRED';end if;
 a:=public.v2_current_membership_id(d.organization_id);if coalesce(current_setting('market_pos.daily_purchase_command',true),'')='on'then c:=current_setting('market_pos.daily_command_id')::uuid;else c:=public.v2_begin_inventory_command(d.organization_id,d.branch_id,d.device_id,op,'purchase.post',payload||jsonb_build_object('purchase_id',i));end if;if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 select coalesce(sum(line_amount),0) into sub from public.purchase_lines where purchase_document_id=i;select coalesce(sum(amount),0)into cost from public.purchase_additional_costs where purchase_document_id=i;
 if not exists(select 1 from public.purchase_lines where purchase_document_id=i)then raise exception using errcode='P0001',message='V2_PURCHASE_LINES_REQUIRED';end if;
 perform set_config('market_pos.purchase_command','on',true);perform set_config('market_pos.inventory_command','on',true);perform id from public.purchase_lines where purchase_document_id=i order by line_number,id for update;perform id from public.purchase_additional_costs where purchase_document_id=i order by id for update;
 for pc in select * from public.purchase_additional_costs where purchase_document_id=i order by id loop
  if pc.currency_code<>d.currency_code then raise exception using errcode='P0001',message='V2_PURCHASE_COST_CURRENCY_MISMATCH';end if;if pc.allocation_method not in('amount','quantity')then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATION_METHOD_UNSUPPORTED';end if;if exists(select 1 from public.purchase_cost_allocations where purchase_additional_cost_id=pc.id)then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATIONS_ALREADY_EXIST';end if;
  if pc.allocation_method='amount'then select sum(line_amount)into basis from public.purchase_lines where purchase_document_id=i;else select sum(base_quantity)into basis from public.purchase_lines where purchase_document_id=i;end if;if coalesce(basis,0)<=0 then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATION_BASIS_ZERO';end if;
  select id into last_line from public.purchase_lines where purchase_document_id=i order by line_number desc,id desc limit 1;given:=0;
  for l in select * from public.purchase_lines where purchase_document_id=i order by line_number,id loop if l.id=last_line then share:=pc.amount-given;else share:=round(pc.amount*(case when pc.allocation_method='amount'then l.line_amount else l.base_quantity end)/basis,4);given:=given+share;end if;insert into public.purchase_cost_allocations(organization_id,purchase_additional_cost_id,purchase_line_id,allocated_amount)values(d.organization_id,pc.id,l.id,share);end loop;
  if(select sum(allocated_amount)from public.purchase_cost_allocations where purchase_additional_cost_id=pc.id)<>pc.amount then raise exception using errcode='P0001',message='V2_PURCHASE_ALLOCATION_TOTAL_MISMATCH';end if;
 end loop;
 perform public.v2_lock_inventory_scopes(d.organization_id,(select coalesce(jsonb_agg(jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',x.product_id,'batch_id',null)order by x.product_id),'[]')from public.purchase_lines x where x.purchase_document_id=i));update public.purchase_documents set subtotal_amount=sub,additional_cost_amount=cost,total_amount=sub+cost,status='posted',posted_at=clock_timestamp(),posted_by=a where id=i;
 for l in select * from public.purchase_lines where purchase_document_id=i order by line_number loop bt:=gen_random_uuid();select coalesce(sum(x.allocated_amount),0)into alloc from public.purchase_cost_allocations x where x.purchase_line_id=l.id;
  insert into public.product_batches_v2(id,organization_id,warehouse_id,product_id,purchase_line_id,batch_code,supplier_batch_number,received_date,expiration_date,initial_quantity,purchase_unit_cost,currency_code)
  values(bt,d.organization_id,d.warehouse_id,l.product_id,l.id,d.document_number||'-'||l.line_number,l.supplier_batch_number,d.business_date,l.expiration_date,l.base_quantity,(l.line_amount+alloc)/l.base_quantity,d.currency_code);
  perform public.v2_apply_inventory_movement(d.organization_id,d.branch_id,d.warehouse_id,l.product_id,bt,'purchase',l.base_quantity,'purchase',i,l.id,'primary',null,c,a);
  perform public.v2_emit_domain_event(d.organization_id,d.branch_id,d.device_id,a,c,null,'product_batch',bt,'batch.created','BatchCreated',jsonb_build_object('purchase_id',i,'line_id',l.id));
 end loop;perform public.v2_emit_domain_event(d.organization_id,d.branch_id,d.device_id,a,c,null,'purchase',i,'purchase.posted','PurchasePosted',jsonb_build_object('purchase_id',i));if coalesce(current_setting('market_pos.daily_purchase_command',true),'')<>'on'then perform public.v2_complete_inventory_command(c,'purchase',i,jsonb_build_object('id',i,'status','posted'));end if;perform set_config('market_pos.purchase_command','off',true);perform set_config('market_pos.inventory_command','off',true);return i;end$$;

create or replace function public.v2_post_daily_delivery(t uuid,n text,bd date,cur char(3),lines jsonb,op uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare x public.daily_delivery_templates%rowtype;d uuid:=gen_random_uuid();dd uuid:=gen_random_uuid();l jsonb;seq integer;c uuid;a uuid;p jsonb;begin select * into x from public.daily_delivery_templates where id=t and status='active'for update;if not found or not public.v2_has_permission(x.organization_id,'purchases.post_daily',x.branch_id)then raise exception using errcode='P0001',message='V2_PURCHASE_POST_DAILY_REQUIRED';end if;p:=jsonb_build_object('template_id',t,'document_number',n,'business_date',bd,'currency_code',cur,'lines',lines);a:=public.v2_current_membership_id(x.organization_id);c:=public.v2_begin_inventory_command(x.organization_id,x.branch_id,null,op,'purchase.post_daily',p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;select coalesce(max(sequence_number),0)+1 into seq from public.daily_delivery_documents where template_id=t and delivery_date=bd;
 perform set_config('market_pos.purchase_command','on',true);insert into public.purchase_documents(id,organization_id,branch_id,warehouse_id,counterparty_id,document_number,business_date,currency_code,local_operation_id)select d,x.organization_id,x.branch_id,w.id,x.counterparty_id,n,bd,cur,op from public.warehouses w where w.branch_id=x.branch_id and w.is_primary and w.archived_at is null;
 for l in select * from jsonb_array_elements(lines)loop insert into public.purchase_lines(organization_id,purchase_document_id,line_number,product_id,unit_id,quantity,unit_factor,base_quantity,unit_purchase_price,line_amount,expiration_date,supplier_batch_number)values(x.organization_id,d,(l->>'line_number')::integer,(l->>'product_id')::uuid,(l->>'unit_id')::uuid,(l->>'quantity')::numeric,(l->>'unit_factor')::numeric,(l->>'quantity')::numeric*(l->>'unit_factor')::numeric,(l->>'unit_purchase_price')::numeric,round((l->>'quantity')::numeric*(l->>'unit_purchase_price')::numeric,4),(l->>'expiration_date')::date,l->>'supplier_batch_number');end loop;
 insert into public.daily_delivery_documents(id,organization_id,template_id,purchase_document_id,delivery_date,sequence_number)values(dd,x.organization_id,t,d,bd,seq);perform set_config('market_pos.daily_purchase_command','on',true);perform set_config('market_pos.daily_command_id',c::text,true);perform public.v2_post_purchase(d,op,p);perform public.v2_emit_domain_event(x.organization_id,x.branch_id,null,a,c,null,'daily_delivery',dd,'daily_delivery.posted','DailyDeliveryPosted',jsonb_build_object('daily_delivery_id',dd,'purchase_id',d));perform public.v2_complete_inventory_command(c,'purchase',d,jsonb_build_object('id',d,'status','posted','daily_delivery_id',dd));perform set_config('market_pos.purchase_command','off',true);perform set_config('market_pos.daily_purchase_command','off',true);perform set_config('market_pos.daily_command_id','',true);return d;end$$;

create or replace function public.v2_create_inventory_document(o uuid,b uuid,w uuid,dt text,n text,bd date,r text,d uuid,op uuid)returns uuid language plpgsql security definer set search_path='' as $$
declare i uuid:=gen_random_uuid();a uuid;c uuid;p jsonb:=jsonb_build_object('branch_id',b,'warehouse_id',w,'document_type',dt,'document_number',n,'business_date',bd,'reason_code',r);begin if dt not in('opening','adjustment','write_off')then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_NOT_POSTABLE';end if;if not public.v2_has_permission(o,'inventory.adjust',b)then raise exception using errcode='P0001',message='V2_INVENTORY_ADJUST_REQUIRED';end if;a:=public.v2_current_membership_id(o);c:=public.v2_begin_inventory_command(o,b,d,op,'inventory.create_draft',p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.inventory_command','on',true);insert into public.inventory_documents(id,organization_id,branch_id,warehouse_id,document_type,document_number,business_date,reason_code,device_id,local_operation_id)values(i,o,b,w,dt,n,bd,r,d,op);perform public.v2_emit_domain_event(o,b,d,a,c,null,'inventory_document',i,'inventory_document.draft_created','InventoryDocumentDraftCreated',p);perform public.v2_complete_inventory_command(c,'inventory_document',i,jsonb_build_object('id',i,'status','draft'));perform set_config('market_pos.inventory_command','off',true);return i;end$$;
create or replace function public.v2_upsert_inventory_line(i uuid,doc uuid,ln integer,p uuid,bt uuid,u uuid,q numeric,f numeric,delta numeric,cm text)returns uuid language plpgsql security definer set search_path='' as $$
declare d public.inventory_documents%rowtype;e public.inventory_document_lines%rowtype;x uuid;begin select * into d from public.inventory_documents where id=doc for update;if not found then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_NOT_FOUND';end if;if d.status<>'draft'or not public.v2_has_permission(d.organization_id,'inventory.adjust',d.branch_id)then raise exception using errcode='P0001',message='V2_INVENTORY_ADJUST_REQUIRED';end if;perform set_config('market_pos.inventory_command','on',true);
 if i is null then x:=gen_random_uuid();insert into public.inventory_document_lines(id,organization_id,inventory_document_id,line_number,product_id,batch_id,unit_id,quantity,unit_factor,base_quantity_delta,comment)values(x,d.organization_id,doc,ln,p,bt,u,q,f,delta,cm);
 else select * into e from public.inventory_document_lines where id=i for update;if not found then raise exception using errcode='P0001',message='V2_INVENTORY_LINE_NOT_FOUND';end if;if e.organization_id<>d.organization_id or e.inventory_document_id<>doc then raise exception using errcode='P0001',message='V2_INVENTORY_LINE_SCOPE_MISMATCH';end if;x:=e.id;update public.inventory_document_lines set line_number=ln,product_id=p,batch_id=bt,unit_id=u,quantity=q,unit_factor=f,base_quantity_delta=delta,comment=cm where id=e.id;end if;perform set_config('market_pos.inventory_command','off',true);return x;end$$;
create or replace function public.v2_post_inventory_adjustment(i uuid,op uuid,approval uuid default null,payload jsonb default '{}'::jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare d public.inventory_documents%rowtype;l public.inventory_document_lines%rowtype;a uuid;c uuid;needs boolean;begin select * into d from public.inventory_documents where id=i for update;if not found or d.document_type not in('opening','adjustment','write_off')then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_NOT_POSTABLE';end if;if not public.v2_has_permission(d.organization_id,'inventory.adjust',d.branch_id)then raise exception using errcode='P0001',message='V2_INVENTORY_ADJUST_REQUIRED';end if;a:=public.v2_current_membership_id(d.organization_id);
 select d.document_type='write_off' or exists(select 1 from public.inventory_document_lines where inventory_document_id=i and base_quantity_delta<0)into needs;if needs then c:=public.v2_use_approved_command(approval,d.organization_id,'inventory.adjust',op,payload||jsonb_build_object('document_id',i));else c:=public.v2_begin_inventory_command(d.organization_id,d.branch_id,d.device_id,op,'inventory.post',payload||jsonb_build_object('document_id',i));end if;if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_inventory_scopes(d.organization_id,(select coalesce(jsonb_agg(s order by s->>'warehouse_id',s->>'product_id',coalesce(s->>'batch_id','')),'[]')from(select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',x.product_id,'batch_id',x.batch_id)s from public.inventory_document_lines x where x.inventory_document_id=i union select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',x.product_id,'batch_id',null)from public.inventory_document_lines x where x.inventory_document_id=i)sq));perform set_config('market_pos.inventory_command','on',true);update public.inventory_documents set status='posted',posted_by=a,posted_at=clock_timestamp()where id=i;
 for l in select * from public.inventory_document_lines where inventory_document_id=i order by product_id,batch_id nulls first loop perform public.v2_apply_inventory_movement(d.organization_id,d.branch_id,d.warehouse_id,l.product_id,l.batch_id,d.document_type,l.base_quantity_delta,'inventory_document',i,l.id,'primary',null,c,a);end loop;
 perform public.v2_emit_domain_event(d.organization_id,d.branch_id,d.device_id,a,c,approval,'inventory_document',i,'inventory_document.posted','InventoryDocumentPosted',jsonb_build_object('document_id',i));perform public.v2_complete_inventory_command(c,'inventory_document',i,jsonb_build_object('id',i,'status','posted'));perform set_config('market_pos.inventory_command','off',true);return i;end$$;

create or replace function public.v2_create_warehouse_transfer(o uuid,b uuid,sw uuid,dw uuid,n text,bd date,d uuid,op uuid)returns uuid language plpgsql security definer set search_path='' as $$
declare i uuid:=gen_random_uuid();a uuid;c uuid;p jsonb:=jsonb_build_object('branch_id',b,'source_warehouse_id',sw,'destination_warehouse_id',dw,'document_number',n,'business_date',bd);begin if not public.v2_has_permission(o,'inventory.transfer',b) or not public.v2_can_access_warehouse(o,sw) or not public.v2_can_access_warehouse(o,dw)then raise exception using errcode='P0001',message='V2_TRANSFER_BOTH_WAREHOUSES_REQUIRED';end if;a:=public.v2_current_membership_id(o);c:=public.v2_begin_inventory_command(o,b,d,op,'inventory.transfer.create_draft',p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.inventory_command','on',true);insert into public.warehouse_transfers(id,organization_id,branch_id,source_warehouse_id,destination_warehouse_id,document_number,business_date,device_id,local_operation_id)values(i,o,b,sw,dw,n,bd,d,op);perform public.v2_emit_domain_event(o,b,d,a,c,null,'warehouse_transfer',i,'warehouse_transfer.draft_created','WarehouseTransferDraftCreated',p);perform public.v2_complete_inventory_command(c,'warehouse_transfer',i,jsonb_build_object('id',i,'status','draft'));perform set_config('market_pos.inventory_command','off',true);return i;end$$;
create or replace function public.v2_upsert_warehouse_transfer_line(i uuid,t uuid,ln integer,p uuid,bt uuid,u uuid,q numeric,f numeric)returns uuid language plpgsql security definer set search_path='' as $$
declare tr public.warehouse_transfers%rowtype;e public.warehouse_transfer_lines%rowtype;x uuid;begin select * into tr from public.warehouse_transfers where id=t for update;if not found then raise exception using errcode='P0001',message='V2_TRANSFER_NOT_FOUND';end if;if tr.status<>'draft'or not public.v2_has_permission(tr.organization_id,'inventory.transfer',tr.branch_id)or not public.v2_can_access_warehouse(tr.organization_id,tr.source_warehouse_id)or not public.v2_can_access_warehouse(tr.organization_id,tr.destination_warehouse_id)then raise exception using errcode='P0001',message='V2_TRANSFER_BOTH_WAREHOUSES_REQUIRED';end if;perform set_config('market_pos.inventory_command','on',true);
 if i is null then x:=gen_random_uuid();insert into public.warehouse_transfer_lines(id,organization_id,warehouse_transfer_id,line_number,product_id,batch_id,unit_id,quantity,unit_factor,base_quantity)values(x,tr.organization_id,t,ln,p,bt,u,q,f,q*f);
 else select * into e from public.warehouse_transfer_lines where id=i for update;if not found then raise exception using errcode='P0001',message='V2_TRANSFER_LINE_NOT_FOUND';end if;if e.organization_id<>tr.organization_id or e.warehouse_transfer_id<>t then raise exception using errcode='P0001',message='V2_TRANSFER_LINE_SCOPE_MISMATCH';end if;x:=e.id;update public.warehouse_transfer_lines set line_number=ln,product_id=p,batch_id=bt,unit_id=u,quantity=q,unit_factor=f,base_quantity=q*f where id=e.id;end if;perform set_config('market_pos.inventory_command','off',true);return x;end$$;
create or replace function public.v2_post_warehouse_transfer(i uuid,op uuid,payload jsonb default '{}'::jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare t public.warehouse_transfers%rowtype;l public.warehouse_transfer_lines%rowtype;a uuid;c uuid;begin select * into t from public.warehouse_transfers where id=i for update;if not found then raise exception using errcode='P0001',message='V2_TRANSFER_NOT_FOUND';end if;if not public.v2_has_permission(t.organization_id,'inventory.transfer',t.branch_id)or not public.v2_can_access_warehouse(t.organization_id,t.source_warehouse_id)or not public.v2_can_access_warehouse(t.organization_id,t.destination_warehouse_id)then raise exception using errcode='P0001',message='V2_TRANSFER_BOTH_WAREHOUSES_REQUIRED';end if;a:=public.v2_current_membership_id(t.organization_id);c:=public.v2_begin_inventory_command(t.organization_id,t.branch_id,t.device_id,op,'inventory.transfer.post',payload||jsonb_build_object('transfer_id',i));if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.inventory_command','on',true);
 perform public.v2_lock_inventory_scopes(t.organization_id,(select coalesce(jsonb_agg(s order by s->>'warehouse_id',s->>'product_id',coalesce(s->>'batch_id','')),'[]')from(select jsonb_build_object('warehouse_id',t.source_warehouse_id,'product_id',x.product_id,'batch_id',x.batch_id)s from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i union select jsonb_build_object('warehouse_id',t.source_warehouse_id,'product_id',x.product_id,'batch_id',null)from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i union select jsonb_build_object('warehouse_id',t.destination_warehouse_id,'product_id',x.product_id,'batch_id',null)from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i)sq));for l in select * from public.warehouse_transfer_lines where warehouse_transfer_id=i order by product_id,batch_id nulls first loop perform public.v2_apply_inventory_movement(t.organization_id,t.branch_id,t.source_warehouse_id,l.product_id,l.batch_id,'transfer',-l.base_quantity,'warehouse_transfer',i,l.id,'out',null,c,a);perform public.v2_apply_inventory_movement(t.organization_id,t.branch_id,t.destination_warehouse_id,l.product_id,null,'transfer',l.base_quantity,'warehouse_transfer',i,l.id,'in',null,c,a);end loop;
 update public.warehouse_transfers set status='posted',posted_by=a,posted_at=clock_timestamp()where id=i;perform public.v2_emit_domain_event(t.organization_id,t.branch_id,t.device_id,a,c,null,'warehouse_transfer',i,'warehouse_transfer.posted','WarehouseTransferPosted',jsonb_build_object('transfer_id',i));perform public.v2_complete_inventory_command(c,'warehouse_transfer',i,jsonb_build_object('id',i,'status','posted'));perform set_config('market_pos.inventory_command','off',true);return i;end$$;

create or replace function public.v2_reverse_purchase(i uuid,n text,op uuid,approval uuid,payload jsonb default '{}'::jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare d public.purchase_documents%rowtype;r uuid:=gen_random_uuid();a uuid;c uuid;l public.purchase_lines%rowtype;pc public.purchase_additional_costs%rowtype;al public.purchase_cost_allocations%rowtype;nl uuid;rc uuid;target_line uuid;bt public.product_batches_v2%rowtype;om public.inventory_movements%rowtype;begin select * into d from public.purchase_documents where id=i and status='posted' for update;if not found then raise exception using errcode='P0001',message='V2_PURCHASE_NOT_REVERSIBLE';end if;if not public.v2_has_permission(d.organization_id,'purchases.reverse',d.branch_id)then raise exception using errcode='P0001',message='V2_PURCHASE_REVERSE_REQUIRED';end if;if exists(select 1 from public.purchase_documents where reversal_of_id=i)then raise exception using errcode='P0001',message='V2_PURCHASE_ALREADY_REVERSED';end if;
 if exists(select 1 from public.product_batches_v2 b join public.inventory_movements m on m.batch_id=b.id where b.purchase_line_id in(select id from public.purchase_lines where purchase_document_id=i)and not(m.source_document_type='purchase'and m.source_document_id=i)and m.reversal_of_id is null)then raise exception using errcode='P0001',message='V2_PURCHASE_REVERSAL_BATCH_CONSUMED';end if;
 a:=public.v2_current_membership_id(d.organization_id);c:=public.v2_use_approved_command(approval,d.organization_id,'purchases.reverse',op,payload||jsonb_build_object('purchase_id',i));if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.purchase_command','on',true);perform set_config('market_pos.inventory_command','on',true);
 insert into public.purchase_documents(id,organization_id,branch_id,warehouse_id,counterparty_id,document_number,business_date,currency_code,device_id,local_operation_id,reversal_of_id)values(r,d.organization_id,d.branch_id,d.warehouse_id,d.counterparty_id,n,current_date,d.currency_code,d.device_id,op,i);
 for l in select * from public.purchase_lines where purchase_document_id=i order by line_number loop nl:=gen_random_uuid();insert into public.purchase_lines(id,organization_id,purchase_document_id,line_number,product_id,unit_id,quantity,unit_factor,base_quantity,unit_purchase_price,line_amount,expiration_date,supplier_batch_number)values(nl,l.organization_id,r,l.line_number,l.product_id,l.unit_id,l.quantity,l.unit_factor,l.base_quantity,l.unit_purchase_price,l.line_amount,l.expiration_date,l.supplier_batch_number);end loop;
 for pc in select * from public.purchase_additional_costs where purchase_document_id=i order by id loop rc:=gen_random_uuid();insert into public.purchase_additional_costs(id,organization_id,purchase_document_id,cost_type,amount,currency_code,allocation_method)values(rc,pc.organization_id,r,pc.cost_type,pc.amount,pc.currency_code,pc.allocation_method);for al in select * from public.purchase_cost_allocations where purchase_additional_cost_id=pc.id order by id loop select rl.id into target_line from public.purchase_lines ol join public.purchase_lines rl on rl.purchase_document_id=r and rl.line_number=ol.line_number where ol.id=al.purchase_line_id;insert into public.purchase_cost_allocations(organization_id,purchase_additional_cost_id,purchase_line_id,allocated_amount)values(al.organization_id,rc,target_line,al.allocated_amount);end loop;end loop;
 update public.purchase_documents set subtotal_amount=d.subtotal_amount,additional_cost_amount=d.additional_cost_amount,total_amount=d.total_amount,status='posted',posted_at=clock_timestamp(),posted_by=a where id=r;
 perform public.v2_lock_inventory_scopes(d.organization_id,(select coalesce(jsonb_agg(s order by s->>'warehouse_id',s->>'product_id',coalesce(s->>'batch_id','')),'[]')from(select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',pl.product_id,'batch_id',pb.id)s from public.purchase_lines pl join public.product_batches_v2 pb on pb.purchase_line_id=pl.id where pl.purchase_document_id=i union select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',pl.product_id,'batch_id',null)from public.purchase_lines pl where pl.purchase_document_id=i)sq));for l in select * from public.purchase_lines where purchase_document_id=i order by line_number loop select id into nl from public.purchase_lines where purchase_document_id=r and line_number=l.line_number;select * into bt from public.product_batches_v2 where purchase_line_id=l.id;select * into om from public.inventory_movements where source_document_type='purchase'and source_line_id=l.id and movement_role='primary';perform public.v2_apply_inventory_movement(d.organization_id,d.branch_id,d.warehouse_id,l.product_id,bt.id,'purchase_reversal',-l.base_quantity,'purchase',r,nl,'reversal',om.id,c,a);update public.product_batches_v2 set status='reversed'where id=bt.id;end loop;
 update public.purchase_documents set status='reversed'where id=i;perform public.v2_emit_domain_event(d.organization_id,d.branch_id,d.device_id,a,c,approval,'purchase',r,'purchase.reversed','PurchaseReversed',jsonb_build_object('original_id',i,'reversal_id',r));perform public.v2_complete_inventory_command(c,'purchase',r,jsonb_build_object('id',r,'status','posted','reversal_of',i));perform set_config('market_pos.purchase_command','off',true);perform set_config('market_pos.inventory_command','off',true);return r;end$$;

create or replace function public.v2_reverse_warehouse_transfer(i uuid,n text,op uuid,payload jsonb default '{}'::jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare t public.warehouse_transfers%rowtype;r uuid:=gen_random_uuid();a uuid;c uuid;l public.warehouse_transfer_lines%rowtype;nl uuid;oo public.inventory_movements%rowtype;ii public.inventory_movements%rowtype;begin select * into t from public.warehouse_transfers where id=i and status='posted'for update;if not found then raise exception using errcode='P0001',message='V2_TRANSFER_NOT_REVERSIBLE';end if;if exists(select 1 from public.warehouse_transfers where reversal_of_id=i)then raise exception using errcode='P0001',message='V2_TRANSFER_ALREADY_REVERSED';end if;if not public.v2_has_permission(t.organization_id,'inventory.transfer',t.branch_id)or not public.v2_can_access_warehouse(t.organization_id,t.source_warehouse_id)or not public.v2_can_access_warehouse(t.organization_id,t.destination_warehouse_id)then raise exception using errcode='P0001',message='V2_TRANSFER_BOTH_WAREHOUSES_REQUIRED';end if;a:=public.v2_current_membership_id(t.organization_id);c:=public.v2_begin_inventory_command(t.organization_id,t.branch_id,t.device_id,op,'inventory.transfer.reverse',payload||jsonb_build_object('transfer_id',i));if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.inventory_command','on',true);
 insert into public.warehouse_transfers(id,organization_id,branch_id,source_warehouse_id,destination_warehouse_id,document_number,business_date,device_id,local_operation_id,reversal_of_id)values(r,t.organization_id,t.branch_id,t.destination_warehouse_id,t.source_warehouse_id,n,current_date,t.device_id,op,i);
 for l in select * from public.warehouse_transfer_lines where warehouse_transfer_id=i order by line_number loop nl:=gen_random_uuid();insert into public.warehouse_transfer_lines(id,organization_id,warehouse_transfer_id,line_number,product_id,batch_id,unit_id,quantity,unit_factor,base_quantity)values(nl,l.organization_id,r,l.line_number,l.product_id,null,l.unit_id,l.quantity,l.unit_factor,l.base_quantity);end loop;update public.warehouse_transfers set status='posted',posted_by=a,posted_at=clock_timestamp()where id=r;
 perform public.v2_lock_inventory_scopes(t.organization_id,(select coalesce(jsonb_agg(s order by s->>'warehouse_id',s->>'product_id',coalesce(s->>'batch_id','')),'[]')from(select jsonb_build_object('warehouse_id',t.source_warehouse_id,'product_id',x.product_id,'batch_id',x.batch_id)s from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i union select jsonb_build_object('warehouse_id',t.source_warehouse_id,'product_id',x.product_id,'batch_id',null)from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i union select jsonb_build_object('warehouse_id',t.destination_warehouse_id,'product_id',x.product_id,'batch_id',null)from public.warehouse_transfer_lines x where x.warehouse_transfer_id=i)sq));for l in select * from public.warehouse_transfer_lines where warehouse_transfer_id=i order by line_number loop select id into nl from public.warehouse_transfer_lines where warehouse_transfer_id=r and line_number=l.line_number;select * into oo from public.inventory_movements where source_document_type='warehouse_transfer'and source_document_id=i and source_line_id=l.id and movement_role='out';select * into ii from public.inventory_movements where source_document_type='warehouse_transfer'and source_document_id=i and source_line_id=l.id and movement_role='in';perform public.v2_apply_inventory_movement(t.organization_id,t.branch_id,t.source_warehouse_id,l.product_id,l.batch_id,'transfer_reversal',l.base_quantity,'warehouse_transfer',r,nl,'reversal',oo.id,c,a);perform public.v2_apply_inventory_movement(t.organization_id,t.branch_id,t.destination_warehouse_id,l.product_id,null,'transfer_reversal',-l.base_quantity,'warehouse_transfer',r,nl,'primary',ii.id,c,a);end loop;
 update public.warehouse_transfers set status='reversed'where id=i;perform public.v2_emit_domain_event(t.organization_id,t.branch_id,t.device_id,a,c,null,'warehouse_transfer',r,'warehouse_transfer.reversed','WarehouseTransferReversed',jsonb_build_object('original_id',i,'reversal_id',r));perform public.v2_complete_inventory_command(c,'warehouse_transfer',r,jsonb_build_object('id',r,'status','posted'));perform set_config('market_pos.inventory_command','off',true);return r;end$$;

create or replace function public.v2_reverse_inventory_document(i uuid,n text,op uuid,approval uuid,payload jsonb default '{}'::jsonb)returns uuid language plpgsql security definer set search_path='' as $$
declare d public.inventory_documents%rowtype;r uuid:=gen_random_uuid();a uuid;c uuid;l public.inventory_document_lines%rowtype;nl uuid;om public.inventory_movements%rowtype;begin select * into d from public.inventory_documents where id=i and status='posted'for update;if not found then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_NOT_REVERSIBLE';end if;if exists(select 1 from public.inventory_documents where reversal_of_id=i)then raise exception using errcode='P0001',message='V2_INVENTORY_DOCUMENT_ALREADY_REVERSED';end if;if not public.v2_has_permission(d.organization_id,'inventory.adjust',d.branch_id)then raise exception using errcode='P0001',message='V2_INVENTORY_ADJUST_REQUIRED';end if;a:=public.v2_current_membership_id(d.organization_id);c:=public.v2_use_approved_command(approval,d.organization_id,'inventory.adjust',op,payload||jsonb_build_object('document_id',i));if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;perform set_config('market_pos.inventory_command','on',true);
 insert into public.inventory_documents(id,organization_id,branch_id,warehouse_id,document_type,document_number,business_date,reason_code,device_id,local_operation_id,reversal_of_id)values(r,d.organization_id,d.branch_id,d.warehouse_id,'reversal',n,current_date,'reversal',d.device_id,op,i);
 for l in select * from public.inventory_document_lines where inventory_document_id=i order by line_number loop nl:=gen_random_uuid();insert into public.inventory_document_lines(id,organization_id,inventory_document_id,line_number,product_id,batch_id,unit_id,quantity,unit_factor,base_quantity_delta,comment)values(nl,l.organization_id,r,l.line_number,l.product_id,l.batch_id,l.unit_id,l.quantity,l.unit_factor,-l.base_quantity_delta,'reversal');end loop;update public.inventory_documents set status='posted',posted_by=a,posted_at=clock_timestamp()where id=r;
 perform public.v2_lock_inventory_scopes(d.organization_id,(select coalesce(jsonb_agg(s order by s->>'warehouse_id',s->>'product_id',coalesce(s->>'batch_id','')),'[]')from(select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',x.product_id,'batch_id',x.batch_id)s from public.inventory_document_lines x where x.inventory_document_id=i union select jsonb_build_object('warehouse_id',d.warehouse_id,'product_id',x.product_id,'batch_id',null)from public.inventory_document_lines x where x.inventory_document_id=i)sq));for l in select * from public.inventory_document_lines where inventory_document_id=i order by line_number loop select id into nl from public.inventory_document_lines where inventory_document_id=r and line_number=l.line_number;select * into om from public.inventory_movements where source_document_type='inventory_document'and source_line_id=l.id and movement_role='primary';perform public.v2_apply_inventory_movement(d.organization_id,d.branch_id,d.warehouse_id,l.product_id,l.batch_id,'inventory_reversal',-l.base_quantity_delta,'inventory_document',r,nl,'reversal',om.id,c,a);end loop;
 update public.inventory_documents set status='reversed'where id=i;perform public.v2_emit_domain_event(d.organization_id,d.branch_id,d.device_id,a,c,approval,'inventory_document',r,'inventory_document.reversed','InventoryDocumentReversed',jsonb_build_object('original_id',i,'reversal_id',r));perform public.v2_complete_inventory_command(c,'inventory_document',r,jsonb_build_object('id',r,'status','posted'));perform set_config('market_pos.inventory_command','off',true);return r;end$$;

-- Function privileges ---------------------------------------------------------
revoke execute on function public.v2_begin_inventory_command(uuid,uuid,uuid,uuid,text,jsonb),public.v2_complete_inventory_command(uuid,text,uuid,jsonb),public.v2_require_domain_approval(uuid,uuid,uuid,text),public.v2_use_approved_command(uuid,uuid,text,uuid,jsonb),public.v2_emit_domain_event(uuid,uuid,uuid,uuid,uuid,uuid,text,uuid,text,text,jsonb),public.v2_lock_inventory_scopes(uuid,jsonb),public.v2_apply_inventory_movement(uuid,uuid,uuid,uuid,uuid,text,numeric,text,uuid,uuid,text,uuid,uuid,uuid) from public,anon,authenticated;
revoke execute on function public.v2_purchase_context_required(),public.v2_inventory_context_required(),public.v2_guard_purchase_document(),public.v2_guard_purchase_child(),public.v2_guard_product_batch_v2(),public.v2_guard_daily_template(),public.v2_guard_inventory_document(),public.v2_guard_inventory_line(),public.v2_guard_warehouse_transfer(),public.v2_guard_transfer_line(),public.v2_guard_inventory_movement(),public.v2_guard_inventory_balance(),public.v2_prevent_posted_delete() from public,anon,authenticated;
revoke execute on function public.v2_create_purchase_draft(uuid,uuid,uuid,uuid,text,date,character,uuid,uuid),public.v2_upsert_purchase_line(uuid,uuid,integer,uuid,uuid,numeric,numeric,numeric,date,text),public.v2_upsert_purchase_cost(uuid,uuid,text,numeric,character,text),public.v2_cancel_purchase_draft(uuid),public.v2_upsert_daily_delivery_template(uuid,uuid,uuid,uuid,text,jsonb,boolean),public.v2_post_purchase(uuid,uuid,jsonb),public.v2_post_daily_delivery(uuid,text,date,character,jsonb,uuid),public.v2_create_inventory_document(uuid,uuid,uuid,text,text,date,text,uuid,uuid),public.v2_upsert_inventory_line(uuid,uuid,integer,uuid,uuid,uuid,numeric,numeric,numeric,text),public.v2_post_inventory_adjustment(uuid,uuid,uuid,jsonb),public.v2_create_warehouse_transfer(uuid,uuid,uuid,uuid,text,date,uuid,uuid),public.v2_upsert_warehouse_transfer_line(uuid,uuid,integer,uuid,uuid,uuid,numeric,numeric),public.v2_post_warehouse_transfer(uuid,uuid,jsonb),public.v2_reverse_purchase(uuid,text,uuid,uuid,jsonb),public.v2_reverse_warehouse_transfer(uuid,text,uuid,jsonb),public.v2_reverse_inventory_document(uuid,text,uuid,uuid,jsonb) from public,anon;
grant execute on function public.v2_create_purchase_draft(uuid,uuid,uuid,uuid,text,date,character,uuid,uuid),public.v2_upsert_purchase_line(uuid,uuid,integer,uuid,uuid,numeric,numeric,numeric,date,text),public.v2_upsert_purchase_cost(uuid,uuid,text,numeric,character,text),public.v2_cancel_purchase_draft(uuid),public.v2_upsert_daily_delivery_template(uuid,uuid,uuid,uuid,text,jsonb,boolean),public.v2_post_purchase(uuid,uuid,jsonb),public.v2_post_daily_delivery(uuid,text,date,character,jsonb,uuid),public.v2_create_inventory_document(uuid,uuid,uuid,text,text,date,text,uuid,uuid),public.v2_upsert_inventory_line(uuid,uuid,integer,uuid,uuid,uuid,numeric,numeric,numeric,text),public.v2_post_inventory_adjustment(uuid,uuid,uuid,jsonb),public.v2_create_warehouse_transfer(uuid,uuid,uuid,uuid,text,date,uuid,uuid),public.v2_upsert_warehouse_transfer_line(uuid,uuid,integer,uuid,uuid,uuid,numeric,numeric),public.v2_post_warehouse_transfer(uuid,uuid,jsonb),public.v2_reverse_purchase(uuid,text,uuid,uuid,jsonb),public.v2_reverse_warehouse_transfer(uuid,text,uuid,jsonb),public.v2_reverse_inventory_document(uuid,text,uuid,uuid,jsonb) to authenticated;
