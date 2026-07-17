-- =========================================================
-- SPRINT 4B.1: CATEGORY HIERARCHY AND LIFECYCLE
-- =========================================================

alter table public.categories
  add column if not exists parent_id uuid references public.categories(id) on delete set null,
  add column if not exists description text,
  add column if not exists sort_order integer not null default 0,
  add column if not exists archived_at timestamptz;

create index if not exists categories_organization_parent_idx
  on public.categories (organization_id, parent_id);

create index if not exists categories_parent_idx
  on public.categories (parent_id);

create index if not exists categories_status_idx
  on public.categories (status);

-- archived_at is the archive source of truth. The shared record_status enum is
-- intentionally not widened because it is used by unrelated business tables.

create or replace function public.category_parent_in_organization(
  p_parent_id uuid,
  p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_parent_id is null
    or exists (
      select 1
      from public.categories as parent_category
      where parent_category.id = p_parent_id
        and parent_category.organization_id = p_organization_id
        and parent_category.archived_at is null
    );
$$;

revoke all on function public.category_parent_in_organization(uuid, uuid) from public;
grant execute on function public.category_parent_in_organization(uuid, uuid) to authenticated;

alter table public.categories enable row level security;

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
drop policy if exists categories_insert_organization on public.categories;
create policy categories_insert_organization
  on public.categories
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.users as profile
      where profile.auth_user_id = (select auth.uid())
        and profile.organization_id = categories.organization_id
        and profile.role in ('owner', 'seller', 'service_admin')
        and profile.status = 'active'
    )
    and categories.archived_at is null
    and categories.status in ('active', 'inactive')
    and public.category_parent_in_organization(categories.parent_id, categories.organization_id)
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
    and categories.status in ('active', 'inactive')
    and public.category_parent_in_organization(categories.parent_id, categories.organization_id)
  );

-- No delete policy is added. Categories are retained for product history.
