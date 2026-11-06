import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:parker_orders/data/import_parser.dart';
import 'package:parker_orders/data/models.dart';
import 'package:parker_orders/util/format.dart';

void main() {
  test('order filters serialise to the filter_orders() contract', () {
    final f = OrderFilters(
      fromDate: DateTime.utc(2026, 11, 1),
      toDate: DateTime.utc(2026, 11, 6),
      partyId: 'p',
      vehicleId: 'none',
      status: OrderStatus.delivered,
      search: '  PWP ',
    );
    expect(f.toJson(), {
      'from_date': '2026-11-01',
      'to_date': '2026-11-06',
      'party_ids': ['p'],
      'vehicle_ids': ['none'],
      'statuses': ['Delivered'],
      'search': 'PWP',
    });
    expect(f.copyWith(partyId: null).toJson().containsKey('party_ids'), isFalse);
    expect(f.copyWith().partyId, 'p');
  });

  test('pending order survives a JSON round trip (offline queue)', () {
    final o = PendingOrder(
      id: 'abc',
      partyId: 'p1',
      vehicleId: null,
      notes: 'gate 2',
      items: const [OrderLineInput('x', 3), OrderLineInput('y', 1)],
      orderDatetime: DateTime.utc(2026, 11, 6, 9, 30),
      estimatedTotal: 270,
    );
    final back = PendingOrder.fromJson(o.toJson());
    expect(back.id, 'abc');
    expect(back.vehicleId, isNull);
    expect(back.items.map((e) => e.quantity), [3, 1]);
    expect(back.orderDatetime, o.orderDatetime);
    expect(back.withError('boom').lastError, 'boom');
  });

  test('plant time is IST', () {
    expect(fmtDateTime(DateTime.utc(2026, 11, 6, 20, 0)), '07 Nov 2026, 01:30 AM');
    expect(money(1234.5), '₹1,234.50');
  });

  test('import date normalisation', () {
    expect(normaliseDate('2026-1-5'), '2026-01-05');
    expect(normaliseDate('05/01/2026'), '2026-01-05');
    expect(normaliseDate(''), isNull);
  });

  test('template round-trips through the import parser', () {
    final bytes = buildTemplate(productNames: ['20 L Jar', '1 L Bottle']);
    final d = parseImport(bytes);
    expect(d.parties.single['name'], 'Example Traders');
    expect(d.rates.map((r) => r['product_name']), ['20 L Jar', '1 L Bottle']);
    expect(d.rates.first['rate'], '0');
    expect(d.warnings, isEmpty);
  });

  test('import parser reads numeric and date cells', () {
    final book = xl.Excel.createExcel();
    book.rename(book.getDefaultSheet()!, 'rates');
    final s = book['rates'];
    s.appendRow([xl.TextCellValue('Party Name'), xl.TextCellValue('Product Name'), xl.TextCellValue('Rate'), xl.TextCellValue('Effective From')]);
    s.appendRow([xl.TextCellValue('City Mart'), xl.TextCellValue('20 L Jar'), xl.DoubleCellValue(52.5), const xl.DateCellValue(year: 2026, month: 10, day: 1)]);
    s.appendRow([null, null, null, null]);
    final d = parseImport(Uint8List.fromList(book.encode()!));
    expect(d.rates, [
      {'party_name': 'City Mart', 'product_name': '20 L Jar', 'rate': '52.5', 'effective_from': '2026-10-01'},
    ]);
    expect(d.parties, isEmpty);
  });
}
