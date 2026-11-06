-- v1.1: drivers master, rate override, invoice categories (General / GST),
-- invoice number series, company/invoice settings.

-------------------------------------------------------------------------------
-- Settings (single row): company details printed on invoices, GST rate and
-- invoice number series. Admin edits; everyone signed in reads.
-------------------------------------------------------------------------------

create table public.app_settings (
  id                     int primary key default 1 check (id = 1),
  company_name           text not null default 'PARKAR WATER PRODUCTS',
  company_address        text default E'PLOT NO -58,1-B, INDUSTRIAL AREA,\nADIPUR-370205',
  company_gstin          text default '24AAQFP1422M1Z2',
  company_pan            text default 'AAQFP1422M',
  company_phone          text,
  jurisdiction           text default 'GANDHIDHAM',
  gst_rate               numeric(5, 2) not null default 5 check (gst_rate >= 0 and gst_rate <= 28),
  -- {n} = running number, {fy} = financial year like 26-27, {yyyy} = calendar year
  gst_invoice_format     text not null default '{n}/PWP/{fy}' check (gst_invoice_format like '%{n}%'),
  gst_next_no            int not null default 1 check (gst_next_no >= 1),
  general_invoice_format text not null default '{n}' check (general_invoice_format like '%{n}%'),
  general_next_no        int not null default 1 check (general_next_no >= 1),
  created_at             timestamptz not null default now(),
  created_by             uuid references public.users (id),
  updated_at             timestamptz not null default now(),
  updated_by             uuid references public.users (id)
);
insert into public.app_settings (id) values (1);

create trigger app_settings_audit before insert or update on public.app_settings
  for each row execute function public.set_audit_fields();
create trigger app_settings_audit_log after insert or update or delete on public.app_settings
  for each row execute function public.audit_row();

alter table public.app_settings enable row level security;
create policy app_settings_read on public.app_settings for select to authenticated
  using ((select public.is_active_user()));
create policy app_settings_update on public.app_settings for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
revoke insert, delete on public.app_settings from anon, authenticated;

-------------------------------------------------------------------------------
-- Drivers master
-------------------------------------------------------------------------------

create table public.drivers (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(trim(name)) > 0),
  phone      text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references public.users (id),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id)
);
create unique index drivers_name_key on public.drivers (lower(trim(name)));

create trigger drivers_audit before insert or update on public.drivers
  for each row execute function public.set_audit_fields();
create trigger drivers_audit_log after insert or update or delete on public.drivers
  for each row execute function public.audit_row();

alter table public.drivers enable row level security;
create policy drivers_read on public.drivers for select to authenticated
  using ((select public.is_active_user()));
create policy drivers_insert on public.drivers for insert to authenticated
  with check ((select public.is_admin()));
create policy drivers_update on public.drivers for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));

-------------------------------------------------------------------------------
-- Master additions
-------------------------------------------------------------------------------

alter table public.parties add column gstin text;
alter table public.products add column hsn_code text;

-------------------------------------------------------------------------------
-- Orders: driver, invoice category / number, tax breakdown
-- total_amount is now the grand total (incl. GST and round-off).
-------------------------------------------------------------------------------

alter table public.orders
  add column driver_id        uuid references public.drivers (id),
  add column invoice_category text not null default 'general' check (invoice_category in ('general', 'gst')),
  add column invoice_no       text,
  add column gst_rate         numeric(5, 2) not null default 0,
  add column subtotal         numeric(14, 2) not null default 0,
  add column cgst_amount      numeric(14, 2) not null default 0,
  add column sgst_amount      numeric(14, 2) not null default 0,
  add column round_off        numeric(6, 2) not null default 0,
  add column has_rate_override boolean not null default false;

create index orders_driver_idx on public.orders (driver_id, order_datetime desc);

alter table public.order_items
  add column standard_rate    numeric(12, 2),        -- party/default rate at save time
  add column is_rate_override boolean not null default false;

update public.order_items set standard_rate = rate where standard_rate is null;
update public.orders set subtotal = total_amount;

-- Financial year label for a plant-local date: April–March, e.g. 26-27.
create or replace function public.fy_label(p_on date)
returns text
language sql
immutable
as $$
  select case when extract(month from p_on) >= 4
    then to_char(p_on, 'YY') || '-' || to_char(p_on + interval '1 year', 'YY')
    else to_char(p_on - interval '1 year', 'YY') || '-' || to_char(p_on, 'YY')
  end
$$;

-- Takes the next number of a series (row-locked) and formats it. Skips numbers
-- already used, so an admin moving the start point backwards cannot cause clashes.
create or replace function public._next_invoice_no(p_category text, p_when timestamptz)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  s     public.app_settings;
  v_no  int;
  v_fmt text;
  v_on  date := (p_when at time zone public.plant_tz())::date;
  v_out text;
begin
  select * into s from public.app_settings where id = 1 for update;
  if p_category = 'gst' then
    v_no := s.gst_next_no; v_fmt := s.gst_invoice_format;
  else
    v_no := s.general_next_no; v_fmt := s.general_invoice_format;
  end if;
  loop
    v_out := replace(replace(replace(v_fmt, '{n}', v_no::text), '{fy}', public.fy_label(v_on)),
                     '{yyyy}', extract(year from v_on)::text);
    exit when not exists (select 1 from public.orders where invoice_category = p_category and invoice_no = v_out);
    v_no := v_no + 1;
  end loop;
  if p_category = 'gst' then
    update public.app_settings set gst_next_no = v_no + 1 where id = 1;
  else
    update public.app_settings set general_next_no = v_no + 1 where id = 1;
  end if;
  return v_out;
end;
$$;
revoke all on function public._next_invoice_no(text, timestamptz) from public, anon, authenticated;

-- Existing (pre-v1.1) orders become General with numbers in date order.
do $$
declare r record;
begin
  for r in select id, order_datetime from public.orders where invoice_no is null order by order_datetime, order_no loop
    update public.orders set invoice_no = public._next_invoice_no('general', r.order_datetime) where id = r.id;
  end loop;
end $$;

alter table public.orders alter column invoice_no set not null;
create unique index orders_invoice_no_key on public.orders (invoice_category, invoice_no);

-------------------------------------------------------------------------------
-- Totals: subtotal, CGST/SGST (half of gst_rate each), round off to rupee.
-------------------------------------------------------------------------------

create or replace function public._recalc_order_totals(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  o      public.orders;
  v_sub  numeric;
  v_qty  int;
  v_ovr  boolean;
  v_half numeric;
  v_tot  numeric;
begin
  select * into o from public.orders where id = p_order_id;
  select coalesce(sum(amount), 0), coalesce(sum(quantity), 0), coalesce(bool_or(is_rate_override), false)
    into v_sub, v_qty, v_ovr
    from public.order_items where order_id = p_order_id;
  v_half := case when o.invoice_category = 'gst' then round(v_sub * o.gst_rate / 200, 2) else 0 end;
  v_tot := v_sub + 2 * v_half;
  update public.orders
     set subtotal = v_sub, cgst_amount = v_half, sgst_amount = v_half,
         round_off = round(v_tot) - v_tot, total_amount = round(v_tot),
         total_quantity = v_qty, has_rate_override = v_ovr
   where id = p_order_id
     and (subtotal, cgst_amount, sgst_amount, total_amount, total_quantity, has_rate_override)
         is distinct from (v_sub, v_half, v_half, round(v_tot), v_qty, v_ovr);
end;
$$;
revoke all on function public._recalc_order_totals(uuid) from public, anon, authenticated;

-- Line writer, now with optional rate override per line: {product_id, quantity, rate?}.
-- A line without "rate" keeps its saved rate (or gets the list rate if new /
-- repriced); a line with "rate" uses it and is flagged if it differs from the list rate.
create or replace function public._write_order_items(
  p_order_id uuid,
  p_party_id uuid,
  p_on       date,
  p_items    jsonb,
  p_reprice  boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item       jsonb;
  v_product_id uuid;
  v_qty        int;
  v_rate       numeric;
  v_std        numeric;
  v_default    boolean;
  v_override   boolean;
  v_seen       uuid[] := '{}';
  v_existing   public.order_items;
  v_has_line   boolean;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'An order needs at least one product' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    if v_product_id is null then
      raise exception 'Line item without product' using errcode = '22023';
    end if;
    if v_product_id = any(v_seen) then
      raise exception 'The same product cannot be added twice' using errcode = '22023';
    end if;
    v_seen := v_seen || v_product_id;

    if (v_item ->> 'quantity') !~ '^\s*[0-9]+\s*$' then
      raise exception 'Quantity must be a whole number' using errcode = '22023';
    end if;
    v_qty := (v_item ->> 'quantity')::int;
    if v_qty <= 0 then
      raise exception 'Quantity must be at least 1' using errcode = '22023';
    end if;

    select er.rate, er.is_default_rate into v_std, v_default
      from public.effective_rate(p_party_id, v_product_id, p_on) er;
    if v_std is null then
      raise exception 'Unknown product %', v_product_id using errcode = '22023';
    end if;

    select * into v_existing from public.order_items
     where order_id = p_order_id and product_id = v_product_id;
    v_has_line := found;

    if v_item ? 'rate' and v_item ->> 'rate' is not null then
      if (v_item ->> 'rate') !~ '^\s*[0-9]+(\.[0-9]{1,2})?\s*$' then
        raise exception 'Rate must be a number with up to 2 decimals' using errcode = '22023';
      end if;
      v_rate := (v_item ->> 'rate')::numeric;
      v_override := v_rate <> v_std;
    elsif v_has_line and not p_reprice then
      v_rate := v_existing.rate;
      v_std := coalesce(v_existing.standard_rate, v_existing.rate);
      v_default := v_existing.is_default_rate;
      v_override := v_existing.is_rate_override;
    else
      v_rate := v_std;
      v_override := false;
    end if;

    if v_has_line then
      update public.order_items
         set quantity = v_qty, rate = v_rate, standard_rate = v_std, is_default_rate = v_default,
             is_rate_override = v_override, amount = round(v_qty * v_rate, 2), updated_by = auth.uid()
       where id = v_existing.id
         and (quantity, rate, standard_rate, is_default_rate, is_rate_override)
             is distinct from (v_qty, v_rate, v_std, v_default, v_override);
    else
      insert into public.order_items (order_id, product_id, quantity, rate, standard_rate, amount,
                                      is_default_rate, is_rate_override, created_by)
      values (p_order_id, v_product_id, v_qty, v_rate, v_std, round(v_qty * v_rate, 2),
              v_default, v_override, auth.uid());
    end if;
  end loop;

  delete from public.order_items
   where order_id = p_order_id and not (product_id = any(v_seen));

  perform public._recalc_order_totals(p_order_id);
end;
$$;
revoke all on function public._write_order_items(uuid, uuid, date, jsonb, boolean) from public, anon, authenticated;

-------------------------------------------------------------------------------
-- submit / update with driver and invoice category
-------------------------------------------------------------------------------

drop function public.submit_order(uuid, uuid, uuid, text, jsonb, timestamptz);
drop function public.update_order(uuid, uuid, uuid, text, jsonb);

create or replace function public.submit_order(
  p_id               uuid,
  p_party_id         uuid,
  p_vehicle_id       uuid,
  p_driver_id        uuid,
  p_invoice_category text,
  p_notes            text,
  p_items            jsonb,
  p_order_datetime   timestamptz default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := public.require_active_user();
  v_order public.orders;
  v_when  timestamptz;
  v_cat   text := coalesce(p_invoice_category, 'general');
begin
  if p_id is null then
    raise exception 'Order id is required' using errcode = '22023';
  end if;

  select * into v_order from public.orders where id = p_id;
  if found then
    if v_order.created_by <> v_uid then
      raise exception 'Order id already used' using errcode = '23505';
    end if;
    return v_order; -- already synced
  end if;

  if v_cat not in ('general', 'gst') then
    raise exception 'Invoice category must be general or gst' using errcode = '22023';
  end if;
  if not exists (select 1 from public.parties where id = p_party_id) then
    raise exception 'Party is required' using errcode = '22023';
  end if;
  if p_vehicle_id is not null and not exists (select 1 from public.vehicles where id = p_vehicle_id) then
    raise exception 'Unknown vehicle' using errcode = '22023';
  end if;
  if p_driver_id is not null and not exists (select 1 from public.drivers where id = p_driver_id) then
    raise exception 'Unknown driver' using errcode = '22023';
  end if;

  v_when := least(coalesce(p_order_datetime, now()), now());

  insert into public.orders (id, order_no, party_id, vehicle_id, driver_id, notes, order_datetime, created_by,
                             invoice_category, invoice_no, gst_rate)
  values (p_id, '', p_party_id, p_vehicle_id, p_driver_id, nullif(trim(p_notes), ''), v_when, v_uid,
          v_cat, public._next_invoice_no(v_cat, v_when),
          case when v_cat = 'gst' then (select gst_rate from public.app_settings where id = 1) else 0 end)
  returning * into v_order;

  perform public._write_order_items(
    v_order.id, p_party_id, (v_when at time zone public.plant_tz())::date, p_items, true);

  select * into v_order from public.orders where id = v_order.id;
  return v_order;
end;
$$;

-- Invoice category and number are fixed once submitted.
create or replace function public.update_order(
  p_id         uuid,
  p_party_id   uuid,
  p_vehicle_id uuid,
  p_driver_id  uuid,
  p_notes      text,
  p_items      jsonb
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := public.require_active_user();
  v_admin boolean := public.is_admin();
  v_order public.orders;
begin
  select * into v_order from public.orders where id = p_id for update;
  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  if not v_admin then
    if v_order.created_by <> v_uid then
      raise exception 'You can only edit your own orders' using errcode = '42501';
    end if;
    if v_order.status <> 'Submitted' then
      raise exception 'Order can no longer be edited (status %)', v_order.status using errcode = '42501';
    end if;
  end if;

  if not exists (select 1 from public.parties where id = p_party_id) then
    raise exception 'Party is required' using errcode = '22023';
  end if;
  if p_vehicle_id is not null and not exists (select 1 from public.vehicles where id = p_vehicle_id) then
    raise exception 'Unknown vehicle' using errcode = '22023';
  end if;
  if p_driver_id is not null and not exists (select 1 from public.drivers where id = p_driver_id) then
    raise exception 'Unknown driver' using errcode = '22023';
  end if;

  update public.orders
     set party_id = p_party_id, vehicle_id = p_vehicle_id, driver_id = p_driver_id,
         notes = nullif(trim(p_notes), ''), updated_by = v_uid
   where id = p_id
     and (party_id, vehicle_id, driver_id, notes)
         is distinct from (p_party_id, p_vehicle_id, p_driver_id, nullif(trim(p_notes), ''));

  perform public._write_order_items(
    p_id, p_party_id, (v_order.order_datetime at time zone public.plant_tz())::date,
    p_items, v_order.party_id <> p_party_id);

  select * into v_order from public.orders where id = p_id;
  return v_order;
end;
$$;

revoke all on function public.submit_order(uuid, uuid, uuid, uuid, text, text, jsonb, timestamptz) from public, anon;
revoke all on function public.update_order(uuid, uuid, uuid, uuid, text, jsonb) from public, anon;
grant execute on function public.submit_order(uuid, uuid, uuid, uuid, text, text, jsonb, timestamptz) to authenticated;
grant execute on function public.update_order(uuid, uuid, uuid, uuid, text, jsonb) to authenticated;

-------------------------------------------------------------------------------
-- Search / lines / totals with driver, category and invoice number
-------------------------------------------------------------------------------

create or replace function public.filter_orders(p_filters jsonb)
returns setof public.orders
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  f        jsonb  := coalesce(p_filters, '{}'::jsonb);
  v_from   date   := nullif(f ->> 'from_date', '')::date;
  v_to     date   := nullif(f ->> 'to_date', '')::date;
  v_party  uuid[] := public.jsonb_text_array(f -> 'party_ids')::uuid[];
  v_prod   uuid[] := public.jsonb_text_array(f -> 'product_ids')::uuid[];
  v_user   uuid[] := public.jsonb_text_array(f -> 'user_ids')::uuid[];
  v_veh    text[] := public.jsonb_text_array(f -> 'vehicle_ids');
  v_drv    text[] := public.jsonb_text_array(f -> 'driver_ids');
  v_cat    text[] := public.jsonb_text_array(f -> 'categories');
  v_status text[] := public.jsonb_text_array(f -> 'statuses');
  v_ovr    boolean := (f ->> 'rate_override')::boolean;
  v_search text   := nullif(trim(f ->> 'search'), '');
begin
  return query
  select o.*
    from public.orders o
   where (v_from is null or o.order_datetime >= (v_from::timestamp at time zone public.plant_tz()))
     and (v_to is null or o.order_datetime < ((v_to + 1)::timestamp at time zone public.plant_tz()))
     and (v_party is null or o.party_id = any(v_party))
     and (v_user is null or o.created_by = any(v_user))
     and (v_status is null or o.status = any(v_status))
     and (v_veh is null or coalesce(o.vehicle_id::text, 'none') = any(v_veh))
     and (v_drv is null or coalesce(o.driver_id::text, 'none') = any(v_drv))
     and (v_cat is null or o.invoice_category = any(v_cat))
     and (v_ovr is null or o.has_rate_override = v_ovr)
     and (v_prod is null or exists (
           select 1 from public.order_items i where i.order_id = o.id and i.product_id = any(v_prod)))
     and (v_search is null
          or o.order_no ilike '%' || v_search || '%'
          or o.invoice_no ilike '%' || v_search || '%'
          or o.notes ilike '%' || v_search || '%'
          or exists (select 1 from public.parties pa
                      where pa.id = o.party_id and pa.name ilike '%' || v_search || '%'));
end;
$$;

drop function public.search_orders(jsonb, int, int);
create function public.search_orders(
  p_filters jsonb default '{}'::jsonb,
  p_limit   int   default 100,
  p_offset  int   default 0
)
returns table (
  id                uuid,
  order_no          text,
  invoice_no        text,
  invoice_category  text,
  order_datetime    timestamptz,
  order_local       timestamp,
  party_id          uuid,
  party_name        text,
  vehicle_id        uuid,
  vehicle_number    text,
  vehicle_label     text,
  driver_id         uuid,
  driver_name       text,
  notes             text,
  status            text,
  total_quantity    int,
  subtotal          numeric,
  gst_amount        numeric,
  total_amount      numeric,
  has_rate_override boolean,
  products_summary  text,
  created_by        uuid,
  created_by_name   text,
  created_by_login  text,
  created_at        timestamptz,
  updated_at        timestamptz,
  updated_by_name   text,
  total_count       bigint
)
language sql
stable
security invoker
set search_path = public
as $$
  with f as (
    select * from public.filter_orders(p_filters)
  ),
  c as (
    select count(*) as n from f
  ),
  page as (
    select * from f
     order by f.order_datetime desc, f.order_no desc
     limit greatest(least(coalesce(p_limit, 100), 5000), 1)
    offset greatest(coalesce(p_offset, 0), 0)
  )
  select p.id, p.order_no, p.invoice_no, p.invoice_category,
         p.order_datetime, p.order_datetime at time zone public.plant_tz(),
         p.party_id, pa.name, p.vehicle_id, v.vehicle_number, v.label, p.driver_id, d.name,
         p.notes, p.status, p.total_quantity, p.subtotal, p.cgst_amount + p.sgst_amount, p.total_amount,
         p.has_rate_override,
         (select string_agg(pr.name || ' × ' || i.quantity, ', ' order by pr.name)
            from public.order_items i join public.products pr on pr.id = i.product_id
           where i.order_id = p.id),
         p.created_by, u.full_name, u.user_id,
         p.created_at, p.updated_at, uu.full_name,
         c.n
    from page p
    join public.parties pa on pa.id = p.party_id
    left join public.vehicles v on v.id = p.vehicle_id
    left join public.drivers d on d.id = p.driver_id
    left join public.users u on u.id = p.created_by
    left join public.users uu on uu.id = p.updated_by
   cross join c
   order by p.order_datetime desc, p.order_no desc
$$;

drop function public.search_order_lines(jsonb, int, int);
create function public.search_order_lines(
  p_filters jsonb default '{}'::jsonb,
  p_limit   int   default 1000,
  p_offset  int   default 0
)
returns table (
  order_id         uuid,
  order_no         text,
  invoice_no       text,
  invoice_category text,
  order_datetime   timestamptz,
  order_local      timestamp,
  status           text,
  party_name       text,
  vehicle_number   text,
  vehicle_label    text,
  driver_name      text,
  created_by_name  text,
  product_name     text,
  hsn_code         text,
  unit             text,
  quantity         int,
  rate             numeric,
  standard_rate    numeric,
  amount           numeric,
  is_default_rate  boolean,
  is_rate_override boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select o.id, o.order_no, o.invoice_no, o.invoice_category,
         o.order_datetime, o.order_datetime at time zone public.plant_tz(), o.status,
         pa.name, v.vehicle_number, v.label, d.name, u.full_name,
         pr.name, pr.hsn_code, pr.unit, i.quantity, i.rate, i.standard_rate, i.amount,
         i.is_default_rate, i.is_rate_override
    from public.filter_orders(p_filters) o
    join public.order_items i on i.order_id = o.id
    join public.products pr on pr.id = i.product_id
    join public.parties pa on pa.id = o.party_id
    left join public.vehicles v on v.id = o.vehicle_id
    left join public.drivers d on d.id = o.driver_id
    left join public.users u on u.id = o.created_by
   order by o.order_datetime desc, o.order_no desc, pr.name
   limit greatest(least(coalesce(p_limit, 1000), 5000), 1)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

create or replace function public.order_totals(p_group_by text, p_filters jsonb default '{}'::jsonb)
returns table (
  group_key      text,
  group_label    text,
  order_count    bigint,
  total_quantity bigint,
  total_amount   numeric
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_prod uuid[] := public.jsonb_text_array(coalesce(p_filters, '{}'::jsonb) -> 'product_ids')::uuid[];
begin
  case p_group_by
  when 'party' then
    return query
      select o.party_id::text, pa.name, count(*), sum(o.total_quantity)::bigint, sum(o.total_amount)
        from public.filter_orders(p_filters) o join public.parties pa on pa.id = o.party_id
       group by o.party_id, pa.name order by sum(o.total_amount) desc, pa.name;
  when 'vehicle' then
    return query
      select coalesce(o.vehicle_id::text, 'none'),
             coalesce(v.vehicle_number || coalesce(' · ' || v.label, ''), 'No vehicle'),
             count(*), sum(o.total_quantity)::bigint, sum(o.total_amount)
        from public.filter_orders(p_filters) o left join public.vehicles v on v.id = o.vehicle_id
       group by o.vehicle_id, v.vehicle_number, v.label order by sum(o.total_amount) desc;
  when 'driver' then
    return query
      select coalesce(o.driver_id::text, 'none'), coalesce(d.name, 'No driver'),
             count(*), sum(o.total_quantity)::bigint, sum(o.total_amount)
        from public.filter_orders(p_filters) o left join public.drivers d on d.id = o.driver_id
       group by o.driver_id, d.name order by sum(o.total_amount) desc;
  when 'category' then
    return query
      select o.invoice_category, case o.invoice_category when 'gst' then 'GST' else 'General' end,
             count(*), sum(o.total_quantity)::bigint, sum(o.total_amount)
        from public.filter_orders(p_filters) o
       group by o.invoice_category order by o.invoice_category;
  when 'user' then
    return query
      select o.created_by::text, coalesce(u.full_name, '?'), count(*), sum(o.total_quantity)::bigint, sum(o.total_amount)
        from public.filter_orders(p_filters) o left join public.users u on u.id = o.created_by
       group by o.created_by, u.full_name order by sum(o.total_amount) desc;
  when 'day' then
    return query
      select d::text, to_char(d, 'DD Mon YYYY'), count(*), sum(x.total_quantity)::bigint, sum(x.total_amount)
        from (select (o.order_datetime at time zone public.plant_tz())::date d, o.total_quantity, o.total_amount
                from public.filter_orders(p_filters) o) x
       group by d order by d desc;
  when 'product' then
    -- line amounts are before GST
    return query
      select i.product_id::text, pr.name || ' (' || pr.unit || ')', count(distinct o.id),
             sum(i.quantity)::bigint, sum(i.amount)
        from public.filter_orders(p_filters) o
        join public.order_items i on i.order_id = o.id
        join public.products pr on pr.id = i.product_id
       where v_prod is null or i.product_id = any(v_prod)
       group by i.product_id, pr.name, pr.unit order by sum(i.amount) desc;
  else
    raise exception 'Unknown group_by %', p_group_by using errcode = '22023';
  end case;
end;
$$;

-- import: parties may now carry a GSTIN
create or replace function public.import_masters(p_parties jsonb, p_rates jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := public.require_active_user();
  v_row        jsonb;
  v_idx        int := 0;
  v_errors     jsonb := '[]'::jsonb;
  v_p_new      int := 0;
  v_p_upd      int := 0;
  v_r_cnt      int := 0;
  v_party_id   uuid;
  v_product_id uuid;
  v_rate       numeric;
  v_eff        date;
  v_name       text;
begin
  if not public.is_admin() then
    raise exception 'Admin only' using errcode = '42501';
  end if;

  for v_row in select * from jsonb_array_elements(coalesce(p_parties, '[]'::jsonb)) loop
    v_idx := v_idx + 1;
    v_name := nullif(trim(v_row ->> 'name'), '');
    if v_name is null then
      v_errors := v_errors || jsonb_build_object('sheet', 'Parties', 'row', v_idx + 1, 'error', 'Name is empty');
      continue;
    end if;
    select id into v_party_id from public.parties where lower(trim(name)) = lower(v_name);
    if found then
      update public.parties set
        contact_name = coalesce(nullif(trim(v_row ->> 'contact_name'), ''), contact_name),
        phone        = coalesce(nullif(trim(v_row ->> 'phone'), ''), phone),
        address      = coalesce(nullif(trim(v_row ->> 'address'), ''), address),
        gstin        = coalesce(upper(nullif(trim(v_row ->> 'gstin'), '')), gstin),
        is_active    = true
      where id = v_party_id;
      v_p_upd := v_p_upd + 1;
    else
      insert into public.parties (name, contact_name, phone, address, gstin)
      values (v_name, nullif(trim(v_row ->> 'contact_name'), ''), nullif(trim(v_row ->> 'phone'), ''),
              nullif(trim(v_row ->> 'address'), ''), upper(nullif(trim(v_row ->> 'gstin'), '')));
      v_p_new := v_p_new + 1;
    end if;
  end loop;

  v_idx := 0;
  for v_row in select * from jsonb_array_elements(coalesce(p_rates, '[]'::jsonb)) loop
    v_idx := v_idx + 1;
    select id into v_party_id from public.parties
     where lower(trim(name)) = lower(trim(v_row ->> 'party_name'));
    if not found then
      v_errors := v_errors || jsonb_build_object('sheet', 'Rates', 'row', v_idx + 1,
        'error', 'Unknown party: ' || coalesce(v_row ->> 'party_name', ''));
      continue;
    end if;
    select id into v_product_id from public.products
     where lower(trim(name)) = lower(trim(v_row ->> 'product_name'));
    if not found then
      v_errors := v_errors || jsonb_build_object('sheet', 'Rates', 'row', v_idx + 1,
        'error', 'Unknown product: ' || coalesce(v_row ->> 'product_name', ''));
      continue;
    end if;
    begin
      v_rate := (v_row ->> 'rate')::numeric;
      v_eff  := coalesce(nullif(trim(v_row ->> 'effective_from'), '')::date,
                         (now() at time zone public.plant_tz())::date);
    exception when others then
      v_errors := v_errors || jsonb_build_object('sheet', 'Rates', 'row', v_idx + 1,
        'error', 'Invalid rate or date');
      continue;
    end;
    if v_rate is null or v_rate < 0 then
      v_errors := v_errors || jsonb_build_object('sheet', 'Rates', 'row', v_idx + 1, 'error', 'Invalid rate');
      continue;
    end if;
    insert into public.party_rates (party_id, product_id, rate, effective_from)
    values (v_party_id, v_product_id, v_rate, v_eff)
    on conflict (party_id, product_id, effective_from) do update set rate = excluded.rate;
    v_r_cnt := v_r_cnt + 1;
  end loop;

  return jsonb_build_object(
    'parties_created', v_p_new,
    'parties_updated', v_p_upd,
    'rates_saved', v_r_cnt,
    'errors', v_errors);
end;
$$;

revoke all on function public.search_orders(jsonb, int, int) from public, anon;
revoke all on function public.search_order_lines(jsonb, int, int) from public, anon;
grant execute on function public.search_orders(jsonb, int, int) to authenticated;
grant execute on function public.search_order_lines(jsonb, int, int) to authenticated;
revoke all on function public.fy_label(date) from anon;
