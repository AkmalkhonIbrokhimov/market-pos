-- =========================================================
-- SPRINT 2C: AUTHENTICATED READ POLICIES
-- =========================================================

alter table public.users enable row level security;
alter table public.user_store_access enable row level security;
alter table public.stores enable row level security;
alter table public.organizations enable row level security;

create index if not exists idx_users_auth_user_id
  on public.users(auth_user_id);

drop policy if exists users_select_own_profile on public.users;
create policy users_select_own_profile
  on public.users
  for select
  to authenticated
  using ((select auth.uid()) = auth_user_id);

drop policy if exists user_store_access_select_own on public.user_store_access;
create policy user_store_access_select_own
  on public.user_store_access
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.id = user_store_access.user_id
        and profile.auth_user_id = (select auth.uid())
    )
  );
drop policy if exists stores_select_assigned on public.stores;
create policy stores_select_assigned
  on public.stores
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.user_store_access as store_access
      join public.users as profile on profile.id = store_access.user_id
      where store_access.store_id = stores.id
        and profile.auth_user_id = (select auth.uid())
    )
  );

drop policy if exists organizations_select_own on public.organizations;
create policy organizations_select_own
  on public.organizations
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.users as profile
      where profile.organization_id = organizations.id
        and profile.auth_user_id = (select auth.uid())
    )
  );
