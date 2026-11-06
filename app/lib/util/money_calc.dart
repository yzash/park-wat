import '../data/models.dart';

double round2(num v) => (v * 100).roundToDouble() / 100;

/// Mirrors _recalc_order_totals() in SQL: CGST = SGST = subtotal × rate/2 %,
/// grand total rounded to the rupee.
({double subtotal, double cgst, double sgst, double roundOff, double total}) orderTotals(
    double subtotal, String category, double gstRate) {
  final sub = round2(subtotal);
  final half = category == InvoiceCategory.gst ? round2(sub * gstRate / 200) : 0.0;
  final raw = round2(sub + 2 * half);
  final total = raw.roundToDouble();
  return (subtotal: sub, cgst: half, sgst: half, roundOff: round2(total - raw), total: total);
}
