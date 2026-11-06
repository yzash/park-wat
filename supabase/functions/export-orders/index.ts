// Excel export of the admin's current All Orders filter (FR-11).
// Runs as the calling user, so row-level security still applies; additionally
// restricted to admins. Produces two sheets: Orders and Order Lines.
import ExcelJS from "npm:exceljs@4.4.0";
import { corsHeaders, handle, HttpError, requireAdmin } from "../_shared/auth.ts";

const PAGE = 1000; // PostgREST max_rows
const MAX_ROWS = 100_000;

// order_local is a plant-local "timestamp without time zone" string. Build a
// Date whose UTC fields equal the local wall-clock time so Excel shows it as-is.
function localDate(s: string | null): Date | null {
  if (!s) return null;
  return new Date(s.endsWith("Z") ? s : s + "Z");
}

async function fetchAll(
  client: { rpc: (fn: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: { message: string } | null }> },
  fn: string,
  filters: unknown,
): Promise<Record<string, unknown>[]> {
  const rows: Record<string, unknown>[] = [];
  for (let offset = 0; offset < MAX_ROWS; offset += PAGE) {
    const { data, error } = await client.rpc(fn, { p_filters: filters, p_limit: PAGE, p_offset: offset });
    if (error) throw new HttpError(500, error.message);
    const page = (data ?? []) as Record<string, unknown>[];
    rows.push(...page);
    if (page.length < PAGE) break;
  }
  return rows;
}

Deno.serve(handle(async (req) => {
  const { client } = await requireAdmin(req);
  const body = await req.json().catch(() => ({}));
  const filters = body?.filters ?? {};

  const [orders, lines] = await Promise.all([
    fetchAll(client, "search_orders", filters),
    fetchAll(client, "search_order_lines", filters),
  ]);

  const wb = new ExcelJS.Workbook();
  wb.creator = "Parker Water Products";
  wb.created = new Date();

  const money = "#,##0.00";
  const dateFmt = "dd-mmm-yyyy";
  const timeFmt = "hh:mm";

  const os = wb.addWorksheet("Orders", { views: [{ state: "frozen", ySplit: 1 }] });
  os.columns = [
    { header: "Order No", key: "order_no", width: 18 },
    { header: "Invoice No", key: "invoice_no", width: 18 },
    { header: "Category", key: "category", width: 10 },
    { header: "Date", key: "date", width: 13, style: { numFmt: dateFmt } },
    { header: "Time", key: "time", width: 9, style: { numFmt: timeFmt } },
    { header: "Party", key: "party", width: 28 },
    { header: "Products", key: "products", width: 45 },
    { header: "Total Qty", key: "qty", width: 10 },
    { header: "Taxable Value", key: "subtotal", width: 14, style: { numFmt: money } },
    { header: "GST", key: "gst", width: 11, style: { numFmt: money } },
    { header: "Total Amount", key: "amount", width: 14, style: { numFmt: money } },
    { header: "Rate Changed?", key: "override", width: 13 },
    { header: "Vehicle", key: "vehicle", width: 16 },
    { header: "Vehicle Label", key: "vehicle_label", width: 20 },
    { header: "Driver", key: "driver", width: 18 },
    { header: "Order Taker", key: "taker", width: 20 },
    { header: "Status", key: "status", width: 11 },
    { header: "Notes", key: "notes", width: 30 },
    { header: "Last Updated By", key: "updated_by", width: 18 },
  ];
  for (const o of orders) {
    const d = localDate(o.order_local as string);
    os.addRow({
      order_no: o.order_no,
      invoice_no: o.invoice_no,
      category: o.invoice_category === "gst" ? "GST" : "General",
      date: d,
      time: d,
      party: o.party_name,
      products: o.products_summary,
      qty: o.total_quantity,
      subtotal: Number(o.subtotal),
      gst: Number(o.gst_amount),
      amount: Number(o.total_amount),
      override: o.has_rate_override ? "Yes" : "No",
      vehicle: o.vehicle_number ?? "No vehicle",
      vehicle_label: o.vehicle_label ?? "",
      driver: o.driver_name ?? "No driver",
      taker: o.created_by_name,
      status: o.status,
      notes: o.notes ?? "",
      updated_by: o.updated_by_name ?? "",
    });
  }

  const ls = wb.addWorksheet("Order Lines", { views: [{ state: "frozen", ySplit: 1 }] });
  ls.columns = [
    { header: "Order No", key: "order_no", width: 18 },
    { header: "Invoice No", key: "invoice_no", width: 18 },
    { header: "Category", key: "category", width: 10 },
    { header: "Date", key: "date", width: 13, style: { numFmt: dateFmt } },
    { header: "Time", key: "time", width: 9, style: { numFmt: timeFmt } },
    { header: "Party", key: "party", width: 28 },
    { header: "Product", key: "product", width: 26 },
    { header: "HSN", key: "hsn", width: 11 },
    { header: "Unit", key: "unit", width: 8 },
    { header: "Quantity", key: "qty", width: 10 },
    { header: "Rate", key: "rate", width: 10, style: { numFmt: money } },
    { header: "List Rate", key: "std_rate", width: 10, style: { numFmt: money } },
    { header: "Rate Changed?", key: "override", width: 13 },
    { header: "Amount (before GST)", key: "amount", width: 18, style: { numFmt: money } },
    { header: "Default Rate?", key: "default_rate", width: 13 },
    { header: "Vehicle", key: "vehicle", width: 16 },
    { header: "Driver", key: "driver", width: 18 },
    { header: "Order Taker", key: "taker", width: 20 },
    { header: "Status", key: "status", width: 11 },
  ];
  for (const l of lines) {
    const d = localDate(l.order_local as string);
    ls.addRow({
      order_no: l.order_no,
      invoice_no: l.invoice_no,
      category: l.invoice_category === "gst" ? "GST" : "General",
      date: d,
      time: d,
      party: l.party_name,
      product: l.product_name,
      hsn: l.hsn_code ?? "",
      unit: l.unit,
      qty: l.quantity,
      rate: Number(l.rate),
      std_rate: l.standard_rate == null ? null : Number(l.standard_rate),
      override: l.is_rate_override ? "Yes" : "No",
      amount: Number(l.amount),
      default_rate: l.is_default_rate ? "Yes" : "No",
      vehicle: l.vehicle_number ?? "No vehicle",
      driver: l.driver_name ?? "No driver",
      taker: l.created_by_name,
      status: l.status,
    });
  }

  for (const ws of [os, ls]) {
    const header = ws.getRow(1);
    header.font = { bold: true, color: { argb: "FFFFFFFF" } };
    header.fill = { type: "pattern", pattern: "solid", fgColor: { argb: "FF0B5394" } };
    ws.autoFilter = { from: { row: 1, column: 1 }, to: { row: 1, column: ws.columnCount } };
  }

  const buf = await wb.xlsx.writeBuffer();
  // file name stamped in plant time (IST, UTC+5:30)
  const stamp = new Date(Date.now() + 330 * 60_000).toISOString().slice(0, 16).replace(/[-:]/g, "").replace("T", "-");
  return new Response(buf, {
    headers: {
      ...corsHeaders,
      "Content-Type": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "Content-Disposition": `attachment; filename="PWP-orders-${stamp}.xlsx"`,
      "X-Order-Count": String(orders.length),
    },
  });
}));
