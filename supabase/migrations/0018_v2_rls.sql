-- MARKET POS V2: FINAL ROW-LEVEL SECURITY MATRIX
-- Raw tables remain authoritative; narrow SECURITY DEFINER projections expose
-- only fields appropriate for browser workflows.

-- Every tenant-owned V2 relation created through 0017 uses standard RLS.
alter table public.command_log enable row level security;
alter table public.outbox_events enable row level security;
alter table public.audit_events enable row level security;
alter table public.migration_exceptions enable row level security;
alter table public.user_profiles enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.permissions enable row level security;
alter table public.permission_profiles enable row level security;
alter table public.permission_profile_permissions enable row level security;
alter table public.membership_permission_profiles enable row level security;
alter table public.branch_access enable row level security;
alter table public.approval_requests enable row level security;
alter table public.support_access_grants enable row level security;
alter table public.branches enable row level security;
alter table public.warehouses enable row level security;
alter table public.registers enable row level security;
alter table public.devices_v2 enable row level security;
alter table public.organization_settings enable row level security;
alter table public.categories_v2 enable row level security;
alter table public.brands_v2 enable row level security;
alter table public.units_v2 enable row level security;
alter table public.product_types_v2 enable row level security;
alter table public.products_v2 enable row level security;
alter table public.unit_conversions enable row level security;
alter table public.product_barcodes enable row level security;
alter table public.product_images enable row level security;
alter table public.price_lists enable row level security;
alter table public.price_change_requests enable row level security;
alter table public.product_prices enable row level security;
alter table public.price_history enable row level security;
alter table public.price_recommendations enable row level security;
alter table public.counterparties enable row level security;
alter table public.counterparty_roles enable row level security;
alter table public.counterparty_contacts enable row level security;
alter table public.counterparty_addresses enable row level security;
alter table public.counterparty_credit_settings enable row level security;
alter table public.purchase_documents enable row level security;
alter table public.purchase_lines enable row level security;
alter table public.purchase_additional_costs enable row level security;
alter table public.purchase_cost_allocations enable row level security;
alter table public.product_batches_v2 enable row level security;
alter table public.daily_delivery_templates enable row level security;
alter table public.daily_delivery_documents enable row level security;
alter table public.inventory_documents enable row level security;
alter table public.inventory_document_lines enable row level security;
alter table public.warehouse_transfers enable row level security;
alter table public.warehouse_transfer_lines enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.inventory_balances enable row level security;
alter table public.shifts_v2 enable row level security;
alter table public.shift_totals enable row level security;
alter table public.sales_v2 enable row level security;
alter table public.sale_lines_v2 enable row level security;
alter table public.sale_line_batch_allocations enable row level security;
alter table public.held_sales enable row level security;
alter table public.payments_v2 enable row level security;
alter table public.sale_returns enable row level security;
alter table public.sale_return_lines enable row level security;
alter table public.fiscal_documents enable row level security;
alter table public.fiscal_attempts enable row level security;
alter table public.receivables enable row level security;
alter table public.debt_payments_v2 enable row level security;
alter table public.debt_allocations enable row level security;
alter table public.settlement_entries enable row level security;
alter table public.settlement_periods enable row level security;
alter table public.settlement_acts enable row level security;
alter table public.settlement_act_lines enable row level security;
alter table public.cash_movements enable row level security;
alter table public.shift_cash_counts enable row level security;
alter table public.supplier_payments enable row level security;
alter table public.sync_commands enable row level security;
alter table public.sync_cursor_state enable row level security;

-- Devices: raw rows contain fingerprint, legacy mapping and cursor state.
drop policy if exists devices_v2_select_authorized on public.devices_v2;
create policy devices_v2_select_authorized
on public.devices_v2 for select to authenticated
using (
  public.v2_has_permission(organization_id, 'devices.manage', branch_id)
  or public.v2_has_support_grant(organization_id, 'devices.manage')
);

create or replace function public.v2_device_directory(
  organization_id uuid,
  branch_id uuid default null
)
returns table(
  id uuid,
  branch_id uuid,
  register_id uuid,
  name text,
  device_type text,
  status text,
  last_seen_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with access as (
    select m.id as membership_id, m.system_role
    from public.organization_memberships m
    join public.user_profiles p on p.id = m.user_profile_id
    where m.organization_id = v2_device_directory.organization_id
      and m.status = 'active'
      and p.status = 'active'
      and p.auth_user_id = auth.uid()
      and m.system_role <> 'service_admin'
  )
  select d.id, d.branch_id, d.register_id, d.name, d.device_type,
         d.status, d.last_seen_at
  from public.devices_v2 d
  where d.organization_id = v2_device_directory.organization_id
    and (v2_device_directory.branch_id is null
         or d.branch_id = v2_device_directory.branch_id)
    and (
      exists (select 1 from access a where a.system_role = 'owner')
      or exists (
        select 1 from access a
        join public.branch_access ba
          on ba.membership_id = a.membership_id
         and ba.organization_id = d.organization_id
         and ba.branch_id = d.branch_id
      )
      or public.v2_has_support_grant(d.organization_id, 'devices.manage')
    )
  order by d.name, d.id
$$;

-- Members: user_profiles remains self-only; managers use a safe projection.
create or replace function public.v2_member_directory(organization_id uuid)
returns table(
  membership_id uuid,
  user_profile_id uuid,
  full_name text,
  email_snapshot text,
  system_role text,
  membership_status text,
  profile_status text,
  preferred_locale text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (
    public.v2_has_permission(organization_id, 'users.manage', null)
    or public.v2_has_support_grant(organization_id, 'users.manage')
  ) then
    raise exception using errcode = 'P0001',
      message = 'V2_USERS_MANAGE_REQUIRED';
  end if;

  return query
  select m.id, p.id, p.full_name, p.email_snapshot, m.system_role,
         m.status, p.status, p.preferred_locale
  from public.organization_memberships m
  join public.user_profiles p on p.id = m.user_profile_id
  where m.organization_id = v2_member_directory.organization_id
  order by p.full_name, m.id;
end
$$;

-- Counterparties: customer.view is projection-only, never raw-party access.
create or replace function public.v2_can_view_counterparty(
  p_organization_id uuid,
  p_counterparty_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.counterparties c
    where c.id = p_counterparty_id
      and c.organization_id = p_organization_id
  ) and (
    public.v2_has_permission(p_organization_id, 'counterparties.view', null)
    or public.v2_has_permission(p_organization_id, 'counterparties.manage', null)
    or public.v2_has_support_grant(p_organization_id, 'counterparties.view')
  )
$$;

drop policy if exists counterparty_roles_select on public.counterparty_roles;
create policy counterparty_roles_select
on public.counterparty_roles for select to authenticated
using (public.v2_can_view_counterparty(organization_id, counterparty_id));

create or replace function public.v2_customer_directory(
  organization_id uuid,
  query text default null,
  requested_limit integer default 50
)
returns table(
  id uuid,
  display_name text,
  status text,
  primary_phone text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if requested_limit not between 1 and 100 then
    raise exception using errcode = 'P0001',
      message = 'V2_CUSTOMER_DIRECTORY_LIMIT_INVALID';
  end if;
  if not (
    public.v2_has_permission(organization_id, 'counterparties.customer.view', null)
    or public.v2_has_permission(organization_id, 'counterparties.view', null)
    or public.v2_has_permission(organization_id, 'counterparties.manage', null)
    or public.v2_has_support_grant(organization_id, 'counterparties.view')
  ) then
    raise exception using errcode = 'P0001',
      message = 'V2_CUSTOMER_DIRECTORY_REQUIRED';
  end if;

  return query
  select c.id, c.display_name, c.status,
         (select cc.value
          from public.counterparty_contacts cc
          where cc.counterparty_id = c.id
            and cc.organization_id = c.organization_id
            and cc.contact_type = 'phone'
            and cc.is_primary
            and cc.archived_at is null
          order by cc.created_at, cc.id
          limit 1) as primary_phone
  from public.counterparties c
  where c.organization_id = v2_customer_directory.organization_id
    and c.status = 'active'
    and exists (
      select 1 from public.counterparty_roles r
      where r.counterparty_id = c.id
        and r.organization_id = c.organization_id
        and r.role_code = 'customer'
        and r.ended_at is null
    )
    and (
      nullif(btrim(v2_customer_directory.query), '') is null
      or c.display_name ilike '%' || v2_customer_directory.query || '%'
      or exists (
        select 1 from public.counterparty_contacts cc
        where cc.counterparty_id = c.id
          and cc.organization_id = c.organization_id
          and cc.contact_type = 'phone'
          and cc.is_primary
          and cc.archived_at is null
          and cc.value ilike '%' || v2_customer_directory.query || '%'
      )
    )
  order by c.display_name, c.id
  limit requested_limit;
end
$$;

-- Pricing: pricing.view is current-only; manage/confirm grants full history.
create or replace function public.v2_can_view_pricing_history(
  organization_id uuid,
  branch_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v2_has_permission(organization_id, 'pricing.manage', branch_id)
      or public.v2_has_permission(organization_id, 'pricing.confirm', branch_id)
      or public.v2_has_support_grant(organization_id, 'pricing.manage')
      or public.v2_has_support_grant(organization_id, 'pricing.confirm')
$$;

drop policy if exists price_lists_select on public.price_lists;
create policy price_lists_select
on public.price_lists for select to authenticated
using (
  public.v2_can_view_pricing_history(organization_id, branch_id)
  or (
    status = 'active'
    and archived_at is null
    and (
      public.v2_has_permission(organization_id, 'pricing.view', branch_id)
      or public.v2_has_support_grant(organization_id, 'pricing.view')
    )
  )
);

drop policy if exists product_prices_select on public.product_prices;
create policy product_prices_select
on public.product_prices for select to authenticated
using (
  exists (
    select 1 from public.price_lists pl
    where pl.id = product_prices.price_list_id
      and pl.organization_id = product_prices.organization_id
      and (
        public.v2_can_view_pricing_history(product_prices.organization_id, pl.branch_id)
        or (
          pl.status = 'active'
          and pl.archived_at is null
          and product_prices.valid_from <= now()
          and (product_prices.valid_to is null or product_prices.valid_to > now())
          and (
            public.v2_has_permission(product_prices.organization_id, 'pricing.view', pl.branch_id)
            or public.v2_has_support_grant(product_prices.organization_id, 'pricing.view')
          )
        )
      )
  )
);

drop policy if exists price_change_requests_select on public.price_change_requests;
create policy price_change_requests_select
on public.price_change_requests for select to authenticated
using (
  exists (
    select 1 from public.price_lists pl
    where pl.id = price_change_requests.price_list_id
      and pl.organization_id = price_change_requests.organization_id
      and public.v2_can_view_pricing_history(price_change_requests.organization_id, pl.branch_id)
  )
);

drop policy if exists price_history_select on public.price_history;
create policy price_history_select
on public.price_history for select to authenticated
using (
  exists (
    select 1 from public.price_lists pl
    where pl.id = price_history.price_list_id
      and pl.organization_id = price_history.organization_id
      and public.v2_can_view_pricing_history(price_history.organization_id, pl.branch_id)
  )
);

drop policy if exists price_recommendations_select on public.price_recommendations;
create policy price_recommendations_select
on public.price_recommendations for select to authenticated
using (
  exists (
    select 1
    from public.price_change_requests pr
    join public.price_lists pl on pl.id = pr.price_list_id
    where pr.id = price_recommendations.price_change_request_id
      and pr.organization_id = price_recommendations.organization_id
      and public.v2_can_view_pricing_history(price_recommendations.organization_id, pl.branch_id)
  )
);

-- Inventory: inventory.view grants the balance projection only.
drop policy if exists inventory_documents_select on public.inventory_documents;
create policy inventory_documents_select
on public.inventory_documents for select to authenticated
using (
  public.v2_has_permission(organization_id, 'inventory.adjust', branch_id)
  or public.v2_has_support_grant(organization_id, 'inventory.adjust')
);

drop policy if exists inventory_lines_select on public.inventory_document_lines;
create policy inventory_lines_select
on public.inventory_document_lines for select to authenticated
using (
  exists (
    select 1 from public.inventory_documents d
    where d.id = inventory_document_lines.inventory_document_id
      and d.organization_id = inventory_document_lines.organization_id
      and (
        public.v2_has_permission(d.organization_id, 'inventory.adjust', d.branch_id)
        or public.v2_has_support_grant(d.organization_id, 'inventory.adjust')
      )
  )
);

drop policy if exists transfers_select on public.warehouse_transfers;
create policy transfers_select
on public.warehouse_transfers for select to authenticated
using (
  public.v2_has_permission(organization_id, 'inventory.transfer', branch_id)
  or public.v2_has_support_grant(organization_id, 'inventory.transfer')
);

drop policy if exists transfer_lines_select on public.warehouse_transfer_lines;
create policy transfer_lines_select
on public.warehouse_transfer_lines for select to authenticated
using (
  exists (
    select 1 from public.warehouse_transfers t
    where t.id = warehouse_transfer_lines.warehouse_transfer_id
      and t.organization_id = warehouse_transfer_lines.organization_id
      and (
        public.v2_has_permission(t.organization_id, 'inventory.transfer', t.branch_id)
        or public.v2_has_support_grant(t.organization_id, 'inventory.transfer')
      )
  )
);

drop policy if exists inventory_movements_select on public.inventory_movements;
create policy inventory_movements_select
on public.inventory_movements for select to authenticated
using (
  public.v2_has_permission(organization_id, 'inventory.adjust', branch_id)
  or public.v2_has_permission(organization_id, 'inventory.transfer', branch_id)
  or public.v2_has_support_grant(organization_id, 'inventory.view')
);

-- Sync and audit: cursor state has no browser surface; journals are projections.
revoke all privileges on table public.sync_cursor_state
  from public, anon, authenticated;

create or replace function public.v2_sync_command_journal(
  p_organization_id uuid,
  p_device_id uuid default null
)
returns table(
  id uuid,
  device_id uuid,
  local_operation_id uuid,
  command_type text,
  status text,
  command_id uuid,
  result jsonb,
  error_code text,
  received_at timestamptz,
  processed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  owner_access boolean := false;
  support_access boolean := false;
begin
  actor_id := public.v2_current_membership_id(p_organization_id);
  support_access := public.v2_has_support_grant(
    p_organization_id, 'devices.manage'
  );

  if actor_id is not null then
    select m.system_role = 'owner'
    into owner_access
    from public.organization_memberships m
    where m.id = actor_id;
  end if;

  if actor_id is null and not support_access then
    raise exception using errcode = 'P0001',
      message = 'V2_SYNC_ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  return query
  select s.id, s.device_id, s.local_operation_id, s.command_type,
         s.status, s.command_id, s.result, s.error_code,
         s.received_at, s.processed_at
  from public.sync_commands s
  where s.organization_id = p_organization_id
    and (owner_access or support_access or s.actor_membership_id = actor_id)
    and (p_device_id is null or s.device_id = p_device_id)
  order by s.received_at desc, s.id;
end
$$;

create or replace function public.v2_my_activity_journal(
  organization_id uuid,
  requested_limit integer default 100
)
returns table(
  id uuid,
  created_at timestamptz,
  action text,
  entity_type text,
  entity_id uuid,
  correlation_id uuid,
  branch_id uuid
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  actor_role text;
begin
  if requested_limit not between 1 and 500 then
    raise exception using errcode = 'P0001',
      message = 'V2_ACTIVITY_JOURNAL_ARGUMENT_INVALID';
  end if;

  actor_id := public.v2_current_membership_id(organization_id);
  select m.system_role into actor_role
  from public.organization_memberships m
  where m.id = actor_id;

  if actor_id is null or actor_role = 'service_admin' then
    raise exception using errcode = 'P0001',
      message = 'V2_ACTIVITY_ACTIVE_MEMBERSHIP_REQUIRED';
  end if;

  return query
  select a.id, a.created_at, a.action, a.entity_type, a.entity_id,
         a.correlation_id, a.branch_id
  from public.audit_events a
  where a.organization_id = v2_my_activity_journal.organization_id
    and a.actor_membership_id = actor_id
  order by a.created_at desc, a.id desc
  limit requested_limit;
end
$$;

-- Browser writes to command-owned and append-only relations remain closed.
revoke insert, update, delete on table
  public.command_log,
  public.outbox_events,
  public.audit_events,
  public.sync_commands,
  public.sync_cursor_state,
  public.purchase_documents,
  public.purchase_lines,
  public.inventory_movements,
  public.inventory_balances,
  public.product_batches_v2,
  public.sales_v2,
  public.sale_lines_v2,
  public.sale_returns,
  public.sale_return_lines,
  public.payments_v2,
  public.receivables,
  public.debt_payments_v2,
  public.debt_allocations,
  public.settlement_entries,
  public.settlement_periods,
  public.settlement_acts,
  public.settlement_act_lines,
  public.cash_movements,
  public.shift_cash_counts,
  public.supplier_payments
from authenticated;

revoke execute on function
  public.v2_device_directory(uuid, uuid),
  public.v2_member_directory(uuid),
  public.v2_customer_directory(uuid, text, integer),
  public.v2_can_view_pricing_history(uuid, uuid),
  public.v2_my_activity_journal(uuid, integer)
from public, anon;

grant execute on function
  public.v2_device_directory(uuid, uuid),
  public.v2_member_directory(uuid),
  public.v2_customer_directory(uuid, text, integer),
  public.v2_can_view_pricing_history(uuid, uuid),
  public.v2_my_activity_journal(uuid, integer)
to authenticated;

comment on function public.v2_device_directory(uuid, uuid) is
  'Safe device projection; omits fingerprint, legacy mapping and sync cursor.';
comment on function public.v2_customer_directory(uuid, text, integer) is
  'Safe active-customer projection; raw legal, tax, notes and contacts stay private.';
comment on function public.v2_my_activity_journal(uuid, integer) is
  'Safe current-member audit projection without before/after data or metadata.';
