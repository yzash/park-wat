// End-to-end backend test against a running Supabase (local by default).
//   supabase start && supabase db reset && supabase functions serve &
//   node scripts/create-user.mjs admin "Plant Admin" admin admin1234   (etc., see README)
//   node --test scripts/backend.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

const URL = process.env.SUPABASE_URL ?? "http://127.0.0.1:54321";
const ANON = process.env.SUPABASE_ANON_KEY ??
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0";

const P = { jar: "11111111-0000-0000-0000-000000000001", l1: "11111111-0000-0000-0000-000000000002",
  ml500: "11111111-0000-0000-0000-000000000003", cup: "11111111-0000-0000-0000-000000000005" };
const PARTY = { ganesh: "33333333-0000-0000-0000-000000000001", cityMart: "33333333-0000-0000-0000-000000000004" };
const VEH = "22222222-0000-0000-0000-000000000001";
const DRV = "44444444-0000-0000-0000-000000000001";
const HOTEL = "33333333-0000-0000-0000-000000000003";

async function login(userId, password) {
  const c = createClient(URL, ANON, { auth: { persistSession: false } });
  const { data, error } = await c.auth.signInWithPassword({ email: `${userId}@parker.local`, password });
  if (error) throw error;
  return { c, uid: data.user.id, token: data.session.access_token };
}

async function fn(token, name, body) {
  const override = process.env[`FN_${name.replace("-", "_").toUpperCase()}`];
  const r = await fetch(override ?? `${URL}/functions/v1/${name}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, apikey: ANON, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return r;
}

const admin = await login("admin", "admin1234");
const ravi = await login("ravi", "ravi1234");
const sunil = await login("sunil", "sunil1234");

test("anon cannot read anything", async () => {
  const anon = createClient(URL, ANON, { auth: { persistSession: false } });
  const { data } = await anon.from("parties").select("*");
  assert.equal((data ?? []).length, 0);
});

test("order taker reads masters but cannot write them", async () => {
  const { data } = await ravi.c.from("products").select("*");
  assert.ok(data.length >= 5);
  const { error } = await ravi.c.from("products").insert({ name: "Hack", unit: "box", default_rate: 1 });
  assert.ok(error, "insert must be rejected");
  const { data: upd } = await ravi.c.from("products").update({ default_rate: 1 }).eq("id", P.jar).select();
  assert.equal(upd.length, 0);
});

let raviOrder;
test("submit order: rates from party list, default fallback, totals, order no", async () => {
  const id = randomUUID();
  const { data, error } = await ravi.c.rpc("submit_order", {
    p_id: id, p_party_id: PARTY.ganesh, p_vehicle_id: VEH, p_driver_id: DRV, p_invoice_category: 'general', p_notes: " gate 2 ",
    p_items: [{ product_id: P.jar, quantity: 10 }, { product_id: P.cup, quantity: 2 }],
  });
  assert.ifError(error);
  raviOrder = data;
  assert.match(data.order_no, /^PWP-\d{4}-\d{6}$/);
  assert.equal(data.notes, "gate 2");
  // jar 50 (party rate) × 10 + cup 110 (default) × 2
  assert.equal(Number(data.total_amount), 720);
  assert.equal(data.total_quantity, 12);
  const { data: items } = await ravi.c.from("order_items").select("*").eq("order_id", id).order("rate");
  assert.deepEqual(items.map((i) => [Number(i.rate), i.is_default_rate]), [[50, false], [110, true]]);
  assert.equal(data.created_by, ravi.uid);
});

test("submit is idempotent (offline retry)", async () => {
  const { data, error } = await ravi.c.rpc("submit_order", {
    p_id: raviOrder.id, p_party_id: PARTY.ganesh, p_vehicle_id: null, p_driver_id: null, p_invoice_category: 'general', p_notes: null,
    p_items: [{ product_id: P.jar, quantity: 99 }],
  });
  assert.ifError(error);
  assert.equal(data.order_no, raviOrder.order_no);
  assert.equal(data.total_quantity, 12);
});

test("validation: duplicates, zero qty, fractional qty, empty", async () => {
  for (const items of [
    [{ product_id: P.jar, quantity: 1 }, { product_id: P.jar, quantity: 2 }],
    [{ product_id: P.jar, quantity: 0 }],
    [{ product_id: P.jar, quantity: 1.5 }],
    [],
  ]) {
    const { error } = await ravi.c.rpc("submit_order", {
      p_id: randomUUID(), p_party_id: PARTY.ganesh, p_vehicle_id: null, p_driver_id: null, p_invoice_category: 'general', p_notes: null, p_items: items,
    });
    assert.ok(error, JSON.stringify(items));
  }
});

test("future-dated client time is clamped; latest effective rate wins", async () => {
  const { data, error } = await sunil.c.rpc("submit_order", {
    p_id: randomUUID(), p_party_id: PARTY.cityMart, p_vehicle_id: null, p_driver_id: null, p_invoice_category: 'general', p_notes: null,
    p_items: [{ product_id: P.jar, quantity: 1 }], p_order_datetime: "2099-01-01T00:00:00Z",
  });
  assert.ifError(error);
  assert.ok(new Date(data.order_datetime) <= new Date(Date.now() + 5000));
  assert.equal(Number(data.total_amount), 54); // Oct rate, not Jan rate
});

test("order taker sees only own orders", async () => {
  const { data } = await sunil.c.from("orders").select("id, created_by");
  assert.ok(data.length >= 1);
  assert.ok(data.every((o) => o.created_by === sunil.uid));
  const { data: s } = await sunil.c.rpc("search_orders", { p_filters: {} });
  assert.ok(s.every((o) => o.created_by === sunil.uid));
});

test("other taker cannot edit; owner can edit while Submitted; rates kept", async () => {
  const items = [{ product_id: P.jar, quantity: 20 }, { product_id: P.l1, quantity: 1 }];
  const { error: e1 } = await sunil.c.rpc("update_order", {
    p_id: raviOrder.id, p_party_id: PARTY.ganesh, p_vehicle_id: null, p_driver_id: null, p_notes: null, p_items: items,
  });
  assert.ok(e1);
  const { data, error } = await ravi.c.rpc("update_order", {
    p_id: raviOrder.id, p_party_id: PARTY.ganesh, p_vehicle_id: null, p_driver_id: null, p_notes: "edited", p_items: items,
  });
  assert.ifError(error);
  assert.equal(Number(data.total_amount), 20 * 50 + 105);
  assert.equal(data.vehicle_id, null);
});

test("status: only admin; logged; taker cannot edit afterwards", async () => {
  const { error: e } = await ravi.c.rpc("set_order_status", { p_id: raviOrder.id, p_status: "Delivered" });
  assert.ok(e);
  const { data, error } = await admin.c.rpc("set_order_status", { p_id: raviOrder.id, p_status: "Delivered" });
  assert.ifError(error);
  assert.equal(data.status, "Delivered");
  const { data: log } = await ravi.c.from("order_status_log").select("*").eq("order_id", raviOrder.id).order("changed_at");
  assert.deepEqual(log.map((l) => l.to_status), ["Submitted", "Delivered"]);
  assert.equal(log[1].changed_by, admin.uid);
  const { error: e2 } = await ravi.c.rpc("update_order", {
    p_id: raviOrder.id, p_party_id: PARTY.ganesh, p_vehicle_id: null, p_driver_id: null, p_notes: null,
    p_items: [{ product_id: P.jar, quantity: 1 }],
  });
  assert.ok(e2);
});

test("admin search with combined filters and totals", async () => {
  const today = new Date(Date.now() + 5.5 * 3600e3).toISOString().slice(0, 10);
  const { data: all } = await admin.c.rpc("search_orders", { p_filters: { from_date: today, to_date: today } });
  assert.ok(all.length >= 2);
  assert.equal(Number(all[0].total_count), all.length);
  const { data: f } = await admin.c.rpc("search_orders", {
    p_filters: { product_ids: [P.l1], user_ids: [ravi.uid], vehicle_ids: ["none"], statuses: ["Delivered"] },
  });
  assert.equal(f.length, 1);
  assert.equal(f[0].id, raviOrder.id);
  assert.match(f[0].products_summary, /20 L Jar × 20/);
  for (const g of ["party", "product", "vehicle", "user", "day"]) {
    const { data, error } = await admin.c.rpc("order_totals", { p_group_by: g, p_filters: {} });
    assert.ifError(error);
    assert.ok(data.length >= 1, g);
  }
  const { data: byProd } = await admin.c.rpc("order_totals", { p_group_by: "product", p_filters: { product_ids: [P.l1] } });
  assert.equal(byProd.length, 1);
});

test("audit fields and audit log", async () => {
  const { data: p, error } = await admin.c.from("products").insert({ name: "Test 5 L Can", unit: "can", default_rate: 30 }).select().single();
  assert.ifError(error);
  assert.equal(p.created_by, admin.uid);
  const { data: p2 } = await admin.c.from("products").update({ default_rate: 35, created_by: ravi.uid }).eq("id", p.id).select().single();
  assert.equal(p2.created_by, admin.uid, "created_by is immutable");
  assert.equal(p2.updated_by, admin.uid);
  const { data: log } = await admin.c.from("audit_log").select("*").eq("record_id", p.id);
  assert.equal(log.length, 2);
  const { data: tlog } = await ravi.c.from("audit_log").select("*");
  assert.equal(tlog.length, 0);
});

test("bulk import parties and rates", async () => {
  const { data, error } = await admin.c.rpc("import_masters", {
    p_parties: [{ name: "New Party One", phone: "99" }, { name: "City Mart", contact_name: "Rina D." }, { name: "" }],
    p_rates: [
      { party_name: "new party one", product_name: "20 L Jar", rate: "45", effective_from: "2026-11-01" },
      { party_name: "Nobody", product_name: "20 L Jar", rate: 1 },
      { party_name: "New Party One", product_name: "20 L Jar", rate: "abc" },
    ],
  });
  assert.ifError(error);
  assert.equal(data.parties_created, 1);
  assert.equal(data.parties_updated, 1);
  assert.equal(data.rates_saved, 1);
  assert.equal(data.errors.length, 3);
  const { error: e } = await ravi.c.rpc("import_masters", { p_parties: [], p_rates: [] });
  assert.ok(e);
});

test("admin-users function: create, duplicate, reset, deactivate blocks login", async () => {
  let r = await fn(ravi.token, "admin-users", { action: "create", user_id: "x1", full_name: "X", role: "order_taker", password: "12345678" });
  assert.equal(r.status, 403);
  const uid = "temp" + Date.now().toString().slice(-6);
  r = await fn(admin.token, "admin-users", { action: "create", user_id: uid, full_name: "Temp User", role: "order_taker", password: "temp12345" });
  const body = await r.json();
  assert.equal(r.status, 200, JSON.stringify(body));
  r = await fn(admin.token, "admin-users", { action: "create", user_id: uid, full_name: "Dup", role: "order_taker", password: "temp12345" });
  assert.equal(r.status, 409);
  r = await fn(admin.token, "admin-users", { action: "reset_password", id: body.user.id, password: "newpass123" });
  assert.equal(r.status, 200);
  const t = await login(uid, "newpass123");
  assert.equal(t.uid, body.user.id);
  r = await fn(admin.token, "admin-users", { action: "set_active", id: body.user.id, is_active: false });
  assert.equal(r.status, 200);
  await assert.rejects(login(uid, "newpass123"));
  // existing session of a deactivated user is cut off by RLS
  const { data } = await t.c.from("products").select("id");
  assert.equal(data.length, 0);
  r = await fn(admin.token, "admin-users", { action: "set_active", id: admin.uid, is_active: false });
  assert.equal(r.status, 400);
});

test("export-orders returns an xlsx with both sheets", async () => {
  let r = await fn(ravi.token, "export-orders", { filters: {} });
  assert.equal(r.status, 403);
  r = await fn(admin.token, "export-orders", { filters: { statuses: ["Delivered", "Submitted"] } });
  assert.equal(r.status, 200, await r.clone().text());
  assert.match(r.headers.get("content-type"), /spreadsheetml/);
  const buf = Buffer.from(await r.arrayBuffer());
  assert.equal(buf.subarray(0, 2).toString(), "PK");
  const s = buf.toString("latin1");
  assert.ok(Number(r.headers.get("x-order-count")) >= 2);
  assert.ok(s.includes("xl/worksheets/sheet2.xml"));
});

// ---- v1.1: drivers, rate override, invoice categories ------------------------
const submit = (who, extra) => who.c.rpc("submit_order", {
  p_id: randomUUID(), p_party_id: HOTEL, p_vehicle_id: VEH, p_driver_id: DRV, p_invoice_category: "general",
  p_notes: null, p_items: [{ product_id: P.jar, quantity: 1 }], ...extra,
});

test("settings: everyone reads, only admin writes", async () => {
  const { data } = await ravi.c.from("app_settings").select("*").single();
  assert.equal(Number(data.gst_rate), 5);
  const { data: upd } = await ravi.c.from("app_settings").update({ gst_next_no: 1 }).eq("id", 1).select();
  assert.equal(upd.length, 0);
  const { error } = await admin.c.from("app_settings").update({ gst_next_no: 1263 }).eq("id", 1);
  assert.ifError(error);
});

let gstOrder;
test("GST order: override rate, 2.5% + 2.5%, round off, series from admin start point", async () => {
  const { data, error } = await submit(ravi, {
    p_invoice_category: "gst", p_items: [{ product_id: P.jar, quantity: 150, rate: 111 }],
  });
  assert.ifError(error);
  gstOrder = data;
  assert.match(data.invoice_no, /^1263\/PWP\/\d\d-\d\d$/);
  assert.equal(Number(data.subtotal), 16650);
  assert.equal(Number(data.cgst_amount), 416.25);
  assert.equal(Number(data.sgst_amount), 416.25);
  assert.equal(Number(data.round_off), 0.5);
  assert.equal(Number(data.total_amount), 17483);
  assert.equal(data.has_rate_override, true);
  assert.equal(data.driver_id, DRV);
  const { data: item } = await ravi.c.from("order_items").select("*").eq("order_id", data.id).single();
  assert.equal(Number(item.standard_rate), 55);
  assert.equal(item.is_rate_override, true);
  const { data: next } = await submit(sunil, { p_invoice_category: "gst" });
  assert.match(next.invoice_no, /^1264\/PWP\//);
});

test("General series is separate, sequential, no tax", async () => {
  const { data: a } = await submit(ravi, {});
  const { data: b } = await submit(ravi, {});
  assert.match(a.invoice_no, /^\d+$/);
  assert.equal(Number(b.invoice_no), Number(a.invoice_no) + 1);
  assert.equal(Number(a.cgst_amount), 0);
  assert.equal(Number(a.total_amount), 55);
  assert.equal(a.has_rate_override, false);
});

test("invalid override rate rejected; unknown category rejected", async () => {
  let { error } = await submit(ravi, { p_items: [{ product_id: P.jar, quantity: 1, rate: "-5" }] });
  assert.ok(error);
  ({ error } = await submit(ravi, { p_items: [{ product_id: P.jar, quantity: 1, rate: "1.234" }] }));
  assert.ok(error);
  ({ error } = await submit(ravi, { p_invoice_category: "other" }));
  assert.ok(error);
});

test("edit keeps override unless reset; category and invoice no fixed; GST recalculated", async () => {
  let { data, error } = await ravi.c.rpc("update_order", {
    p_id: gstOrder.id, p_party_id: HOTEL, p_vehicle_id: null, p_driver_id: null, p_notes: null,
    p_items: [{ product_id: P.jar, quantity: 100 }],
  });
  assert.ifError(error);
  assert.equal(Number(data.subtotal), 11100); // kept 111
  assert.equal(Number(data.total_amount), 11655);
  assert.equal(data.invoice_no, gstOrder.invoice_no);
  assert.equal(data.invoice_category, "gst");
  ({ data } = await ravi.c.rpc("update_order", {
    p_id: gstOrder.id, p_party_id: HOTEL, p_vehicle_id: null, p_driver_id: DRV, p_notes: null,
    p_items: [{ product_id: P.jar, quantity: 100, rate: 55 }],
  }));
  assert.equal(data.has_rate_override, false);
  assert.equal(Number(data.total_amount), Math.round(5500 * 1.05));
});

test("filters and totals by driver and category; override flag filter", async () => {
  const { data: byDrv } = await admin.c.rpc("search_orders", { p_filters: { driver_ids: [DRV] } });
  assert.ok(byDrv.length >= 3 && byDrv.every((o) => o.driver_id === DRV && o.driver_name === "Ramesh Bhai"));
  const { data: none } = await admin.c.rpc("search_orders", { p_filters: { driver_ids: ["none"] } });
  assert.ok(none.every((o) => o.driver_id === null));
  const { data: gst } = await admin.c.rpc("search_orders", { p_filters: { categories: ["gst"] } });
  assert.ok(gst.length >= 2 && gst.every((o) => o.invoice_category === "gst"));
  const { data: inv } = await admin.c.rpc("search_orders", { p_filters: { search: "1264/PWP" } });
  assert.equal(inv.length, 1);
  for (const g of ["driver", "category"]) {
    const { data, error } = await admin.c.rpc("order_totals", { p_group_by: g, p_filters: {} });
    assert.ifError(error);
    assert.ok(data.length >= 1);
  }
  const { data: lines } = await admin.c.rpc("search_order_lines", { p_filters: { categories: ["gst"] } });
  assert.ok(lines.every((l) => l.hsn_code === "22011010"));
});
