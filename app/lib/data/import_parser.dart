import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;

/// Bulk import of parties and rate lists (FR-14).
/// Template: sheet "Parties" (Name, Contact Name, Phone, Address) and sheet
/// "Rates" (Party Name, Product Name, Rate, Effective From [YYYY-MM-DD]).
class ImportData {
  ImportData(this.parties, this.rates, this.warnings);
  final List<Map<String, dynamic>> parties;
  final List<Map<String, dynamic>> rates;
  final List<String> warnings;
}

const partiesSheet = 'Parties';
const ratesSheet = 'Rates';
const _partyCols = ['Name', 'Contact Name', 'Phone', 'Address', 'GSTIN'];
const _rateCols = ['Party Name', 'Product Name', 'Rate', 'Effective From'];

String _pad(int n) => n.toString().padLeft(2, '0');

String cellText(xl.Data? d) {
  final v = d?.value;
  return switch (v) {
    null => '',
    xl.TextCellValue() => (v.value.text ?? v.value.children?.map((c) => c.text ?? '').join() ?? '').trim(),
    xl.IntCellValue() => '${v.value}',
    xl.DoubleCellValue() => v.value == v.value.roundToDouble() ? v.value.toInt().toString() : '${v.value}',
    xl.DateCellValue() => '${v.year}-${_pad(v.month)}-${_pad(v.day)}',
    xl.DateTimeCellValue() => '${v.year}-${_pad(v.month)}-${_pad(v.day)}',
    _ => v.toString().trim(),
  };
}

/// Accepts YYYY-MM-DD, DD-MM-YYYY, DD/MM/YYYY; returns YYYY-MM-DD or null.
String? normaliseDate(String s) {
  s = s.trim();
  if (s.isEmpty) return null;
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
  if (iso != null) return '${iso[1]}-${_pad(int.parse(iso[2]!))}-${_pad(int.parse(iso[3]!))}';
  final dmy = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})$').firstMatch(s);
  if (dmy != null) return '${dmy[3]}-${_pad(int.parse(dmy[2]!))}-${_pad(int.parse(dmy[1]!))}';
  return s; // let the server report it
}

ImportData parseImport(Uint8List bytes) {
  final book = xl.Excel.decodeBytes(bytes);
  final warnings = <String>[];
  xl.Sheet? find(String name) =>
      book.tables.entries.where((e) => e.key.trim().toLowerCase() == name.toLowerCase()).firstOrNull?.value;

  List<List<String>> rows(xl.Sheet? s) {
    if (s == null) return [];
    final r = s.rows.map((row) => row.map(cellText).toList()).toList();
    if (r.isEmpty) return [];
    return r.skip(1).where((row) => row.any((c) => c.isNotEmpty)).toList(); // skip header + blank rows
  }

  String at(List<String> r, int i) => i < r.length ? r[i] : '';

  final p = find(partiesSheet);
  final rs = find(ratesSheet);
  if (p == null && rs == null) {
    warnings.add('No "$partiesSheet" or "$ratesSheet" sheet found. Download the template to see the expected layout.');
  }
  final parties = [
    for (final r in rows(p)) {'name': at(r, 0), 'contact_name': at(r, 1), 'phone': at(r, 2), 'address': at(r, 3), 'gstin': at(r, 4)},
  ];
  final rates = [
    for (final r in rows(rs))
      {'party_name': at(r, 0), 'product_name': at(r, 1), 'rate': at(r, 2).replaceAll(',', ''), 'effective_from': normaliseDate(at(r, 3))},
  ];
  return ImportData(parties, rates, warnings);
}

Uint8List buildTemplate({List<String> productNames = const []}) {
  final book = xl.Excel.createExcel();
  final def = book.getDefaultSheet()!;
  book.rename(def, partiesSheet);
  final ps = book[partiesSheet];
  ps.appendRow(_partyCols.map((c) => xl.TextCellValue(c)).toList());
  ps.appendRow([
    xl.TextCellValue('Example Traders'),
    xl.TextCellValue('Ramesh Shah'),
    xl.TextCellValue('9876543210'),
    xl.TextCellValue('Ahmedabad'),
    xl.TextCellValue(''),
  ]);
  final rs = book[ratesSheet];
  rs.appendRow(_rateCols.map((c) => xl.TextCellValue(c)).toList());
  final today = DateTime.now();
  final date = '${today.year}-${_pad(today.month)}-${_pad(today.day)}';
  for (final name in productNames.isEmpty ? ['20 L Jar'] : productNames) {
    rs.appendRow([xl.TextCellValue('Example Traders'), xl.TextCellValue(name), xl.DoubleCellValue(0), xl.TextCellValue(date)]);
  }
  for (final s in [ps, rs]) {
    for (var i = 0; i < 5; i++) {
      s.setColumnWidth(i, 24);
    }
  }
  return Uint8List.fromList(book.encode()!);
}
