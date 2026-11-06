import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/masters.dart';
import '../../util/invoice_pdf.dart';
import '../../util/save_file.dart';

pw.Font? _regular;
pw.Font? _bold;

/// Builds the invoice PDF for an order and downloads it (web) or opens the
/// share sheet (Android) so it can be sent on WhatsApp, printed, etc.
Future<void> shareInvoice(BuildContext context, OrderDetail order) async {
  final api = context.read<Api>();
  final masters = context.read<MastersState>();
  _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
  AppSettings settings;
  try {
    settings = await api.settings().timeout(const Duration(seconds: 8));
  } catch (_) {
    settings = masters.settings; // offline: last downloaded company details
  }
  final bytes = await buildInvoicePdf(order, settings, regular: _regular!, bold: _bold!);
  final safe = order.invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');
  final prefix = order.isGst ? 'TaxInvoice' : 'Invoice';
  await saveBytes('$prefix-$safe.pdf', bytes, 'application/pdf');
}
