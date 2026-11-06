-- Order write paths, search, summaries and bulk import.
-- Write functions are SECURITY DEFINER and enforce every business rule here, so
-- they hold even if a client is tampered with. Read functions are SECURITY
-- INVOKER, so row-level security decides what each caller can see.

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

create or replace function public.jsonb_text_array(p jsonb)
returns text[]
language sql
immutable
as $$
  select case
    when p is null or jsonb_typeof(p) <> 'array' or jsonb_array_length(p) = 0 then null
    else array(select jsonb_array_elements_text(p))
  end
$$;

create or replace function public.require_active_user()
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_active_user() then
    raise exception 'Not signed in or account inactive' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

-- Validates line items and writes them for an order, keeping the saved rate of
-- products that were already on the order (so edits never re-price old lines
-- unless the party changed). Recomputes order totals.
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
  v_default    boolean;
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

    select * into v_existing from public.order_items
     where order_id = p_order_id and product_id = v_product_id;
    v_has_line := found;

    if v_has_line and not p_reprice then
      v_rate := v_existing.rate;
      v_default := v_existing.is_default_rate;
    else
      select er.rate, er.is_default_rate into v_rate, v_default
        from public.effective_rate(p_party_id, v_product_id, p_on) er;
      if v_rate is null then
        raise exception 'Unknown product %', v_product_id using errcode = '22023';
      end if;
    end if;

    if v_has_line then
      update public.order_items
         set quantity = v_qty, rate = v_rate, is_default_rate = v_default,
             amount = round(v_qty * v_rate, 2), updated_by = auth.uid()
       where id = v_existing.id
         and (quantity, rate, is_default_rate) is distinct from (v_qty, v_rate, v_default);
    else
      insert into public.order_items (order_id, product_id, quantity, rate, amount, is_default_rate, created_by)
      values (p_order_id, v_product_id, v_qty, v_rate, round(v_qty * v_rate, 2), v_default, auth.uid());
    end if;
  end loop;

  delete from public.order_items
   where order_id = p_order_id and not (product_id = any(v_seen));

  update public.orders o
     set total_quantity = t.qty, total_amount = t.amt
    from (select coalesce(sum(quantity), 0) qty, coalesce(sum(amount), 0) amt
            from public.order_items where order_id = p_order_id) t
   where o.id = p_order_id
     and (o.total_quantity, o.total_amount) is distinct from (t.qty, t.amt);
end;
$$;
revoke all on function public._write_order_items(uuid, uuid, date, jsonb, boolean) from public, anon, authenticated;

-------------------------------------------------------------------------------
-- Submit (idempotent — the phone generates p_id, so a retried offline sync
-- never creates a duplicate).
-------------------------------------------------------------------------------

create or replace function public.submit_order(
  p_id             uuid,
  p_party_id       uuid,
  p_vehicle_id     uuid,
  p_notes          text,
  p_items          jsonb,
  p_order_datetime timestamptz default null
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

  if not exists (select 1 from public.parties where id = p_party_id) then
    raise exception 'Party is required' using errcode = '22023';
  end if;
  if p_vehicle_id is not null and not exists (select 1 from public.vehicles where id = p_vehicle_id) then
    raise exception 'Unknown vehicle' using errcode = '22023';
  end if;

  -- Captured on the phone at submit (may be earlier if it was queued offline);
  -- never in the future.
  v_when := least(coalesce(p_order_datetime, now()), now());

  insert into public.orders (id, order_no, party_id, vehicle_id, notes, order_datetime, created_by)
  values (p_id, '', p_party_id, p_vehicle_id, nullif(trim(p_notes), ''), v_when, v_uid)
  returning * into v_order;

  perform public._write_order_items(
    v_order.id, p_party_id, (v_when at time zone public.plant_tz())::date, p_items, true);

  select * into v_order from public.orders where id = v_order.id;
  return v_order;
end;
$$;

-------------------------------------------------------------------------------
-- Edit — owner while Submitted, admin always.
-------------------------------------------------------------------------------

create or replace function public.update_order(
  p_id         uuid,
  p_party_id   uuid,
  p_vehicle_id uuid,
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

  update public.orders
     set party_id = p_party_id, vehicle_id = p_vehicle_id,
         notes = nullif(trim(p_notes), ''), updated_by = v_uid
   where id = p_id
     and (party_id, vehicle_id, notes) is distinct from (p_party_id, p_vehicle_id, nullif(trim(p_notes), ''));

  perform public._write_order_items(
    p_id, p_party_id, (v_order.order_datetime at time zone public.plant_tz())::date,
    p_items, v_order.party_id <> p_party_id);

  select * into v_order from public.orders where id = p_id;
  return v_order;
end;
$$;

-------------------------------------------------------------------------------
-- Status lifecycle — admin only. Each change lands in order_status_log.
-------------------------------------------------------------------------------

create or replace function public.set_order_status(p_id uuid, p_status text)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid   uuid := public.require_active_user();
  v_order public.orders;
begin
  if not public.is_admin() then
    raise exception 'Only admin can change order status' using errcode = '42501';
  end if;
  if not exists (select 1 from public.order_statuses where code = p_status) then
    raise exception 'Unknown status %', p_status using errcode = '22023';
  end if;
  update public.orders set status = p_status, updated_by = v_uid
   where id = p_id
  returning * into v_order;
  if not found then
    raise exception 'Order not found' using errcode = 'P0002';
  end if;
  return v_order;
end;
$$;

-------------------------------------------------------------------------------
-- Search. Filters (all optional, combinable), as jsonb:
--   from_date, to_date   plant-local dates, inclusive ("YYYY-MM-DD")
--   party_ids, product_ids, user_ids   uuid arrays
--   vehicle_ids          uuid array; the string "none" matches "No vehicle"
--   statuses             text array
--   search               matches order no / notes / party name
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
  v_status text[] := public.jsonb_text_array(f -> 'statuses');
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
     and (v_prod is null or exists (
           select 1 from public.order_items i where i.order_id = o.id and i.product_id = any(v_prod)))
     and (v_search is null
          or o.order_no ilike '%' || v_search || '%'
          or o.notes ilike '%' || v_search || '%'
          or exists (select 1 from public.parties pa
                      where pa.id = o.party_id and pa.name ilike '%' || v_search || '%'));
end;
$$;

create or replace function public.search_orders(
  p_filters jsonb default '{}'::jsonb,
  p_limit   int   default 100,
  p_offset  int   default 0
)
returns table (
  id                uuid,
  order_no          text,
  order_datetime    timestamptz,
  order_local       timestamp,
  party_id          uuid,
  party_name        text,
  vehicle_id        uuid,
  vehicle_number    text,
  vehicle_label     text,
  notes             text,
  status            text,
  total_quantity    int,
  total_amount      numeric,
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
  select p.id, p.order_no, p.order_datetime, p.order_datetime at time zone public.plant_tz(),
         p.party_id, pa.name, p.vehicle_id, v.vehicle_number, v.label,
         p.notes, p.status, p.total_quantity, p.total_amount,
         (select string_agg(pr.name || ' × ' || i.quantity, ', ' order by pr.name)
            from public.order_items i join public.products pr on pr.id = i.product_id
           where i.order_id = p.id),
         p.created_by, u.full_name, u.user_id,
         p.created_at, p.updated_at, uu.full_name,
         c.n
    from page p
    join public.parties pa on pa.id = p.party_id
    left join public.vehicles v on v.id = p.vehicle_id
    left join public.users u on u.id = p.created_by
    left join public.users uu on uu.id = p.updated_by
   cross join c
   order by p.order_datetime desc, p.order_no desc
$$;

-- One row per order line for the filtered orders (Excel "Order Lines" sheet).
create or replace function public.search_order_lines(
  p_filters jsonb default '{}'::jsonb,
  p_limit   int   default 1000,
  p_offset  int   default 0
)
returns table (
  order_id        uuid,
  order_no        text,
  order_datetime  timestamptz,
  order_local     timestamp,
  status          text,
  party_name      text,
  vehicle_number  text,
  vehicle_label   text,
  created_by_name text,
  product_name    text,
  unit            text,
  quantity        int,
  rate            numeric,
  amount          numeric,
  is_default_rate boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  select o.id, o.order_no, o.order_datetime, o.order_datetime at time zone public.plant_tz(), o.status,
         pa.name, v.vehicle_number, v.label, u.full_name,
         pr.name, pr.unit, i.quantity, i.rate, i.amount, i.is_default_rate
    from public.filter_orders(p_filters) o
    join public.order_items i on i.order_id = o.id
    join public.products pr on pr.id = i.product_id
    join public.parties pa on pa.id = o.party_id
    left join public.vehicles v on v.id = o.vehicle_id
    left join public.users u on u.id = o.created_by
   order by o.order_datetime desc, o.order_no desc, pr.name
   limit greatest(least(coalesce(p_limit, 1000), 5000), 1)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

-------------------------------------------------------------------------------
-- Summary totals (FR-13): group_by = party | product | vehicle | user | day
-- By product, quantities/amounts come from the order lines (only the filtered
-- products if a product filter is set); otherwise from order totals.
-------------------------------------------------------------------------------

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

-------------------------------------------------------------------------------
-- Bulk import of parties and rate lists (FR-14). Admin only.
--   p_parties: [{name, contact_name, phone, address}]   upsert by name
--   p_rates:   [{party_name, product_name, rate, effective_from}]
-- Returns counts and a list of row errors; valid rows are applied.
-------------------------------------------------------------------------------

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
        is_active    = true
      where id = v_party_id;
      v_p_upd := v_p_upd + 1;
    else
      insert into public.parties (name, contact_name, phone, address)
      values (v_name, nullif(trim(v_row ->> 'contact_name'), ''), nullif(trim(v_row ->> 'phone'), ''),
              nullif(trim(v_row ->> 'address'), ''));
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

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

revoke all on function public.submit_order(uuid, uuid, uuid, text, jsonb, timestamptz) from public, anon;
revoke all on function public.update_order(uuid, uuid, uuid, text, jsonb) from public, anon;
revoke all on function public.set_order_status(uuid, text) from public, anon;
revoke all on function public.import_masters(jsonb, jsonb) from public, anon;
revoke all on function public.search_orders(jsonb, int, int) from public, anon;
revoke all on function public.search_order_lines(jsonb, int, int) from public, anon;
revoke all on function public.order_totals(text, jsonb) from public, anon;
revoke all on function public.filter_orders(jsonb) from public, anon;

grant execute on function public.submit_order(uuid, uuid, uuid, text, jsonb, timestamptz) to authenticated;
grant execute on function public.update_order(uuid, uuid, uuid, text, jsonb) to authenticated;
grant execute on function public.set_order_status(uuid, text) to authenticated;
grant execute on function public.import_masters(jsonb, jsonb) to authenticated;
grant execute on function public.search_orders(jsonb, int, int) to authenticated;
grant execute on function public.search_order_lines(jsonb, int, int) to authenticated;
grant execute on function public.order_totals(text, jsonb) to authenticated;
grant execute on function public.filter_orders(jsonb) to authenticated;
