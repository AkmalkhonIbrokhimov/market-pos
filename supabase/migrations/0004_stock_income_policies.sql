-- =========================================================
-- SPRINT 4A: STOCK INCOME POLICIES
-- =========================================================

alter table public.suppliers enable row level security;
alter table public.product_batches enable row level security;
alter table public.stock_movements enable row level security;

drop policy if exists suppliers_select_organization on public.suppliers;
create policy suppliers_select_organization
  on public.suppliers
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = suppliers.organization_id
        and profile.status = 'active'
    )
  );

drop policy if exists suppliers_insert_management on public.suppliers;
create policy suppliers_insert_management
  on public.suppliers
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = suppliers.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  );

drop policy if exists suppliers_update_management on public.suppliers;
create policy suppliers_update_management
  on public.suppliers
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = suppliers.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  )
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = suppliers.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  );

drop policy if exists product_batches_select_store_access on public.product_batches;
create policy product_batches_select_store_access
  on public.product_batches
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_store_access as store_access
      join public.users as profile on profile.id = store_access.user_id
      where store_access.store_id = product_batches.store_id
        and profile.auth_user_id = (select auth.uid())
        and profile.status = 'active'
    )
  );

drop policy if exists product_batches_insert_management on public.product_batches;
create policy product_batches_insert_management
  on public.product_batches
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.user_store_access as store_access
      join public.users as profile on profile.id = store_access.user_id
      where store_access.store_id = product_batches.store_id
        and profile.auth_user_id = (select auth.uid())
        and profile.id = product_batches.created_by
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
    and exists (
      select 1
      from public.stores as store
      join public.products as product on product.id = product_batches.product_id
      where store.id = product_batches.store_id
        and product.organization_id = store.organization_id
    )
    and (
      product_batches.supplier_id is null
      or exists (
        select 1
        from public.stores as store
        join public.suppliers as supplier on supplier.id = product_batches.supplier_id
        where store.id = product_batches.store_id
          and supplier.organization_id = store.organization_id
      )
    )
  );

drop policy if exists stock_movements_select_store_access on public.stock_movements;
create policy stock_movements_select_store_access
  on public.stock_movements
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_store_access as store_access
      join public.users as profile on profile.id = store_access.user_id
      where store_access.store_id = stock_movements.store_id
        and profile.auth_user_id = (select auth.uid())
        and profile.status = 'active'
    )
  );

drop policy if exists stock_movements_insert_management on public.stock_movements;
create policy stock_movements_insert_management
  on public.stock_movements
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.user_store_access as store_access
      join public.users as profile on profile.id = store_access.user_id
      where store_access.store_id = stock_movements.store_id
        and profile.auth_user_id = (select auth.uid())
        and profile.id = stock_movements.created_by
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
    and exists (
      select 1
      from public.stores as store
      join public.products as product on product.id = stock_movements.product_id
      where store.id = stock_movements.store_id
        and product.organization_id = store.organization_id
    )
    and (
      stock_movements.batch_id is null
      or exists (
        select 1
        from public.product_batches as batch
        where batch.id = stock_movements.batch_id
          and batch.store_id = stock_movements.store_id
          and batch.product_id = stock_movements.product_id
      )
    )
  );
