-- MARKET POS V2: SHIFTS AND CASH LEDGER
-- Additive coexistence: legacy shifts, payments and debt_payments remain untouched.

-- Permission registry ---------------------------------------------------------
alter table public.permissions disable trigger v2_permissions_prevent_insert;
insert into public.permissions(code,module,description,critical) values
 ('cash.view','cash','View authorized shift cash journals and reconciliation.',false),
 ('settlements.reverse','settlements','Reverse a posted supplier settlement payment.',true)
on conflict(code) do update set module=excluded.module,description=excluded.description,critical=excluded.critical;
alter table public.permissions enable trigger v2_permissions_prevent_insert;

insert into public.permission_profile_permissions(permission_profile_id,permission_id)
select '00000000-0000-0000-0000-000000000101'::uuid,id
from public.permissions where code in('cash.view','settlements.reverse')
on conflict do nothing;
update public.organization_memberships m set permission_version=permission_version+1
where m.status='active' and exists(
 select 1 from public.membership_permission_profiles x
 where x.membership_id=m.id and x.permission_profile_id='00000000-0000-0000-0000-000000000101'::uuid
);

-- Enrich the minimal 0014 shift contract. Historical rows stay nullable when an
-- exact command cannot be proven; every new command-created row is guarded.
alter table public.shifts_v2
 add column business_date date,
 add column currency_code char(3),
 add column expected_cash_amount numeric(18,4),
 add column open_command_id uuid references public.command_log(id) on delete restrict,
 add column close_command_id uuid references public.command_log(id) on delete restrict,
 add column close_approval_id uuid references public.approval_requests(id) on delete restrict,
 add constraint shifts_v2_currency_check check(currency_code is null or currency_code::text~'^[A-Z]{3}$'),
 add constraint shifts_v2_expected_cash_check check(expected_cash_amount is null or expected_cash_amount>=0);

update public.shifts_v2 s set
 currency_code=os.currency_code,
 business_date=(s.opened_at at time zone os.timezone)::date
from public.organization_settings os
where os.organization_id=s.organization_id
  and(s.currency_code is null or s.business_date is null);

with x as(
 select organization_id,entity_id,(array_agg(id order by id))[1] id,count(*) n
 from public.command_log where entity_type='shift'and command_type='shift.open'and status='succeeded'
 group by organization_id,entity_id
)
update public.shifts_v2 s set open_command_id=x.id from x
where s.open_command_id is null and x.n=1 and x.organization_id=s.organization_id and x.entity_id=s.id;

create table public.supplier_payments(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 register_id uuid not null references public.registers(id) on delete restrict,
 counterparty_id uuid not null references public.counterparties(id) on delete restrict,
 shift_id uuid not null references public.shifts_v2(id) on delete restrict,
 document_number text not null,
 business_date date not null,
 total_amount numeric(18,4) not null,
 currency_code char(3) not null,
 status text not null default 'posted',
 device_id uuid not null references public.devices_v2(id) on delete restrict,
 local_operation_id uuid not null,
 client_created_at timestamptz not null,
 posted_by uuid not null references public.organization_memberships(id) on delete restrict,
 posted_at timestamptz not null default now(),
 reversal_of_id uuid references public.supplier_payments(id) on delete restrict,
 command_id uuid not null unique references public.command_log(id) on delete restrict,
 approval_request_id uuid references public.approval_requests(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint supplier_payments_number_check check(btrim(document_number)<>''),
 constraint supplier_payments_amount_check check(total_amount>0),
 constraint supplier_payments_currency_check check(currency_code::text~'^[A-Z]{3}$'),
 constraint supplier_payments_status_check check(status in('posted','reversed')),
 unique(organization_id,document_number),
 unique(organization_id,device_id,local_operation_id)
);
create unique index supplier_payments_one_reversal on public.supplier_payments(reversal_of_id) where reversal_of_id is not null;
create index supplier_payments_journal_idx on public.supplier_payments(organization_id,branch_id,business_date desc,id);
create index supplier_payments_counterparty_idx on public.supplier_payments(counterparty_id,business_date desc,id);
create index supplier_payments_shift_idx on public.supplier_payments(shift_id,posted_at,id);

alter table public.payments_v2
 add column supplier_payment_id uuid references public.supplier_payments(id) on delete restrict;
alter table public.payments_v2 drop constraint payments_v2_source_check;
alter table public.payments_v2 add constraint payments_v2_source_check check(
 ((sale_id is not null)::integer+(sale_return_id is not null)::integer+
  (debt_payment_id is not null)::integer+(supplier_payment_id is not null)::integer)=1
);
create index payments_v2_supplier_payment_idx on public.payments_v2(supplier_payment_id) where supplier_payment_id is not null;

create table public.cash_movements(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 register_id uuid not null references public.registers(id) on delete restrict,
 shift_id uuid not null references public.shifts_v2(id) on delete restrict,
 movement_type text not null,
 amount_delta numeric(18,4) not null,
 currency_code char(3) not null,
 business_date date not null,
 source_type text not null,
 source_id uuid not null,
 reason text,
 device_id uuid not null references public.devices_v2(id) on delete restrict,
 local_operation_id uuid not null,
 reversal_of_id uuid references public.cash_movements(id) on delete restrict,
 command_id uuid not null references public.command_log(id) on delete restrict,
 approval_request_id uuid references public.approval_requests(id) on delete restrict,
 created_by uuid not null references public.organization_memberships(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint cash_movements_type_check check(movement_type in('opening','sale','refund','debt_payment','supplier_payment','cash_in','cash_out','correction')),
 constraint cash_movements_source_check check(source_type in('shift','payment','command')),
 constraint cash_movements_amount_check check((movement_type='opening' and amount_delta>=0)or(movement_type<>'opening'and amount_delta<>0)),
 constraint cash_movements_currency_check check(currency_code::text~'^[A-Z]{3}$'),
 constraint cash_movements_reason_check check(
  (movement_type in('cash_in','cash_out','correction')and reason is not null and btrim(reason)<>'')or
  (movement_type not in('cash_in','cash_out','correction')and reason is null)
 )
);
create unique index cash_movements_one_opening on public.cash_movements(shift_id) where movement_type='opening'and reversal_of_id is null;
create unique index cash_movements_primary_payment on public.cash_movements(source_id) where source_type='payment'and reversal_of_id is null;
create unique index cash_movements_one_reversal on public.cash_movements(reversal_of_id) where reversal_of_id is not null;
create unique index cash_movements_manual_operation on public.cash_movements(organization_id,device_id,local_operation_id)
 where source_type='command'and reversal_of_id is null;
create index cash_movements_shift_journal_idx on public.cash_movements(shift_id,created_at,id);
create index cash_movements_org_branch_date_idx on public.cash_movements(organization_id,branch_id,business_date,created_at,id);
create index cash_movements_source_idx on public.cash_movements(source_type,source_id);
create index cash_movements_command_idx on public.cash_movements(command_id);

create table public.shift_cash_counts(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 branch_id uuid not null references public.branches(id) on delete restrict,
 register_id uuid not null references public.registers(id) on delete restrict,
 shift_id uuid not null references public.shifts_v2(id) on delete restrict,
 line_number integer not null,
 denomination_value numeric(18,4) not null,
 quantity integer not null,
 counted_amount numeric(18,4) not null,
 currency_code char(3) not null,
 command_id uuid not null references public.command_log(id) on delete restrict,
 counted_by uuid not null references public.organization_memberships(id) on delete restrict,
 created_at timestamptz not null default now(),
 constraint shift_cash_counts_line_check check(line_number>0),
 constraint shift_cash_counts_denomination_check check(denomination_value>0),
 constraint shift_cash_counts_quantity_check check(quantity>=0),
 constraint shift_cash_counts_amount_check check(counted_amount=denomination_value*quantity),
 constraint shift_cash_counts_currency_check check(currency_code::text~'^[A-Z]{3}$'),
 unique(shift_id,line_number),
 unique(shift_id,denomination_value)
);
create index shift_cash_counts_command_idx on public.shift_cash_counts(command_id);

-- Internal contexts and deterministic lock ----------------------------------
create or replace function public.v2_lock_register_shift_scope(organization_id uuid,branch_id uuid,register_id uuid)
returns void language plpgsql set search_path=''as $$
declare r public.registers%rowtype;begin
 if organization_id is null or branch_id is null or register_id is null then raise exception using errcode='P0001',message='V2_REGISTER_SHIFT_SCOPE_REQUIRED';end if;
 perform pg_advisory_xact_lock(hashtextextended('register-shift:'||organization_id::text||':'||branch_id::text||':'||register_id::text,0));
 select * into r from public.registers where id=register_id;
 if r.id is null or r.organization_id<>organization_id or r.branch_id<>branch_id then raise exception using errcode='P0001',message='V2_REGISTER_SHIFT_SCOPE_MISMATCH';end if;
end$$;

create or replace function public.v2_cash_context_required()returns trigger language plpgsql set search_path=''as $$
begin if coalesce(current_setting('market_pos.cash_command',true),'')<>'on'then raise exception using errcode='P0001',message='V2_CASH_COMMAND_CONTEXT_REQUIRED';end if;return coalesce(new,old);end$$;
create or replace function public.v2_cash_append_only()returns trigger language plpgsql set search_path=''as $$
begin raise exception using errcode='P0001',message='V2_CASH_APPEND_ONLY';end$$;
create or replace function public.v2_supplier_payment_context_required()returns trigger language plpgsql set search_path=''as $$
begin if coalesce(current_setting('market_pos.supplier_payment_command',true),'')<>'on'then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_COMMAND_CONTEXT_REQUIRED';end if;return coalesce(new,old);end$$;

create or replace function public.v2_guard_cash_movement()returns trigger language plpgsql set search_path=''as $$
declare s public.shifts_v2%rowtype;p public.payments_v2%rowtype;o public.cash_movements%rowtype;c public.command_log%rowtype;a public.approval_requests%rowtype;chain_ok boolean;begin
 select * into s from public.shifts_v2 where id=new.shift_id;
 select * into c from public.command_log where id=new.command_id;
 if s.id is null or s.status<>'open'or s.organization_id<>new.organization_id or s.branch_id<>new.branch_id or s.register_id<>new.register_id or s.currency_code<>new.currency_code or s.business_date<>new.business_date then raise exception using errcode='P0001',message='V2_CASH_SHIFT_SCOPE_MISMATCH';end if;
 if c.id is null or c.organization_id<>new.organization_id or c.branch_id is distinct from new.branch_id or c.device_id is distinct from new.device_id or c.status not in('processing','succeeded')then raise exception using errcode='P0001',message='V2_CASH_COMMAND_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.devices_v2 d where d.id=new.device_id and d.organization_id=new.organization_id and d.branch_id=new.branch_id and d.register_id=new.register_id and d.status='trusted')then raise exception using errcode='P0001',message='V2_CASH_DEVICE_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.organization_memberships m where m.id=new.created_by and m.organization_id=new.organization_id and m.status='active')then raise exception using errcode='P0001',message='V2_CASH_ACTOR_SCOPE_MISMATCH';end if;
 if new.approval_request_id is not null then select * into a from public.approval_requests where id=new.approval_request_id;if a.id is null or a.organization_id<>new.organization_id or a.command_id<>new.command_id or a.status<>'approved'then raise exception using errcode='P0001',message='V2_CASH_APPROVAL_SCOPE_MISMATCH';end if;end if;
 if new.reversal_of_id is not null then
  select * into o from public.cash_movements where id=new.reversal_of_id;
  if o.id is null or o.movement_type='opening'or o.organization_id<>new.organization_id or o.branch_id<>new.branch_id or o.register_id<>new.register_id or o.currency_code<>new.currency_code then raise exception using errcode='P0001',message='V2_CASH_REVERSAL_MISMATCH';end if;
  if new.source_type='payment'and new.movement_type='refund'and o.movement_type='sale'then
   if new.amount_delta>=0 or o.amount_delta<=0 or abs(new.amount_delta)>o.amount_delta then raise exception using errcode='P0001',message='V2_CASH_REVERSAL_MISMATCH';end if;
  elsif new.amount_delta<>-o.amount_delta or new.movement_type<>o.movement_type then raise exception using errcode='P0001',message='V2_CASH_REVERSAL_MISMATCH';end if;
 end if;
 case new.source_type
  when'shift'then if new.movement_type<>'opening'or new.source_id<>new.shift_id or new.reversal_of_id is not null then raise exception using errcode='P0001',message='V2_CASH_SOURCE_GRAPH_MISMATCH';end if;
  when'payment'then
   select * into p from public.payments_v2 where id=new.source_id;
   if p.reversal_of_id is not null and o.id is not null then
    with recursive ancestry as(select x.id,x.reversal_of_id,x.source_id from public.cash_movements x where x.id=o.id union all select x.id,x.reversal_of_id,x.source_id from public.cash_movements x join ancestry q on q.reversal_of_id=x.id)
    select exists(select 1 from ancestry where source_id=p.reversal_of_id)into chain_ok;
   end if;
   if p.id is null or p.method<>'cash'or p.organization_id<>new.organization_id or p.branch_id<>new.branch_id or p.register_id<>new.register_id or p.shift_id<>new.shift_id or p.device_id<>new.device_id or p.currency_code<>new.currency_code or p.amount<>new.amount_delta or(p.reversal_of_id is null and new.reversal_of_id is not null)or(p.reversal_of_id is not null and(new.reversal_of_id is null or not coalesce(chain_ok,false)))then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_SOURCE_MISMATCH';end if;
  when'command'then if new.movement_type not in('cash_in','cash_out','correction')or new.source_id<>new.command_id then raise exception using errcode='P0001',message='V2_CASH_SOURCE_GRAPH_MISMATCH';end if;
 end case;
 if(new.movement_type='cash_in'and new.amount_delta<=0)or(new.movement_type='cash_out'and new.amount_delta>=0)then raise exception using errcode='P0001',message='V2_CASH_MOVEMENT_SIGN_MISMATCH';end if;
 return new;
end$$;

create or replace function public.v2_guard_shift_cash_count()returns trigger language plpgsql set search_path=''as $$
declare s public.shifts_v2%rowtype;begin select * into s from public.shifts_v2 where id=new.shift_id;
 if s.id is null or s.status<>'closing'or s.organization_id<>new.organization_id or s.branch_id<>new.branch_id or s.register_id<>new.register_id or s.currency_code<>new.currency_code or s.close_command_id is distinct from new.command_id then raise exception using errcode='P0001',message='V2_SHIFT_CASH_COUNT_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.organization_memberships m where m.id=new.counted_by and m.organization_id=new.organization_id and m.status='active')then raise exception using errcode='P0001',message='V2_SHIFT_CASH_COUNT_ACTOR_MISMATCH';end if;return new;end$$;

create or replace function public.v2_guard_supplier_payment()returns trigger language plpgsql set search_path=''as $$
declare s public.shifts_v2%rowtype;c public.counterparties%rowtype;o public.supplier_payments%rowtype;cmd public.command_log%rowtype;begin
 select * into s from public.shifts_v2 where id=new.shift_id;select * into c from public.counterparties where id=new.counterparty_id;select * into cmd from public.command_log where id=new.command_id;
 if s.id is null or(tg_op='INSERT'and s.status<>'open')or s.organization_id<>new.organization_id or s.branch_id<>new.branch_id or s.register_id<>new.register_id or s.currency_code<>new.currency_code or(tg_op='INSERT'and s.business_date<>new.business_date)then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_SHIFT_SCOPE_MISMATCH';end if;
 if c.id is null or c.organization_id<>new.organization_id then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_COUNTERPARTY_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.devices_v2 d where d.id=new.device_id and d.organization_id=new.organization_id and d.branch_id=new.branch_id and d.register_id=new.register_id and d.status='trusted')then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_DEVICE_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.organization_memberships m where m.id=new.posted_by and m.organization_id=new.organization_id and m.status='active')or cmd.id is null or cmd.organization_id<>new.organization_id or cmd.branch_id is distinct from new.branch_id or cmd.device_id is distinct from new.device_id then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_COMMAND_SCOPE_MISMATCH';end if;
 if tg_op='UPDATE'then
  if old.status<>'posted'or new.status<>'reversed'or(to_jsonb(new)-'status')<>(to_jsonb(old)-'status')then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_IMMUTABLE';end if;
 elsif new.reversal_of_id is not null then
  select * into o from public.supplier_payments where id=new.reversal_of_id;
  if o.id is null or o.reversal_of_id is not null or o.status<>'posted'or o.organization_id<>new.organization_id or o.branch_id<>new.branch_id or o.register_id<>new.register_id or o.counterparty_id<>new.counterparty_id or o.total_amount<>new.total_amount or o.currency_code<>new.currency_code then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_REVERSAL_MISMATCH';end if;
 end if;return new;
end$$;

create trigger v2_cash_movements_context before insert on public.cash_movements for each row execute function public.v2_cash_context_required();
create trigger v2_cash_movements_guard before insert on public.cash_movements for each row execute function public.v2_guard_cash_movement();
create trigger v2_cash_movements_append_only before update or delete on public.cash_movements for each row execute function public.v2_cash_append_only();
create trigger v2_shift_cash_counts_context before insert on public.shift_cash_counts for each row execute function public.v2_cash_context_required();
create trigger v2_shift_cash_counts_guard before insert on public.shift_cash_counts for each row execute function public.v2_guard_shift_cash_count();
create trigger v2_shift_cash_counts_append_only before update or delete on public.shift_cash_counts for each row execute function public.v2_cash_append_only();
create trigger v2_supplier_payments_context before insert or update or delete on public.supplier_payments for each row execute function public.v2_supplier_payment_context_required();
create trigger v2_supplier_payments_guard before insert or update on public.supplier_payments for each row execute function public.v2_guard_supplier_payment();
create trigger v2_supplier_payments_delete before delete on public.supplier_payments for each row execute function public.v2_cash_append_only();

-- Harden the enriched shift and payment graphs ------------------------------
create or replace function public.v2_shift_guard()returns trigger language plpgsql set search_path=''as $$
declare cmd public.command_log%rowtype;ap public.approval_requests%rowtype;begin
 if not exists(select 1 from public.registers r where r.id=new.register_id and r.organization_id=new.organization_id and r.branch_id=new.branch_id and r.status='active')then raise exception using errcode='P0001',message='V2_SHIFT_REGISTER_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.organization_memberships m where m.id=new.opened_by and m.organization_id=new.organization_id and m.status='active')or(new.closed_by is not null and not exists(select 1 from public.organization_memberships m where m.id=new.closed_by and m.organization_id=new.organization_id and m.status='active'))then raise exception using errcode='P0001',message='V2_SHIFT_ACTOR_SCOPE_MISMATCH';end if;
 if tg_op='INSERT'then
  if new.business_date is null or new.currency_code is null or new.open_command_id is null or new.close_command_id is not null or new.close_approval_id is not null or new.expected_cash_amount is not null then raise exception using errcode='P0001',message='V2_SHIFT_NEW_COMMAND_SHAPE_INVALID';end if;
  select * into cmd from public.command_log where id=new.open_command_id;
  if cmd.id is null or cmd.organization_id<>new.organization_id or cmd.branch_id is distinct from new.branch_id or cmd.command_type<>'shift.open'or cmd.status not in('processing','succeeded')then raise exception using errcode='P0001',message='V2_SHIFT_OPEN_COMMAND_MISMATCH';end if;
 else
  if old.status='closed'or new.id<>old.id or new.organization_id<>old.organization_id or new.branch_id<>old.branch_id or new.register_id<>old.register_id or new.opened_by<>old.opened_by or new.opened_at<>old.opened_at or new.opening_cash_amount<>old.opening_cash_amount or new.business_date is distinct from old.business_date or new.currency_code is distinct from old.currency_code or new.open_command_id is distinct from old.open_command_id or new.created_at<>old.created_at then raise exception using errcode='P0001',message='V2_SHIFT_CLOSED_IMMUTABLE';end if;
  if not((old.status='open'and new.status in('open','closing'))or(old.status='closing'and new.status in('closing','closed')))then raise exception using errcode='P0001',message='V2_SHIFT_TRANSITION_FORBIDDEN';end if;
  if new.status='closing'then
   if new.close_command_id is null or new.closed_by is not null or new.closed_at is not null or new.actual_cash_amount is not null or new.expected_cash_amount is not null or new.difference_amount is not null then raise exception using errcode='P0001',message='V2_SHIFT_CLOSING_SHAPE_INVALID';end if;
  elsif new.status='closed'then
   if new.close_command_id is null or new.closed_by is null or new.closed_at is null or new.actual_cash_amount is null or new.expected_cash_amount is null or new.difference_amount is null then raise exception using errcode='P0001',message='V2_SHIFT_CLOSED_SHAPE_INVALID';end if;
  end if;
  if new.close_command_id is not null then select * into cmd from public.command_log where id=new.close_command_id;if cmd.id is null or cmd.organization_id<>new.organization_id or cmd.branch_id is distinct from new.branch_id or cmd.command_type not in('shift.close','cash.move.override')or cmd.status not in('processing','succeeded')then raise exception using errcode='P0001',message='V2_SHIFT_CLOSE_COMMAND_MISMATCH';end if;end if;
  if new.close_approval_id is not null then select * into ap from public.approval_requests where id=new.close_approval_id;if ap.id is null or ap.organization_id<>new.organization_id or ap.command_id<>new.close_command_id or ap.permission_code<>'cash.move.override'or ap.status<>'approved'then raise exception using errcode='P0001',message='V2_SHIFT_CLOSE_APPROVAL_MISMATCH';end if;end if;
 end if;return new;
end$$;

create or replace function public.v2_shift_total_guard()returns trigger language plpgsql set search_path=''as $$
declare s public.shifts_v2%rowtype;begin select * into s from public.shifts_v2 where id=new.shift_id;
 if s.id is null or s.organization_id is distinct from new.organization_id then raise exception using errcode='P0001',message='V2_SHIFT_TOTAL_SCOPE_MISMATCH';end if;
 if tg_op='UPDATE'and(new.id<>old.id or new.organization_id<>old.organization_id or new.shift_id<>old.shift_id or new.payment_method<>old.payment_method)then raise exception using errcode='P0001',message='V2_SHIFT_TOTAL_IDENTITY_MUTATION_FORBIDDEN';end if;
 if s.status not in('open','closing')then raise exception using errcode='P0001',message='V2_SHIFT_TOTAL_FROZEN';end if;return new;
end$$;

create or replace function public.v2_payment_guard()returns trigger language plpgsql set search_path=''as $$
declare s public.shifts_v2%rowtype;sv public.sales_v2%rowtype;sr public.sale_returns%rowtype;dp public.debt_payments_v2%rowtype;sp public.supplier_payments%rowtype;original public.payments_v2%rowtype;refunded numeric;begin
 select * into s from public.shifts_v2 where id=new.shift_id;
 if s.id is null or s.status<>'open'or s.organization_id<>new.organization_id or s.branch_id<>new.branch_id or s.register_id<>new.register_id or s.currency_code<>new.currency_code then raise exception using errcode='P0001',message='V2_PAYMENT_SHIFT_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.devices_v2 d where d.id=new.device_id and d.organization_id=new.organization_id and d.branch_id=new.branch_id and d.register_id=new.register_id and d.status='trusted')then raise exception using errcode='P0001',message='V2_PAYMENT_DEVICE_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.organization_memberships m where m.id=new.created_by and m.organization_id=new.organization_id and m.status='active')then raise exception using errcode='P0001',message='V2_PAYMENT_ACTOR_SCOPE_MISMATCH';end if;
 if new.reversal_of_id is not null then select * into original from public.payments_v2 where id=new.reversal_of_id;if original.id is null or original.organization_id<>new.organization_id or original.method<>new.method or original.currency_code<>new.currency_code then raise exception using errcode='P0001',message='V2_PAYMENT_SOURCE_GRAPH_MISMATCH';end if;end if;
 if new.sale_id is not null then
  select * into sv from public.sales_v2 where id=new.sale_id;
  if sv.id is null or sv.organization_id<>new.organization_id or sv.branch_id<>new.branch_id or sv.register_id<>new.register_id or sv.currency_code<>new.currency_code or((sv.reversal_of_id is null and(new.amount<=0 or new.reversal_of_id is not null))or(sv.reversal_of_id is not null and(new.amount>=0 or new.reversal_of_id is null or original.sale_id is distinct from sv.reversal_of_id or new.amount<>-original.amount)))then raise exception using errcode='P0001',message='V2_PAYMENT_SOURCE_GRAPH_MISMATCH';end if;
 elsif new.sale_return_id is not null then
  select * into sr from public.sale_returns where id=new.sale_return_id;select * into sv from public.sales_v2 where id=sr.original_sale_id;
  select coalesce(sum(abs(x.amount)),0)into refunded from public.payments_v2 x where x.reversal_of_id=original.id and x.status='confirmed'and not exists(select 1 from public.payments_v2 y where y.reversal_of_id=x.id and y.status='confirmed');
  if sr.reversal_of_id is null and original.id is not null and refunded+abs(new.amount)>original.amount then raise exception using errcode='P0001',message='V2_PAYMENT_REFUND_EXCEEDED';end if;
  if sr.id is null or sr.organization_id<>new.organization_id or sv.branch_id<>new.branch_id or sr.register_id<>new.register_id or sv.currency_code<>new.currency_code or((sr.reversal_of_id is null and(new.amount>=0 or new.reversal_of_id is null or original.status<>'confirmed'or original.amount<=0 or original.sale_id is distinct from sr.original_sale_id or original.branch_id<>new.branch_id or original.register_id<>new.register_id))or(sr.reversal_of_id is not null and(new.amount<=0 or new.reversal_of_id is null or original.sale_return_id is distinct from sr.reversal_of_id or new.amount<>-original.amount)))then raise exception using errcode='P0001',message='V2_PAYMENT_SOURCE_GRAPH_MISMATCH';end if;
 elsif new.debt_payment_id is not null then
  select * into dp from public.debt_payments_v2 where id=new.debt_payment_id;
  if dp.id is null or dp.organization_id<>new.organization_id or dp.branch_id<>new.branch_id or dp.register_id<>new.register_id or dp.currency_code<>new.currency_code or((dp.reversal_of_id is null and(new.amount<=0 or new.reversal_of_id is not null))or(dp.reversal_of_id is not null and(new.amount>=0 or new.reversal_of_id is null or original.debt_payment_id is distinct from dp.reversal_of_id or new.amount<>-original.amount)))then raise exception using errcode='P0001',message='V2_PAYMENT_SOURCE_GRAPH_MISMATCH';end if;
 else
  select * into sp from public.supplier_payments where id=new.supplier_payment_id;
  if sp.id is null or sp.organization_id<>new.organization_id or sp.branch_id<>new.branch_id or sp.register_id<>new.register_id or sp.shift_id<>new.shift_id or sp.device_id<>new.device_id or sp.currency_code<>new.currency_code or((sp.reversal_of_id is null and(new.amount>=0 or new.reversal_of_id is not null))or(sp.reversal_of_id is not null and(new.amount<=0 or new.reversal_of_id is null or original.supplier_payment_id is distinct from sp.reversal_of_id or new.amount<>-original.amount)))then raise exception using errcode='P0001',message='V2_PAYMENT_SOURCE_GRAPH_MISMATCH';end if;
 end if;return new;
end$$;

-- Reconciliation helpers -----------------------------------------------------
create or replace function public.v2_recompute_shift_payment_totals(i uuid)
returns table(payment_method text,expected_amount numeric)language sql stable set search_path=''as $$
 select x.m,coalesce(sum(p.amount),0)::numeric from unnest(array['cash','card','transfer'])as x(m)
 left join public.payments_v2 p on p.shift_id=i and p.method=x.m and p.status='confirmed' group by x.m order by x.m
$$;
create or replace function public.v2_expected_physical_cash(i uuid)returns numeric language sql stable set search_path=''as $$
 select coalesce(sum(amount_delta),0)from public.cash_movements where shift_id=i
$$;
create or replace function public.v2_validate_payment_cash_graph(i uuid)returns void language plpgsql set search_path=''as $$
begin
 if exists(select 1 from public.payments_v2 p left join public.cash_movements c on c.source_type='payment'and c.source_id=p.id where p.shift_id=i and p.method='cash'and c.id is null)then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_MOVEMENT_MISSING';end if;
 if exists(select 1 from public.cash_movements c left join public.payments_v2 p on p.id=c.source_id where c.shift_id=i and c.source_type='payment'and(p.id is null or p.method<>'cash'or p.shift_id<>i or p.amount<>c.amount_delta))then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_MOVEMENT_ORPHAN';end if;
end$$;
create or replace function public.v2_cash_count_total(i uuid,c uuid)returns numeric language sql stable set search_path=''as $$
 select coalesce(sum(counted_amount),0)from public.shift_cash_counts where shift_id=i and command_id=c
$$;
create or replace function public.v2_validate_shift_close_snapshot(i uuid,c uuid)returns void language plpgsql set search_path=''as $$
begin
 if c is null then raise exception using errcode='P0001',message='V2_CASH_COMMAND_SCOPE_MISMATCH';end if;
 if exists(select 1 from public.v2_recompute_shift_payment_totals(i)r join public.shift_totals t on t.shift_id=i and t.payment_method=r.payment_method where t.expected_amount<>r.expected_amount)then raise exception using errcode='P0001',message='V2_SHIFT_TOTAL_PROJECTION_DRIFT';end if;
 perform public.v2_validate_payment_cash_graph(i);
end$$;

-- Exact payment -> physical cash append helper ------------------------------
create or replace function public.v2_append_cash_movement_for_payment(payment_id uuid,command_id uuid)returns uuid language plpgsql security definer set search_path=''as $$
declare p public.payments_v2%rowtype;s public.shifts_v2%rowtype;c public.command_log%rowtype;existing uuid;original public.cash_movements%rowtype;mt text;a uuid;begin
 select * into p from public.payments_v2 where id=payment_id;if not found then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_NOT_FOUND';end if;
 if p.method<>'cash'then return null;end if;
 select * into c from public.command_log where id=command_id;select * into s from public.shifts_v2 where id=p.shift_id;
 if c.id is null or c.organization_id<>p.organization_id or c.branch_id is distinct from p.branch_id or c.device_id is distinct from p.device_id or c.status not in('processing','succeeded')or s.id is null or s.status<>'open'then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_COMMAND_MISMATCH';end if;
 select id into existing from public.cash_movements where source_type='payment'and source_id=p.id;if existing is not null then return existing;end if;
 if p.sale_id is not null then mt:='sale';
 elsif p.sale_return_id is not null then mt:='refund';
 elsif p.debt_payment_id is not null then mt:='debt_payment';
 elsif p.supplier_payment_id is not null then mt:='supplier_payment';
 else raise exception using errcode='P0001',message='V2_CASH_PAYMENT_SOURCE_MISMATCH';end if;
 if p.reversal_of_id is not null then
  with recursive chain as(
   select x.id,x.reversal_of_id,0 depth from public.cash_movements x where x.source_type='payment'and x.source_id=p.reversal_of_id
   union all select x.id,x.reversal_of_id,q.depth+1 from public.cash_movements x join chain q on x.reversal_of_id=q.id
  )select x.* into original from chain q join public.cash_movements x on x.id=q.id where not exists(select 1 from public.cash_movements z where z.reversal_of_id=q.id)order by q.depth desc limit 1;
  if original.id is null or not(original.movement_type=mt or(mt='refund'and original.movement_type='sale'))then raise exception using errcode='P0001',message='V2_CASH_PAYMENT_REVERSAL_MISMATCH';end if;
 end if;
 a:=public.v2_current_membership_id(p.organization_id);if a is null then a:=p.created_by;end if;
 perform set_config('market_pos.cash_command','on',true);
 insert into public.cash_movements(organization_id,branch_id,register_id,shift_id,movement_type,amount_delta,currency_code,business_date,source_type,source_id,device_id,local_operation_id,reversal_of_id,command_id,created_by)
 values(p.organization_id,p.branch_id,p.register_id,p.shift_id,mt,p.amount,p.currency_code,s.business_date,'payment',p.id,p.device_id,p.local_operation_id,original.id,command_id,a)returning id into existing;
 perform public.v2_emit_domain_event(p.organization_id,p.branch_id,p.device_id,a,command_id,null,'cash_movement',existing,case when original.id is null then'cash_movement.posted'else'cash_movement.reversed'end,case when original.id is null then'CashMovementPosted'else'CashMovementReversed'end,jsonb_build_object('cash_movement_id',existing,'shift_id',p.shift_id,'movement_type',mt,'amount_delta',p.amount,'currency_code',p.currency_code,'reversal_of_id',original.id));
 perform set_config('market_pos.cash_command','off',true);return existing;
end$$;

-- Shift open and shared open-shift validation -------------------------------
create or replace function public.v2_require_open_sales_shift(o uuid,b uuid,r uuid,sh uuid,d uuid,a uuid)returns public.shifts_v2 language plpgsql security definer set search_path=''as $$
declare x public.shifts_v2%rowtype;m public.organization_memberships%rowtype;begin
 perform public.v2_lock_register_shift_scope(o,b,r);
 select * into x from public.shifts_v2 where id=sh for update;
 if not found or x.status<>'open'or x.organization_id<>o or x.branch_id<>b or x.register_id<>r then raise exception using errcode='P0001',message='V2_SALE_OPEN_SHIFT_REQUIRED';end if;
 if not exists(select 1 from public.registers q where q.id=r and q.organization_id=o and q.branch_id=b and q.status='active')then raise exception using errcode='P0001',message='V2_SALE_OPEN_SHIFT_REQUIRED';end if;
 if not exists(select 1 from public.devices_v2 q where q.id=d and q.organization_id=o and q.branch_id=b and q.register_id=r and q.status='trusted')then raise exception using errcode='P0001',message='V2_SHIFT_DEVICE_SCOPE_MISMATCH';end if;
 select * into m from public.organization_memberships where id=a and organization_id=o and status='active';if not found then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OWNED';end if;
 if m.system_role='seller'and x.opened_by<>a then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OWNED';end if;
 if m.system_role='owner'and not public.v2_can_access_branch(o,b)then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OWNED';end if;return x;
end$$;

create or replace function public.v2_open_shift(o uuid,b uuid,r uuid,d uuid,opening numeric,cur char(3),bd date,op uuid)returns uuid language plpgsql security definer set search_path=''as $$
declare a uuid:=public.v2_current_membership_id(o);i uuid:=gen_random_uuid();c uuid;mv uuid;p jsonb:=jsonb_build_object('organization_id',o,'branch_id',b,'register_id',r,'device_id',d,'opening_cash_amount',opening,'currency_code',cur,'business_date',bd);begin
 if not public.v2_has_permission(o,'shifts.open',b)then raise exception using errcode='P0001',message='V2_SHIFT_OPEN_REQUIRED';end if;
 if a is null then raise exception using errcode='P0001',message='V2_ACTIVE_MEMBERSHIP_REQUIRED';end if;
 if opening<0 or cur is null or cur::text!~'^[A-Z]{3}$'or bd is null then raise exception using errcode='P0001',message='V2_SHIFT_OPEN_INPUT_INVALID';end if;
 c:=public.v2_begin_inventory_command(o,b,d,op,'shift.open',p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(o,b,r);
 if not public.v2_can_access_branch(o,b)or not exists(select 1 from public.registers x where x.id=r and x.organization_id=o and x.branch_id=b and x.status='active')then raise exception using errcode='P0001',message='V2_SHIFT_REGISTER_SCOPE_MISMATCH';end if;
 if not exists(select 1 from public.devices_v2 x where x.id=d and x.organization_id=o and x.branch_id=b and x.register_id=r and x.status='trusted')then raise exception using errcode='P0001',message='V2_SHIFT_DEVICE_SCOPE_MISMATCH';end if;
 if exists(select 1 from public.shifts_v2 where register_id=r and status in('open','closing'))then raise exception using errcode='P0001',message='V2_SHIFT_ALREADY_OPEN';end if;
 perform set_config('market_pos.sales_command','on',true);perform set_config('market_pos.cash_command','on',true);
 insert into public.shifts_v2(id,organization_id,branch_id,register_id,opened_by,opening_cash_amount,business_date,currency_code,open_command_id)values(i,o,b,r,a,opening,bd,cur,c);
 insert into public.shift_totals(organization_id,shift_id,payment_method)values(o,i,'cash'),(o,i,'card'),(o,i,'transfer');
 insert into public.cash_movements(organization_id,branch_id,register_id,shift_id,movement_type,amount_delta,currency_code,business_date,source_type,source_id,device_id,local_operation_id,command_id,created_by)
 values(o,b,r,i,'opening',opening,cur,bd,'shift',i,d,op,c,a)returning id into mv;
 perform public.v2_emit_domain_event(o,b,d,a,c,null,'shift',i,'shift.opened','ShiftOpened',jsonb_build_object('shift_id',i,'business_date',bd,'currency_code',cur));
 perform public.v2_emit_domain_event(o,b,d,a,c,null,'cash_movement',mv,'opening_cash.recorded','OpeningCashRecorded',jsonb_build_object('shift_id',i,'cash_movement_id',mv,'amount_delta',opening,'currency_code',cur));
 perform public.v2_complete_inventory_command(c,'shift',i,jsonb_build_object('id',i,'status','open'));
 perform set_config('market_pos.cash_command','off',true);perform set_config('market_pos.sales_command','off',true);return i;
end$$;

create or replace function public.v2_open_shift(o uuid,b uuid,r uuid,d uuid,opening numeric,op uuid)returns uuid language plpgsql security definer set search_path=''as $$
declare os public.organization_settings%rowtype;begin select * into os from public.organization_settings where organization_id=o;if not found then raise exception using errcode='P0001',message='V2_ORGANIZATION_SETTINGS_REQUIRED';end if;
 return public.v2_open_shift(o,b,r,d,opening,os.currency_code,(clock_timestamp()at time zone os.timezone)::date,op);end$$;

-- Manual cash commands -------------------------------------------------------
create or replace function public.v2_record_cash_movement(shift_id uuid,device_id uuid,movement_type text,amount numeric,currency_code char(3),business_date date,reason text,local_operation_id uuid,approval_id uuid default null)returns uuid language plpgsql security definer set search_path=''as $$
declare s public.shifts_v2%rowtype;a uuid;c uuid;i uuid:=gen_random_uuid();delta numeric;p jsonb:=jsonb_build_object('shift_id',shift_id,'device_id',device_id,'movement_type',movement_type,'amount',amount,'currency_code',currency_code,'business_date',business_date,'reason',reason);begin
 select * into s from public.shifts_v2 where id=shift_id;if not found then raise exception using errcode='P0001',message='V2_SHIFT_NOT_FOUND';end if;
 if not public.v2_has_permission(s.organization_id,'cash.move',s.branch_id)then raise exception using errcode='P0001',message='V2_CASH_MOVE_REQUIRED';end if;
 if movement_type not in('cash_in','cash_out','correction')or reason is null or btrim(reason)=''or currency_code is distinct from s.currency_code or business_date is distinct from s.business_date or(movement_type in('cash_in','cash_out')and amount<=0)or(movement_type='correction'and amount=0)then raise exception using errcode='P0001',message='V2_CASH_MOVEMENT_INPUT_INVALID';end if;
 if movement_type='correction'then if not public.v2_has_permission(s.organization_id,'cash.move.override',s.branch_id)then raise exception using errcode='P0001',message='V2_CASH_OVERRIDE_REQUIRED';end if;c:=public.v2_use_approved_command(approval_id,s.organization_id,'cash.move.override',local_operation_id,p);else c:=public.v2_begin_inventory_command(s.organization_id,s.branch_id,device_id,local_operation_id,'cash.movement.record',p);end if;
 if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(s.organization_id,s.branch_id,s.register_id);select * into s from public.shifts_v2 where id=shift_id for update;
 a:=public.v2_current_membership_id(s.organization_id);perform public.v2_require_open_sales_shift(s.organization_id,s.branch_id,s.register_id,s.id,device_id,a);
 delta:=case movement_type when'cash_in'then amount when'cash_out' then-amount else amount end;
 perform set_config('market_pos.cash_command','on',true);
 insert into public.cash_movements(id,organization_id,branch_id,register_id,shift_id,movement_type,amount_delta,currency_code,business_date,source_type,source_id,reason,device_id,local_operation_id,command_id,approval_request_id,created_by)
 values(i,s.organization_id,s.branch_id,s.register_id,s.id,movement_type,delta,currency_code,business_date,'command',c,reason,device_id,local_operation_id,c,case when movement_type='correction'then approval_id end,a);
 perform public.v2_emit_domain_event(s.organization_id,s.branch_id,device_id,a,c,case when movement_type='correction'then approval_id end,'cash_movement',i,'cash_movement.posted','CashMovementPosted',jsonb_build_object('cash_movement_id',i,'shift_id',s.id,'movement_type',movement_type,'amount_delta',delta,'currency_code',currency_code));
 perform public.v2_complete_inventory_command(c,'cash_movement',i,jsonb_build_object('id',i));perform set_config('market_pos.cash_command','off',true);return i;
end$$;

create or replace function public.v2_reverse_cash_movement(cash_movement_id uuid,current_shift_id uuid,device_id uuid,local_operation_id uuid,approval_id uuid,payload jsonb default'{}')returns uuid language plpgsql security definer set search_path=''as $$
declare o public.cash_movements%rowtype;s public.shifts_v2%rowtype;a uuid;c uuid;i uuid:=gen_random_uuid();p jsonb;begin
 select * into o from public.cash_movements where id=cash_movement_id;if not found then raise exception using errcode='P0001',message='V2_CASH_MOVEMENT_NOT_FOUND';end if;
 if o.movement_type not in('cash_in','cash_out','correction')or o.reversal_of_id is not null then raise exception using errcode='P0001',message='V2_CASH_MANUAL_REVERSAL_FORBIDDEN';end if;
 if not public.v2_has_permission(o.organization_id,'cash.move',o.branch_id)or not public.v2_has_permission(o.organization_id,'cash.move.override',o.branch_id)then raise exception using errcode='P0001',message='V2_CASH_OVERRIDE_REQUIRED';end if;
 select * into s from public.shifts_v2 where id=current_shift_id;if s.id is null or s.organization_id<>o.organization_id or s.branch_id<>o.branch_id or s.register_id<>o.register_id or s.currency_code<>o.currency_code then raise exception using errcode='P0001',message='V2_CASH_REVERSAL_SHIFT_MISMATCH';end if;
 p:=payload||jsonb_build_object('cash_movement_id',cash_movement_id,'current_shift_id',current_shift_id,'device_id',device_id);
 c:=public.v2_use_approved_command(approval_id,o.organization_id,'cash.move.override',local_operation_id,p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(o.organization_id,o.branch_id,o.register_id);select * into s from public.shifts_v2 where id=current_shift_id for update;a:=public.v2_current_membership_id(o.organization_id);perform public.v2_require_open_sales_shift(o.organization_id,o.branch_id,o.register_id,current_shift_id,device_id,a);
 if exists(select 1 from public.cash_movements where reversal_of_id=o.id)then raise exception using errcode='P0001',message='V2_CASH_MOVEMENT_ALREADY_REVERSED';end if;
 perform set_config('market_pos.cash_command','on',true);
 insert into public.cash_movements(id,organization_id,branch_id,register_id,shift_id,movement_type,amount_delta,currency_code,business_date,source_type,source_id,reason,device_id,local_operation_id,reversal_of_id,command_id,approval_request_id,created_by)
 values(i,o.organization_id,o.branch_id,o.register_id,current_shift_id,o.movement_type,-o.amount_delta,o.currency_code,s.business_date,'command',c,'Controlled reversal',device_id,local_operation_id,o.id,c,approval_id,a);
 perform public.v2_emit_domain_event(o.organization_id,o.branch_id,device_id,a,c,approval_id,'cash_movement',i,'cash_movement.reversed','CashMovementReversed',jsonb_build_object('cash_movement_id',i,'reversal_of_id',o.id,'shift_id',current_shift_id,'movement_type',o.movement_type,'amount_delta',-o.amount_delta,'currency_code',o.currency_code));
 perform public.v2_complete_inventory_command(c,'cash_movement',i,jsonb_build_object('id',i));perform set_config('market_pos.cash_command','off',true);return i;
end$$;

-- Supplier settlement source graph -----------------------------------------
alter table public.settlement_entries drop constraint settlement_entries_source_check;
alter table public.settlement_entries add constraint settlement_entries_source_check check(
 source_document_type in('sale','sale_return','debt_payment','purchase','debt_allocation','supplier_payment','cash_movement','goods_taken','offset')
);
drop trigger v2_settlement_entries_guard on public.settlement_entries;
create trigger v2_settlement_entries_guard before insert on public.settlement_entries
for each row when(new.source_document_type<>'supplier_payment')execute function public.v2_guard_settlement_entry();

create or replace function public.v2_guard_supplier_settlement_entry()returns trigger language plpgsql set search_path=''as $$
declare sp public.supplier_payments%rowtype;o public.settlement_entries%rowtype;cmd public.command_log%rowtype;begin
 perform public.v2_lock_settlement_scope(new.organization_id,new.counterparty_id,new.currency_code);
 select * into sp from public.supplier_payments where id=new.source_document_id;select * into cmd from public.command_log where id=new.command_id;
 if sp.id is null or sp.organization_id<>new.organization_id or sp.branch_id<>new.branch_id or sp.counterparty_id<>new.counterparty_id or sp.currency_code<>new.currency_code or sp.command_id<>new.command_id or new.entry_type<>'supplier_payment'or cmd.id is null or cmd.organization_id<>new.organization_id or cmd.status not in('processing','succeeded')then raise exception using errcode='P0001',message='V2_SUPPLIER_SETTLEMENT_SOURCE_MISMATCH';end if;
 if exists(select 1 from public.settlement_periods p where p.organization_id=new.organization_id and p.counterparty_id=new.counterparty_id and p.currency_code=new.currency_code and p.status in('closed','corrected')and new.business_date>=p.starts_on and new.business_date<p.ends_on)then raise exception using errcode='P0001',message='V2_SETTLEMENT_PERIOD_CLOSED';end if;
 if sp.reversal_of_id is null then
  if new.reversal_of_id is not null or new.amount_delta<>sp.total_amount then raise exception using errcode='P0001',message='V2_SUPPLIER_SETTLEMENT_SOURCE_MISMATCH';end if;
 else
  select * into o from public.settlement_entries where id=new.reversal_of_id;
  if o.id is null or o.reversal_of_id is not null or o.source_document_type<>'supplier_payment'or o.source_document_id<>sp.reversal_of_id or o.organization_id<>new.organization_id or o.branch_id<>new.branch_id or o.counterparty_id<>new.counterparty_id or o.currency_code<>new.currency_code or new.amount_delta<>-o.amount_delta or new.amount_delta<>-sp.total_amount then raise exception using errcode='P0001',message='V2_SUPPLIER_SETTLEMENT_REVERSAL_MISMATCH';end if;
 end if;
 if new.approval_request_id is not null and not exists(select 1 from public.approval_requests a where a.id=new.approval_request_id and a.organization_id=new.organization_id and a.command_id=new.command_id and a.status='approved')then raise exception using errcode='P0001',message='V2_SUPPLIER_SETTLEMENT_APPROVAL_MISMATCH';end if;return new;
end$$;
create trigger v2_settlement_entries_guard_supplier before insert on public.settlement_entries
for each row when(new.source_document_type='supplier_payment')execute function public.v2_guard_supplier_settlement_entry();

create or replace function public.v2_record_supplier_payment(organization_id uuid,branch_id uuid,register_id uuid,current_shift_id uuid,counterparty_id uuid,document_number text,business_date date,currency_code char(3),device_id uuid,local_operation_id uuid,client_created_at timestamptz,payments jsonb)returns uuid language plpgsql security definer set search_path=''as $$
declare s public.shifts_v2%rowtype;a uuid;c uuid;i uuid:=gen_random_uuid();entry_id uuid:=gen_random_uuid();p jsonb:=jsonb_build_object('organization_id',organization_id,'branch_id',branch_id,'register_id',register_id,'current_shift_id',current_shift_id,'counterparty_id',counterparty_id,'document_number',document_number,'business_date',business_date,'currency_code',currency_code,'device_id',device_id,'client_created_at',client_created_at,'payments',payments);item jsonb;total numeric:=0;pay_id uuid;balance numeric;begin
 if not public.v2_has_permission(organization_id,'settlements.manage',branch_id)then raise exception using errcode='P0001',message='V2_SETTLEMENTS_MANAGE_REQUIRED';end if;
 if document_number is null or btrim(document_number)=''or jsonb_typeof(payments)<>'array'or jsonb_array_length(payments)=0 then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_INPUT_INVALID';end if;
 for item in select value from jsonb_array_elements(payments)loop
  if jsonb_typeof(item)<>'object'or exists(select 1 from jsonb_object_keys(item)k where k not in('method','amount','local_operation_id'))or item->>'method'not in('cash','card','transfer')or(item->>'amount')::numeric>=0 then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_INPUT_INVALID';end if;
  if item->>'method'='cash'and not public.v2_has_permission(organization_id,'cash.move',branch_id)then raise exception using errcode='P0001',message='V2_CASH_MOVE_REQUIRED';end if;total:=total-(item->>'amount')::numeric;
 end loop;
 c:=public.v2_begin_inventory_command(organization_id,branch_id,device_id,local_operation_id,'supplier_payment.record',p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(organization_id,branch_id,register_id);select * into s from public.shifts_v2 where id=current_shift_id for update;a:=public.v2_current_membership_id(organization_id);perform public.v2_require_open_sales_shift(organization_id,branch_id,register_id,current_shift_id,device_id,a);
 if s.currency_code<>currency_code or s.business_date<>business_date then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_SHIFT_SCOPE_MISMATCH';end if;
 perform public.v2_lock_settlement_scope(organization_id,counterparty_id,currency_code);balance:=public.v2_counterparty_balance(organization_id,counterparty_id,currency_code);
 if balance>=0 or total>abs(balance)then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_EXCEEDS_PAYABLE';end if;
 perform set_config('market_pos.supplier_payment_command','on',true);perform set_config('market_pos.sales_command','on',true);perform set_config('market_pos.settlement_command','on',true);
 insert into public.supplier_payments(id,organization_id,branch_id,register_id,counterparty_id,shift_id,document_number,business_date,total_amount,currency_code,device_id,local_operation_id,client_created_at,posted_by,command_id)
 values(i,organization_id,branch_id,register_id,counterparty_id,current_shift_id,document_number,business_date,total,currency_code,device_id,local_operation_id,client_created_at,a,c);
 for item in select value from jsonb_array_elements(payments)loop
  pay_id:=gen_random_uuid();insert into public.payments_v2(id,organization_id,branch_id,register_id,shift_id,supplier_payment_id,method,amount,currency_code,device_id,local_operation_id,created_by)
  values(pay_id,organization_id,branch_id,register_id,current_shift_id,i,item->>'method',(item->>'amount')::numeric,currency_code,device_id,coalesce((item->>'local_operation_id')::uuid,gen_random_uuid()),a);
  insert into public.shift_totals(organization_id,shift_id,payment_method,expected_amount,version)values(organization_id,current_shift_id,item->>'method',(item->>'amount')::numeric,1)on conflict(shift_id,payment_method)do update set expected_amount=public.shift_totals.expected_amount+excluded.expected_amount,version=public.shift_totals.version+1,updated_at=now();
  perform public.v2_append_cash_movement_for_payment(pay_id,c);
 end loop;
 insert into public.settlement_entries(id,organization_id,branch_id,counterparty_id,entry_type,amount_delta,currency_code,business_date,source_document_type,source_document_id,command_id,created_by)
 values(entry_id,organization_id,branch_id,counterparty_id,'supplier_payment',total,currency_code,business_date,'supplier_payment',i,c,a);
 perform public.v2_emit_domain_event(organization_id,branch_id,device_id,a,c,null,'supplier_payment',i,'supplier_payment.recorded','SupplierPaymentRecorded',jsonb_build_object('supplier_payment_id',i,'amount',total,'currency_code',currency_code));
 perform public.v2_emit_domain_event(organization_id,branch_id,device_id,a,c,null,'settlement_entry',entry_id,'settlement.entry.posted','SettlementEntryPosted',jsonb_build_object('settlement_entry_id',entry_id,'source_type','supplier_payment','source_id',i));
 perform public.v2_complete_inventory_command(c,'supplier_payment',i,jsonb_build_object('id',i));perform set_config('market_pos.settlement_command','off',true);perform set_config('market_pos.sales_command','off',true);perform set_config('market_pos.supplier_payment_command','off',true);return i;
end$$;

create or replace function public.v2_reverse_supplier_payment(supplier_payment_id uuid,current_shift_id uuid,document_number text,device_id uuid,local_operation_id uuid,approval_id uuid,payload jsonb default'{}')returns uuid language plpgsql security definer set search_path=''as $$
declare o public.supplier_payments%rowtype;s public.shifts_v2%rowtype;a uuid;c uuid;i uuid:=gen_random_uuid();entry_id uuid:=gen_random_uuid();primary_entry public.settlement_entries%rowtype;p jsonb;pay public.payments_v2%rowtype;np uuid;begin
 select * into o from public.supplier_payments where id=supplier_payment_id;if not found then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_NOT_FOUND';end if;
 if not public.v2_has_permission(o.organization_id,'settlements.reverse',o.branch_id)then raise exception using errcode='P0001',message='V2_SETTLEMENTS_REVERSE_REQUIRED';end if;
 p:=payload||jsonb_build_object('supplier_payment_id',supplier_payment_id,'current_shift_id',current_shift_id,'document_number',document_number,'device_id',device_id);
 c:=public.v2_use_approved_command(approval_id,o.organization_id,'settlements.reverse',local_operation_id,p);if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(o.organization_id,o.branch_id,o.register_id);select * into s from public.shifts_v2 where id=current_shift_id for update;a:=public.v2_current_membership_id(o.organization_id);perform public.v2_require_open_sales_shift(o.organization_id,o.branch_id,o.register_id,current_shift_id,device_id,a);
 perform public.v2_lock_settlement_scope(o.organization_id,o.counterparty_id,o.currency_code);select * into o from public.supplier_payments where id=supplier_payment_id for update;
 if o.status<>'posted'or o.reversal_of_id is not null or exists(select 1 from public.supplier_payments z where z.reversal_of_id=o.id)then raise exception using errcode='P0001',message='V2_SUPPLIER_PAYMENT_ALREADY_REVERSED';end if;
 perform set_config('market_pos.supplier_payment_command','on',true);perform set_config('market_pos.sales_command','on',true);perform set_config('market_pos.settlement_command','on',true);
 insert into public.supplier_payments(id,organization_id,branch_id,register_id,counterparty_id,shift_id,document_number,business_date,total_amount,currency_code,device_id,local_operation_id,client_created_at,posted_by,reversal_of_id,command_id,approval_request_id)
 values(i,o.organization_id,o.branch_id,o.register_id,o.counterparty_id,current_shift_id,document_number,s.business_date,o.total_amount,o.currency_code,device_id,local_operation_id,clock_timestamp(),a,o.id,c,approval_id);
 for pay in select p0.* from public.payments_v2 p0 where p0.supplier_payment_id=o.id and p0.reversal_of_id is null order by p0.id loop
  np:=gen_random_uuid();insert into public.payments_v2(id,organization_id,branch_id,register_id,shift_id,supplier_payment_id,method,amount,currency_code,device_id,local_operation_id,reversal_of_id,created_by)
  values(np,o.organization_id,o.branch_id,o.register_id,current_shift_id,i,pay.method,-pay.amount,pay.currency_code,device_id,gen_random_uuid(),pay.id,a);
  update public.shift_totals set expected_amount=expected_amount-pay.amount,version=version+1,updated_at=now()where shift_id=current_shift_id and payment_method=pay.method;perform public.v2_append_cash_movement_for_payment(np,c);
 end loop;
 select * into primary_entry from public.settlement_entries where source_document_type='supplier_payment'and source_document_id=o.id and entry_type='supplier_payment'and reversal_of_id is null;
 insert into public.settlement_entries(id,organization_id,branch_id,counterparty_id,entry_type,amount_delta,currency_code,business_date,source_document_type,source_document_id,reversal_of_id,command_id,approval_request_id,created_by)
 values(entry_id,o.organization_id,o.branch_id,o.counterparty_id,'supplier_payment',-o.total_amount,o.currency_code,s.business_date,'supplier_payment',i,primary_entry.id,c,approval_id,a);
 update public.supplier_payments set status='reversed'where id=o.id;
 perform public.v2_emit_domain_event(o.organization_id,o.branch_id,device_id,a,c,approval_id,'supplier_payment',i,'supplier_payment.reversed','SupplierPaymentReversed',jsonb_build_object('supplier_payment_id',i,'reversal_of_id',o.id,'amount',o.total_amount,'currency_code',o.currency_code));
 perform public.v2_emit_domain_event(o.organization_id,o.branch_id,device_id,a,c,approval_id,'settlement_entry',entry_id,'settlement.entry.reversed','SettlementEntryReversed',jsonb_build_object('settlement_entry_id',entry_id,'reversal_of_id',primary_entry.id));
 perform public.v2_complete_inventory_command(c,'supplier_payment',i,jsonb_build_object('id',i));perform set_config('market_pos.settlement_command','off',true);perform set_config('market_pos.sales_command','off',true);perform set_config('market_pos.supplier_payment_command','off',true);return i;
end$$;

-- Canonical close ------------------------------------------------------------
create or replace function public.v2_close_shift(i uuid,d uuid,actuals jsonb,counts jsonb,op uuid,approval uuid default null)returns uuid language plpgsql security definer set search_path=''as $$
declare s public.shifts_v2%rowtype;a uuid;c uuid;p jsonb;item jsonb;expected_cash numeric;actual_cash numeric;manual_delta numeric;cash_actual_equiv numeric;cash_expected numeric;card_expected numeric;transfer_expected numeric;cash_diff numeric;card_diff numeric;transfer_diff numeric;line_count integer:=0;cfg jsonb;begin
 select * into s from public.shifts_v2 where id=i;if not found then raise exception using errcode='P0001',message='V2_SHIFT_NOT_FOUND';end if;
 if not public.v2_has_permission(s.organization_id,'shifts.close',s.branch_id)then raise exception using errcode='P0001',message='V2_SHIFT_CLOSE_REQUIRED';end if;
 if jsonb_typeof(actuals)<>'object'or actuals is null or exists(select 1 from jsonb_object_keys(actuals)k where k not in('cash','card','transfer'))or not(actuals?'cash'and actuals?'card'and actuals?'transfer')or(select count(*)from jsonb_object_keys(actuals))<>3 or jsonb_typeof(actuals->'cash')<>'number'or jsonb_typeof(actuals->'card')<>'number'or jsonb_typeof(actuals->'transfer')<>'number'or(actuals->>'cash')::numeric<0 then raise exception using errcode='P0001',message='V2_SHIFT_ACTUAL_TOTALS_INVALID';end if;
 if jsonb_typeof(counts)<>'array'or jsonb_array_length(counts)=0 then raise exception using errcode='P0001',message='V2_SHIFT_CASH_COUNTS_REQUIRED';end if;
 for item in select value from jsonb_array_elements(counts)loop
  if jsonb_typeof(item)<>'object'or exists(select 1 from jsonb_object_keys(item)k where k not in('line_number','denomination_value','quantity'))or not(item?'line_number'and item?'denomination_value'and item?'quantity')or(item->>'line_number')::integer<=0 or(item->>'denomination_value')::numeric<=0 or(item->>'quantity')::integer<0 then raise exception using errcode='P0001',message='V2_SHIFT_CASH_COUNTS_INVALID';end if;line_count:=line_count+1;
 end loop;
 actual_cash:=(actuals->>'cash')::numeric;p:=jsonb_build_object('shift_id',i,'device_id',d,'actual_totals',actuals,'cash_counts',counts);
 if approval is null then c:=public.v2_begin_inventory_command(s.organization_id,s.branch_id,d,op,'shift.close',p);else c:=public.v2_use_approved_command(approval,s.organization_id,'cash.move.override',op,p);end if;
 if(select status='succeeded'from public.command_log where id=c)then return(select entity_id from public.command_log where id=c);end if;
 perform public.v2_lock_register_shift_scope(s.organization_id,s.branch_id,s.register_id);select * into s from public.shifts_v2 where id=i for update;a:=public.v2_current_membership_id(s.organization_id);
 if exists(select 1 from public.organization_memberships where id=a and system_role='seller')and a<>s.opened_by then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OWNED';end if;
 if exists(select 1 from public.organization_memberships where id=a and system_role='owner')and not public.v2_can_access_branch(s.organization_id,s.branch_id)then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OWNED';end if;
 if not exists(select 1 from public.devices_v2 q where q.id=d and q.organization_id=s.organization_id and q.branch_id=s.branch_id and q.register_id=s.register_id and q.status='trusted')then raise exception using errcode='P0001',message='V2_SHIFT_DEVICE_SCOPE_MISMATCH';end if;
 if s.status<>'open'then raise exception using errcode='P0001',message='V2_SHIFT_NOT_OPEN';end if;
 select settings->'fiscal'into cfg from public.registers where id=s.register_id;
 if coalesce(cfg->>'mode','disabled')='required'and exists(select 1 from public.fiscal_documents f where f.shift_id=i and f.status not in('issued','cancelled'))then raise exception using errcode='P0001',message='V2_SHIFT_FISCAL_NONTERMINAL';end if;
 perform set_config('market_pos.sales_command','on',true);perform set_config('market_pos.cash_command','on',true);
 update public.shifts_v2 set status='closing',close_command_id=c,version=version+1 where id=i returning * into s;
 perform 1 from public.payments_v2 where shift_id=i order by id for update;perform 1 from public.cash_movements where shift_id=i order by id for update;perform 1 from public.shift_totals where shift_id=i order by payment_method for update;
 perform public.v2_validate_shift_close_snapshot(i,c);
 select expected_amount into cash_expected from public.v2_recompute_shift_payment_totals(i)where payment_method='cash';select expected_amount into card_expected from public.v2_recompute_shift_payment_totals(i)where payment_method='card';select expected_amount into transfer_expected from public.v2_recompute_shift_payment_totals(i)where payment_method='transfer';
 expected_cash:=public.v2_expected_physical_cash(i);select coalesce(sum(amount_delta),0)into manual_delta from public.cash_movements where shift_id=i and source_type='command';cash_actual_equiv:=actual_cash-s.opening_cash_amount-manual_delta;
 for item in select value from jsonb_array_elements(counts)loop
  insert into public.shift_cash_counts(organization_id,branch_id,register_id,shift_id,line_number,denomination_value,quantity,counted_amount,currency_code,command_id,counted_by)
  values(s.organization_id,s.branch_id,s.register_id,i,(item->>'line_number')::integer,(item->>'denomination_value')::numeric,(item->>'quantity')::integer,(item->>'denomination_value')::numeric*(item->>'quantity')::integer,s.currency_code,c,a);
 end loop;
 if public.v2_cash_count_total(i,c)<>actual_cash then raise exception using errcode='P0001',message='V2_SHIFT_CASH_COUNT_TOTAL_MISMATCH';end if;
 cash_diff:=actual_cash-expected_cash;card_diff:=(actuals->>'card')::numeric-card_expected;transfer_diff:=(actuals->>'transfer')::numeric-transfer_expected;
 if(cash_diff<>0 or card_diff<>0 or transfer_diff<>0)then
  if approval is null or not public.v2_has_permission(s.organization_id,'cash.move.override',s.branch_id)then raise exception using errcode='P0001',message='V2_SHIFT_DISCREPANCY_APPROVAL_REQUIRED';end if;
 end if;
 update public.shift_totals set expected_amount=case payment_method when'cash'then cash_expected when'card'then card_expected else transfer_expected end,
  actual_amount=case payment_method when'cash'then cash_actual_equiv when'card'then(actuals->>'card')::numeric else(actuals->>'transfer')::numeric end,version=version+1,updated_at=now()where shift_id=i;
 update public.shifts_v2 set status='closed',closed_by=a,closed_at=clock_timestamp(),expected_cash_amount=expected_cash,actual_cash_amount=actual_cash,difference_amount=cash_diff,close_approval_id=case when cash_diff<>0 or card_diff<>0 or transfer_diff<>0 then approval end,version=version+1 where id=i;
 if cash_diff<>0 or card_diff<>0 or transfer_diff<>0 then perform public.v2_emit_domain_event(s.organization_id,s.branch_id,d,a,c,approval,'shift',i,'shift.discrepancy.detected','ShiftDiscrepancyDetected',jsonb_build_object('shift_id',i,'cash_difference',cash_diff,'card_difference',card_diff,'transfer_difference',transfer_diff,'currency_code',s.currency_code));end if;
 perform public.v2_emit_domain_event(s.organization_id,s.branch_id,d,a,c,case when cash_diff<>0 or card_diff<>0 or transfer_diff<>0 then approval end,'shift',i,'shift.closed','ShiftClosed',jsonb_build_object('shift_id',i,'expected_cash_amount',expected_cash,'actual_cash_amount',actual_cash,'difference_amount',cash_diff,'currency_code',s.currency_code));
 perform public.v2_complete_inventory_command(c,'shift',i,jsonb_build_object('id',i,'status','closed'));perform set_config('market_pos.cash_command','off',true);perform set_config('market_pos.sales_command','off',true);return i;
end$$;

create or replace function public.v2_close_shift(i uuid,d uuid,actual numeric,op uuid)returns uuid language plpgsql security definer set search_path=''as $$
begin perform 1 from public.shifts_v2 where id=i;if not found then raise exception using errcode='P0001',message='V2_SHIFT_NOT_FOUND';end if;
 if actual<0 then raise exception using errcode='P0001',message='V2_SHIFT_ACTUAL_CASH_INVALID';end if;
 if exists(select 1 from public.shift_totals where shift_id=i and payment_method in('card','transfer')and expected_amount<>0)then raise exception using errcode='P0001',message='V2_SHIFT_ACTUAL_TOTALS_REQUIRED';end if;
 return public.v2_close_shift(i,d,jsonb_build_object('cash',actual,'card',0,'transfer',0),jsonb_build_array(jsonb_build_object('line_number',1,'denomination_value',case when actual=0 then 1 else actual end,'quantity',case when actual=0 then 0 else 1 end)),op,null);
end$$;

-- Controlled wrappers add exact cash rows to every existing payment writer. --
alter function public.v2_post_sale(uuid,uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb,uuid,jsonb)rename to v2_post_sale_0015_cash_base;
alter function public.v2_post_sale_return(uuid,uuid,text,uuid,uuid,jsonb,jsonb)rename to v2_post_sale_return_0015_cash_base;
alter function public.v2_reverse_sale(uuid,uuid,text,uuid,uuid,uuid,jsonb)rename to v2_reverse_sale_0015_cash_base;
alter function public.v2_reverse_sale_return(uuid,uuid,text,uuid,uuid,uuid,jsonb)rename to v2_reverse_sale_return_0015_cash_base;
alter function public.v2_record_debt_payment(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb)rename to v2_record_debt_payment_0015_cash_base;
alter function public.v2_reverse_debt_payment(uuid,uuid,text,uuid,uuid,uuid,jsonb)rename to v2_reverse_debt_payment_0015_cash_base;

create or replace function public.v2_post_sale(o uuid,b uuid,r uuid,w uuid,sh uuid,customer uuid,n text,bd date,cur char(3),d uuid,op uuid,client_at timestamptz,lines jsonb,pays jsonb,approval uuid,debt_terms jsonb)returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;pmt record;begin
 -- The 0015 base retains FOR UPDATE, V2_SALE_DEBT_DUE_DATE_INVALID,
 -- V2_SALE_MULTIPLE_APPROVALS_REQUIRED and limit_override_approval_id checks.
 if customer is not null then perform public.v2_lock_settlement_scope(o,customer,cur);end if;perform public.v2_lock_register_shift_scope(o,b,r);
 i:=public.v2_post_sale_0015_cash_base(o,b,r,w,sh,customer,n,bd,cur,d,op,client_at,lines,pays,approval,debt_terms);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;for pmt in select id from public.payments_v2 where sale_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;
create or replace function public.v2_post_sale_return(sale uuid,sh uuid,n text,d uuid,op uuid,lines jsonb,pays jsonb)returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;sr public.sale_returns%rowtype;s public.sales_v2%rowtype;pmt record;begin
 -- v2_lock_settlement_scope is acquired by the hardened 0015 base before settlement reads.
 i:=public.v2_post_sale_return_0015_cash_base(sale,sh,n,d,op,lines,pays);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;select * into sr from public.sale_returns where id=i;select * into s from public.sales_v2 where id=sr.original_sale_id;perform public.v2_lock_register_shift_scope(sr.organization_id,s.branch_id,sr.register_id);for pmt in select id from public.payments_v2 where sale_return_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;
create or replace function public.v2_reverse_sale(sale uuid,sh uuid,n text,d uuid,op uuid,approval uuid,payload jsonb default'{}')returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;s public.sales_v2%rowtype;pmt record;begin
 -- v2_lock_settlement_scope, v2_lock_inventory_scopes and reversal_of_id validation
 -- are retained by the hardened 0015 base before financial mutation.
 i:=public.v2_reverse_sale_0015_cash_base(sale,sh,n,d,op,approval,payload);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;select * into s from public.sales_v2 where id=i;perform public.v2_lock_register_shift_scope(s.organization_id,s.branch_id,s.register_id);for pmt in select id from public.payments_v2 where sale_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;
create or replace function public.v2_reverse_sale_return(ret uuid,sh uuid,n text,d uuid,op uuid,approval uuid,payload jsonb default'{}')returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;sr public.sale_returns%rowtype;s public.sales_v2%rowtype;pmt record;begin
 -- v2_lock_settlement_scope is acquired by the hardened 0015 base before settlement reads.
 i:=public.v2_reverse_sale_return_0015_cash_base(ret,sh,n,d,op,approval,payload);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;select * into sr from public.sale_returns where id=i;select * into s from public.sales_v2 where id=sr.original_sale_id;perform public.v2_lock_register_shift_scope(sr.organization_id,s.branch_id,sr.register_id);for pmt in select id from public.payments_v2 where sale_return_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;
create or replace function public.v2_record_debt_payment(organization_id uuid,branch_id uuid,register_id uuid,current_shift_id uuid,counterparty_id uuid,document_number text,business_date date,currency_code char(3),device_id uuid,local_operation_id uuid,client_created_at timestamptz,payments jsonb,allocations jsonb)returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;pmt record;begin perform public.v2_lock_settlement_scope(organization_id,counterparty_id,currency_code);perform public.v2_lock_register_shift_scope(organization_id,branch_id,register_id);i:=public.v2_record_debt_payment_0015_cash_base(organization_id,branch_id,register_id,current_shift_id,counterparty_id,document_number,business_date,currency_code,device_id,local_operation_id,client_created_at,payments,allocations);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;for pmt in select id from public.payments_v2 where debt_payment_id=i order by id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;
create or replace function public.v2_reverse_debt_payment(debt_payment_id uuid,current_shift_id uuid,document_number text,device_id uuid,local_operation_id uuid,approval_id uuid,payload jsonb default'{}')returns uuid language plpgsql security definer set search_path=''as $$
declare i uuid;c uuid;dp public.debt_payments_v2%rowtype;pmt record;begin
 -- v2_lock_settlement_scope is acquired by the hardened 0015 base before settlement reads.
 i:=public.v2_reverse_debt_payment_0015_cash_base(debt_payment_id,current_shift_id,document_number,device_id,local_operation_id,approval_id,payload);c:=nullif(current_setting('market_pos.current_command_id',true),'')::uuid;select * into dp from public.debt_payments_v2 where id=i;perform public.v2_lock_register_shift_scope(dp.organization_id,dp.branch_id,dp.register_id);for pmt in select p0.id from public.payments_v2 p0 where p0.debt_payment_id=i order by p0.id loop perform public.v2_append_cash_movement_for_payment(pmt.id,c);end loop;return i;end$$;

-- RLS and safe read surfaces -------------------------------------------------
create or replace function public.v2_cash_journal(o uuid,b uuid,sh uuid)
returns table(movement_type text,amount_delta numeric,currency_code char(3),created_at timestamptz,shift_id uuid)
language sql stable security definer set search_path=''as $$
 select c.movement_type,c.amount_delta,c.currency_code,c.created_at,c.shift_id from public.cash_movements c
 where c.organization_id=o and c.branch_id=b and c.shift_id=sh and(
  (exists(select 1 from public.shifts_v2 s join public.organization_memberships m on m.id=public.v2_current_membership_id(o)where s.id=sh and s.opened_by=m.id and m.system_role='seller'and m.status='active'))
  or public.v2_has_permission(o,'cash.view',b)or public.v2_has_support_grant(o,'cash.view')
 )order by c.created_at,c.id
$$;

create or replace function public.v2_shift_reconciliation(i uuid)
returns table(shift_id uuid,status text,currency_code char(3),expected_cash_amount numeric,actual_cash_amount numeric,difference_amount numeric,payment_totals jsonb)
language plpgsql stable security definer set search_path=''as $$
declare s public.shifts_v2%rowtype;totals jsonb;begin select * into s from public.shifts_v2 where id=i;if not found then return;end if;
 if not(public.v2_has_permission(s.organization_id,'cash.view',s.branch_id)or public.v2_has_support_grant(s.organization_id,'cash.view'))then raise exception using errcode='P0001',message='V2_CASH_VIEW_REQUIRED';end if;
 select jsonb_object_agg(t.payment_method,jsonb_build_object('expected',t.expected_amount,'actual',t.actual_amount,'version',t.version)order by t.payment_method)into totals from public.shift_totals t where t.shift_id=i;
 return query select s.id,s.status,s.currency_code,s.expected_cash_amount,s.actual_cash_amount,s.difference_amount,coalesce(totals,'{}'::jsonb);
end$$;

create or replace function public.v2_supplier_payment_journal(o uuid,b uuid,cp uuid)
returns table(id uuid,document_number text,business_date date,total_amount numeric,currency_code char(3),status text,reversal_of_id uuid,posted_at timestamptz)
language plpgsql stable security definer set search_path=''as $$
begin
 if not(public.v2_has_permission(o,'settlements.view',b)or public.v2_has_permission(o,'settlements.manage',b)or public.v2_has_support_grant(o,'settlements.view'))or not public.v2_can_view_full_settlement_scope(o,cp,(select p0.currency_code from public.supplier_payments p0 where p0.organization_id=o and p0.counterparty_id=cp order by p0.posted_at desc limit 1),null,null)then raise exception using errcode='P0001',message='V2_SETTLEMENT_FULL_VISIBILITY_REQUIRED';end if;
 return query select p.id,p.document_number,p.business_date,p.total_amount,p.currency_code,p.status,p.reversal_of_id,p.posted_at from public.supplier_payments p where p.organization_id=o and p.branch_id=b and p.counterparty_id=cp order by p.business_date,p.posted_at,p.id;
end$$;

alter table public.cash_movements enable row level security;
alter table public.shift_cash_counts enable row level security;
alter table public.supplier_payments enable row level security;
create policy cash_movements_owner_select on public.cash_movements for select to authenticated using(
 public.v2_has_permission(organization_id,'cash.view',branch_id)and exists(select 1 from public.organization_memberships m where m.id=public.v2_current_membership_id(organization_id)and m.system_role='owner'and m.status='active')
);
create policy shift_cash_counts_owner_select on public.shift_cash_counts for select to authenticated using(
 public.v2_has_permission(organization_id,'cash.view',branch_id)and exists(select 1 from public.organization_memberships m where m.id=public.v2_current_membership_id(organization_id)and m.system_role='owner'and m.status='active')
);
create policy supplier_payments_owner_select on public.supplier_payments for select to authenticated using(
 (public.v2_has_permission(organization_id,'settlements.view',branch_id)or public.v2_has_permission(organization_id,'settlements.manage',branch_id))
 and public.v2_can_view_full_settlement_scope(organization_id,counterparty_id,currency_code,null,null)
 and exists(select 1 from public.organization_memberships m where m.id=public.v2_current_membership_id(organization_id)and m.system_role='owner'and m.status='active')
);

revoke all on public.cash_movements,public.shift_cash_counts,public.supplier_payments from anon,authenticated,service_role;
grant select on public.cash_movements,public.shift_cash_counts,public.supplier_payments to authenticated;

revoke execute on function public.v2_lock_register_shift_scope(uuid,uuid,uuid),public.v2_cash_context_required(),public.v2_cash_append_only(),public.v2_supplier_payment_context_required(),public.v2_guard_cash_movement(),public.v2_guard_shift_cash_count(),public.v2_guard_supplier_payment(),public.v2_guard_supplier_settlement_entry(),public.v2_recompute_shift_payment_totals(uuid),public.v2_expected_physical_cash(uuid),public.v2_validate_payment_cash_graph(uuid),public.v2_cash_count_total(uuid,uuid),public.v2_validate_shift_close_snapshot(uuid,uuid),public.v2_append_cash_movement_for_payment(uuid,uuid),public.v2_post_sale_0015_cash_base(uuid,uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb,uuid,jsonb),public.v2_post_sale_return_0015_cash_base(uuid,uuid,text,uuid,uuid,jsonb,jsonb),public.v2_reverse_sale_0015_cash_base(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_reverse_sale_return_0015_cash_base(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_record_debt_payment_0015_cash_base(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb),public.v2_reverse_debt_payment_0015_cash_base(uuid,uuid,text,uuid,uuid,uuid,jsonb)from public,anon,authenticated;
revoke execute on function public.v2_cash_journal(uuid,uuid,uuid),public.v2_shift_reconciliation(uuid),public.v2_supplier_payment_journal(uuid,uuid,uuid),public.v2_open_shift(uuid,uuid,uuid,uuid,numeric,character,date,uuid),public.v2_open_shift(uuid,uuid,uuid,uuid,numeric,uuid),public.v2_record_cash_movement(uuid,uuid,text,numeric,character,date,text,uuid,uuid),public.v2_reverse_cash_movement(uuid,uuid,uuid,uuid,uuid,jsonb),public.v2_record_supplier_payment(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb),public.v2_reverse_supplier_payment(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid),public.v2_close_shift(uuid,uuid,numeric,uuid)from public,anon;
grant execute on function public.v2_cash_journal(uuid,uuid,uuid),public.v2_shift_reconciliation(uuid),public.v2_supplier_payment_journal(uuid,uuid,uuid),public.v2_open_shift(uuid,uuid,uuid,uuid,numeric,character,date,uuid),public.v2_open_shift(uuid,uuid,uuid,uuid,numeric,uuid),public.v2_record_cash_movement(uuid,uuid,text,numeric,character,date,text,uuid,uuid),public.v2_reverse_cash_movement(uuid,uuid,uuid,uuid,uuid,jsonb),public.v2_record_supplier_payment(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb),public.v2_reverse_supplier_payment(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_close_shift(uuid,uuid,jsonb,jsonb,uuid,uuid),public.v2_close_shift(uuid,uuid,numeric,uuid)to authenticated;
revoke execute on function public.v2_post_sale(uuid,uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb,uuid,jsonb),public.v2_post_sale_return(uuid,uuid,text,uuid,uuid,jsonb,jsonb),public.v2_reverse_sale(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_reverse_sale_return(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_record_debt_payment(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb),public.v2_reverse_debt_payment(uuid,uuid,text,uuid,uuid,uuid,jsonb)from public,anon;
grant execute on function public.v2_post_sale(uuid,uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb,uuid,jsonb),public.v2_post_sale_return(uuid,uuid,text,uuid,uuid,jsonb,jsonb),public.v2_reverse_sale(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_reverse_sale_return(uuid,uuid,text,uuid,uuid,uuid,jsonb),public.v2_record_debt_payment(uuid,uuid,uuid,uuid,uuid,text,date,character,uuid,uuid,timestamptz,jsonb,jsonb),public.v2_reverse_debt_payment(uuid,uuid,text,uuid,uuid,uuid,jsonb)to authenticated;
