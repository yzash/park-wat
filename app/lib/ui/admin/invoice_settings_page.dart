import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/masters.dart';
import '../../util/format.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';

/// Company details printed on invoices, GST rate and invoice number series.
class InvoiceSettingsPage extends StatefulWidget {
  const InvoiceSettingsPage({super.key});
  @override
  State<InvoiceSettingsPage> createState() => _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState extends State<InvoiceSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  Object? _error;
  bool _loaded = false;
  bool _busy = false;

  TextEditingController c(String k) => _c.putIfAbsent(k, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final x in _c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<Api>().settings();
      c('company_name').text = s.companyName;
      c('company_address').text = s.companyAddress ?? '';
      c('company_gstin').text = s.companyGstin ?? '';
      c('company_pan').text = s.companyPan ?? '';
      c('company_phone').text = s.companyPhone ?? '';
      c('jurisdiction').text = s.jurisdiction ?? '';
      c('gst_rate').text = number(s.gstRate);
      c('gst_format').text = s.gstInvoiceFormat;
      c('gst_next').text = '${s.gstNextNo}';
      c('gen_format').text = s.generalInvoiceFormat;
      c('gen_next').text = '${s.generalNextNo}';
      setState(() => _loaded = true);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  String? _opt(String k) => c(k).text.trim().isEmpty ? null : c(k).text.trim();

  /// Preview of the next number, using today's financial year.
  String _preview(String format, String next) {
    final d = plantToday();
    final fy = d.month >= 4
        ? '${(d.year % 100).toString().padLeft(2, '0')}-${((d.year + 1) % 100).toString().padLeft(2, '0')}'
        : '${((d.year - 1) % 100).toString().padLeft(2, '0')}-${(d.year % 100).toString().padLeft(2, '0')}';
    return format.replaceAll('{n}', next).replaceAll('{fy}', fy).replaceAll('{yyyy}', '${d.year}');
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<Api>().saveSettings(AppSettings(
            companyName: c('company_name').text.trim(),
            companyAddress: _opt('company_address'),
            companyGstin: _opt('company_gstin')?.toUpperCase(),
            companyPan: _opt('company_pan')?.toUpperCase(),
            companyPhone: _opt('company_phone'),
            jurisdiction: _opt('jurisdiction'),
            gstRate: double.parse(c('gst_rate').text),
            gstInvoiceFormat: c('gst_format').text.trim(),
            gstNextNo: int.parse(c('gst_next').text),
            generalInvoiceFormat: c('gen_format').text.trim(),
            generalNextNo: int.parse(c('gen_next').text),
          ));
      if (!mounted) return;
      context.read<MastersState>().refresh();
      showInfo(context, context.t.saved);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    if (_error != null) return Scaffold(appBar: AppBar(title: Text(t.invoiceSettings)), body: ErrorRetry(error: _error!, onRetry: _load));
    if (!_loaded) return Scaffold(appBar: AppBar(title: Text(t.invoiceSettings)), body: const Center(child: CircularProgressIndicator()));

    String? fmtCheck(String? v) => (v ?? '').contains('{n}') ? null : t.formatNeedsN;
    String? posInt(String? v) => (int.tryParse(v ?? '') ?? 0) >= 1 ? null : t.required;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(title: Text(t.invoiceSettings)),
      body: PageWidth(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(t.companyDetails, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(controller: c('company_name'), decoration: InputDecoration(labelText: t.companyNameLabel), validator: (v) => requiredText(context, v)),
            const SizedBox(height: 12),
            TextFormField(controller: c('company_address'), minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: t.address)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: c('company_gstin'), textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: t.gstin))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: c('company_pan'), textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: t.pan))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: c('company_phone'), decoration: InputDecoration(labelText: t.phone))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: c('jurisdiction'), decoration: InputDecoration(labelText: t.jurisdiction))),
            ]),
            const SizedBox(height: 24),
            Text(t.gstInvoices, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: c('gst_rate'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: t.gstRatePercent, helperText: t.gstRateHelp, suffixText: '%'),
              validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? t.required : null,
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: c('gst_format'),
                  decoration: InputDecoration(labelText: t.seriesFormat, helperText: t.seriesFormatHelp),
                  validator: fmtCheck,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: c('gst_next'),
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: InputDecoration(labelText: t.nextNumber),
                  validator: posInt,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.nextInvoiceWillBe(_preview(c('gst_format').text, c('gst_next').text)), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 24),
            Text(t.generalInvoices, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: c('gen_format'),
                  decoration: InputDecoration(labelText: t.seriesFormat),
                  validator: fmtCheck,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: c('gen_next'),
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: InputDecoration(labelText: t.nextNumber),
                  validator: posInt,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t.nextInvoiceWillBe(_preview(c('gen_format').text, c('gen_next').text)), style: theme.textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Text(t.seriesNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 24),
            FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
          ]),
        ),
      ),
    );
  }
}
