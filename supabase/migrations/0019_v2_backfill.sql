-- MARKET POS V2: CONTROLLED CURRENT-STATE BACKFILL
-- V1 transactional history remains immutable evidence; only provable current
-- identity, access, location, catalog, counterparty and pricing state is mapped.

create table public.migration_backfill_runs(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  mode text not null default 'dry_run' check(mode in('dry_run','apply')),
  source_snapshot_at timestamptz not null,
  status text not null default 'running'
    check(status in('running','completed','prepared','blocked','stale')),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  summary jsonb not null default '{}'::jsonb check(jsonb_typeof(summary)='object'),
  created_at timestamptz not null default now(),
  constraint migration_backfill_runs_finish_check check(
    (status='running'and finished_at is null)or
    (status<>'running'and finished_at is not null)
  )
);
create index migration_backfill_runs_org_started_idx
  on public.migration_backfill_runs(organization_id,started_at desc,id);

create table public.migration_backfill_checkpoints(
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.migration_backfill_runs(id) on delete restrict,
  phase text not null,
  last_legacy_key text,
  processed_count bigint not null default 0 check(processed_count>=0),
  mapped_count bigint not null default 0 check(mapped_count>=0),
  finding_count bigint not null default 0 check(finding_count>=0),
  status text not null default 'pending' check(status in('pending','running','completed')),
  updated_at timestamptz not null default now(),
  unique(run_id,phase)
);
create index migration_backfill_checkpoints_run_status_idx
  on public.migration_backfill_checkpoints(run_id,status,phase);

create table public.migration_entity_mappings(
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  legacy_table text not null check(btrim(legacy_table)<>''),
  legacy_key text not null check(btrim(legacy_key)<>''),
  target_table text not null check(btrim(target_table)<>''),
  target_id uuid not null,
  mapping_kind text not null check(mapping_kind in('exact','generated')),
  created_at timestamptz not null default now(),
  unique(organization_id,legacy_table,legacy_key,target_table)
);
create index migration_entity_mappings_target_idx
  on public.migration_entity_mappings(organization_id,target_table,target_id);

create table public.migration_backfill_findings(
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.migration_backfill_runs(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  phase text not null check(btrim(phase)<>''),
  legacy_table text not null check(btrim(legacy_table)<>''),
  legacy_id text,
  severity text not null check(severity in('info','warning','blocker')),
  error_code text not null check(btrim(error_code)<>''),
  details jsonb not null default '{}'::jsonb check(jsonb_typeof(details)='object'),
  created_at timestamptz not null default now()
);
create unique index migration_backfill_findings_identity_key
  on public.migration_backfill_findings(
    run_id,legacy_table,coalesce(legacy_id,''),error_code
  );
create index migration_backfill_findings_run_severity_idx
  on public.migration_backfill_findings(run_id,severity,phase,id);

create or replace function public.v2_guard_backfill_evidence()
returns trigger language plpgsql set search_path='' as $$
declare new_row jsonb;old_row jsonb;
begin
  if tg_op='DELETE'then
    raise exception using errcode='P0001',message='V2_BACKFILL_HARD_DELETE_FORBIDDEN';
  end if;
  if tg_table_name in('migration_entity_mappings','migration_backfill_findings')then
    raise exception using errcode='P0001',message='V2_BACKFILL_EVIDENCE_IMMUTABLE';
  end if;
  new_row:=to_jsonb(new);old_row:=to_jsonb(old);
  if tg_table_name='migration_backfill_runs'and(
    new_row->'id' is distinct from old_row->'id' or
    new_row->'organization_id' is distinct from old_row->'organization_id' or
    new_row->'mode' is distinct from old_row->'mode' or
    new_row->'source_snapshot_at' is distinct from old_row->'source_snapshot_at' or
    new_row->'started_at' is distinct from old_row->'started_at' or
    new_row->'created_at' is distinct from old_row->'created_at'
  )then
    raise exception using errcode='P0001',message='V2_BACKFILL_RUN_IDENTITY_IMMUTABLE';
  end if;
  if tg_table_name='migration_backfill_checkpoints'and(
    new_row->'id' is distinct from old_row->'id' or
    new_row->'run_id' is distinct from old_row->'run_id' or
    new_row->'phase' is distinct from old_row->'phase'
  )then
    raise exception using errcode='P0001',message='V2_BACKFILL_CHECKPOINT_IDENTITY_IMMUTABLE';
  end if;
  return new;
end$$;

create trigger v2_backfill_runs_guard before update or delete
on public.migration_backfill_runs for each row execute function public.v2_guard_backfill_evidence();
create trigger v2_backfill_checkpoints_guard before update or delete
on public.migration_backfill_checkpoints for each row execute function public.v2_guard_backfill_evidence();
create trigger v2_backfill_mappings_guard before update or delete
on public.migration_entity_mappings for each row execute function public.v2_guard_backfill_evidence();
create trigger v2_backfill_findings_guard before update or delete
on public.migration_backfill_findings for each row execute function public.v2_guard_backfill_evidence();

alter table public.migration_backfill_runs enable row level security;
alter table public.migration_backfill_checkpoints enable row level security;
alter table public.migration_entity_mappings enable row level security;
alter table public.migration_backfill_findings enable row level security;
revoke all on table public.migration_backfill_runs,
  public.migration_backfill_checkpoints,public.migration_entity_mappings,
  public.migration_backfill_findings from public,anon,authenticated,service_role;

create or replace function public.v2_backfill_uuid_fragment(value uuid)
returns text language sql immutable strict set search_path='' as $$
  select upper(right(replace(value::text,'-',''),12))
$$;

create or replace function public.v2_backfill_source_fingerprint(organization_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'product_batches',(
      select md5(coalesce(jsonb_agg(jsonb_build_array(
        pb.id,pb.store_id,pb.product_id,pb.supplier_id,pb.remaining_quantity,
        pb.purchase_price,pb.expiration_date
      )order by pb.id),'[]'::jsonb)::text)
      from public.product_batches pb
      join public.stores s on s.id=pb.store_id
      where s.organization_id=v2_backfill_source_fingerprint.organization_id
    ),
    'sale_items',(
      select md5(coalesce(jsonb_agg(jsonb_build_array(
        i.id,i.sale_id,i.product_id,i.batch_id,i.quantity,i.purchase_price,
        i.sale_price,i.discount_amount,i.total_price,i.profit_amount
      )order by i.id),'[]'::jsonb)::text)
      from public.sale_items i
      join public.sales sa on sa.id=i.sale_id
      join public.stores s on s.id=sa.store_id
      where s.organization_id=v2_backfill_source_fingerprint.organization_id
    ),
    'user_store_access',(
      select md5(coalesce(jsonb_agg(jsonb_build_array(
        a.user_id,a.store_id,a.role_in_store::text
      )order by a.user_id,a.store_id),'[]'::jsonb)::text)
      from public.user_store_access a
      join public.users u on u.id=a.user_id
      where u.organization_id=v2_backfill_source_fingerprint.organization_id
    )
  )
$$;

create or replace function public.v2_backfill_finding(
  run_id uuid,phase text,legacy_table text,legacy_id text,severity text,
  error_code text,details jsonb default '{}'
)returns boolean language plpgsql security definer set search_path='' as $$
declare run public.migration_backfill_runs%rowtype;inserted integer;
begin
  select * into run from public.migration_backfill_runs r where r.id=run_id;
  if not found then
    raise exception using errcode='P0001',message='V2_BACKFILL_RUN_NOT_FOUND';
  end if;
  insert into public.migration_backfill_findings(
    run_id,organization_id,phase,legacy_table,legacy_id,severity,error_code,details
  )values(run.id,run.organization_id,phase,legacy_table,legacy_id,severity,error_code,coalesce(details,'{}'))
  on conflict do nothing;
  get diagnostics inserted=row_count;
  if run.mode='apply'and severity in('warning','blocker')then
    insert into public.migration_exceptions(
      organization_id,migration_name,legacy_table,legacy_id,error_code,details
    )values(run.organization_id,'0019_v2_backfill',legacy_table,legacy_id,error_code,coalesce(details,'{}'))
    on conflict do nothing;
  end if;
  return inserted=1;
end$$;

create or replace function public.v2_backfill_mapping(
  organization_id uuid,legacy_table text,legacy_key text,target_table text,
  target_id uuid,mapping_kind text
)returns boolean language plpgsql security definer set search_path='' as $$
declare existing uuid;inserted integer;
begin
  select m.target_id into existing from public.migration_entity_mappings m
  where m.organization_id=v2_backfill_mapping.organization_id
    and m.legacy_table=v2_backfill_mapping.legacy_table
    and m.legacy_key=v2_backfill_mapping.legacy_key
    and m.target_table=v2_backfill_mapping.target_table;
  if existing is not null and existing<>target_id then
    raise exception using errcode='P0001',message='V2_BACKFILL_MAPPING_CONFLICT';
  end if;
  insert into public.migration_entity_mappings(
    organization_id,legacy_table,legacy_key,target_table,target_id,mapping_kind
  )values(organization_id,legacy_table,legacy_key,target_table,target_id,mapping_kind)
  on conflict do nothing;
  get diagnostics inserted=row_count;
  return inserted=1;
end$$;

create or replace function public.v2_start_backfill_run(
  organization_id uuid,mode text default 'dry_run'
)returns uuid language plpgsql security definer set search_path='' as $$
declare run_id uuid;phase text;phases constant text[]:=array[
  'identity_profiles','identity_access','locations','catalog_categories',
  'catalog_category_parents','catalog_references','catalog_products',
  'counterparties','pricing','cutover_assessment'];
begin
  if mode not in('dry_run','apply')then
    raise exception using errcode='P0001',message='V2_BACKFILL_MODE_INVALID';
  end if;
  if not exists(select 1 from public.organizations o where o.id=organization_id)then
    raise exception using errcode='P0001',message='V2_BACKFILL_ORGANIZATION_NOT_FOUND';
  end if;
  insert into public.migration_backfill_runs(
    organization_id,mode,source_snapshot_at,summary
  )values(organization_id,mode,clock_timestamp(),jsonb_build_object(
    'source_fingerprint',public.v2_backfill_source_fingerprint(organization_id)
  ))returning id into run_id;
  foreach phase in array phases loop
    insert into public.migration_backfill_checkpoints(run_id,phase)values(run_id,phase);
  end loop;
  return run_id;
end$$;

create or replace function public.v2_run_backfill_batch(
  run_id uuid,phase text,batch_size integer default 200
)returns jsonb language plpgsql security definer set search_path='' as $$
declare
  run public.migration_backfill_runs%rowtype;
  cp public.migration_backfill_checkpoints%rowtype;
  phases constant text[]:=array['identity_profiles','identity_access','locations',
    'catalog_categories','catalog_category_parents','catalog_references',
    'catalog_products','counterparties','pricing','cutover_assessment'];
  phase_no integer;previous_pending boolean;row_data record;
  target uuid;parent_target uuid;branch_target uuid;warehouse_target uuid;
  register_target uuid;profile_target uuid;membership_target uuid;
  owner_target uuid;unit_target uuid;list_target uuid;source_org uuid;
  processed_delta bigint:=0;mapped_delta bigint:=0;last_key text;
  has_more boolean:=false;existing_count bigint;target_amount numeric;
  target_status text;target_archived timestamptz;generated_code text;
  normalized text;history_summary jsonb;
begin
  if batch_size not between 1 and 1000 then
    raise exception using errcode='P0001',message='V2_BACKFILL_BATCH_SIZE_INVALID';
  end if;
  phase_no:=array_position(phases,phase);
  if phase_no is null then
    raise exception using errcode='P0001',message='V2_BACKFILL_PHASE_INVALID';
  end if;
  select * into run from public.migration_backfill_runs r where r.id=run_id for update;
  if not found then
    raise exception using errcode='P0001',message='V2_BACKFILL_RUN_NOT_FOUND';
  end if;
  if run.status<>'running'then
    raise exception using errcode='P0001',message='V2_BACKFILL_RUN_NOT_RUNNING';
  end if;
  select * into cp from public.migration_backfill_checkpoints c
  where c.run_id=run.id and c.phase=v2_run_backfill_batch.phase for update;
  if cp.status='completed'then
    return jsonb_build_object('run_id',run.id,'phase',phase,'status','completed',
      'processed_count',cp.processed_count,'mapped_count',cp.mapped_count,
      'finding_count',cp.finding_count,'replayed',true);
  end if;
  select exists(select 1 from public.migration_backfill_checkpoints c
    where c.run_id=run.id and array_position(phases,c.phase)<phase_no
      and c.status<>'completed')into previous_pending;
  if previous_pending then
    raise exception using errcode='P0001',message='V2_BACKFILL_PHASE_ORDER_REQUIRED';
  end if;
  update public.migration_backfill_checkpoints
    set status='running',updated_at=clock_timestamp()where id=cp.id;

  if phase='identity_profiles'then
    for row_data in select u.*,'users:'||u.id::text legacy_order
      from public.users u where u.organization_id=run.organization_id
        and u.created_at<=run.source_snapshot_at and u.updated_at<=run.source_snapshot_at
        and('users:'||u.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        if row_data.auth_user_id is null then
          perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
            'blocker','V2_BACKFILL_AUTH_ID_REQUIRED','{}');continue;
        end if;
        if not exists(select 1 from auth.users a where a.id=row_data.auth_user_id)then
          perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
            'blocker','V2_BACKFILL_AUTH_ID_NOT_FOUND','{}');continue;
        end if;
        if(select count(*)from public.users u where u.auth_user_id=row_data.auth_user_id)>1 then
          perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
            'blocker','V2_BACKFILL_AUTH_ID_AMBIGUOUS','{}');continue;
        end if;
        if row_data.status::text='deleted'then
          perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
            'blocker','V2_BACKFILL_DELETED_USER_REVIEW_REQUIRED','{}');
        end if;
        if run.mode='apply'then
          select p.id into profile_target from public.user_profiles p
          where p.auth_user_id=row_data.auth_user_id;
          if profile_target is null then
            insert into public.user_profiles(
              auth_user_id,full_name,phone,email_snapshot,status,created_at
            )values(row_data.auth_user_id,row_data.full_name,row_data.phone,row_data.email,
              case row_data.status::text when'active'then'active'
                when'blocked'then'blocked'else'inactive'end,row_data.created_at)
            returning id into profile_target;
          elsif not exists(select 1 from public.user_profiles p where p.id=profile_target
              and p.full_name=row_data.full_name)then
            perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
              'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','user_profiles'));
          end if;
          if public.v2_backfill_mapping(run.organization_id,'users',row_data.id::text,
            'user_profiles',profile_target,'exact')then mapped_delta:=mapped_delta+1;end if;
          if row_data.role::text='service_admin'then
            perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
              'warning','V2_BACKFILL_SERVICE_ADMIN_REVIEW_REQUIRED','{}');
          elsif row_data.role::text in('owner','seller')then
            select m.id into membership_target from public.organization_memberships m
            where m.organization_id=run.organization_id and m.user_profile_id=profile_target;
            if membership_target is null then
              insert into public.organization_memberships(
                organization_id,user_profile_id,system_role,status,joined_at,created_at
              )values(run.organization_id,profile_target,row_data.role::text,
                case row_data.status::text when'active'then'active'
                  when'blocked'then'blocked'else'inactive'end,
                case when row_data.status::text='active'then row_data.created_at end,
                row_data.created_at)returning id into membership_target;
            elsif not exists(select 1 from public.organization_memberships m
              where m.id=membership_target and m.system_role=row_data.role::text)then
              perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
                'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','organization_memberships'));
            end if;
            if public.v2_backfill_mapping(run.organization_id,'users',row_data.id::text,
              'organization_memberships',membership_target,'exact')then mapped_delta:=mapped_delta+1;end if;
          end if;
        elsif row_data.role::text='service_admin'then
          perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
            'warning','V2_BACKFILL_SERVICE_ADMIN_REVIEW_REQUIRED','{}');
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
          'blocker',case when sqlerrm like'V2_BACKFILL_%'then sqlerrm
            else'V2_BACKFILL_TARGET_DIVERGED'end,jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.users u
      where u.organization_id=run.organization_id
        and u.created_at<=run.source_snapshot_at and u.updated_at<=run.source_snapshot_at
        and('users:'||u.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='identity_access'then
    for row_data in select u.id,u.role::text role,'users:'||u.id::text legacy_order
      from public.users u where u.organization_id=run.organization_id
        and u.created_at<=run.source_snapshot_at and u.updated_at<=run.source_snapshot_at
        and u.role::text in('owner','seller')
        and('users:'||u.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        if run.mode='apply'then
          select m.target_id into membership_target
          from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='users'
            and m.legacy_key=row_data.id::text
            and m.target_table='organization_memberships';
          if membership_target is null then continue;end if;
          if row_data.role='owner'then owner_target:=membership_target;
          else
            select case when count(*)=1 then(array_agg(id order by id))[1]end into owner_target
            from public.organization_memberships where organization_id=run.organization_id
              and system_role='owner'and status='active';
          end if;
          if owner_target is null then
            perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
              'blocker','V2_BACKFILL_OWNER_MEMBERSHIP_REQUIRED','{}');continue;
          end if;
          insert into public.membership_permission_profiles(
            membership_id,permission_profile_id,assigned_by
          )values(membership_target,case row_data.role when'owner'then
            '00000000-0000-0000-0000-000000000101'::uuid else
            '00000000-0000-0000-0000-000000000102'::uuid end,owner_target)
          on conflict do nothing;
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,'users',row_data.id::text,
          'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.users u
      where u.organization_id=run.organization_id and u.role::text in('owner','seller')
        and u.created_at<=run.source_snapshot_at and u.updated_at<=run.source_snapshot_at
        and('users:'||u.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='locations'then
    if run.mode='apply'then
      insert into public.organization_settings(organization_id)
      values(run.organization_id)on conflict do nothing;
    end if;
    for row_data in
      select '1-store:'||s.id::text legacy_order,'store'kind,s.id,
        s.organization_id,s.name,s.address,s.phone,s.status::text,
        s.created_at,s.updated_at,null::uuid store_id
      from public.stores s where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
      union all
      select '2-device:'||d.id::text,'device',d.id,s.organization_id,d.name,
        null,null,d.status::text,d.created_at,d.updated_at,d.store_id
      from public.devices d join public.stores s on s.id=d.store_id
      where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
        and d.created_at<=run.source_snapshot_at and d.updated_at<=run.source_snapshot_at
      order by legacy_order loop
      if row_data.legacy_order<=coalesce(cp.last_legacy_key,'')then continue;end if;
      exit when processed_delta>=batch_size;
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        if row_data.kind='store'then
          if run.mode='apply'then
            select b.id into branch_target from public.branches b
            where b.legacy_store_id=row_data.id;
            if branch_target is null then
              generated_code:='MIG-BR-'||public.v2_backfill_uuid_fragment(row_data.id);
              insert into public.branches(
                organization_id,code,name,address,phone,status,legacy_store_id,
                created_at,archived_at
              )values(run.organization_id,generated_code,row_data.name,row_data.address,
                row_data.phone,case row_data.status when'active'then'active'
                  when'deleted'then'archived'else'inactive'end,row_data.id,
                row_data.created_at,case when row_data.status='deleted'then
                  coalesce(row_data.updated_at,row_data.created_at)end)
              returning id into branch_target;
            elsif not exists(select 1 from public.branches b where b.id=branch_target
              and b.organization_id=run.organization_id)then
              raise exception using errcode='P0001',message='V2_BACKFILL_MAPPING_CONFLICT';
            end if;
            if public.v2_backfill_mapping(run.organization_id,'stores',row_data.id::text,
              'branches',branch_target,'exact')then mapped_delta:=mapped_delta+1;end if;
            select m.target_id into warehouse_target from public.migration_entity_mappings m
            where m.organization_id=run.organization_id and m.legacy_table='stores'
              and m.legacy_key=row_data.id::text and m.target_table='warehouses';
            if warehouse_target is null then
              select count(*),case when count(*)=1 then(array_agg(id order by id))[1]end
                into existing_count,warehouse_target from public.warehouses
              where branch_id=branch_target and is_primary and archived_at is null;
              if existing_count=0 and exists(select 1 from public.warehouses where branch_id=branch_target)then
                perform public.v2_backfill_finding(run.id,phase,'stores',row_data.id::text,
                  'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','warehouses'));
                continue;
              elsif existing_count=0 then
                insert into public.warehouses(organization_id,branch_id,code,name,is_primary)
                values(run.organization_id,branch_target,
                  'MIG-WH-'||public.v2_backfill_uuid_fragment(row_data.id),
                  'Migration warehouse',true)returning id into warehouse_target;
              elsif existing_count>1 then
                perform public.v2_backfill_finding(run.id,phase,'stores',row_data.id::text,
                  'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','warehouses'));
                continue;
              end if;
              if public.v2_backfill_mapping(run.organization_id,'stores',row_data.id::text,
                'warehouses',warehouse_target,case when existing_count=0 then'generated'
                  else'exact'end)then mapped_delta:=mapped_delta+1;end if;
            end if;
            select m.target_id into register_target from public.migration_entity_mappings m
            where m.organization_id=run.organization_id and m.legacy_table='stores'
              and m.legacy_key=row_data.id::text and m.target_table='registers';
            if register_target is null then
              select count(*),case when count(*)=1 then(array_agg(id order by id))[1]end
                into existing_count,register_target from public.registers
              where branch_id=branch_target;
              if existing_count=0 then
                insert into public.registers(
                  organization_id,branch_id,default_warehouse_id,code,name
                )values(run.organization_id,branch_target,warehouse_target,
                  'MIG-REG-'||public.v2_backfill_uuid_fragment(row_data.id),
                  'Migration register')returning id into register_target;
              elsif existing_count>1 or not exists(select 1 from public.registers
                where id=register_target and default_warehouse_id=warehouse_target)then
                perform public.v2_backfill_finding(run.id,phase,'stores',row_data.id::text,
                  'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','registers'));
                continue;
              end if;
              if public.v2_backfill_mapping(run.organization_id,'stores',row_data.id::text,
                'registers',register_target,case when existing_count=0 then'generated'
                  else'exact'end)then mapped_delta:=mapped_delta+1;end if;
            end if;
            for source_org in select usa.user_id from public.user_store_access usa
              join public.users u on u.id=usa.user_id
              where usa.store_id=row_data.id and u.role::text='seller'
                and run.summary->'source_fingerprint'->>'user_store_access'=
                  public.v2_backfill_source_fingerprint(run.organization_id)->>'user_store_access'
              loop
              select m.target_id into membership_target
              from public.migration_entity_mappings m
              where m.organization_id=run.organization_id and m.legacy_table='users'
                and m.legacy_key=source_org::text
                and m.target_table='organization_memberships';
              if membership_target is not null then
                if exists(select 1 from public.user_store_access a
                  join public.users u on u.id=a.user_id where a.store_id=row_data.id
                    and a.user_id=source_org and a.role_in_store::text<>u.role::text)then
                  perform public.v2_backfill_finding(run.id,phase,'user_store_access',
                    source_org::text||':'||row_data.id::text,'warning',
                    'V2_BACKFILL_STORE_ROLE_CONFLICT','{}');
                else
                  insert into public.branch_access(organization_id,membership_id,branch_id)
                  values(run.organization_id,membership_target,branch_target)
                  on conflict do nothing;
                end if;
              end if;
            end loop;
          end if;
        else
          select b.id into branch_target from public.branches b
          where b.legacy_store_id=row_data.store_id;
          select d.id into target from public.devices_v2 d
          where d.legacy_device_id=row_data.id;
          if target is null then
            perform public.v2_backfill_finding(run.id,phase,'devices',row_data.id::text,
              'warning','V2_BACKFILL_DEVICE_REENROLL_REQUIRED',
              jsonb_build_object('store_id',row_data.store_id));
          elsif exists(select 1 from public.devices_v2 d
            where d.id=target and d.organization_id=run.organization_id
              and d.branch_id=branch_target)then
            if run.mode='apply'then
              if public.v2_backfill_mapping(run.organization_id,'devices',row_data.id::text,
                'devices_v2',target,'exact')then mapped_delta:=mapped_delta+1;end if;
            end if;
          else
            perform public.v2_backfill_finding(run.id,phase,'devices',row_data.id::text,
              'blocker','V2_BACKFILL_MAPPING_CONFLICT','{}');
          end if;
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,row_data.kind||'s',
          row_data.id::text,'blocker',case when sqlerrm like'V2_BACKFILL_%'then sqlerrm
            else'V2_BACKFILL_TARGET_DIVERGED'end,jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from(
      select '1-store:'||s.id::text k from public.stores s
      where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
      union all select '2-device:'||d.id::text from public.devices d
      join public.stores s on s.id=d.store_id where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
        and d.created_at<=run.source_snapshot_at and d.updated_at<=run.source_snapshot_at
    )q where q.k>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='catalog_categories'then
    for row_data in select c.*,'categories:'||c.id::text legacy_order
      from public.categories c where c.organization_id=run.organization_id
        and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
        and('categories:'||c.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        if row_data.parent_id is not null then
          select organization_id into source_org from public.categories
          where id=row_data.parent_id;
          if source_org is null then
            perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
              'blocker','V2_BACKFILL_CATEGORY_PARENT_MISSING','{}');
          elsif source_org<>run.organization_id then
            perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
              'blocker','V2_BACKFILL_CATEGORY_PARENT_TENANT_MISMATCH','{}');
          end if;
          if exists(with recursive chain(id,parent_id,path,cycle)as(
            select c.id,c.parent_id,array[c.id],false from public.categories c
              where c.id=row_data.id
            union all select p.id,p.parent_id,ch.path||p.id,p.id=any(ch.path)
              from public.categories p join chain ch on p.id=ch.parent_id
              where not ch.cycle)select 1 from chain where cycle)then
            perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
              'blocker','V2_BACKFILL_CATEGORY_CYCLE','{}');
          end if;
        end if;
        target_status:=case when row_data.archived_at is not null
          or row_data.status::text='deleted'then'archived'
          when row_data.status::text='active'then'active'else'inactive'end;
        target_archived:=case when target_status='archived'then
          coalesce(row_data.archived_at,row_data.updated_at,row_data.created_at)end;
        select m.target_id into target from public.migration_entity_mappings m
        where m.organization_id=run.organization_id and m.legacy_table='categories'
          and m.legacy_key=row_data.id::text and m.target_table='categories_v2';
        if target is null then
          select c.id into target from public.categories_v2 c
          where c.legacy_category_id=row_data.id;
        end if;
        if target is not null and not exists(select 1 from public.categories_v2 c
          where c.id=target and c.organization_id=run.organization_id
            and c.legacy_category_id=row_data.id and c.name=row_data.name
            and c.status=target_status
            and((target_status='archived'and c.archived_at is not null)or
              (target_status<>'archived'and c.archived_at is null)))then
          perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
            'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','categories_v2'));
          continue;
        end if;
        if run.mode='apply'then
          if target is null then
            insert into public.categories_v2(
              organization_id,legacy_category_id,name,description,sort_order,
              status,created_at,archived_at
            )values(run.organization_id,row_data.id,row_data.name,row_data.description,
              row_data.sort_order,target_status,row_data.created_at,target_archived)
            returning id into target;
          end if;
          if public.v2_backfill_mapping(run.organization_id,'categories',row_data.id::text,
            'categories_v2',target,'exact')then mapped_delta:=mapped_delta+1;end if;
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
          'blocker',case when sqlerrm like'V2_BACKFILL_%'then sqlerrm
            else'V2_BACKFILL_MAPPING_CONFLICT'end,jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.categories c
      where c.organization_id=run.organization_id
        and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
        and('categories:'||c.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='catalog_category_parents'then
    for row_data in select c.*,'categories:'||c.id::text legacy_order
      from public.categories c where c.organization_id=run.organization_id
        and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
        and c.parent_id is not null
        and('categories:'||c.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        if run.mode='apply'then
          select m.target_id into target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='categories'
            and m.legacy_key=row_data.id::text and m.target_table='categories_v2';
          select m.target_id into parent_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='categories'
            and m.legacy_key=row_data.parent_id::text and m.target_table='categories_v2';
          if target is null or parent_target is null then
            perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
              'blocker','V2_BACKFILL_CATEGORY_PARENT_MISSING','{}');
          elsif exists(select 1 from public.categories_v2 c where c.id=target
            and c.parent_id is not null and c.parent_id<>parent_target)then
            perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
              'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','parent_id'));
          else
            update public.categories_v2 set parent_id=parent_target
            where id=target and parent_id is null;
          end if;
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,'categories',row_data.id::text,
          'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.categories c
      where c.organization_id=run.organization_id and c.parent_id is not null
        and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
        and('categories:'||c.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='catalog_references'then
    for row_data in
      select '1-brand:'||b.id::text legacy_order,'brands'kind,b.id,b.name,
        null::text short_name,null::text code,b.description,b.status::text status,
        b.archived_at,b.created_at,b.updated_at
      from public.brands b where b.organization_id=run.organization_id
        and b.created_at<=run.source_snapshot_at and b.updated_at<=run.source_snapshot_at
      union all select '2-unit:'||u.id::text,'units',u.id,u.name,u.short_name,
        null,null,u.status::text,u.archived_at,u.created_at,u.updated_at
      from public.units u where u.organization_id=run.organization_id
        and u.created_at<=run.source_snapshot_at and u.updated_at<=run.source_snapshot_at
      union all select '3-type:'||t.id::text,'product_types',t.id,t.name,null,
        t.code,t.description,t.status::text,t.archived_at,t.created_at,t.updated_at
      from public.product_types t where t.organization_id=run.organization_id
        and t.created_at<=run.source_snapshot_at and t.updated_at<=run.source_snapshot_at
      union all select '4-unit-text:'||lower(btrim(p.unit)),'unit_text',null::uuid,
        min(p.unit),min(p.unit),null,null,'active',null,min(p.created_at),max(p.updated_at)
      from public.products p where p.organization_id=run.organization_id
        and p.created_at<=run.source_snapshot_at and p.updated_at<=run.source_snapshot_at
        and p.unit_id is null and btrim(p.unit)<>''group by lower(btrim(p.unit))
      order by legacy_order loop
      if row_data.legacy_order<=coalesce(cp.last_legacy_key,'')then continue;end if;
      exit when processed_delta>=batch_size;
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        normalized:=case when row_data.kind='unit_text'then
          'unit-text:'||lower(btrim(row_data.name))else row_data.id::text end;
        target_status:=case when row_data.archived_at is not null then'archived'
          when row_data.status='active'then'active'else'inactive'end;
        target_archived:=case when target_status='archived'then
          coalesce(row_data.archived_at,row_data.updated_at,row_data.created_at)end;
        generated_code:=case when row_data.kind in('units','unit_text')then
          'MIG-U-'||case when row_data.id is null then
            upper(substr(md5(lower(btrim(row_data.name))),1,12))
            else public.v2_backfill_uuid_fragment(row_data.id)end
          when row_data.kind='product_types'then coalesce(nullif(btrim(row_data.code),''),
            'MIG-T-'||public.v2_backfill_uuid_fragment(row_data.id))end;
        select m.target_id into target from public.migration_entity_mappings m
        where m.organization_id=run.organization_id
          and m.legacy_table=case when row_data.kind='unit_text'then'products.unit'
            else row_data.kind end and m.legacy_key=normalized
          and m.target_table=case row_data.kind when'brands'then'brands_v2'
            when'product_types'then'product_types_v2'else'units_v2'end;
        if target is null and row_data.kind='brands'then
          select b.id into target from public.brands_v2 b
          where b.legacy_brand_id=row_data.id;
        elsif target is null and row_data.kind='units'then
          select u.id into target from public.units_v2 u
          where u.legacy_unit_id=row_data.id;
        elsif target is null and row_data.kind='product_types'then
          select t.id into target from public.product_types_v2 t
          where t.legacy_product_type_id=row_data.id;
        end if;
        if target is not null and not(
          (row_data.kind='brands'and exists(select 1 from public.brands_v2 b
            where b.id=target and b.organization_id=run.organization_id
              and b.legacy_brand_id=row_data.id and b.name=row_data.name
              and b.status=target_status and((target_status='archived'and b.archived_at is not null)
                or(target_status<>'archived'and b.archived_at is null))))or
          (row_data.kind in('units','unit_text')and exists(select 1 from public.units_v2 u
            where u.id=target and u.organization_id=run.organization_id
              and u.legacy_unit_id is not distinct from case when row_data.kind='units'then row_data.id end
              and u.code=generated_code and u.name=row_data.name
              and u.short_name=row_data.short_name and u.status=target_status
              and((target_status='archived'and u.archived_at is not null)
                or(target_status<>'archived'and u.archived_at is null))))or
          (row_data.kind='product_types'and exists(select 1 from public.product_types_v2 t
            where t.id=target and t.organization_id=run.organization_id
              and t.legacy_product_type_id=row_data.id and t.code=generated_code
              and t.name=row_data.name and t.status=target_status
              and((target_status='archived'and t.archived_at is not null)
                or(target_status<>'archived'and t.archived_at is null))))
        )then
          perform public.v2_backfill_finding(run.id,phase,
            case when row_data.kind='unit_text'then'products.unit'else row_data.kind end,
            coalesce(row_data.id::text,lower(btrim(row_data.name))),'blocker',
            'V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target',case row_data.kind
              when'brands'then'brands_v2'when'product_types'then'product_types_v2'else'units_v2'end));
          continue;
        end if;
        if run.mode='apply'then
          if target is null then
            if row_data.kind='brands'then
              insert into public.brands_v2(
                organization_id,legacy_brand_id,name,description,status,created_at,archived_at
              )values(run.organization_id,row_data.id,row_data.name,row_data.description,
                target_status,row_data.created_at,target_archived)returning id into target;
            elsif row_data.kind in('units','unit_text')then
              insert into public.units_v2(
                organization_id,legacy_unit_id,code,name,short_name,status,created_at,archived_at
              )values(run.organization_id,case when row_data.kind='units'then row_data.id end,
                generated_code,row_data.name,row_data.short_name,target_status,
                row_data.created_at,target_archived)returning id into target;
            else
              insert into public.product_types_v2(
                organization_id,legacy_product_type_id,code,name,description,status,
                created_at,archived_at
              )values(run.organization_id,row_data.id,generated_code,row_data.name,
                row_data.description,target_status,row_data.created_at,target_archived)
              returning id into target;
            end if;
          end if;
          if public.v2_backfill_mapping(run.organization_id,
            case when row_data.kind='unit_text'then'products.unit'else row_data.kind end,
            normalized,case row_data.kind when'brands'then'brands_v2'
              when'product_types'then'product_types_v2'else'units_v2'end,target,
            case when row_data.kind='unit_text'then'generated'else'exact'end)then
            mapped_delta:=mapped_delta+1;
          end if;
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,
          case when row_data.kind='unit_text'then'products.unit'else row_data.kind end,
          coalesce(row_data.id::text,lower(btrim(row_data.name))),'blocker',
          'V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from(
      select '1-brand:'||id::text k from public.brands
        where organization_id=run.organization_id
          and created_at<=run.source_snapshot_at and updated_at<=run.source_snapshot_at
      union all select '2-unit:'||id::text from public.units
        where organization_id=run.organization_id
          and created_at<=run.source_snapshot_at and updated_at<=run.source_snapshot_at
      union all select '3-type:'||id::text from public.product_types
        where organization_id=run.organization_id
          and created_at<=run.source_snapshot_at and updated_at<=run.source_snapshot_at
      union all select distinct '4-unit-text:'||lower(btrim(unit))from public.products
        where organization_id=run.organization_id and unit_id is null and btrim(unit)<>''
          and created_at<=run.source_snapshot_at and updated_at<=run.source_snapshot_at
    )q where q.k>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='catalog_products'then
    for row_data in select p.*,'products:'||p.id::text legacy_order
      from public.products p where p.organization_id=run.organization_id
        and p.created_at<=run.source_snapshot_at and p.updated_at<=run.source_snapshot_at
        and('products:'||p.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        select m.target_id into target from public.migration_entity_mappings m
        where m.organization_id=run.organization_id and m.legacy_table='products'
          and m.legacy_key=row_data.id::text and m.target_table='products_v2';
        if target is null then
          select p.id into target from public.products_v2 p
          where p.legacy_product_id=row_data.id;
        end if;

        parent_target:=null;branch_target:=null;register_target:=null;unit_target:=null;
        if row_data.category_id is not null then
          if not exists(select 1 from public.categories c where c.id=row_data.category_id
            and c.organization_id=run.organization_id and c.created_at<=run.source_snapshot_at
            and c.updated_at<=run.source_snapshot_at)then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('reference','category'));
            continue;
          end if;
          select m.target_id into parent_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='categories'
            and m.legacy_key=row_data.category_id::text and m.target_table='categories_v2';
          if parent_target is null and run.mode='dry_run'then
            select c.id into parent_target from public.categories_v2 c
            where c.legacy_category_id=row_data.category_id;end if;
        end if;
        if row_data.brand_id is not null then
          if not exists(select 1 from public.brands b where b.id=row_data.brand_id
            and b.organization_id=run.organization_id and b.created_at<=run.source_snapshot_at
            and b.updated_at<=run.source_snapshot_at)then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('reference','brand'));
            continue;
          end if;
          select m.target_id into branch_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='brands'
            and m.legacy_key=row_data.brand_id::text and m.target_table='brands_v2';
          if branch_target is null and run.mode='dry_run'then
            select b.id into branch_target from public.brands_v2 b
            where b.legacy_brand_id=row_data.brand_id;end if;
        end if;
        if row_data.product_type_id is not null then
          if not exists(select 1 from public.product_types t where t.id=row_data.product_type_id
            and t.organization_id=run.organization_id and t.created_at<=run.source_snapshot_at
            and t.updated_at<=run.source_snapshot_at)then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('reference','product_type'));
            continue;
          end if;
          select m.target_id into register_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='product_types'
            and m.legacy_key=row_data.product_type_id::text and m.target_table='product_types_v2';
          if register_target is null and run.mode='dry_run'then
            select t.id into register_target from public.product_types_v2 t
            where t.legacy_product_type_id=row_data.product_type_id;end if;
        end if;
        if row_data.unit_id is not null then
          if not exists(select 1 from public.units u where u.id=row_data.unit_id
            and u.organization_id=run.organization_id and u.created_at<=run.source_snapshot_at
            and u.updated_at<=run.source_snapshot_at)then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('reference','base_unit'));
            continue;
          end if;
          select m.target_id into unit_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='units'
            and m.legacy_key=row_data.unit_id::text and m.target_table='units_v2';
          if unit_target is null and run.mode='dry_run'then
            select u.id into unit_target from public.units_v2 u
            where u.legacy_unit_id=row_data.unit_id;end if;
        else
          select m.target_id into unit_target from public.migration_entity_mappings m
          where m.organization_id=run.organization_id and m.legacy_table='products.unit'
            and m.legacy_key='unit-text:'||lower(btrim(row_data.unit))
            and m.target_table='units_v2';
          if unit_target is null and run.mode='dry_run'then
            select u.id into unit_target from public.units_v2 u
            where u.organization_id=run.organization_id and u.legacy_unit_id is null
              and u.code='MIG-U-'||upper(substr(md5(lower(btrim(row_data.unit))),1,12));end if;
        end if;
        if(run.mode='apply'or target is not null)and(
          unit_target is null or(row_data.category_id is not null and parent_target is null)or
          (row_data.brand_id is not null and branch_target is null)or
          (row_data.product_type_id is not null and register_target is null))then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('reference','catalog'));
          continue;
        end if;

        target_status:=case when row_data.deleted_at is not null
          or row_data.archived_at is not null or row_data.status::text='deleted'
          then'archived'when row_data.status::text='active'then'active'else'inactive'end;
        target_archived:=case when target_status='archived'then
          coalesce(row_data.deleted_at,row_data.archived_at,row_data.updated_at,row_data.created_at)end;
        if target is not null and not exists(select 1 from public.products_v2 p
          where p.id=target and p.organization_id=run.organization_id
            and p.legacy_product_id=row_data.id and p.name=row_data.name
            and p.category_id is not distinct from parent_target
            and p.brand_id is not distinct from branch_target
            and p.product_type_id is not distinct from register_target
            and p.base_unit_id=unit_target and p.status=target_status
            and((target_status='archived'and p.archived_at is not null)or
              (target_status<>'archived'and p.archived_at is null)))then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','products_v2'));
          continue;
        end if;

        generated_code:=nullif(btrim(row_data.sku),'');
        if generated_code is not null and exists(select 1 from public.products_v2 p
          where p.organization_id=run.organization_id and lower(p.sku)=lower(generated_code)
            and(target is null or p.id<>target))then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'warning','V2_BACKFILL_SKU_CONFLICT',jsonb_build_object('legacy_product_id',row_data.id));
          generated_code:=null;
        end if;
        normalized:=case when nullif(btrim(row_data.barcode),'')is not null
          then public.v2_normalize_barcode(row_data.barcode)end;
        if normalized is not null and exists(select 1 from public.product_barcodes b
          where b.organization_id=run.organization_id and b.normalized_barcode=normalized
            and(target is null or b.product_id<>target)and b.archived_at is null)then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'warning','V2_BACKFILL_BARCODE_CONFLICT',jsonb_build_object('legacy_product_id',row_data.id));
          normalized:=null;
        end if;

        if run.mode='apply'then
          if target is null then
            insert into public.products_v2(
              organization_id,legacy_product_id,sku,name,category_id,brand_id,
              product_type_id,base_unit_id,description,is_expirable,min_quantity,
              status,created_at,archived_at
            )values(run.organization_id,row_data.id,generated_code,row_data.name,
              parent_target,branch_target,register_target,unit_target,row_data.description,
              row_data.is_expirable,row_data.min_quantity,target_status,row_data.created_at,
              target_archived)returning id into target;
          end if;
          if public.v2_backfill_mapping(run.organization_id,'products',row_data.id::text,
            'products_v2',target,'exact')then mapped_delta:=mapped_delta+1;end if;
          if normalized is not null then
            insert into public.product_barcodes(organization_id,product_id,barcode,is_primary)
            values(run.organization_id,target,row_data.barcode,true)on conflict do nothing;
          end if;
          if nullif(btrim(row_data.image_url),'')is not null then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'info','V2_BACKFILL_IMAGE_REIMPORT_REQUIRED',jsonb_build_object('legacy_product_id',row_data.id));
          end if;
        elsif nullif(btrim(row_data.image_url),'')is not null then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'info','V2_BACKFILL_IMAGE_REIMPORT_REQUIRED',jsonb_build_object('legacy_product_id',row_data.id));
        end if;
      exception when others then
        perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
          'blocker',case when sqlerrm like'V2_BACKFILL_%'then sqlerrm
            else'V2_BACKFILL_MAPPING_CONFLICT'end,jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.products p
      where p.organization_id=run.organization_id
        and p.created_at<=run.source_snapshot_at and p.updated_at<=run.source_snapshot_at
        and('products:'||p.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='counterparties'then
    for row_data in
      select '1-supplier:'||s.id::text legacy_order,'suppliers'kind,s.id,
        s.organization_id,s.name,s.phone,s.comment,s.status::text,s.created_at,
        s.updated_at,0::numeric current_debt,null::uuid store_id
      from public.suppliers s where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
      union all select '2-customer:'||c.id::text,'customers',c.id,s.organization_id,
        c.full_name,c.phone,c.comment,c.status::text,c.created_at,c.updated_at,
        c.current_debt,c.store_id from public.customers c
      join public.stores s on s.id=c.store_id
      where s.organization_id=run.organization_id
        and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
        and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
      order by legacy_order loop
      if row_data.legacy_order<=coalesce(cp.last_legacy_key,'')then continue;end if;
      exit when processed_delta>=batch_size;
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        select m.target_id into target from public.migration_entity_mappings m
        where m.organization_id=run.organization_id and m.legacy_table=row_data.kind
          and m.legacy_key=row_data.id::text and m.target_table='counterparties';
        if target is null and row_data.kind='suppliers'then
          select c.id into target from public.counterparties c
          where c.legacy_supplier_id=row_data.id;
        elsif target is null and row_data.kind='customers'then
          select c.id into target from public.counterparties c
          where c.legacy_customer_id=row_data.id;
        end if;
        target_status:=case when row_data.status='active'then'active'
          when row_data.status='deleted'then'archived'else'inactive'end;
        target_archived:=case when target_status='archived'then
          coalesce(row_data.updated_at,row_data.created_at)end;
        if target is not null and not exists(select 1 from public.counterparties c
          where c.id=target and c.organization_id=run.organization_id
            and c.display_name=row_data.name and c.status=target_status
            and((row_data.kind='suppliers'and c.legacy_supplier_id=row_data.id
              and c.legacy_customer_id is null)or(row_data.kind='customers'
              and c.legacy_customer_id=row_data.id and c.legacy_supplier_id is null))
            and((target_status='archived'and c.archived_at is not null)or
              (target_status<>'archived'and c.archived_at is null))
            and exists(select 1 from public.counterparty_roles r
              where r.organization_id=run.organization_id and r.counterparty_id=c.id
                and r.role_code=case when row_data.kind='suppliers'then'supplier'else'customer'end))then
          perform public.v2_backfill_finding(run.id,phase,row_data.kind,row_data.id::text,
            'blocker','V2_BACKFILL_TARGET_DIVERGED',jsonb_build_object('target','counterparties'));
          continue;
        end if;
        if run.mode='apply'then
          if target is null then
            perform set_config('market_pos.counterparty_command','on',true);
            insert into public.counterparties(
              organization_id,legacy_supplier_id,legacy_customer_id,display_name,
              notes,status,created_at,archived_at
            )values(run.organization_id,case when row_data.kind='suppliers'then row_data.id end,
              case when row_data.kind='customers'then row_data.id end,row_data.name,
              row_data.comment,target_status,row_data.created_at,target_archived)
            returning id into target;
            insert into public.counterparty_roles(
              organization_id,counterparty_id,role_code,started_at
            )values(run.organization_id,target,case when row_data.kind='suppliers'
              then'supplier'else'customer'end,row_data.created_at);
            if nullif(btrim(row_data.phone),'')is not null then
              insert into public.counterparty_contacts(
                organization_id,counterparty_id,contact_type,value,is_primary,created_at
              )values(run.organization_id,target,'phone',row_data.phone,true,row_data.created_at);
            end if;
            perform set_config('market_pos.counterparty_command','off',true);
          end if;
          if public.v2_backfill_mapping(run.organization_id,row_data.kind,
            row_data.id::text,'counterparties',target,'exact')then mapped_delta:=mapped_delta+1;end if;
        end if;
        if row_data.kind='customers'and row_data.current_debt>0 then
          select b.id into branch_target from public.branches b
          where b.legacy_store_id=row_data.store_id;
          perform public.v2_backfill_finding(run.id,phase,'customers',row_data.id::text,
            'blocker','V2_BACKFILL_OPENING_DEBT_REVIEW_REQUIRED',
            jsonb_build_object('customer_id',row_data.id,'current_debt',row_data.current_debt,
              'store_id',row_data.store_id,'branch_id',branch_target));
        end if;
      exception when others then
        perform set_config('market_pos.counterparty_command','off',true);
        perform public.v2_backfill_finding(run.id,phase,row_data.kind,row_data.id::text,
          'blocker','V2_BACKFILL_MAPPING_CONFLICT',jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from(
      select '1-supplier:'||id::text k from public.suppliers
        where organization_id=run.organization_id
          and created_at<=run.source_snapshot_at and updated_at<=run.source_snapshot_at
      union all select '2-customer:'||c.id::text from public.customers c
        join public.stores s on s.id=c.store_id where s.organization_id=run.organization_id
          and s.created_at<=run.source_snapshot_at and s.updated_at<=run.source_snapshot_at
          and c.created_at<=run.source_snapshot_at and c.updated_at<=run.source_snapshot_at
    )q where q.k>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  elsif phase='pricing'then
    for row_data in select p.*,'products:'||p.id::text legacy_order
      from public.products p where p.organization_id=run.organization_id
        and p.created_at<=run.source_snapshot_at and p.updated_at<=run.source_snapshot_at
        and('products:'||p.id::text)>coalesce(cp.last_legacy_key,'')
      order by legacy_order limit batch_size loop
      begin
        processed_delta:=processed_delta+1;last_key:=row_data.legacy_order;
        select m.target_id into target from public.migration_entity_mappings m
        where m.organization_id=run.organization_id and m.legacy_table='products'
          and m.legacy_key=row_data.id::text and m.target_table='products_v2';
        if target is null then select p.id into target from public.products_v2 p
          where p.legacy_product_id=row_data.id;end if;
        if target is null then continue;end if;
        select count(*),case when count(*)=1 then(array_agg(id order by id))[1]end
          into existing_count,list_target from public.price_lists
        where organization_id=run.organization_id and branch_id is null
          and is_default and status='active';
        if existing_count>1 then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'blocker','V2_BACKFILL_PRICE_TARGET_DIVERGED',jsonb_build_object('target','default_price_list'));
          continue;
        end if;
        target_amount:=null;
        if existing_count=1 then
          select pp.amount into target_amount from public.product_prices pp
          where pp.organization_id=run.organization_id and pp.price_list_id=list_target
            and pp.product_id=target and pp.valid_from<=run.source_snapshot_at
            and(pp.valid_to is null or pp.valid_to>run.source_snapshot_at)
          order by pp.valid_from desc limit 1;
          if target_amount is not null and target_amount<>row_data.sale_price then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_PRICE_TARGET_DIVERGED',jsonb_build_object('legacy_product_id',row_data.id));
            continue;
          end if;
        end if;
        if run.mode='apply'then
          select case when count(*)=1 then(array_agg(id order by id))[1]end into owner_target
          from public.organization_memberships where organization_id=run.organization_id
            and system_role='owner'and status='active';
          if owner_target is null then
            perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
              'blocker','V2_BACKFILL_PRICE_ACTOR_REQUIRED','{}');continue;
          end if;
          if existing_count=0 then
            perform set_config('market_pos.pricing_command','on',true);
            insert into public.price_lists(
              organization_id,code,name,currency_code,is_default,status
            )select run.organization_id,'LEGACY-DEFAULT','Legacy default price',
              s.currency_code,true,'active'from public.organization_settings s
              where s.organization_id=run.organization_id returning id into list_target;
            perform set_config('market_pos.pricing_command','off',true);
          end if;
          if target_amount is null then
            perform set_config('market_pos.pricing_command','on',true);
            insert into public.product_prices(
              organization_id,price_list_id,product_id,amount,currency_code,
              valid_from,confirmed_by
            )select run.organization_id,list_target,target,row_data.sale_price,
              s.currency_code,least(run.source_snapshot_at,row_data.updated_at),owner_target
              from public.organization_settings s where s.organization_id=run.organization_id
            returning id into profile_target;
            insert into public.price_history(
              organization_id,product_price_id,price_list_id,product_id,old_amount,
              new_amount,reason_code,source_type,changed_by,created_at
            )values(run.organization_id,profile_target,list_target,target,null,row_data.sale_price,
              'legacy_backfill','import',owner_target,
              least(run.source_snapshot_at,row_data.updated_at));
            perform set_config('market_pos.pricing_command','off',true);
          end if;
        end if;
      exception when others then
        perform set_config('market_pos.pricing_command','off',true);
        perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
          'blocker','V2_BACKFILL_PRICE_TARGET_DIVERGED',jsonb_build_object('sqlstate',sqlstate));
      end;
    end loop;
    select exists(select 1 from public.products p
      where p.organization_id=run.organization_id
        and p.created_at<=run.source_snapshot_at and p.updated_at<=run.source_snapshot_at
        and('products:'||p.id::text)>coalesce(last_key,cp.last_legacy_key,''))into has_more;

  else
    if coalesce(cp.last_legacy_key,'')=''then
      processed_delta:=1;last_key:='assessment';
      for row_data in select p.id,p.current_quantity from public.products p
        where p.organization_id=run.organization_id and p.current_quantity<>0 loop
        perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
          'blocker','V2_BACKFILL_OPENING_STOCK_REVIEW_REQUIRED',
          jsonb_build_object('product_id',row_data.id,'current_quantity',row_data.current_quantity));
        if exists(select 1 from public.product_batches b
          join public.stores s on s.id=b.store_id where b.product_id=row_data.id
            and s.organization_id=run.organization_id
          having sum(b.remaining_quantity)<>row_data.current_quantity)then
          perform public.v2_backfill_finding(run.id,phase,'products',row_data.id::text,
            'blocker','V2_BACKFILL_STOCK_SOURCE_MISMATCH',jsonb_build_object('product_id',row_data.id));
        end if;
      end loop;
      for row_data in select sh.id from public.shifts sh
        join public.stores s on s.id=sh.store_id
        where s.organization_id=run.organization_id and sh.status::text='open'loop
        perform public.v2_backfill_finding(run.id,phase,'shifts',row_data.id::text,
          'blocker','V2_BACKFILL_OPEN_SHIFT','{}');
      end loop;
      for row_data in select so.id,so.status::text from public.sync_operations so
        join public.stores s on s.id=so.store_id where s.organization_id=run.organization_id
          and so.status::text in('pending','syncing','error','conflict')loop
        perform public.v2_backfill_finding(run.id,phase,'sync_operations',row_data.id::text,
          'blocker','V2_BACKFILL_PENDING_LEGACY_SYNC',jsonb_build_object('status',row_data.status));
      end loop;
      for row_data in select sa.id,sa.payment_status::text from public.sales sa
        join public.stores s on s.id=sa.store_id where s.organization_id=run.organization_id
          and sa.payment_status::text in('unpaid','partial')loop
        perform public.v2_backfill_finding(run.id,phase,'sales',row_data.id::text,
          'blocker','V2_BACKFILL_OPEN_FINANCIAL_STATE_REVIEW_REQUIRED',
          jsonb_build_object('payment_status',row_data.payment_status));
      end loop;
      if run.mode='apply'then
        for row_data in
          select 'users't,u.id from public.users u
          where u.organization_id=run.organization_id and u.role::text in('owner','seller')
            and u.status::text='active'and not exists(select 1
              from public.migration_entity_mappings m where m.organization_id=run.organization_id
              and m.legacy_table='users'and m.legacy_key=u.id::text
              and m.target_table='organization_memberships')
          union all select 'stores',s.id from public.stores s
          where s.organization_id=run.organization_id and s.status::text='active'
            and not exists(select 1 from public.migration_entity_mappings m
              where m.organization_id=run.organization_id and m.legacy_table='stores'
              and m.legacy_key=s.id::text and m.target_table='branches')
          union all select 'products',p.id from public.products p
          where p.organization_id=run.organization_id and p.status::text='active'
            and not exists(select 1 from public.migration_entity_mappings m
              where m.organization_id=run.organization_id and m.legacy_table='products'
              and m.legacy_key=p.id::text and m.target_table='products_v2')
          union all select 'suppliers',s.id from public.suppliers s
          where s.organization_id=run.organization_id and s.status::text='active'
            and not exists(select 1 from public.migration_entity_mappings m
              where m.organization_id=run.organization_id and m.legacy_table='suppliers'
              and m.legacy_key=s.id::text and m.target_table='counterparties')
          union all select 'customers',c.id from public.customers c
          join public.stores s on s.id=c.store_id
          where s.organization_id=run.organization_id and c.status::text='active'
            and not exists(select 1 from public.migration_entity_mappings m
              where m.organization_id=run.organization_id and m.legacy_table='customers'
              and m.legacy_key=c.id::text and m.target_table='counterparties')
        loop
          perform public.v2_backfill_finding(run.id,phase,row_data.t,row_data.id::text,
            'blocker','V2_BACKFILL_UNMAPPED_ACTIVE_SOURCE',jsonb_build_object('legacy_table',row_data.t));
        end loop;
      end if;
      select jsonb_build_object(
        'sales',jsonb_build_object('count',count(*),'from',min(sa.created_at),'to',max(sa.created_at)),
        'sale_items',(select count(*)from public.sale_items i join public.sales x on x.id=i.sale_id
          join public.stores s on s.id=x.store_id where s.organization_id=run.organization_id),
        'payments',(select count(*)from public.payments p join public.stores s on s.id=p.store_id
          where s.organization_id=run.organization_id),
        'shifts',(select count(*)from public.shifts sh join public.stores s on s.id=sh.store_id
          where s.organization_id=run.organization_id),
        'debt_payments',(select count(*)from public.debt_payments d join public.stores s on s.id=d.store_id
          where s.organization_id=run.organization_id),
        'debt_entries',(select count(*)from public.debt_entries d join public.stores s on s.id=d.store_id
          where s.organization_id=run.organization_id),
        'stock_movements',(select count(*)from public.stock_movements sm join public.stores s on s.id=sm.store_id
          where s.organization_id=run.organization_id),
        'operation_logs',(select count(*)from public.operation_logs l join public.stores s on s.id=l.store_id
          where s.organization_id=run.organization_id),
        'synced_sync_operations',(select count(*)from public.sync_operations so
          join public.stores s on s.id=so.store_id where s.organization_id=run.organization_id
            and so.status::text='synced')
      )into history_summary from public.sales sa join public.stores st on st.id=sa.store_id
      where st.organization_id=run.organization_id;
      update public.migration_backfill_runs
        set summary=jsonb_set(summary,'{retained_v1_history}',history_summary,true)
      where id=run.id;
    end if;
    has_more:=false;
  end if;

  update public.migration_backfill_checkpoints set
    last_legacy_key=coalesce(last_key,last_legacy_key),
    processed_count=processed_count+processed_delta,
    mapped_count=mapped_count+mapped_delta,
    finding_count=(select count(*)from public.migration_backfill_findings f
      where f.run_id=run.id and f.phase=v2_run_backfill_batch.phase),
    status=case when has_more then'running'else'completed'end,
    updated_at=clock_timestamp()
  where id=cp.id returning * into cp;
  return jsonb_build_object('run_id',run.id,'phase',phase,'status',cp.status,
    'processed_count',cp.processed_count,'mapped_count',cp.mapped_count,
    'finding_count',cp.finding_count,'replayed',false);
end$$;

create or replace function public.v2_finalize_backfill_run(run_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare run public.migration_backfill_runs%rowtype;
  source_changed boolean;blockers bigint;
begin
  select * into run from public.migration_backfill_runs r where r.id=run_id for update;
  if not found then
    raise exception using errcode='P0001',message='V2_BACKFILL_RUN_NOT_FOUND';
  end if;
  if run.status<>'running'then
    return jsonb_build_object('run_id',run.id,'status',run.status,'replayed',true);
  end if;
  if exists(select 1 from public.migration_backfill_checkpoints c
    where c.run_id=run.id and c.status<>'completed')then
    raise exception using errcode='P0001',message='V2_BACKFILL_PHASES_INCOMPLETE';
  end if;
  if run.mode='dry_run'then
    update public.migration_backfill_runs
      set status='completed',finished_at=clock_timestamp()where id=run.id;
    return jsonb_build_object('run_id',run.id,'status','completed','replayed',false);
  end if;
  select exists(
    select 1 from public.users where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.stores where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.categories where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.brands where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.units where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.product_types where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.products where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.suppliers where organization_id=run.organization_id
      and(created_at>run.source_snapshot_at or updated_at>run.source_snapshot_at)
    union all select 1 from public.customers c join public.stores s on s.id=c.store_id
      where s.organization_id=run.organization_id
        and(c.created_at>run.source_snapshot_at or c.updated_at>run.source_snapshot_at)
    union all select 1 from public.devices d join public.stores s on s.id=d.store_id
      where s.organization_id=run.organization_id
        and(d.created_at>run.source_snapshot_at or d.updated_at>run.source_snapshot_at)
    union all select 1 from public.user_store_access a
      join public.users u on u.id=a.user_id where u.organization_id=run.organization_id
        and a.created_at>run.source_snapshot_at
    union all select 1 from public.shifts sh join public.stores s on s.id=sh.store_id
      where s.organization_id=run.organization_id
        and(sh.created_at>run.source_snapshot_at or sh.updated_at>run.source_snapshot_at)
    union all select 1 from public.sync_operations so
      join public.stores s on s.id=so.store_id where s.organization_id=run.organization_id
        and(so.created_at>run.source_snapshot_at or so.updated_at>run.source_snapshot_at)
    union all select 1 from public.product_batches pb
      join public.stores s on s.id=pb.store_id where s.organization_id=run.organization_id
        and pb.created_at>run.source_snapshot_at
    union all select 1 from public.sales sa join public.stores s on s.id=sa.store_id
      where s.organization_id=run.organization_id
        and(sa.created_at>run.source_snapshot_at or sa.updated_at>run.source_snapshot_at)
    union all select 1 from public.payments p join public.stores s on s.id=p.store_id
      where s.organization_id=run.organization_id and p.created_at>run.source_snapshot_at
    union all select 1 from public.debt_payments d join public.stores s on s.id=d.store_id
      where s.organization_id=run.organization_id and d.created_at>run.source_snapshot_at
    union all select 1 from public.debt_entries d join public.stores s on s.id=d.store_id
      where s.organization_id=run.organization_id and d.created_at>run.source_snapshot_at
    union all select 1 from public.stock_movements sm join public.stores s on s.id=sm.store_id
      where s.organization_id=run.organization_id and sm.created_at>run.source_snapshot_at
    union all select 1 from public.operation_logs l join public.stores s on s.id=l.store_id
      where s.organization_id=run.organization_id and l.created_at>run.source_snapshot_at
  )into source_changed;
  source_changed:=source_changed or
    run.summary->'source_fingerprint' is distinct from
      public.v2_backfill_source_fingerprint(run.organization_id);
  if source_changed then
    update public.migration_backfill_runs set status='stale',
      finished_at=clock_timestamp(),summary=summary||jsonb_build_object(
        'final_error','V2_BACKFILL_SOURCE_CHANGED_AFTER_SNAPSHOT')where id=run.id;
    return jsonb_build_object('run_id',run.id,'status','stale',
      'error_code','V2_BACKFILL_SOURCE_CHANGED_AFTER_SNAPSHOT');
  end if;
  select count(*)into blockers from public.migration_backfill_findings f
  where f.run_id=run.id and f.severity='blocker';
  update public.migration_backfill_runs set
    status=case when blockers>0 then'blocked'else'prepared'end,
    finished_at=clock_timestamp()where id=run.id;
  return jsonb_build_object('run_id',run.id,
    'status',case when blockers>0 then'blocked'else'prepared'end,
    'blocker_count',blockers,'replayed',false);
end$$;

revoke execute on function public.v2_guard_backfill_evidence(),
  public.v2_backfill_uuid_fragment(uuid),
  public.v2_backfill_source_fingerprint(uuid),
  public.v2_backfill_finding(uuid,text,text,text,text,text,jsonb),
  public.v2_backfill_mapping(uuid,text,text,text,uuid,text)
from public,anon,authenticated,service_role;

revoke execute on function public.v2_start_backfill_run(uuid,text),
  public.v2_run_backfill_batch(uuid,text,integer),
  public.v2_finalize_backfill_run(uuid)
from public,anon,authenticated,service_role;
grant execute on function public.v2_start_backfill_run(uuid,text),
  public.v2_run_backfill_batch(uuid,text,integer),
  public.v2_finalize_backfill_run(uuid)
to service_role;

comment on table public.migration_backfill_runs is
  'Logical-snapshot dry-run/apply evidence. Prepared is not cutover.';
comment on table public.migration_entity_mappings is
  'Static mapping evidence only; target_table is never interpreted as SQL.';
