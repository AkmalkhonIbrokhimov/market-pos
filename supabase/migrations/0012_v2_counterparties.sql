-- MARKET POS V2: COUNTERPARTIES
-- Additive coexistence: legacy suppliers/customers and their FK remain untouched.

alter table public.permissions disable trigger v2_permissions_prevent_insert;
insert into public.permissions(code,module,description,critical) values
('counterparties.view','counterparties','View the complete counterparty directory.',false),
('counterparties.manage','counterparties','Manage counterparties, roles, contacts and addresses.',false),
('counterparties.customer.view','counterparties','View counterparties with an active customer role.',false),
('counterparties.customer.create','counterparties','Create a minimal quick customer from POS.',false),
('counterparties.credit.view','counterparties','View effective customer credit terms.',false),
('counterparties.credit.manage','counterparties','Manage standard customer credit terms.',false)
on conflict(code) do nothing;
alter table public.permissions enable trigger v2_permissions_prevent_insert;

insert into public.permission_profile_permissions(permission_profile_id,permission_id)
select '00000000-0000-0000-0000-000000000101',id from public.permissions
where code like 'counterparties.%' on conflict do nothing;
insert into public.permission_profile_permissions(permission_profile_id,permission_id)
select '00000000-0000-0000-0000-000000000102',id from public.permissions
where code in('counterparties.customer.view','counterparties.customer.create','counterparties.credit.view')
on conflict do nothing;
-- seller_default was expanded; bump active assigned memberships once to invalidate permission caches.
update public.organization_memberships om
set permission_version=om.permission_version+1
where om.status='active' and exists(
 select 1 from public.membership_permission_profiles mpp
 where mpp.membership_id=om.id
 and mpp.permission_profile_id='00000000-0000-0000-0000-000000000102'::uuid
);

create table public.counterparties(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 legacy_supplier_id uuid references public.suppliers(id) on delete restrict,
 legacy_customer_id uuid references public.customers(id) on delete restrict,
 display_name text not null,legal_name text,tax_id text,notes text,
 status text not null default 'active',created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),archived_at timestamptz,
 constraint counterparties_display_check check(btrim(display_name)<>''),
 constraint counterparties_legal_check check(legal_name is null or btrim(legal_name)<>''),
 constraint counterparties_tax_check check(tax_id is null or btrim(tax_id)<>''),
 constraint counterparties_status_check check(status in('active','inactive','archived')),
 constraint counterparties_lifecycle_check check((status='archived' and archived_at is not null) or(status in('active','inactive') and archived_at is null))
);
create index counterparties_org_status_name_idx on public.counterparties(organization_id,status,display_name);
create index counterparties_active_name_idx on public.counterparties(organization_id,lower(display_name)) where archived_at is null;
create unique index counterparties_tax_key on public.counterparties(organization_id,lower(btrim(tax_id))) where tax_id is not null;
create unique index counterparties_legacy_supplier_key on public.counterparties(legacy_supplier_id) where legacy_supplier_id is not null;
create unique index counterparties_legacy_customer_key on public.counterparties(legacy_customer_id) where legacy_customer_id is not null;

create table public.counterparty_roles(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 role_code text not null,started_at timestamptz not null default now(),ended_at timestamptz,
 constraint counterparty_roles_code_check check(role_code in('supplier','customer')),
 constraint counterparty_roles_period_check check(ended_at is null or ended_at>=started_at)
);
create unique index counterparty_roles_active_key on public.counterparty_roles(counterparty_id,role_code) where ended_at is null;
create index counterparty_roles_org_code_idx on public.counterparty_roles(organization_id,role_code,counterparty_id);

create table public.counterparty_contacts(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 contact_type text not null,value text not null,label text,is_primary boolean not null default false,
 created_at timestamptz not null default now(),archived_at timestamptz,
 constraint counterparty_contacts_type_check check(contact_type in('phone','email','person')),
 constraint counterparty_contacts_value_check check(btrim(value)<>''),
 constraint counterparty_contacts_archive_check check(archived_at is null or not is_primary)
);
create unique index counterparty_contacts_primary_key on public.counterparty_contacts(counterparty_id,contact_type) where is_primary and archived_at is null;
create index counterparty_contacts_lookup_idx on public.counterparty_contacts(organization_id,lower(btrim(value))) where archived_at is null;
create index counterparty_contacts_party_idx on public.counterparty_contacts(counterparty_id,contact_type);

create table public.counterparty_addresses(
 id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id) on delete restrict,
 counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 address_type text not null,address_text text not null,metadata jsonb not null default '{}',
 is_primary boolean not null default false,created_at timestamptz not null default now(),archived_at timestamptz,
 constraint counterparty_addresses_type_check check(address_type in('legal','delivery','other')),
 constraint counterparty_addresses_text_check check(btrim(address_text)<>''),
 constraint counterparty_addresses_metadata_check check(jsonb_typeof(metadata)='object'),
 constraint counterparty_addresses_archive_check check(archived_at is null or not is_primary)
);
create unique index counterparty_addresses_primary_key on public.counterparty_addresses(counterparty_id,address_type) where is_primary and archived_at is null;
create index counterparty_addresses_party_idx on public.counterparty_addresses(counterparty_id,address_type);

create table public.counterparty_credit_settings(
 counterparty_id uuid primary key references public.counterparties(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 credit_enabled boolean not null default false,credit_limit_amount numeric(18,4) not null default 0,
 max_due_days integer not null default 0,currency_code char(3) not null,
 updated_by uuid not null references public.organization_memberships(id) on delete restrict,
 updated_at timestamptz not null default now(),
 constraint counterparty_credit_limit_check check(credit_limit_amount>=0),
 constraint counterparty_credit_days_check check(max_due_days>=0),
 constraint counterparty_credit_currency_check check(currency_code::text~'^[A-Z]{3}$')
);
create index counterparty_credit_org_enabled_idx on public.counterparty_credit_settings(organization_id,credit_enabled);

create or replace function public.v2_counterparty_context_required() returns trigger language plpgsql set search_path='' as $$
begin if current_setting('market_pos.counterparty_command',true) is distinct from 'on' then
 raise exception using errcode='P0001',message='V2_COUNTERPARTY_COMMAND_CONTEXT_REQUIRED';end if;return new;end$$;
create or replace function public.v2_prevent_counterparty_delete() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='P0001',message='V2_COUNTERPARTY_HARD_DELETE_FORBIDDEN';end$$;
create or replace function public.v2_guard_counterparty() returns trigger language plpgsql set search_path='' as $$
declare o uuid;begin
 if new.legacy_supplier_id is not null then select organization_id into o from public.suppliers where id=new.legacy_supplier_id;
  if o is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_SUPPLIER_TENANT_MISMATCH';end if;end if;
 if new.legacy_customer_id is not null then select s.organization_id into o from public.customers c join public.stores s on s.id=c.store_id where c.id=new.legacy_customer_id;
  if o is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CUSTOMER_TENANT_MISMATCH';end if;end if;
 if tg_op='UPDATE' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.legacy_supplier_id is distinct from old.legacy_supplier_id or new.legacy_customer_id is distinct from old.legacy_customer_id or new.created_at is distinct from old.created_at)
 then raise exception using errcode='P0001',message='V2_COUNTERPARTY_IDENTITY_MUTATION_FORBIDDEN';end if;return new;end$$;
create or replace function public.v2_guard_counterparty_child() returns trigger language plpgsql set search_path='' as $$
declare p record;begin select organization_id,status into p from public.counterparties where id=new.counterparty_id;
 if p.organization_id is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CHILD_TENANT_MISMATCH';end if;
 if p.status='archived' and tg_op='INSERT' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 if tg_op='UPDATE' and(new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.counterparty_id is distinct from old.counterparty_id or new.created_at is distinct from old.created_at)
 then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CHILD_IDENTITY_MUTATION_FORBIDDEN';end if;return new;end$$;
create or replace function public.v2_guard_counterparty_contact() returns trigger language plpgsql set search_path='' as $$
declare p record;begin select organization_id,status into p from public.counterparties where id=new.counterparty_id;
 if p.organization_id is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CHILD_TENANT_MISMATCH';end if;
 if p.status='archived' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 if tg_op='UPDATE' then
  if old.archived_at is not null then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_ARCHIVED_IMMUTABLE';end if;
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.counterparty_id is distinct from old.counterparty_id or new.contact_type is distinct from old.contact_type or new.created_at is distinct from old.created_at
  then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_IDENTITY_MUTATION_FORBIDDEN';end if;
 end if;return new;end$$;
create or replace function public.v2_guard_counterparty_address() returns trigger language plpgsql set search_path='' as $$
declare p record;begin select organization_id,status into p from public.counterparties where id=new.counterparty_id;
 if p.organization_id is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CHILD_TENANT_MISMATCH';end if;
 if p.status='archived' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 if tg_op='UPDATE' then
  if old.archived_at is not null then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_ARCHIVED_IMMUTABLE';end if;
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.counterparty_id is distinct from old.counterparty_id or new.address_type is distinct from old.address_type or new.created_at is distinct from old.created_at
  then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_IDENTITY_MUTATION_FORBIDDEN';end if;
 end if;return new;end$$;
create or replace function public.v2_guard_counterparty_role() returns trigger language plpgsql set search_path='' as $$
declare p record;begin select organization_id,status into p from public.counterparties where id=new.counterparty_id;
 if p.organization_id is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ROLE_TENANT_MISMATCH';end if;
 if tg_op='INSERT' and p.status='archived' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 if tg_op='UPDATE' then
  if new.id is distinct from old.id or new.organization_id is distinct from old.organization_id or new.counterparty_id is distinct from old.counterparty_id or new.role_code is distinct from old.role_code or new.started_at is distinct from old.started_at or old.ended_at is not null or new.ended_at is null
  then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ROLE_UPDATE_FORBIDDEN';end if;
  if old.role_code='customer' and exists(select 1 from public.counterparty_credit_settings where counterparty_id=old.counterparty_id and credit_enabled)
  then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CUSTOMER_ROLE_ACTIVE_CREDIT';end if;
 end if;return new;end$$;
create or replace function public.v2_guard_counterparty_credit() returns trigger language plpgsql set search_path='' as $$
declare po uuid;mo uuid;begin select organization_id into po from public.counterparties where id=new.counterparty_id;
 select organization_id into mo from public.organization_memberships where id=new.updated_by;
 if po is distinct from new.organization_id or mo is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CREDIT_TENANT_MISMATCH';end if;
 if not exists(select 1 from public.counterparty_roles where counterparty_id=new.counterparty_id and role_code='customer' and ended_at is null) then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CREDIT_CUSTOMER_ROLE_REQUIRED';end if;
 if tg_op='UPDATE' and(new.counterparty_id is distinct from old.counterparty_id or new.organization_id is distinct from old.organization_id) then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CREDIT_IDENTITY_MUTATION_FORBIDDEN';end if;return new;end$$;

create trigger v2_counterparties_context before insert or update on public.counterparties for each row execute function public.v2_counterparty_context_required();
create trigger v2_counterparties_guard before insert or update on public.counterparties for each row execute function public.v2_guard_counterparty();
create trigger v2_counterparties_updated_at before update on public.counterparties for each row execute function public.set_updated_at();
create trigger v2_counterparties_delete before delete on public.counterparties for each row execute function public.v2_prevent_counterparty_delete();
create trigger v2_roles_context before insert or update on public.counterparty_roles for each row execute function public.v2_counterparty_context_required();
create trigger v2_roles_guard before insert or update on public.counterparty_roles for each row execute function public.v2_guard_counterparty_role();
create trigger v2_roles_delete before delete on public.counterparty_roles for each row execute function public.v2_prevent_counterparty_delete();
create trigger v2_contacts_context before insert or update on public.counterparty_contacts for each row execute function public.v2_counterparty_context_required();
create trigger v2_contacts_guard before insert or update on public.counterparty_contacts for each row execute function public.v2_guard_counterparty_contact();
create trigger v2_contacts_delete before delete on public.counterparty_contacts for each row execute function public.v2_prevent_counterparty_delete();
create trigger v2_addresses_context before insert or update on public.counterparty_addresses for each row execute function public.v2_counterparty_context_required();
create trigger v2_addresses_guard before insert or update on public.counterparty_addresses for each row execute function public.v2_guard_counterparty_address();
create trigger v2_addresses_delete before delete on public.counterparty_addresses for each row execute function public.v2_prevent_counterparty_delete();
create trigger v2_credit_context before insert or update on public.counterparty_credit_settings for each row execute function public.v2_counterparty_context_required();
create trigger v2_credit_guard before insert or update on public.counterparty_credit_settings for each row execute function public.v2_guard_counterparty_credit();
create trigger v2_credit_delete before delete on public.counterparty_credit_settings for each row execute function public.v2_prevent_counterparty_delete();

create or replace function public.v2_can_view_counterparty(p_organization_id uuid,p_counterparty_id uuid) returns boolean language sql stable security definer set search_path='' as $$
select public.v2_has_permission(p_organization_id,'counterparties.view',null) or public.v2_has_permission(p_organization_id,'counterparties.manage',null)
 or public.v2_has_support_grant(p_organization_id,'counterparties.view')
 or(public.v2_has_permission(p_organization_id,'counterparties.customer.view',null) and exists(select 1 from public.counterparty_roles r where r.counterparty_id=p_counterparty_id and r.role_code='customer' and r.ended_at is null))$$;
create or replace function public.v2_can_view_counterparty_credit(p_organization_id uuid,p_counterparty_id uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.counterparty_roles where counterparty_id=p_counterparty_id and role_code='customer' and ended_at is null) and
(public.v2_has_permission(p_organization_id,'counterparties.credit.view',null) or public.v2_has_permission(p_organization_id,'counterparties.credit.manage',null) or public.v2_has_support_grant(p_organization_id,'counterparties.credit.view'))$$;

create or replace function public.v2_emit_counterparty_event(o uuid,a uuid,c uuid,act text,ev text,p jsonb) returns void language plpgsql security definer set search_path='' as $$
declare corr uuid:=gen_random_uuid();begin insert into public.audit_events(organization_id,actor_auth_user_id,actor_membership_id,correlation_id,action,entity_type,entity_id,metadata)values(o,auth.uid(),a,corr,act,'counterparty',c,p);
insert into public.outbox_events(organization_id,aggregate_type,aggregate_id,event_type,payload,correlation_id)values(o,'counterparty',c,ev,p,corr);end$$;

create or replace function public.v2_create_counterparty(o uuid,n text,l text default null,t text default null,nt text default null,s boolean default false,c boolean default false,ls uuid default null,lc uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid;i uuid:=gen_random_uuid();begin a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;
perform set_config('market_pos.counterparty_command','on',true);insert into public.counterparties(id,organization_id,display_name,legal_name,tax_id,notes,legacy_supplier_id,legacy_customer_id)values(i,o,n,l,t,nt,ls,lc);
if s then insert into public.counterparty_roles(organization_id,counterparty_id,role_code)values(o,i,'supplier');end if;if c then insert into public.counterparty_roles(organization_id,counterparty_id,role_code)values(o,i,'customer');end if;
perform public.v2_emit_counterparty_event(o,a,i,'counterparty.created','CounterpartyCreated',jsonb_build_object('counterparty_id',i));perform set_config('market_pos.counterparty_command','off',true);return i;end$$;
create or replace function public.v2_create_quick_customer(o uuid,n text,p text default null) returns uuid language plpgsql security definer set search_path='' as $$
declare a uuid;i uuid:=gen_random_uuid();begin a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.customer.create',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CUSTOMER_CREATE_REQUIRED';end if;
perform set_config('market_pos.counterparty_command','on',true);insert into public.counterparties(id,organization_id,display_name)values(i,o,n);insert into public.counterparty_roles(organization_id,counterparty_id,role_code)values(o,i,'customer');
if p is not null then insert into public.counterparty_contacts(organization_id,counterparty_id,contact_type,value,is_primary)values(o,i,'phone',p,true);end if;
perform public.v2_emit_counterparty_event(o,a,i,'counterparty.created','CounterpartyCreated',jsonb_build_object('counterparty_id',i,'quick_customer',true));perform set_config('market_pos.counterparty_command','off',true);return i;end$$;
create or replace function public.v2_update_counterparty(i uuid,n text,l text,t text,nt text,st text) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;begin select organization_id into o from public.counterparties where id=i;a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;perform set_config('market_pos.counterparty_command','on',true);update public.counterparties set display_name=n,legal_name=l,tax_id=t,notes=nt,status=st where id=i;perform public.v2_emit_counterparty_event(o,a,i,'counterparty.changed','CounterpartyChanged',jsonb_build_object('counterparty_id',i));perform set_config('market_pos.counterparty_command','off',true);end$$;
create or replace function public.v2_add_counterparty_role(i uuid,r text) returns uuid language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;x uuid;begin select organization_id into o from public.counterparties where id=i;a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;perform set_config('market_pos.counterparty_command','on',true);insert into public.counterparty_roles(organization_id,counterparty_id,role_code)values(o,i,r)returning id into x;perform public.v2_emit_counterparty_event(o,a,i,'counterparty.role_added','CounterpartyRoleAdded',jsonb_build_object('counterparty_id',i,'role',r));perform set_config('market_pos.counterparty_command','off',true);return x;end$$;
create or replace function public.v2_end_counterparty_role(i uuid) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;p uuid;a uuid;begin select organization_id,counterparty_id into o,p from public.counterparty_roles where id=i;a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;perform set_config('market_pos.counterparty_command','on',true);update public.counterparty_roles set ended_at=clock_timestamp() where id=i;perform public.v2_emit_counterparty_event(o,a,p,'counterparty.role_ended','CounterpartyRoleEnded',jsonb_build_object('counterparty_id',p,'role_id',i));perform set_config('market_pos.counterparty_command','off',true);end$$;

create or replace function public.v2_upsert_counterparty_contact(i uuid,p uuid,ct text,v text,l text,pr boolean,ar boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;x uuid;ps text;e public.counterparty_contacts%rowtype;begin
 select organization_id,status into o,ps from public.counterparties where id=p;if not found then raise exception using errcode='P0001',message='V2_COUNTERPARTY_NOT_FOUND';end if;
 a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;
 if ps='archived' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 perform set_config('market_pos.counterparty_command','on',true);
 if i is null then
  if ar then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_ARCHIVE_REQUIRES_EXISTING';end if;x:=gen_random_uuid();
  insert into public.counterparty_contacts(id,organization_id,counterparty_id,contact_type,value,label,is_primary)values(x,o,p,ct,v,l,pr);
 else
  select * into e from public.counterparty_contacts where id=i for update;if not found then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_NOT_FOUND';end if;
  if e.organization_id is distinct from o or e.counterparty_id is distinct from p then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_SCOPE_MISMATCH';end if;
  if e.contact_type is distinct from ct then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_TYPE_MUTATION_FORBIDDEN';end if;
  if e.archived_at is not null then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CONTACT_ARCHIVED_IMMUTABLE';end if;x:=e.id;
  if ar then update public.counterparty_contacts set archived_at=clock_timestamp(),is_primary=false where id=e.id;
  else update public.counterparty_contacts set value=v,label=l,is_primary=pr where id=e.id;end if;
 end if;
 perform public.v2_emit_counterparty_event(o,a,p,'counterparty.changed','CounterpartyChanged',jsonb_build_object('counterparty_id',p));perform set_config('market_pos.counterparty_command','off',true);return x;end$$;
create or replace function public.v2_upsert_counterparty_address(i uuid,p uuid,at text,v text,m jsonb,pr boolean,ar boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;x uuid;ps text;e public.counterparty_addresses%rowtype;begin
 select organization_id,status into o,ps from public.counterparties where id=p;if not found then raise exception using errcode='P0001',message='V2_COUNTERPARTY_NOT_FOUND';end if;
 a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;
 if ps='archived' then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ARCHIVED_SCOPE';end if;
 perform set_config('market_pos.counterparty_command','on',true);
 if i is null then
  if ar then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_ARCHIVE_REQUIRES_EXISTING';end if;x:=gen_random_uuid();
  insert into public.counterparty_addresses(id,organization_id,counterparty_id,address_type,address_text,metadata,is_primary)values(x,o,p,at,v,m,pr);
 else
  select * into e from public.counterparty_addresses where id=i for update;if not found then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_NOT_FOUND';end if;
  if e.organization_id is distinct from o or e.counterparty_id is distinct from p then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_SCOPE_MISMATCH';end if;
  if e.address_type is distinct from at then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_TYPE_MUTATION_FORBIDDEN';end if;
  if e.archived_at is not null then raise exception using errcode='P0001',message='V2_COUNTERPARTY_ADDRESS_ARCHIVED_IMMUTABLE';end if;x:=e.id;
  if ar then update public.counterparty_addresses set archived_at=clock_timestamp(),is_primary=false where id=e.id;
  else update public.counterparty_addresses set address_text=v,metadata=m,is_primary=pr where id=e.id;end if;
 end if;
 perform public.v2_emit_counterparty_event(o,a,p,'counterparty.changed','CounterpartyChanged',jsonb_build_object('counterparty_id',p));perform set_config('market_pos.counterparty_command','off',true);return x;end$$;
create or replace function public.v2_set_counterparty_credit_settings(p uuid,e boolean,lim numeric,d integer,cur char(3)) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;begin select organization_id into o from public.counterparties where id=p;a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.credit.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTY_CREDIT_MANAGE_REQUIRED';end if;perform set_config('market_pos.counterparty_command','on',true);insert into public.counterparty_credit_settings(counterparty_id,organization_id,credit_enabled,credit_limit_amount,max_due_days,currency_code,updated_by)values(p,o,e,lim,d,cur,a)on conflict(counterparty_id)do update set credit_enabled=excluded.credit_enabled,credit_limit_amount=excluded.credit_limit_amount,max_due_days=excluded.max_due_days,currency_code=excluded.currency_code,updated_by=excluded.updated_by,updated_at=now();perform public.v2_emit_counterparty_event(o,a,p,'credit_terms.changed','CreditTermsChanged',jsonb_build_object('counterparty_id',p));perform set_config('market_pos.counterparty_command','off',true);end$$;
create or replace function public.v2_archive_counterparty(p uuid) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;a uuid;begin select organization_id into o from public.counterparties where id=p;a:=public.v2_current_membership_id(o);if a is null or not public.v2_has_permission(o,'counterparties.manage',null)then raise exception using errcode='P0001',message='V2_COUNTERPARTIES_MANAGE_REQUIRED';end if;perform set_config('market_pos.counterparty_command','on',true);update public.counterparty_credit_settings set credit_enabled=false,updated_by=a,updated_at=now()where counterparty_id=p and credit_enabled;update public.counterparty_roles set ended_at=clock_timestamp()where counterparty_id=p and ended_at is null;update public.counterparty_contacts set archived_at=clock_timestamp(),is_primary=false where counterparty_id=p and archived_at is null;update public.counterparty_addresses set archived_at=clock_timestamp(),is_primary=false where counterparty_id=p and archived_at is null;update public.counterparties set status='archived',archived_at=clock_timestamp()where id=p;perform public.v2_emit_counterparty_event(o,a,p,'counterparty.archived','CounterpartyArchived',jsonb_build_object('counterparty_id',p));perform set_config('market_pos.counterparty_command','off',true);end$$;

alter table public.counterparties enable row level security;alter table public.counterparty_roles enable row level security;alter table public.counterparty_contacts enable row level security;alter table public.counterparty_addresses enable row level security;alter table public.counterparty_credit_settings enable row level security;
create policy counterparties_select on public.counterparties for select to authenticated using(public.v2_can_view_counterparty(organization_id,id));
create policy counterparty_roles_select on public.counterparty_roles for select to authenticated using(public.v2_can_view_counterparty(organization_id,counterparty_id) and(role_code='customer' or public.v2_has_permission(organization_id,'counterparties.view',null)or public.v2_has_permission(organization_id,'counterparties.manage',null)or public.v2_has_support_grant(organization_id,'counterparties.view')));
create policy counterparty_contacts_select on public.counterparty_contacts for select to authenticated using(public.v2_can_view_counterparty(organization_id,counterparty_id));
create policy counterparty_addresses_select on public.counterparty_addresses for select to authenticated using(public.v2_can_view_counterparty(organization_id,counterparty_id));
create policy counterparty_credit_select on public.counterparty_credit_settings for select to authenticated using(public.v2_can_view_counterparty_credit(organization_id,counterparty_id));
revoke all on public.counterparties,public.counterparty_roles,public.counterparty_contacts,public.counterparty_addresses,public.counterparty_credit_settings from anon,authenticated;
grant select on public.counterparties,public.counterparty_roles,public.counterparty_contacts,public.counterparty_addresses,public.counterparty_credit_settings to authenticated;

revoke execute on function public.v2_counterparty_context_required(),public.v2_prevent_counterparty_delete(),public.v2_guard_counterparty(),public.v2_guard_counterparty_child(),public.v2_guard_counterparty_contact(),public.v2_guard_counterparty_address(),public.v2_guard_counterparty_role(),public.v2_guard_counterparty_credit(),public.v2_emit_counterparty_event(uuid,uuid,uuid,text,text,jsonb) from public,anon,authenticated;
revoke execute on function public.v2_can_view_counterparty(uuid,uuid),public.v2_can_view_counterparty_credit(uuid,uuid) from public,anon;grant execute on function public.v2_can_view_counterparty(uuid,uuid),public.v2_can_view_counterparty_credit(uuid,uuid) to authenticated;
revoke execute on function public.v2_create_counterparty(uuid,text,text,text,text,boolean,boolean,uuid,uuid),public.v2_create_quick_customer(uuid,text,text),public.v2_update_counterparty(uuid,text,text,text,text,text),public.v2_add_counterparty_role(uuid,text),public.v2_end_counterparty_role(uuid),public.v2_upsert_counterparty_contact(uuid,uuid,text,text,text,boolean,boolean),public.v2_upsert_counterparty_address(uuid,uuid,text,text,jsonb,boolean,boolean),public.v2_set_counterparty_credit_settings(uuid,boolean,numeric,integer,character),public.v2_archive_counterparty(uuid) from public,anon;
grant execute on function public.v2_create_counterparty(uuid,text,text,text,text,boolean,boolean,uuid,uuid),public.v2_create_quick_customer(uuid,text,text),public.v2_update_counterparty(uuid,text,text,text,text,text),public.v2_add_counterparty_role(uuid,text),public.v2_end_counterparty_role(uuid),public.v2_upsert_counterparty_contact(uuid,uuid,text,text,text,boolean,boolean),public.v2_upsert_counterparty_address(uuid,uuid,text,text,jsonb,boolean,boolean),public.v2_set_counterparty_credit_settings(uuid,boolean,numeric,integer,character),public.v2_archive_counterparty(uuid) to authenticated;
