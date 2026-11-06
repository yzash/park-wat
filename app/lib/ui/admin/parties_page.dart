import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/masters.dart';
import '../../util/format.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'master_list.dart';
import 'products_page.dart' show moneyInput;

class PartiesPage extends StatelessWidget {
  const PartiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return MasterList<Party>(
      title: t.parties,
      addLabel: t.addParty,
      load: context.read<Api>().parties,
      isActive: (p) => p.isActive,
      searchText: (p) => '${p.name} ${p.contactName ?? ''} ${p.phone ?? ''} ${p.address ?? ''} ${p.gstin ?? ''}',
      onAdd: (c) => Navigator.push<bool>(c, MaterialPageRoute(builder: (_) => const PartyDetailPage())),
      tile: (c, p, reload) => ListTile(
        leading: const Icon(Icons.storefront_outlined),
        title: Row(children: [Flexible(child: Text(p.name)), if (!p.isActive) ...[const SizedBox(width: 8), const InactiveTag()]]),
        subtitle: Text([p.contactName, p.phone, p.gstin, p.address].whereType<String>().join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.push(c, MaterialPageRoute(builder: (_) => PartyDetailPage(party: p)));
          reload();
        },
      ),
    );
  }
}

/// Party details + Rate List tab.
class PartyDetailPage extends StatefulWidget {
  const PartyDetailPage({super.key, this.party});
  final Party? party;
  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  Party? _party;
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.party?.name);
  late final _contact = TextEditingController(text: widget.party?.contactName);
  late final _phone = TextEditingController(text: widget.party?.phone);
  late final _address = TextEditingController(text: widget.party?.address);
  late final _gstin = TextEditingController(text: widget.party?.gstin);
  late bool _active = widget.party?.isActive ?? true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _party = widget.party;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final p = await context.read<Api>().saveParty(
          id: _party?.id, name: _name.text, contactName: _contact.text, phone: _phone.text, address: _address.text, gstin: _gstin.text, isActive: _active);
      if (!mounted) return;
      final wasNew = _party == null;
      setState(() => _party = p);
      context.read<MastersState>().refresh();
      showInfo(context, wasNew ? context.t.partyCreatedNowRates : context.t.saved);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final details = PageWidth(
      child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(controller: _name, decoration: InputDecoration(labelText: t.partyName), validator: (v) => requiredText(context, v)),
          const SizedBox(height: 12),
          TextFormField(controller: _contact, decoration: InputDecoration(labelText: t.contactName)),
          const SizedBox(height: 12),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t.phone)),
          const SizedBox(height: 12),
          TextFormField(controller: _address, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: t.address)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _gstin,
            textCapitalization: TextCapitalization.characters,
            maxLength: 15,
            decoration: InputDecoration(labelText: t.gstinOptional, helperText: t.gstinHelp),
            validator: (v) {
              final x = (v ?? '').trim().toUpperCase();
              if (x.isEmpty) return null;
              return RegExp(r'^[0-9]{2}[A-Z0-9]{13}$').hasMatch(x) ? null : t.gstinInvalid;
            },
          ),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t.active), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(t.save)),
        ]),
      ),
    );

    if (_party == null) {
      return Scaffold(appBar: AppBar(title: Text(t.addParty)), body: details);
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_party!.name),
          bottom: TabBar(tabs: [Tab(text: t.details), Tab(text: t.rateList)]),
        ),
        body: TabBarView(children: [details, _RateList(party: _party!)]),
      ),
    );
  }
}

class _RateList extends StatefulWidget {
  const _RateList({required this.party});
  final Party party;
  @override
  State<_RateList> createState() => _RateListState();
}

class _RateListState extends State<_RateList> {
  List<Product>? _products;
  List<PartyRate> _rates = [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    try {
      final r = await Future.wait([api.products(), api.partyRates(widget.party.id)]);
      if (!mounted) return;
      setState(() {
        _products = r[0] as List<Product>;
        _rates = r[1] as List<PartyRate>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// Rate in force today (latest effective_from <= today); history sorted newest first.
  PartyRate? _current(String productId) =>
      _rates.where((r) => r.productId == productId && !r.effectiveFrom.isAfter(plantToday())).firstOrNull;
  PartyRate? _upcoming(String productId) =>
      _rates.where((r) => r.productId == productId && r.effectiveFrom.isAfter(plantToday())).lastOrNull;

  Future<void> _edit(Product p) async {
    final t = context.t;
    final cur = _current(p.id);
    final rate = TextEditingController(text: cur?.rate.toStringAsFixed(2) ?? '');
    var from = plantToday();
    final form = GlobalKey<FormState>();
    final history = _rates.where((r) => r.productId == p.id).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(p.name),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextFormField(
                  controller: rate,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: moneyInput,
                  decoration: InputDecoration(labelText: t.ratePerUnit(p.unit), prefixText: '₹ '),
                  validator: (v) => double.tryParse(v ?? '') == null ? t.required : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: c, firstDate: DateTime.utc(2024), lastDate: DateTime.utc(2100), initialDate: from);
                    if (d != null) setS(() => from = DateTime.utc(d.year, d.month, d.day));
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: t.effectiveFrom, prefixIcon: const Icon(Icons.event)),
                    child: Text(fmtDate(from)),
                  ),
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(t.rateHistory, style: Theme.of(c).textTheme.titleSmall),
                  for (final h in history.take(6))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('${fmtDate(h.effectiveFrom)}  →  ${money(h.rate)}'),
                    ),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
            FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, true) : null, child: Text(t.save)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<Api>().saveRate(PartyRate(partyId: widget.party.id, productId: p.id, rate: double.parse(rate.text), effectiveFrom: from));
      await _load();
      if (mounted) context.read<MastersState>().refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    if (_error != null) return ErrorRetry(error: _error!, onRetry: _load);
    if (_products == null) return const Center(child: CircularProgressIndicator());
    final products = _products!.where((p) => p.isActive || _rates.any((r) => r.productId == p.id)).toList();
    return PageWidth(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          itemCount: products.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (c, i) {
            if (i == 0) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(t.rateListHelp, style: theme.textTheme.bodySmall));
            }
            final p = products[i - 1];
            final cur = _current(p.id);
            final next = _upcoming(p.id);
            return ListTile(
              title: Row(children: [Flexible(child: Text(p.name)), if (!p.isActive) ...[const SizedBox(width: 8), const InactiveTag()]]),
              subtitle: Text([
                cur == null ? t.usingDefaultRate(money(p.defaultRate)) : t.effectiveSince(fmtDate(cur.effectiveFrom)),
                if (next != null) t.upcomingRate(money(next.rate), fmtDate(next.effectiveFrom)),
              ].join('\n')),
              isThreeLine: next != null,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(cur == null ? '—' : money(cur.rate), style: theme.textTheme.titleMedium),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18),
              ]),
              onTap: () => _edit(p),
            );
          },
        ),
      ),
    );
  }
}
