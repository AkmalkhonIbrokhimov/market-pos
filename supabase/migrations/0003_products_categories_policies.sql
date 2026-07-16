-- =========================================================
-- SPRINT 3A: PRODUCTS AND CATEGORIES POLICIES
-- =========================================================

alter table public.categories enable row level security;
alter table public.products enable row level security;

drop policy if exists categories_select_organization on public.categories;
create policy categories_select_organization
  on public.categories
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = categories.organization_id
        and profile.status = 'active'
    )
  );

drop policy if exists categories_insert_management on public.categories;
create policy categories_insert_management
  on public.categories
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = categories.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  );

drop policy if exists categories_update_management on public.categories;
create policy categories_update_management
  on public.categories
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = categories.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  )
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = categories.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  );

drop policy if exists products_select_organization on public.products;
create policy products_select_organization
  on public.products
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = products.organization_id
        and profile.status = 'active'
    )
  );

drop policy if exists products_insert_management on public.products;
create policy products_insert_management
  on public.products
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = products.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
    and (
      products.category_id is null
      or exists (
        select 1
        from public.categories as category
        where category.id = products.category_id
          and category.organization_id = products.organization_id
      )
    )
  );

drop policy if exists products_update_management on public.products;
create policy products_update_management
  on public.products
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = products.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
  )
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = products.organization_id
        and profile.role in ('owner', 'service_admin')
        and profile.status = 'active'
    )
    and (
      products.category_id is null
      or exists (
        select 1
        from public.categories as category
        where category.id = products.category_id
          and category.organization_id = products.organization_id
      )
    )
  );
