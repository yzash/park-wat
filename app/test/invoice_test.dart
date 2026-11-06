import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parker_orders/data/models.dart';
import 'package:parker_orders/util/invoice_pdf.dart';
import 'package:parker_orders/util/money_calc.dart';
import 'package:pdf/widgets.dart' as pw;

OrderDetail sample({required String category}) {
  final gst = category == InvoiceCategory.gst;
  final t = orderTotals(16650, category, gst ? 5 : 0);
  return OrderDetail(
    id: 'x',
    orderNo: 'PWP-2026-000042',
    invoiceNo: gst ? '1263/PWP/26-27' : '17',
    invoiceCategory: category,
    orderDatetime: DateTime.utc(2026, 10, 31, 5, 15),
    partyId: 'p',
    partyName: 'RADISSON HOTEL',
    partyAddress: 'NEAR RAILWAY CROSSING,\nGANDHIDHAM',
    partyGstin: gst ? '24AADCR4532Q1Z2' : null,
    vehicleId: 'v',
    vehicleNumber: 'GJ12AB1234',
    vehicleDisplay: 'GJ12AB1234',
    driverName: 'Ramesh Bhai',
    status: OrderStatus.submitted,
    totalQuantity: 150,
    gstRate: gst ? 5 : 0,
    subtotal: t.subtotal,
    cgstAmount: t.cgst,
    sgstAmount: t.sgst,
    roundOff: t.roundOff,
    totalAmount: t.total,
    hasRateOverride: true,
    createdBy: 'u',
    createdByName: 'Ravi Kumar',
    createdAt: DateTime.utc(2026, 10, 31),
    updatedAt: DateTime.utc(2026, 10, 31),
    items: const [
      OrderItem(productId: 'a', productName: '200 ML WODKA ( 35 PCS )', unit: 'box', hsnCode: '22011010', quantity: 150, rate: 111, amount: 16650, isDefaultRate: false, isRateOverride: true),
    ],
    history: const [],
  );
}

void main() {
  test('totals match the sample tax invoice', () {
    final t = orderTotals(16650, InvoiceCategory.gst, 5);
    expect([t.cgst, t.sgst, t.roundOff, t.total], [416.25, 416.25, 0.5, 17483]);
    final g = orderTotals(16650.4, InvoiceCategory.general, 5);
    expect([g.cgst, g.total, g.roundOff], [0, 16650, -0.4]);
  });

  test('amount in words (Indian numbering)', () {
    expect(amountInWords(17483), 'INR Seventeen Thousand Four Hundred Eighty Three Only');
    expect(amountInWords(832.5), 'INR Eight Hundred Thirty Two and Fifty Paise Only');
    expect(numberToWords(12345678), 'One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight');
    expect(stateFromGstin('24AADCR4532Q1Z2'), 'Gujarat, Code : 24');
    expect(stateFromGstin(null), isNull);
  });

  test('builds GST and General invoice PDFs', () async {
    final regular = pw.Font.ttf((await File('assets/fonts/NotoSans-Regular.ttf').readAsBytes()).buffer.asByteData());
    final bold = pw.Font.ttf((await File('assets/fonts/NotoSans-Bold.ttf').readAsBytes()).buffer.asByteData());
    const settings = AppSettings(
      companyName: 'PARKAR WATER PRODUCTS',
      companyAddress: 'PLOT NO -58,1-B, INDUSTRIAL AREA,\nADIPUR-370205',
      companyGstin: '24AAQFP1422M1Z2',
      companyPan: 'AAQFP1422M',
      jurisdiction: 'Gandhidham',
      gstRate: 5,
      gstInvoiceFormat: '{n}/PWP/{fy}',
      gstNextNo: 1264,
      generalInvoiceFormat: '{n}',
      generalNextNo: 18,
    );
    for (final c in [InvoiceCategory.gst, InvoiceCategory.general]) {
      final bytes = await buildInvoicePdf(sample(category: c), settings, regular: regular, bold: bold);
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      final out = Platform.environment['INVOICE_OUT'];
      if (out != null) await File('$out/invoice_$c.pdf').writeAsBytes(bytes);
    }
  });
}
