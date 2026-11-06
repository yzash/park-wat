import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/import_parser.dart';
import '../../state/masters.dart';
import '../../util/l10n.dart';
import '../../util/save_file.dart';
import '../widgets/common.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});
  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String? _fileName;
  ImportData? _data;
  Map<String, dynamic>? _result;
  bool _busy = false;

  Future<void> _template() async {
    try {
      final names = context.read<MastersState>().activeProducts.map((p) => p.name).toList();
      await saveBytes('PWP-import-template.xlsx', buildTemplate(productNames: names),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pick() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx']);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final d = parseImport(bytes);
      setState(() {
        _fileName = f.name;
        _data = d;
        _result = null;
      });
    } catch (e) {
      if (mounted) showError(context, ApiException(context.t.importReadError));
    }
  }

  Future<void> _import() async {
    final d = _data!;
    setState(() => _busy = true);
    try {
      final r = await context.read<Api>().importMasters(d.parties, d.rates);
      if (!mounted) return;
      setState(() => _result = r);
      context.read<MastersState>().refresh();
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
    final d = _data;
    final r = _result;
    final errors = (r?['errors'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(t.importExcel)),
      body: PageWidth(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(t.importIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            OutlinedButton.icon(onPressed: _template, icon: const Icon(Icons.download), label: Text(t.downloadTemplate)),
            FilledButton.tonalIcon(onPressed: _busy ? null : _pick, icon: const Icon(Icons.upload_file), label: Text(t.chooseFile)),
          ]),
          if (d != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_fileName ?? '', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(t.importPreview(d.parties.length, d.rates.length)),
                  for (final w in d.warnings) Text(w, style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || (d.parties.isEmpty && d.rates.isEmpty) ? null : _import,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: Text(t.importNow),
                  ),
                ]),
              ),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 16),
            Card(
              color: errors.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.importDone(r['parties_created'] as int, r['parties_updated'] as int, r['rates_saved'] as int),
                      style: theme.textTheme.titleMedium),
                  if (errors.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(t.importErrors(errors.length), style: TextStyle(color: theme.colorScheme.error)),
                    for (final e in errors.cast<Map>())
                      Text('${e['sheet']} row ${e['row']}: ${e['error']}', style: theme.textTheme.bodySmall),
                  ],
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
