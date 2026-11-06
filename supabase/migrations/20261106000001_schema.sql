-- Parker Water Products — Sales & Order Tracking
-- Core schema: master data, users, orders, audit, row-level security.
--
-- Conventions
--   * Every table carries created_at / created_by / updated_at / updated_by,
--     maintained by the set_audit_fields() trigger. created_* is immutable.
--   * Master records are soft-deleted via is_active so old orders keep references.
--   * All timestamps are timestamptz (stored UTC). The plant time zone is defined
--     once in plant_tz() and used for day boundaries, order-number year and reports.

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------

create or replace function public.plant_tz()
returns text
language sql
immutable
as $$ select 'Asia/Kolkata'::text $$;

comment on function public.plant_tz() is
  'Plant local time zone. Change here (new migration) if the plant is elsewhere.';

-------------------------------------------------------------------------------
-- Roles & users
-------------------------------------------------------------------------------

-- Roles are rows, not an enum, so a new role (Supervisor, Driver…) is an INSERT.
create table public.roles (
  code  text primary key,
  label text not null
);

insert into public.roles (code, label) values
  ('admin', 'Admin'),
  ('order_taker', 'Order Taker');

-- Profile for each login. The password hash lives in auth.users (bcrypt, managed
-- by Supabase Auth); login is "<user_id>@parker.local" behind the scenes.
create table public.users (
  id         uuid primary key references auth.users (id) on delete restrict,
  user_id    text not null,
  full_name  text not null,
  role       text not null references public.roles (code),
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references public.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id),
  constraint users_user_id_format check (user_id ~ '^[a-z0-9][a-z0-9._-]{1,39}$')
);
create unique index users_user_id_key on public.users (lower(user_id));

-------------------------------------------------------------------------------
-- Audit helpers
-------------------------------------------------------------------------------

create or replace function public.set_audit_fields()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.updated_at := new.created_at;
    new.updated_by := new.created_by;
  else
    -- created_* can never change
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    new.updated_at := now();
    -- service-role writers (edge functions) pass updated_by explicitly
    new.updated_by := coalesce(auth.uid(), new.updated_by);
  end if;
  return new;
end;
$$;

create trigger users_audit before insert or update on public.users
  for each row execute function public.set_audit_fields();

-- Append-only audit trail of master-data and order changes (FR-17).
create table public.audit_log (
  id         bigint generated always as identity primary key,
  table_name text not null,
  record_id  text not null,
  action     text not null,
  old_data   jsonb,
  new_data   jsonb,
  changed_at timestamptz not null default now(),
  changed_by uuid
);
create index audit_log_record_idx on public.audit_log (table_name, record_id);
create index audit_log_changed_at_idx on public.audit_log (changed_at desc);

create or replace function public.audit_row()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new jsonb := case when tg_op <> 'DELETE' then to_jsonb(new) end;
  v_old jsonb := case when tg_op <> 'INSERT' then to_jsonb(old) end;
begin
  if tg_op = 'UPDATE' and v_new - 'updated_at' = v_old - 'updated_at' then
    return new; -- nothing meaningful changed
  end if;
  insert into public.audit_log (table_name, record_id, action, old_data, new_data, changed_by)
  values (
    tg_table_name,
    coalesce(v_new ->> 'id', v_old ->> 'id'),
    tg_op,
    v_old,
    v_new,
    coalesce(auth.uid(), (v_new ->> 'updated_by')::uuid, (v_old ->> 'updated_by')::uuid)
  );
  return coalesce(new, old);
end;
$$;

create trigger users_audit_log after insert or update or delete on public.users
  for each row execute function public.audit_row();

-------------------------------------------------------------------------------
-- Role helpers (used by RLS). SECURITY DEFINER so they can read users under RLS.
-------------------------------------------------------------------------------

create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.users where id = auth.uid() and is_active
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select role = 'admin' from public.users where id = auth.uid() and is_active), false)
$$;

create or replace function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.users where id = auth.uid() and is_active)
$$;

-------------------------------------------------------------------------------
-- Master data
-------------------------------------------------------------------------------

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(trim(name)) > 0),
  unit         text not null check (length(trim(unit)) > 0),
  default_rate numeric(12, 2) not null default 0 check (default_rate >= 0),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  created_by   uuid references public.users (id),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references public.users (id)
);
create unique index products_name_key on public.products (lower(trim(name)));

create table public.vehicles (
  id             uuid primary key default gen_random_uuid(),
  vehicle_number text not null check (length(trim(vehicle_number)) > 0),
  label          text,
  is_active      boolean not null default true,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.users (id),
  updated_at     timestamptz not null default now(),
  updated_by     uuid references public.users (id)
);
create unique index vehicles_number_key on public.vehicles (upper(replace(vehicle_number, ' ', '')));

create table public.parties (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (length(trim(name)) > 0),
  contact_name text,
  phone        text,
  address      text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  created_by   uuid references public.users (id),
  updated_at   timestamptz not null default now(),
  updated_by   uuid references public.users (id)
);
create unique index parties_name_key on public.parties (lower(trim(name)));

-- One row per party × product × effective date. Latest effective_from (<= the
-- order date) wins; older rows stay for history.
create table public.party_rates (
  id             uuid primary key default gen_random_uuid(),
  party_id       uuid not null references public.parties (id),
  product_id     uuid not null references public.products (id),
  rate           numeric(12, 2) not null check (rate >= 0),
  effective_from date not null default ((now() at time zone public.plant_tz())::date),
  created_at     timestamptz not null default now(),
  created_by     uuid references public.users (id),
  updated_at     timestamptz not null default now(),
  updated_by     uuid references public.users (id),
  unique (party_id, product_id, effective_from)
);
create index party_rates_lookup_idx on public.party_rates (party_id, product_id, effective_from desc);

create trigger products_audit before insert or update on public.products
  for each row execute function public.set_audit_fields();
create trigger vehicles_audit before insert or update on public.vehicles
  for each row execute function public.set_audit_fields();
create trigger parties_audit before insert or update on public.parties
  for each row execute function public.set_audit_fields();
create trigger party_rates_audit before insert or update on public.party_rates
  for each row execute function public.set_audit_fields();

create trigger products_audit_log after insert or update or delete on public.products
  for each row execute function public.audit_row();
create trigger vehicles_audit_log after insert or update or delete on public.vehicles
  for each row execute function public.audit_row();
create trigger parties_audit_log after insert or update or delete on public.parties
  for each row execute function public.audit_row();
create trigger party_rates_audit_log after insert or update or delete on public.party_rates
  for each row execute function public.audit_row();

-- Rate currently in force for each party × product (used by the app cache).
create view public.current_party_rates
with (security_invoker = true)
as
select distinct on (r.party_id, r.product_id)
  r.party_id, r.product_id, r.rate, r.effective_from
from public.party_rates r
where r.effective_from <= (now() at time zone public.plant_tz())::date
order by r.party_id, r.product_id, r.effective_from desc, r.created_at desc;

-- Rate for a party × product on a given plant-local date, falling back to the
-- product default rate.
create or replace function public.effective_rate(p_party_id uuid, p_product_id uuid, p_on date)
returns table (rate numeric, is_default_rate boolean)
language sql
stable
set search_path = public
as $$
  select coalesce(pr.rate, p.default_rate), pr.rate is null
  from public.products p
  left join lateral (
    select r.rate
    from public.party_rates r
    where r.party_id = p_party_id and r.product_id = p.id and r.effective_from <= p_on
    order by r.effective_from desc, r.created_at desc
    limit 1
  ) pr on true
  where p.id = p_product_id
$$;

-------------------------------------------------------------------------------
-- Orders
-------------------------------------------------------------------------------

create table public.order_statuses (
  code       text primary key,
  sort_order int not null
);
insert into public.order_statuses (code, sort_order) values
  ('Submitted', 1), ('Delivered', 2), ('Cancelled', 3);

-- Per-year counter → PWP-2026-000123 (gap-free within a year, row-locked).
create table public.order_counters (
  year    int primary key,
  last_no int not null default 0
);

create table public.orders (
  id             uuid primary key default gen_random_uuid(),  -- generated on the phone for offline idempotency
  order_no       text not null unique,
  party_id       uuid not null references public.parties (id),
  vehicle_id     uuid references public.vehicles (id),         -- null = "No vehicle"
  notes          text,
  status         text not null default 'Submitted' references public.order_statuses (code),
  order_datetime timestamptz not null default now(),
  total_quantity int not null default 0,
  total_amount   numeric(14, 2) not null default 0,
  created_at     timestamptz not null default now(),
  created_by     uuid not null references public.users (id),
  updated_at     timestamptz not null default now(),
  updated_by     uuid references public.users (id)
);
create index orders_datetime_idx on public.orders (order_datetime desc);
create index orders_party_idx on public.orders (party_id, order_datetime desc);
create index orders_vehicle_idx on public.orders (vehicle_id, order_datetime desc);
create index orders_created_by_idx on public.orders (created_by, order_datetime desc);
create index orders_status_idx on public.orders (status, order_datetime desc);

create table public.order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references public.orders (id) on delete cascade,
  product_id      uuid not null references public.products (id),
  quantity        int not null check (quantity > 0),
  rate            numeric(12, 2) not null check (rate >= 0),     -- copied at save time
  amount          numeric(14, 2) not null,
  is_default_rate boolean not null default false,
  created_at      timestamptz not null default now(),
  created_by      uuid references public.users (id),
  updated_at      timestamptz not null default now(),
  updated_by      uuid references public.users (id),
  unique (order_id, product_id)
);
create index order_items_product_idx on public.order_items (product_id, order_id);

create table public.order_status_log (
  id          bigint generated always as identity primary key,
  order_id    uuid not null references public.orders (id) on delete cascade,
  from_status text,
  to_status   text not null,
  changed_at  timestamptz not null default now(),
  changed_by  uuid references public.users (id)
);
create index order_status_log_order_idx on public.order_status_log (order_id, changed_at);

create or replace function public.assign_order_no()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_year int := extract(year from (new.order_datetime at time zone public.plant_tz()))::int;
  v_no   int;
begin
  if new.order_no is null or new.order_no = '' then
    insert into public.order_counters (year, last_no) values (v_year, 1)
    on conflict (year) do update set last_no = public.order_counters.last_no + 1
    returning last_no into v_no;
    new.order_no := 'PWP-' || v_year || '-' || lpad(v_no::text, 6, '0');
  end if;
  return new;
end;
$$;

create trigger orders_assign_no before insert on public.orders
  for each row execute function public.assign_order_no();
create trigger orders_audit before insert or update on public.orders
  for each row execute function public.set_audit_fields();
create trigger order_items_audit before insert or update on public.order_items
  for each row execute function public.set_audit_fields();
create trigger orders_audit_log after insert or update or delete on public.orders
  for each row execute function public.audit_row();
create trigger order_items_audit_log after insert or update or delete on public.order_items
  for each row execute function public.audit_row();

create or replace function public.log_order_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.order_status_log (order_id, from_status, to_status, changed_by)
    values (new.id, case when tg_op = 'UPDATE' then old.status end, new.status,
            coalesce(auth.uid(), new.updated_by));
  end if;
  return new;
end;
$$;

create trigger orders_status_log after insert or update of status on public.orders
  for each row execute function public.log_order_status();

-------------------------------------------------------------------------------
-- Row-level security
-------------------------------------------------------------------------------

alter table public.roles            enable row level security;
alter table public.users            enable row level security;
alter table public.audit_log        enable row level security;
alter table public.products         enable row level security;
alter table public.vehicles         enable row level security;
alter table public.parties          enable row level security;
alter table public.party_rates      enable row level security;
alter table public.order_statuses   enable row level security;
alter table public.order_counters   enable row level security;
alter table public.orders           enable row level security;
alter table public.order_items      enable row level security;
alter table public.order_status_log enable row level security;

-- Lookups
create policy roles_read on public.roles for select to authenticated using (true);
create policy order_statuses_read on public.order_statuses for select to authenticated using (true);

-- Users: you see yourself; admin sees everyone. Writes go through the
-- admin-users edge function (service role), never directly from clients.
create policy users_read on public.users for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

-- Audit log: admin read-only; nobody can update or delete.
create policy audit_log_read on public.audit_log for select to authenticated
  using ((select public.is_admin()));

-- Master data: every active user reads (incl. inactive rows for history);
-- only admin writes. No DELETE policy: soft-delete with is_active.
create policy products_read on public.products for select to authenticated
  using ((select public.is_active_user()));
create policy products_insert on public.products for insert to authenticated
  with check ((select public.is_admin()));
create policy products_update on public.products for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy vehicles_read on public.vehicles for select to authenticated
  using ((select public.is_active_user()));
create policy vehicles_insert on public.vehicles for insert to authenticated
  with check ((select public.is_admin()));
create policy vehicles_update on public.vehicles for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy parties_read on public.parties for select to authenticated
  using ((select public.is_active_user()));
create policy parties_insert on public.parties for insert to authenticated
  with check ((select public.is_admin()));
create policy parties_update on public.parties for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

create policy party_rates_read on public.party_rates for select to authenticated
  using ((select public.is_active_user()));
create policy party_rates_insert on public.party_rates for insert to authenticated
  with check ((select public.is_admin()));
create policy party_rates_update on public.party_rates for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-- Orders: order takers read only their own; admin reads all. All writes go
-- through the SECURITY DEFINER functions below, which enforce the rules.
create policy orders_read on public.orders for select to authenticated
  using ((select public.is_admin())
         or (created_by = (select auth.uid()) and (select public.is_active_user())));

create policy order_items_read on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));

create policy order_status_log_read on public.order_status_log for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id));

-- Lock down direct table writes for API roles where there is no policy anyway,
-- and make sure the counter and audit tables are untouchable.
revoke insert, update, delete on public.orders, public.order_items, public.order_status_log,
  public.audit_log, public.order_counters, public.users, public.roles, public.order_statuses
  from anon, authenticated;
revoke all on public.order_counters from anon, authenticated;
revoke all on all tables in schema public from anon;
