import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import 'format.dart';

/// GST state codes (first two digits of a GSTIN).
const gstStates = <String, String>{
  '01': 'Jammu and Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab', '04': 'Chandigarh', '05': 'Uttarakhand',
  '06': 'Haryana', '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar', '11': 'Sikkim',
  '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram', '16': 'Tripura', '17': 'Meghalaya',
  '18': 'Assam', '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh', '23': 'Madhya Pradesh',
  '24': 'Gujarat', '26': 'Dadra and Nagar Haveli and Daman and Diu', '27': 'Maharashtra', '29': 'Karnataka', '30': 'Goa',
  '31': 'Lakshadweep', '32': 'Kerala', '33': 'Tamil Nadu', '34': 'Puducherry', '35': 'Andaman and Nicobar Islands',
  '36': 'Telangana', '37': 'Andhra Pradesh', '38': 'Ladakh',
};

/// "Gujarat, Code : 24" from a GSTIN, or null.
String? stateFromGstin(String? gstin) {
  if (gstin == null || gstin.trim().length < 2) return null;
  final code = gstin.trim().substring(0, 2);
  final name = gstStates[code];
  return name == null ? null : '$name, Code : $code';
}

const _ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve',
  'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const _tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

String _below100(int n) => n < 20 ? _ones[n] : '${_tens[n ~/ 10]}${n % 10 > 0 ? ' ${_ones[n % 10]}' : ''}';
String _below1000(int n) {
  final h = n ~/ 100, r = n % 100;
  return [if (h > 0) '${_ones[h]} Hundred', if (r > 0) _below100(r)].join(' ');
}

/// Indian numbering: 17483 → "Seventeen Thousand Four Hundred Eighty Three".
String numberToWords(int n) {
  if (n == 0) return 'Zero';
  final parts = <String>[];
  final crore = n ~/ 10000000;
  n %= 10000000;
  final lakh = n ~/ 100000;
  n %= 100000;
  final thousand = n ~/ 1000;
  n %= 1000;
  if (crore > 0) parts.add('${numberToWords(crore)} Crore');
  if (lakh > 0) parts.add('${_below100(lakh)} Lakh');
  if (thousand > 0) parts.add('${_below100(thousand)} Thousand');
  if (n > 0) parts.add(_below1000(n));
  return parts.join(' ');
}

/// "INR Eight Hundred Thirty Two and Fifty Paise Only"
String amountInWords(double amount) {
  final paise = ((amount * 100).round()) % 100;
  final rupees = (amount * 100).round() ~/ 100;
  return 'INR ${numberToWords(rupees)}${paise > 0 ? ' and ${_below100(paise)} Paise' : ''} Only';
}

final _amt = NumberFormat('#,##,##0.00', 'en_IN');
String _a(num v) => _amt.format(v);

/// Builds the invoice PDF. GST orders → "TAX INVOICE" with CGST/SGST, HSN
/// summary and buyer GSTIN; General orders → "INVOICE" with party name and
/// address only. Empty party fields are left blank.
Future<Uint8List> buildInvoicePdf(OrderDetail o, AppSettings s, {required pw.Font regular, required pw.Font bold}) async {
  final gst = o.isGst;
  final doc = pw.Document(
    title: 'Invoice ${o.invoiceNo}',
    author: s.companyName,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );
  const line = PdfColors.black;
  const bw = 0.6;
  const side = pw.BorderSide(color: line, width: bw);
  pw.TextStyle st(double size, {bool b = false}) => pw.TextStyle(fontSize: size, fontWeight: b ? pw.FontWeight.bold : null);
  final small = st(7.5), normal = st(8.5), normalB = st(8.5, b: true);
  final local = toPlant(o.orderDatetime);
  final dated = '${DateFormat('dd-MMM-yy').format(local)}  ${DateFormat('hh:mm a').format(local)}';

  // ---- header boxes -----------------------------------------------------------
  pw.Widget cell(String label, String? value, {bool boldValue = false, bool right = true, bool bottom = true}) => pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(3, 2, 3, 3),
        height: 30,
        decoration: pw.BoxDecoration(border: pw.Border(right: right ? side : pw.BorderSide.none, bottom: bottom ? side : pw.BorderSide.none)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: small),
          if (value != null && value.isNotEmpty) pw.Text(value, style: boldValue ? normalB : normal, maxLines: 1),
        ]),
      );
  pw.Widget cellRow(pw.Widget a, pw.Widget b) => pw.Row(children: [pw.Expanded(child: a), pw.Expanded(child: b)]);

  final companyLines = <pw.Widget>[
    pw.Text(s.companyName, style: st(9.5, b: true)),
    if ((s.companyAddress ?? '').isNotEmpty) pw.Text(s.companyAddress!, style: normal),
    if ((s.companyPhone ?? '').isNotEmpty) pw.Text('Phone: ${s.companyPhone}', style: normal),
    if (gst && (s.companyGstin ?? '').isNotEmpty) pw.Text('GSTIN/UIN: ${s.companyGstin}', style: normal),
    if (gst && stateFromGstin(s.companyGstin) != null) pw.Text('State Name : ${stateFromGstin(s.companyGstin)}', style: normal),
  ];
  final buyerLines = <pw.Widget>[
    pw.Text('Buyer (Bill to)', style: small),
    pw.Text(o.partyName, style: st(9.5, b: true)),
    pw.Text(o.partyAddress ?? '', style: normal),
    if (gst) ...[
      pw.SizedBox(height: 2),
      pw.Row(children: [pw.SizedBox(width: 60, child: pw.Text('GSTIN/UIN', style: normal)), pw.Text(': ${o.partyGstin ?? ''}', style: normal)]),
      pw.Row(children: [
        pw.SizedBox(width: 60, child: pw.Text('State Name', style: normal)),
        pw.Text(': ${stateFromGstin(o.partyGstin) ?? ''}', style: normal),
      ]),
    ],
  ];

  final header = pw.Table(
    columnWidths: const {0: pw.FlexColumnWidth(52), 1: pw.FlexColumnWidth(48)},
    border: const pw.TableBorder(left: side, right: side, top: side, verticalInside: side),
    children: [
      pw.TableRow(verticalAlignment: pw.TableCellVerticalAlignment.top, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: side)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: companyLines),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: buyerLines),
          ),
        ]),
        pw.Column(children: [
          cellRow(cell('Invoice No.', o.invoiceNo, boldValue: true), cell('Dated', dated, boldValue: true, right: false)),
          cellRow(cell('Order No.', o.orderNo), cell('Mode/Terms of Payment', null, right: false)),
          cellRow(cell('Reference No. and Date', null), cell('Other References', null, right: false)),
          cellRow(cell("Buyer's Order No.", null), cell('Dated', null, right: false)),
          cellRow(cell('Dispatched through', o.vehicleNumber), cell('Driver', o.driverName, right: false)),
          cellRow(cell('Destination', null), cell('Order Taker', o.createdByName, right: false)),
          pw.Container(
            height: 28,
            padding: const pw.EdgeInsets.all(3),
            alignment: pw.Alignment.topLeft,
            child: pw.Text('Terms of Delivery', style: small),
          ),
        ]),
      ]),
    ],
  );

  // ---- item table -------------------------------------------------------------
  final cols = <(String, int, pw.Alignment)>[
    ('Sl.\nNo.', 5, pw.Alignment.topCenter),
    ('Description of Goods', gst ? 40 : 48, pw.Alignment.topLeft),
    if (gst) ('HSN/SAC', 10, pw.Alignment.topCenter),
    ('Quantity', 11, pw.Alignment.topRight),
    ('Rate', 10, pw.Alignment.topRight),
    ('Per', 7, pw.Alignment.topCenter),
    ('Amount', 17, pw.Alignment.topRight),
  ];
  final colCount = cols.length;
  pw.Widget rowOf(List<pw.Widget?> cells, {double? height, bool topBorder = false, bool bottomBorder = false}) => pw.Table(
        columnWidths: {for (var i = 0; i < colCount; i++) i: pw.FlexColumnWidth(cols[i].$2.toDouble())},
        border: pw.TableBorder(
          left: side,
          right: side,
          verticalInside: side,
          top: topBorder ? side : pw.BorderSide.none,
          bottom: bottomBorder ? side : pw.BorderSide.none,
        ),
        children: [
          pw.TableRow(children: [
            for (var i = 0; i < colCount; i++)
              pw.Container(
                height: height,
                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                alignment: cols[i].$3,
                child: cells[i] ?? pw.SizedBox(),
              ),
          ]),
        ],
      );

  final units = o.items.map((i) => i.unit.toUpperCase()).toSet();
  final qtyTotal = units.length == 1 ? '${o.totalQuantity} ${units.first}' : '${o.totalQuantity}';
  final amountCol = colCount - 1;
  final descCol = 1;

  pw.Widget taxLine(String label, double amount) => rowOf([
        for (var i = 0; i < colCount; i++)
          i == descCol
              ? pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(label, style: normalB))
              : i == amountCol
                  ? pw.Text(_a(amount), style: normalB)
                  : null,
      ]);

  final itemRows = <pw.Widget>[
    rowOf([for (final c in cols) pw.Text(c.$1, style: normal, textAlign: pw.TextAlign.center)], topBorder: true, bottomBorder: true),
    for (var k = 0; k < o.items.length; k++)
      rowOf([
        pw.Text('${k + 1}', style: normalB),
        pw.Text(o.items[k].productName.toUpperCase(), style: normalB),
        if (gst) pw.Text(o.items[k].hsnCode ?? '', style: normal),
        pw.Text('${o.items[k].quantity} ${o.items[k].unit.toUpperCase()}', style: normalB),
        pw.Text(_a(o.items[k].rate), style: normal),
        pw.Text(o.items[k].unit.toUpperCase(), style: normal),
        pw.Text(_a(o.items[k].amount), style: normalB),
      ]),
    rowOf(List.filled(colCount, null), height: 8),
    if (gst) ...[
      taxLine('CGST', o.cgstAmount),
      taxLine('SGST', o.sgstAmount),
    ],
    if (o.roundOff != 0) taxLine('ROUND OFF', o.roundOff),
  ];

  final totalRow = rowOf([
    for (var i = 0; i < colCount; i++)
      i == descCol
          ? pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Total', style: normal))
          : cols[i].$1 == 'Quantity'
              ? pw.Text(qtyTotal, style: normalB)
              : i == amountCol
                  ? pw.Text('₹ ${_a(o.totalAmount)}', style: normalB)
                  : null,
  ], topBorder: true, bottomBorder: true);

  // ---- tax summary (GST only) ---------------------------------------------------
  pw.Widget? taxSummary;
  if (gst) {
    final byHsn = <String, double>{};
    for (final i in o.items) {
      byHsn.update(i.hsnCode ?? '', (v) => v + i.amount, ifAbsent: () => i.amount);
    }
    final halfRate = o.gstRate / 2;
    String pct(double r) => '${NumberFormat('0.##').format(r)}%';
    // split tax per HSN proportionally so totals reconcile with the order
    final keys = byHsn.keys.toList();
    final rows = <List<String>>[];
    var cgstLeft = o.cgstAmount, sgstLeft = o.sgstAmount;
    for (var k = 0; k < keys.length; k++) {
      final taxable = byHsn[keys[k]]!;
      final last = k == keys.length - 1;
      final c = last ? cgstLeft : double.parse((taxable * halfRate / 100).toStringAsFixed(2));
      final sg = last ? sgstLeft : c;
      cgstLeft -= c;
      sgstLeft -= sg;
      rows.add([keys[k], _a(taxable), pct(halfRate), _a(c), pct(halfRate), _a(sg), _a(c + sg)]);
    }
    const flex = [32, 13, 7, 11, 7, 11, 13];
    pw.Widget trow(List<String> c, {bool b = false, bool top = false}) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border(top: top ? side : pw.BorderSide.none)),
          child: pw.Row(children: [
            for (var i = 0; i < 7; i++)
              pw.Expanded(
                flex: flex[i],
                child: pw.Container(
                  height: 14,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 3),
                  alignment: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                  decoration: pw.BoxDecoration(border: pw.Border(left: i == 0 ? side : pw.BorderSide.none, right: side)),
                  child: pw.Text(c[i], style: b ? normalB : normal),
                ),
              ),
          ]),
        );
    taxSummary = pw.Column(children: [
      pw.Container(
        decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side, top: side, bottom: side)),
        child: pw.Row(children: [
          pw.Expanded(flex: 32, child: pw.Center(child: pw.Text('HSN/SAC', style: normal))),
          pw.Expanded(
              flex: 13,
              child: pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side)),
                  child: pw.Center(child: pw.Text('Taxable\nValue', style: normal, textAlign: pw.TextAlign.center)))),
          pw.Expanded(
            flex: 18,
            child: pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(right: side)),
              child: pw.Column(children: [
                pw.Text('CGST', style: normal),
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: side)),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 7, child: pw.Center(child: pw.Text('Rate', style: normal))),
                    pw.Expanded(flex: 11, child: pw.Center(child: pw.Text('Amount', style: normal))),
                  ]),
                ),
              ]),
            ),
          ),
          pw.Expanded(
            flex: 18,
            child: pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(right: side)),
              child: pw.Column(children: [
                pw.Text('SGST/UTGST', style: normal),
                pw.Container(
                  decoration: const pw.BoxDecoration(border: pw.Border(top: side)),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 7, child: pw.Center(child: pw.Text('Rate', style: normal))),
                    pw.Expanded(flex: 11, child: pw.Center(child: pw.Text('Amount', style: normal))),
                  ]),
                ),
              ]),
            ),
          ),
          pw.Expanded(flex: 13, child: pw.Center(child: pw.Text('Total\nTax Amount', style: normal, textAlign: pw.TextAlign.center))),
        ]),
      ),
      for (final r in rows) trow(r),
      trow(['Total', _a(o.subtotal), ' ', _a(o.cgstAmount), ' ', _a(o.sgstAmount), _a(o.cgstAmount + o.sgstAmount)], b: true, top: true),
      pw.Container(height: 0, decoration: const pw.BoxDecoration(border: pw.Border(top: side))),
    ]);
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 36, marginRight: 36, marginTop: 30, marginBottom: 30),
    build: (ctx) => [
      pw.Center(child: pw.Text(gst ? 'TAX INVOICE' : 'INVOICE', style: st(14, b: true))),
      pw.SizedBox(height: 10),
      header,
      ...itemRows,
      // stretch the item columns down the page like a printed invoice
      rowOf(List.filled(colCount, null), height: (220 - o.items.length * 16.0).clamp(20, 220).toDouble()),
      totalRow,
      pw.Container(
        padding: const pw.EdgeInsets.all(3),
        decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Amount Chargeable (in words)', style: normal),
              pw.Text(amountInWords(o.totalAmount), style: normalB),
            ]),
          ),
          pw.Text('E. & O.E', style: normal),
        ]),
      ),
      if (taxSummary != null) ...[
        taxSummary,
        pw.Container(
          padding: const pw.EdgeInsets.all(3),
          decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              pw.Text('Tax Amount (in words) : ', style: normal),
              pw.Expanded(child: pw.Text(amountInWords(o.cgstAmount + o.sgstAmount), style: normalB)),
            ]),
            if ((s.companyPan ?? '').isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Row(children: [
                  pw.SizedBox(width: 100, child: pw.Text("Company's PAN", style: normal)),
                  pw.Text(': ${s.companyPan}', style: normalB),
                ]),
              ),
          ]),
        ),
      ],
      pw.Container(
        decoration: const pw.BoxDecoration(border: pw.Border(left: side, right: side, bottom: side, top: side)),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(3),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Declaration', style: normal.copyWith(decoration: pw.TextDecoration.underline)),
                pw.Text(
                    'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
                    style: normal),
              ]),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 56,
              padding: const pw.EdgeInsets.all(3),
              decoration: const pw.BoxDecoration(border: pw.Border(left: side)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('for ${s.companyName}', style: st(7.5, b: true)),
                pw.Text('Authorised Signatory', style: st(7.5, b: true)),
              ]),
            ),
          ),
        ]),
      ),
      pw.SizedBox(height: 6),
      if ((s.jurisdiction ?? '').isNotEmpty) pw.Center(child: pw.Text('SUBJECT TO ${s.jurisdiction!.toUpperCase()} JURISDICTION', style: normal)),
      pw.Center(child: pw.Text('This is a Computer Generated Invoice', style: normal)),
    ],
  ));
  return doc.save();
}
