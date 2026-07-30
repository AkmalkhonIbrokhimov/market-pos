-- MARKET POS V2: PRICING
-- Additive coexistence only. Legacy public.products.sale_price remains untouched.

create extension if not exists btree_gist with schema extensions;

create table public.price_lists (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  branch_id uuid references public.branches(id) on delete restrict,
  code text not null,
  name text not null,
  currency_code char(3) not null,
  is_default boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  constraint price_lists_code_check check (btrim(code) <> ''),
  constraint price_lists_name_check check (btrim(name) <> ''),
  constraint price_lists_currency_check check (currency_code::text ~ '^[A-Z]{3}$'),
  constraint price_lists_status_check check (status in ('active','inactive','archived')),
  constraint price_lists_lifecycle_check check (
    (status = 'archived' and archived_at is not null and not is_default)
    or (status in ('active','inactive') and archived_at is null)
  )
);
create unique index price_lists_organization_code_key
  on public.price_lists(organization_id,lower(code));
create unique index price_lists_organization_default_key
  on public.price_lists(organization_id) where branch_id is null and is_default and status='active';
create unique index price_lists_branch_default_key
  on public.price_lists(branch_id) where branch_id is not null and is_default and status='active';
create index price_lists_organization_status_idx on public.price_lists(organization_id,status);
create index price_lists_branch_status_idx on public.price_lists(branch_id,status) where branch_id is not null;

create table public.price_change_requests (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  price_list_id uuid not null references public.price_lists(id) on delete restrict,
  current_amount numeric(18,4),
  requested_amount numeric(18,4) not null,
  source_type text not null,
  source_id uuid,
  status text not null default 'pending',
  requested_by uuid not null references public.organization_memberships(id) on delete restrict,
  decided_by uuid references public.organization_memberships(id) on delete restrict,
  decided_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  constraint price_change_requests_current_check check (current_amount is null or current_amount >= 0),
  constraint price_change_requests_requested_check check (requested_amount >= 0),
  constraint price_change_requests_source_check check (source_type in ('initial','manual','purchase','import','system')),
  constraint price_change_requests_status_check check (status in ('pending','confirmed','rejected','expired')),
  constraint price_change_requests_expiry_check check (expires_at is null or expires_at > created_at),
  constraint price_change_requests_decision_check check (
    (status='pending' and decided_by is null and decided_at is null)
    or (status in ('confirmed','rejected') and decided_by is not null and decided_at is not null)
    or (status='expired' and decided_at is not null)
  )
);
create unique index price_change_requests_pending_source_key
  on public.price_change_requests(product_id,price_list_id,source_type,source_id)
  where status='pending' and source_id is not null;
create unique index price_change_requests_pending_null_source_key
  on public.price_change_requests(product_id,price_list_id,source_type)
  where status='pending' and source_id is null;
create index price_change_requests_organization_status_idx
  on public.price_change_requests(organization_id,status,created_at desc);
create index price_change_requests_product_idx on public.price_change_requests(product_id,created_at desc);
create index price_change_requests_list_status_idx on public.price_change_requests(price_list_id,status);
create index price_change_requests_requested_by_idx on public.price_change_requests(requested_by);
create index price_change_requests_decided_by_idx on public.price_change_requests(decided_by) where decided_by is not null;

create table public.product_prices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  price_list_id uuid not null references public.price_lists(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  amount numeric(18,4) not null,
  currency_code char(3) not null,
  valid_from timestamptz not null,
  valid_to timestamptz,
  confirmed_by uuid not null references public.organization_memberships(id) on delete restrict,
  price_change_request_id uuid references public.price_change_requests(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint product_prices_amount_check check (amount >= 0),
  constraint product_prices_currency_check check (currency_code::text ~ '^[A-Z]{3}$'),
  constraint product_prices_period_check check (valid_to is null or valid_to > valid_from),
  constraint product_prices_period_excl exclude using gist (
    price_list_id with =,
    product_id with =,
    tstzrange(valid_from,valid_to,'[)') with &&
  )
);
create index product_prices_active_lookup_idx
  on public.product_prices(price_list_id,product_id,valid_from desc);
create index product_prices_organization_product_idx
  on public.product_prices(organization_id,product_id);
create index product_prices_request_idx
  on public.product_prices(price_change_request_id) where price_change_request_id is not null;

create table public.price_history (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  product_price_id uuid not null references public.product_prices(id) on delete restrict,
  price_list_id uuid not null references public.price_lists(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  old_amount numeric(18,4),
  new_amount numeric(18,4) not null,
  reason_code text not null,
  source_type text not null,
  source_id uuid,
  changed_by uuid not null references public.organization_memberships(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint price_history_old_amount_check check (old_amount is null or old_amount >= 0),
  constraint price_history_new_amount_check check (new_amount >= 0),
  constraint price_history_reason_check check (btrim(reason_code) <> ''),
  constraint price_history_source_check check (source_type in ('initial','manual','purchase','import','system')),
  constraint price_history_initial_check check (
    (source_type='initial' and old_amount is null) or
    (source_type<>'initial' and old_amount is not null)
  ),
  constraint price_history_product_price_key unique(product_price_id)
);
create index price_history_organization_product_idx
  on public.price_history(organization_id,product_id,created_at desc);
create index price_history_list_product_idx
  on public.price_history(price_list_id,product_id,created_at desc);

create table public.price_recommendations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  price_change_request_id uuid not null references public.price_change_requests(id) on delete restrict,
  product_id uuid not null references public.products_v2(id) on delete restrict,
  purchase_price numeric(18,4) not null,
  previous_purchase_price numeric(18,4),
  margin_percent numeric(9,4),
  recommended_amount numeric(18,4) not null,
  calculation jsonb not null default '{}',
  created_at timestamptz not null default now(),
  constraint price_recommendations_purchase_check check (purchase_price >= 0),
  constraint price_recommendations_previous_check check (previous_purchase_price is null or previous_purchase_price >= 0),
  constraint price_recommendations_margin_check check (margin_percent is null or margin_percent >= 0),
  constraint price_recommendations_amount_check check (recommended_amount >= 0),
  constraint price_recommendations_calculation_check check (jsonb_typeof(calculation)='object')
);
create index price_recommendations_request_idx on public.price_recommendations(price_change_request_id);
create index price_recommendations_organization_product_idx
  on public.price_recommendations(organization_id,product_id,created_at desc);

create or replace function public.v2_prevent_pricing_delete()
returns trigger language plpgsql set search_path=''
as $$ begin
  raise exception using errcode='P0001',message='V2_PRICING_HARD_DELETE_FORBIDDEN';
end $$;

create or replace function public.v2_guard_price_list()
returns trigger language plpgsql set search_path=''
as $$
declare v_org uuid;
begin
  if new.branch_id is not null then
    select organization_id into v_org from public.branches where id=new.branch_id;
    if v_org is distinct from new.organization_id then
      raise exception using errcode='P0001',message='V2_PRICE_LIST_BRANCH_TENANT_MISMATCH';
    end if;
  end if;
  if tg_op='UPDATE' and (
    new.id is distinct from old.id or new.organization_id is distinct from old.organization_id
    or new.branch_id is distinct from old.branch_id or new.code is distinct from old.code
    or new.created_at is distinct from old.created_at
  ) then raise exception using errcode='P0001',message='V2_PRICE_LIST_IDENTITY_MUTATION_FORBIDDEN'; end if;
  return new;
end $$;

create or replace function public.v2_guard_price_request()
returns trigger language plpgsql set search_path=''
as $$
declare v_product record; v_list record; v_member_org uuid;
begin
  select organization_id,status into v_product from public.products_v2 where id=new.product_id;
  select organization_id,status into v_list from public.price_lists where id=new.price_list_id;
  select organization_id into v_member_org from public.organization_memberships where id=new.requested_by;
  if v_product.organization_id is distinct from new.organization_id
    or v_list.organization_id is distinct from new.organization_id
    or v_member_org is distinct from new.organization_id then
    raise exception using errcode='P0001',message='V2_PRICE_REQUEST_TENANT_MISMATCH';
  end if;
  if v_product.status='archived' or v_list.status='archived' then
    raise exception using errcode='P0001',message='V2_PRICE_REQUEST_ARCHIVED_SCOPE';
  end if;
  if new.decided_by is not null then
    select organization_id into v_member_org from public.organization_memberships where id=new.decided_by;
    if v_member_org is distinct from new.organization_id then
      raise exception using errcode='P0001',message='V2_PRICE_REQUEST_DECIDER_TENANT_MISMATCH';
    end if;
  end if;
  if tg_op='UPDATE' then
    if old.status<>'pending' then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_TERMINAL_IMMUTABLE'; end if;
    if current_setting('market_pos.pricing_command',true) is distinct from 'on'
      or new.id is distinct from old.id or new.organization_id is distinct from old.organization_id
      or new.product_id is distinct from old.product_id or new.price_list_id is distinct from old.price_list_id
      or new.current_amount is distinct from old.current_amount or new.requested_amount is distinct from old.requested_amount
      or new.source_type is distinct from old.source_type or new.source_id is distinct from old.source_id
      or new.requested_by is distinct from old.requested_by or new.expires_at is distinct from old.expires_at
      or new.created_at is distinct from old.created_at or new.status='pending'
    then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_UPDATE_FORBIDDEN'; end if;
  end if;
  return new;
end $$;

create or replace function public.v2_guard_product_price()
returns trigger language plpgsql set search_path=''
as $$
declare v_product record; v_list record; v_member_org uuid; v_request record;
begin
  if tg_op='UPDATE' and (
    current_setting('market_pos.pricing_command',true) is distinct from 'on'
    or old.valid_to is not null or new.valid_to is null
    or new.id is distinct from old.id or new.organization_id is distinct from old.organization_id
    or new.price_list_id is distinct from old.price_list_id or new.product_id is distinct from old.product_id
    or new.amount is distinct from old.amount or new.currency_code is distinct from old.currency_code
    or new.valid_from is distinct from old.valid_from or new.confirmed_by is distinct from old.confirmed_by
    or new.price_change_request_id is distinct from old.price_change_request_id
    or new.created_at is distinct from old.created_at
  ) then raise exception using errcode='P0001',message='V2_PRODUCT_PRICE_UPDATE_FORBIDDEN'; end if;
  select organization_id,status into v_product from public.products_v2 where id=new.product_id;
  select organization_id,currency_code,status into v_list from public.price_lists where id=new.price_list_id;
  select organization_id into v_member_org from public.organization_memberships where id=new.confirmed_by;
  if v_product.organization_id is distinct from new.organization_id
    or v_list.organization_id is distinct from new.organization_id
    or v_member_org is distinct from new.organization_id then
    raise exception using errcode='P0001',message='V2_PRODUCT_PRICE_TENANT_MISMATCH';
  end if;
  if v_product.status='archived' or v_list.status='archived' then
    raise exception using errcode='P0001',message='V2_PRODUCT_PRICE_ARCHIVED_SCOPE';
  end if;
  if new.currency_code is distinct from v_list.currency_code then
    raise exception using errcode='P0001',message='V2_PRODUCT_PRICE_CURRENCY_MISMATCH';
  end if;
  if new.price_change_request_id is not null then
    select organization_id,product_id,price_list_id,requested_amount,status into v_request
      from public.price_change_requests where id=new.price_change_request_id;
    if v_request.organization_id is distinct from new.organization_id
      or v_request.product_id is distinct from new.product_id
      or v_request.price_list_id is distinct from new.price_list_id
      or v_request.requested_amount is distinct from new.amount
      or v_request.status not in ('pending','confirmed')
    then raise exception using errcode='P0001',message='V2_PRODUCT_PRICE_REQUEST_MISMATCH'; end if;
  end if;
  return new;
end $$;

create or replace function public.v2_guard_price_history()
returns trigger language plpgsql set search_path=''
as $$
declare v_price record; v_member_org uuid;
begin
  if tg_op='UPDATE' then raise exception using errcode='P0001',message='V2_PRICE_HISTORY_IMMUTABLE'; end if;
  select organization_id,price_list_id,product_id,amount into v_price
    from public.product_prices where id=new.product_price_id;
  select organization_id into v_member_org from public.organization_memberships where id=new.changed_by;
  if v_price.organization_id is distinct from new.organization_id
    or v_price.price_list_id is distinct from new.price_list_id
    or v_price.product_id is distinct from new.product_id
    or v_price.amount is distinct from new.new_amount
    or v_member_org is distinct from new.organization_id
  then raise exception using errcode='P0001',message='V2_PRICE_HISTORY_TENANT_MISMATCH'; end if;
  return new;
end $$;

create or replace function public.v2_guard_price_recommendation()
returns trigger language plpgsql set search_path=''
as $$
declare v_request record;
begin
  if tg_op='UPDATE' then raise exception using errcode='P0001',message='V2_PRICE_RECOMMENDATION_IMMUTABLE'; end if;
  select organization_id,product_id,status into v_request
    from public.price_change_requests where id=new.price_change_request_id;
  if v_request.organization_id is distinct from new.organization_id
    or v_request.product_id is distinct from new.product_id
  then raise exception using errcode='P0001',message='V2_PRICE_RECOMMENDATION_TENANT_MISMATCH'; end if;
  if v_request.status is distinct from 'pending' then
    raise exception using errcode='P0001',message='V2_PRICE_RECOMMENDATION_REQUEST_NOT_PENDING';
  end if;
  return new;
end $$;

create trigger v2_price_lists_guard before insert or update on public.price_lists
  for each row execute function public.v2_guard_price_list();
create trigger v2_price_change_requests_guard before insert or update on public.price_change_requests
  for each row execute function public.v2_guard_price_request();
create trigger v2_product_prices_guard before insert or update on public.product_prices
  for each row execute function public.v2_guard_product_price();
create trigger v2_price_history_guard before insert or update on public.price_history
  for each row execute function public.v2_guard_price_history();
create trigger v2_price_recommendations_guard before insert or update on public.price_recommendations
  for each row execute function public.v2_guard_price_recommendation();

create trigger v2_price_lists_updated_at before update on public.price_lists
  for each row execute function public.set_updated_at();
create trigger v2_price_lists_prevent_delete before delete on public.price_lists
  for each row execute function public.v2_prevent_pricing_delete();
create trigger v2_price_change_requests_prevent_delete before delete on public.price_change_requests
  for each row execute function public.v2_prevent_pricing_delete();
create trigger v2_product_prices_prevent_delete before delete on public.product_prices
  for each row execute function public.v2_prevent_pricing_delete();
create trigger v2_price_history_prevent_delete before delete on public.price_history
  for each row execute function public.v2_prevent_pricing_delete();
create trigger v2_price_recommendations_prevent_delete before delete on public.price_recommendations
  for each row execute function public.v2_prevent_pricing_delete();

create or replace function public.v2_create_price_change_request(
  p_organization_id uuid, p_product_id uuid, p_price_list_id uuid,
  p_requested_amount numeric, p_source_type text, p_source_id uuid default null
) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_actor uuid; v_branch uuid; v_current numeric(18,4); v_id uuid;
begin
  v_actor:=public.v2_current_membership_id(p_organization_id);
  if v_actor is null or not public.v2_has_permission(p_organization_id,'pricing.manage',null) then
    raise exception using errcode='P0001',message='V2_PRICING_MANAGE_REQUIRED';
  end if;
  select branch_id into v_branch from public.price_lists
    where id=p_price_list_id and organization_id=p_organization_id;
  if not found then raise exception using errcode='P0001',message='V2_PRICE_LIST_NOT_FOUND'; end if;
  if v_branch is not null and not public.v2_has_permission(p_organization_id,'pricing.manage',v_branch) then
    raise exception using errcode='P0001',message='V2_PRICING_BRANCH_ACCESS_REQUIRED';
  end if;
  select amount into v_current from public.product_prices
    where product_id=p_product_id and price_list_id=p_price_list_id and valid_to is null
    order by valid_from desc limit 1;
  insert into public.price_change_requests(
    organization_id,product_id,price_list_id,current_amount,requested_amount,
    source_type,source_id,requested_by
  ) values(p_organization_id,p_product_id,p_price_list_id,v_current,p_requested_amount,
    p_source_type,p_source_id,v_actor) returning id into v_id;
  insert into public.audit_events(
    organization_id,branch_id,actor_auth_user_id,actor_membership_id,correlation_id,
    action,entity_type,entity_id,after_data,metadata
  ) values(p_organization_id,v_branch,auth.uid(),v_actor,v_id,
    'price_change.requested','price_change_request',v_id,
    jsonb_build_object('product_id',p_product_id,'price_list_id',p_price_list_id,
      'current_amount',v_current,'requested_amount',p_requested_amount),
    jsonb_build_object('source_type',p_source_type,'source_id',p_source_id));
  insert into public.outbox_events(
    organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id
  ) values(p_organization_id,'price_change_request',v_id,'PriceChangeRequested',
    jsonb_build_object('product_id',p_product_id,'price_list_id',p_price_list_id,
      'current_amount',v_current,'requested_amount',p_requested_amount,
      'source_type',p_source_type,'source_id',p_source_id),v_id);
  return v_id;
end $$;

create or replace function public.v2_confirm_price_change(p_request_id uuid)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_request public.price_change_requests%rowtype; v_actor uuid; v_branch uuid;
  v_current public.product_prices%rowtype; v_now timestamptz:=clock_timestamp(); v_price_id uuid;
begin
  select * into v_request from public.price_change_requests where id=p_request_id for update;
  if not found then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_NOT_FOUND'; end if;
  if v_request.status<>'pending' then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_NOT_PENDING'; end if;
  if v_request.expires_at is not null and v_request.expires_at<=v_now then
    raise exception using errcode='P0001',message='V2_PRICE_REQUEST_EXPIRED';
  end if;
  v_actor:=public.v2_current_membership_id(v_request.organization_id);
  if v_actor is null or not public.v2_has_permission(v_request.organization_id,'pricing.confirm',null) then
    raise exception using errcode='P0001',message='V2_PRICING_CONFIRM_REQUIRED';
  end if;
  select branch_id into v_branch from public.price_lists where id=v_request.price_list_id;
  if v_branch is not null and not public.v2_has_permission(v_request.organization_id,'pricing.confirm',v_branch) then
    raise exception using errcode='P0001',message='V2_PRICING_BRANCH_ACCESS_REQUIRED';
  end if;
  select * into v_current from public.product_prices
    where product_id=v_request.product_id and price_list_id=v_request.price_list_id and valid_to is null
    order by valid_from desc limit 1 for update;
  if (v_request.current_amount is null and found)
    or (v_request.current_amount is not null and (not found or v_current.amount is distinct from v_request.current_amount))
  then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_STALE'; end if;
  perform set_config('market_pos.pricing_command','on',true);
  if v_current.id is not null then update public.product_prices set valid_to=v_now where id=v_current.id; end if;
  insert into public.product_prices(
    organization_id,price_list_id,product_id,amount,currency_code,valid_from,
    confirmed_by,price_change_request_id
  ) select v_request.organization_id,v_request.price_list_id,v_request.product_id,
    v_request.requested_amount,pl.currency_code,v_now,v_actor,v_request.id
    from public.price_lists pl where pl.id=v_request.price_list_id
    returning id into v_price_id;
  insert into public.price_history(
    organization_id,product_price_id,price_list_id,product_id,old_amount,new_amount,
    reason_code,source_type,source_id,changed_by
  ) values(v_request.organization_id,v_price_id,v_request.price_list_id,v_request.product_id,
    v_request.current_amount,v_request.requested_amount,'price_change_confirmed',
    v_request.source_type,v_request.source_id,v_actor);
  update public.price_change_requests set status='confirmed',decided_by=v_actor,decided_at=v_now
    where id=v_request.id;
  perform set_config('market_pos.pricing_command','off',true);
  insert into public.audit_events(
    organization_id,branch_id,actor_auth_user_id,actor_membership_id,correlation_id,
    action,entity_type,entity_id,after_data,metadata
  ) values(v_request.organization_id,v_branch,auth.uid(),v_actor,v_request.id,
    'price_change.confirmed','product_price',v_price_id,
    jsonb_build_object('amount',v_request.requested_amount,'price_list_id',v_request.price_list_id),
    jsonb_build_object('price_change_request_id',v_request.id));
  insert into public.outbox_events(
    organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id
  ) values(v_request.organization_id,'product_price',v_price_id,'SalePriceConfirmed',
    jsonb_build_object('product_id',v_request.product_id,'price_list_id',v_request.price_list_id,
      'amount',v_request.requested_amount),v_request.id);
  return v_price_id;
end $$;

create or replace function public.v2_reject_price_change(p_request_id uuid)
returns void language plpgsql security definer set search_path=''
as $$
declare v_request public.price_change_requests%rowtype; v_actor uuid; v_branch uuid; v_now timestamptz:=clock_timestamp();
begin
  select * into v_request from public.price_change_requests where id=p_request_id for update;
  if not found then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_NOT_FOUND'; end if;
  if v_request.status<>'pending' then raise exception using errcode='P0001',message='V2_PRICE_REQUEST_NOT_PENDING'; end if;
  v_actor:=public.v2_current_membership_id(v_request.organization_id);
  if v_actor is null or not public.v2_has_permission(v_request.organization_id,'pricing.confirm',null) then
    raise exception using errcode='P0001',message='V2_PRICING_CONFIRM_REQUIRED';
  end if;
  select branch_id into v_branch from public.price_lists where id=v_request.price_list_id;
  if v_branch is not null and not public.v2_has_permission(v_request.organization_id,'pricing.confirm',v_branch) then
    raise exception using errcode='P0001',message='V2_PRICING_BRANCH_ACCESS_REQUIRED';
  end if;
  perform set_config('market_pos.pricing_command','on',true);
  update public.price_change_requests set status='rejected',decided_by=v_actor,decided_at=v_now
    where id=v_request.id;
  perform set_config('market_pos.pricing_command','off',true);
  insert into public.audit_events(
    organization_id,branch_id,actor_auth_user_id,actor_membership_id,correlation_id,
    action,entity_type,entity_id,metadata
  ) values(v_request.organization_id,v_branch,auth.uid(),v_actor,v_request.id,
    'price_change.rejected','price_change_request',v_request.id,
    jsonb_build_object('price_change_request_id',v_request.id));
  insert into public.outbox_events(
    organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id
  ) values(v_request.organization_id,'price_change_request',v_request.id,'PriceChangeRejected',
    jsonb_build_object('product_id',v_request.product_id,'price_list_id',v_request.price_list_id),
    v_request.id);
end $$;

alter table public.price_lists enable row level security;
alter table public.price_change_requests enable row level security;
alter table public.product_prices enable row level security;
alter table public.price_history enable row level security;
alter table public.price_recommendations enable row level security;

create policy price_lists_select on public.price_lists for select to authenticated using (
  public.v2_has_permission(organization_id,'pricing.view',branch_id)
  or public.v2_has_support_grant(organization_id,'pricing.manage')
);
create policy product_prices_select on public.product_prices for select to authenticated using (
  exists(select 1 from public.price_lists pl where pl.id=public.product_prices.price_list_id and
    (public.v2_has_permission(public.product_prices.organization_id,'pricing.view',pl.branch_id)
     or public.v2_has_support_grant(public.product_prices.organization_id,'pricing.manage')))
);
create policy price_change_requests_select on public.price_change_requests for select to authenticated using (
  exists(select 1 from public.price_lists pl where pl.id=public.price_change_requests.price_list_id and
    (public.v2_is_owner(public.price_change_requests.organization_id)
     or public.v2_has_permission(public.price_change_requests.organization_id,'pricing.manage',pl.branch_id)
     or public.v2_has_permission(public.price_change_requests.organization_id,'pricing.confirm',pl.branch_id)
     or public.v2_has_support_grant(public.price_change_requests.organization_id,'pricing.manage')))
);
create policy price_history_select on public.price_history for select to authenticated using (
  exists(select 1 from public.price_lists pl where pl.id=public.price_history.price_list_id and
    (public.v2_is_owner(public.price_history.organization_id)
     or public.v2_has_permission(public.price_history.organization_id,'pricing.manage',pl.branch_id)
     or public.v2_has_permission(public.price_history.organization_id,'pricing.confirm',pl.branch_id)
     or public.v2_has_support_grant(public.price_history.organization_id,'pricing.manage')))
);
create policy price_recommendations_select on public.price_recommendations for select to authenticated using (
  exists(select 1 from public.price_change_requests pr join public.price_lists pl on pl.id=pr.price_list_id
    where pr.id=public.price_recommendations.price_change_request_id and
    (public.v2_is_owner(public.price_recommendations.organization_id)
     or public.v2_has_permission(public.price_recommendations.organization_id,'pricing.manage',pl.branch_id)
     or public.v2_has_permission(public.price_recommendations.organization_id,'pricing.confirm',pl.branch_id)
     or public.v2_has_support_grant(public.price_recommendations.organization_id,'pricing.manage')))
);

revoke all on table public.price_lists,public.price_change_requests,public.product_prices,
  public.price_history,public.price_recommendations from anon,authenticated;
grant select on table public.price_lists,public.price_change_requests,public.product_prices,
  public.price_history,public.price_recommendations to authenticated;

revoke execute on function public.v2_prevent_pricing_delete() from public,anon,authenticated;
revoke execute on function public.v2_guard_price_list() from public,anon,authenticated;
revoke execute on function public.v2_guard_price_request() from public,anon,authenticated;
revoke execute on function public.v2_guard_product_price() from public,anon,authenticated;
revoke execute on function public.v2_guard_price_history() from public,anon,authenticated;
revoke execute on function public.v2_guard_price_recommendation() from public,anon,authenticated;
revoke execute on function public.v2_create_price_change_request(uuid,uuid,uuid,numeric,text,uuid) from public,anon;
revoke execute on function public.v2_confirm_price_change(uuid) from public,anon;
revoke execute on function public.v2_reject_price_change(uuid) from public,anon;
grant execute on function public.v2_create_price_change_request(uuid,uuid,uuid,numeric,text,uuid) to authenticated;
grant execute on function public.v2_confirm_price_change(uuid) to authenticated;
grant execute on function public.v2_reject_price_change(uuid) to authenticated;
