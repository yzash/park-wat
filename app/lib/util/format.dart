import 'package:intl/intl.dart';

import '../config.dart';

final _money = NumberFormat.currency(locale: AppConfig.currencyLocale, symbol: AppConfig.currencySymbol, decimalDigits: 2);
final _num = NumberFormat.decimalPattern(AppConfig.currencyLocale);

String money(num v) => _money.format(v);
String number(num v) => _num.format(v);

/// UTC instant → plant wall-clock time (as a DateTime whose fields are local).
DateTime toPlant(DateTime utc) => utc.toUtc().add(AppConfig.plantUtcOffset);

String fmtDateTime(DateTime utc) => DateFormat('dd MMM yyyy, hh:mm a').format(toPlant(utc));
String fmtTime(DateTime utc) => DateFormat('hh:mm a').format(toPlant(utc));
String fmtDateTimeShort(DateTime utc) => DateFormat('dd MMM, hh:mm a').format(toPlant(utc));
String fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
String fmtShortDate(DateTime d) => DateFormat('dd MMM').format(d);

/// Today's date at the plant (date only, UTC-based so it compares cleanly).
DateTime plantToday() {
  final p = toPlant(DateTime.now());
  return DateTime.utc(p.year, p.month, p.day);
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
