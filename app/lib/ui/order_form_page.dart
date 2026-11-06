import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../state/masters.dart';
import '../state/session.dart';
import '../state/sync.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import '../util/money_calc.dart';
import 'widgets/common.dart';
import 'widgets/pickers.dart';
import 'widgets/qty_stepper.dart';

const _none = 'none';

class _Line {
  _Line(this.productId, this.quantity, {this.overrideRate});
  final String productId;
  int quantity;

  /// Rate typed by the order taker; null = use the party's list rate.
  double? overrideRate;
}

/// New Order (and Edit Order) form, top to bottom:
/// Party · Invoice type · Products · Qty · Rate (auto, can be changed) · Vehicle · Driver · Notes · Total · Submit.
class OrderFormPage extends StatefulWidget {
  const OrderFormPage({super.key, this.existing});

  /// When set, the form edits this order (online only).
  final OrderDetail? existing;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  String? _partyId;
  String? _vehicle; // null = not chosen yet, 'none' = No vehicle, else id
  String? _driver; // null = not chosen yet, 'none' = No driver, else id
  String _category = InvoiceCategory.general;
  final List<_Line> _lines = [];
  final _notes = TextEditingController();
  bool _submitting = false;
  bool _triedSubmit = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _partyId = e.partyId;
      _vehicle = e.vehicleId ?? _none;
      _driver = e.driverId ?? _none;
      _category = e.invoiceCategory;
      _notes.text = e.notes ?? '';
      _lines.addAll(e.items.map((i) => _Line(i.productId, i.quantity, overrideRate: i.isRateOverride ? i.rate : null)));
    } else {
      // Last-used party, vehicle, driver and invoice type are pre-selected.
      final uid = context.read<SessionState>().user!.id;
      final store = context.read<LocalStore>();
      final masters = context.read<MastersState>();
      final lp = store.lastPartyId(uid);
      if (masters.party(lp)?.isActive ?? false) _partyId = lp;
      final lv = store.lastVehicle(uid);
      if (lv == _none || (masters.vehicle(lv)?.isActive ?? false)) _vehicle = lv;
      final ld = store.lastDriver(uid);
      if (ld == _none || (masters.driver(ld)?.isActive ?? false)) _driver = ld;
      _category = store.lastCategory(uid) ?? InvoiceCategory.general;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// The party's list rate (or product default) for a product.
  ({double rate, bool isDefault}) _listRate(MastersState m, String productId) {
    final e = widget.existing;
    if (e != null && e.partyId == _partyId) {
      final saved = e.items.where((i) => i.productId == productId).firstOrNull;
      if (saved != null) return (rate: saved.standardRate ?? saved.rate, isDefault: saved.isDefaultRate);
    }
    if (_partyId == null) return (rate: m.product(productId)?.defaultRate ?? 0, isDefault: true);
    return m.rateFor(_partyId!, productId);
  }

  double _lineRate(MastersState m, _Line l) => l.overrideRate ?? _listRate(m, l.productId).rate;

  double _gstRate(MastersState m) => _editing ? (widget.existing!.isGst ? widget.existing!.gstRate : 0) : m.settings.gstRate;

  ({double subtotal, double cgst, double sgst, double roundOff, double total}) _totals(MastersState m) =>
      orderTotals(_lines.fold(0.0, (s, l) => s + round2(l.quantity * _lineRate(m, l))), _category, _gstRate(m));

  int get _totalQty => _lines.fold(0, (s, l) => s + l.quantity);

  Future<void> _pickParty() async {
    final m = context.read<MastersState>();
    final t = context.t;
    final p = await showSearchPicker<Party>(
      context,
      title: t.selectParty,
      items: m.activeParties,
      label: (p) => p.name,
      subtitle: (p) => [p.address, p.phone].whereType<String>().join(' · '),
      selected: m.party(_partyId),
    );
    if (p != null) setState(() => _partyId = p.id);
  }

  Future<void> _addProducts() async {
    final m = context.read<MastersState>();
    final have = _lines.map((l) => l.productId).toSet();
    final options = m.activeProducts.where((p) => !have.contains(p.id)).toList();
    if (options.isEmpty) {
      showInfo(context, context.t.allProductsAdded);
      return;
    }
    final chosen = await showMultiPicker<Product>(
      context,
      title: context.t.addProducts,
      items: options,
      label: (p) => p.name,
      subtitle: (p) {
        final r = _partyId == null ? (rate: p.defaultRate, isDefault: true) : m.rateFor(_partyId!, p.id);
        return '${p.unit} · ${money(r.rate)}';
      },
    );
    if (chosen == null || chosen.isEmpty) return;
    setState(() => _lines.addAll(chosen.map((p) => _Line(p.id, 1))));
  }

  void _repeatLast(List<OrderLineInput> last) {
    final m = context.read<MastersState>();
    setState(() {
      _lines
        ..clear()
        ..addAll(last
            .where((i) => m.product(i.productId)?.isActive ?? false)
            .map((i) => _Line(i.productId, i.quantity, overrideRate: i.rate)));
    });
  }

  Future<void> _editRate(_Line l) async {
    final t = context.t;
    final m = context.read<MastersState>();
    final list = _listRate(m, l.productId);
    final ctrl = TextEditingController(text: _lineRate(m, l).toStringAsFixed(2));
    final form = GlobalKey<FormState>();
    final result = await showDialog<double?>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.changeRate),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m.product(l.productId)?.name ?? ''}\n${t.listRateIs(money(list.rate))}'),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
              decoration: InputDecoration(labelText: t.ratePerUnit(m.product(l.productId)?.unit ?? ''), prefixText: '₹ '),
              validator: (v) => double.tryParse(v ?? '') == null ? t.required : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, -1.0), child: Text(t.useListRate)),
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, double.parse(ctrl.text)) : null, child: Text(t.save)),
        ],
      ),
    );
    if (result == null) return;
    setState(() => l.overrideRate = (result < 0 || round2(result) == round2(list.rate)) ? null : round2(result));
  }

  String? _validate() {
    final t = context.t;
    if (_partyId == null) return t.errPartyRequired;
    if (_lines.isEmpty) return t.errProductsRequired;
    if (_lines.any((l) => l.quantity <= 0)) return t.errQuantityRequired;
    if (_vehicle == null) return t.errVehicleRequired;
    if (_driver == null) return t.errDriverRequired;
    return null;
  }

  Future<void> _submit() async {
    setState(() => _triedSubmit = true);
    final err = _validate();
    if (err != null) {
      showError(context, ApiException(err));
      return;
    }
    final t = context.t;
    final m = context.read<MastersState>();
    final vehicleId = _vehicle == _none ? null : _vehicle;
    final driverId = _driver == _none ? null : _driver;
    final items = _lines.map((l) => OrderLineInput(l.productId, l.quantity, rate: l.overrideRate)).toList();
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    setState(() => _submitting = true);
    try {
      if (_editing) {
        await context.read<Api>().updateOrder(widget.existing!.id,
            partyId: _partyId!, vehicleId: vehicleId, driverId: driverId, notes: notes, items: items);
        if (!mounted) return;
        showInfo(context, t.orderUpdated);
        Navigator.pop(context, true);
        return;
      }
      final uid = context.read<SessionState>().user!.id;
      final store = context.read<LocalStore>();
      final sync = context.read<SyncState>();
      final order = PendingOrder(
        id: const Uuid().v4(),
        partyId: _partyId!,
        vehicleId: vehicleId,
        driverId: driverId,
        invoiceCategory: _category,
        notes: notes,
        items: items,
        orderDatetime: DateTime.now().toUtc(), // captured automatically at submit
        estimatedTotal: _totals(m).total,
      );
      await store.setLastUsed(uid, partyId: _partyId!, vehicle: _vehicle!, driver: _driver!, category: _category);
      await store.setLastItems(uid, _partyId!, items);
      final res = await sync.submit(order);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: Icon(res != null ? Icons.check_circle : Icons.cloud_upload_outlined,
              color: res != null ? Colors.green : Colors.orange, size: 48),
          title: Text(res != null ? t.orderSaved : t.orderQueued),
          content: Text(
            res != null ? '${res.orderNo}\n${t.invoiceNoIs(res.invoiceNo)}' : t.orderQueuedMessage,
            textAlign: TextAlign.center,
            style: res != null ? Theme.of(c).textTheme.titleLarge : null,
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(t.ok))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final m = context.watch<MastersState>();
    final uid = context.read<SessionState>().user!.id;
    final party = m.party(_partyId);
    final lastItems = (!_editing && _partyId != null && _lines.isEmpty)
        ? context.read<LocalStore>().lastItemsFor(uid, _partyId!)
        : const <OrderLineInput>[];
    final vehicles = m.activeVehicles;
    final currentVehicle = m.vehicle(_vehicle);
    final vehicleOptions = [
      DropdownMenuItem(value: _none, child: Text(t.noVehicle)),
      for (final v in vehicles) DropdownMenuItem(value: v.id, child: Text(v.display)),
      if (currentVehicle != null && !currentVehicle.isActive)
        DropdownMenuItem(value: currentVehicle.id, child: Text(currentVehicle.display)),
    ];
    final drivers = m.activeDrivers;
    final currentDriver = m.driver(_driver);
    final driverOptions = [
      DropdownMenuItem(value: _none, child: Text(t.noDriver)),
      for (final d in drivers) DropdownMenuItem(value: d.id, child: Text(d.name)),
      if (currentDriver != null && !currentDriver.isActive)
        DropdownMenuItem(value: currentDriver.id, child: Text(currentDriver.name)),
    ];
    final totals = _totals(m);
    final isGst = _category == InvoiceCategory.gst;

    if (m.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(t.newOrder)),
        body: m.loading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(
                icon: Icons.cloud_off,
                message: t.mastersNotLoaded,
                action: OutlinedButton(onPressed: m.refresh, child: Text(t.retry)),
              ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? t.editOrderNo(widget.existing!.orderNo) : t.newOrder)),
      body: PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Party
            PickerField(
              label: t.partyName,
              hint: t.selectParty,
              icon: Icons.storefront,
              value: party?.name,
              errorText: _triedSubmit && _partyId == null ? t.required : null,
              onTap: _pickParty,
            ),
            if (lastItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.replay, size: 18),
                  label: Text(t.repeatLastOrder(lastItems.length)),
                  onPressed: () => _repeatLast(lastItems),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Invoice type
            Text(t.invoiceType, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: InvoiceCategory.general, label: Text(t.categoryGeneral), icon: const Icon(Icons.receipt_outlined)),
                ButtonSegment(
                    value: InvoiceCategory.gst,
                    label: Text(t.categoryGstWithRate(number(_gstRate(m) == 0 ? m.settings.gstRate : _gstRate(m)))),
                    icon: const Icon(Icons.request_quote_outlined)),
              ],
              selected: {_category},
              onSelectionChanged: _editing ? null : (s) => setState(() => _category = s.first),
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.invoiceTypeFixed, style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 20),

            // Products, quantity, rate
            Row(children: [
              Text(t.products, style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(onPressed: _addProducts, icon: const Icon(Icons.add), label: Text(t.addProducts)),
            ]),
            if (_triedSubmit && _lines.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t.errProductsRequired, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            for (final l in _lines) _lineCard(context, m, l),
            const SizedBox(height: 16),

            // Vehicle
            DropdownButtonFormField<String>(
              key: ValueKey('veh-${vehicles.length}'),
              initialValue: _vehicle,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.vehicle,
                prefixIcon: const Icon(Icons.local_shipping_outlined),
                errorText: _triedSubmit && _vehicle == null ? t.required : null,
              ),
              hint: Text(t.selectVehicle),
              items: vehicleOptions,
              onChanged: (v) => setState(() => _vehicle = v),
            ),
            const SizedBox(height: 16),

            // Driver
            DropdownButtonFormField<String>(
              key: ValueKey('drv-${drivers.length}'),
              initialValue: _driver,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: t.driver,
                prefixIcon: const Icon(Icons.badge_outlined),
                errorText: _triedSubmit && _driver == null ? t.required : null,
              ),
              hint: Text(t.selectDriver),
              items: driverOptions,
              onChanged: (v) => setState(() => _driver = v),
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: t.notesOptional, alignLabelWithHint: true, prefixIcon: const Icon(Icons.notes)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Material(
          elevation: 8,
          color: theme.colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    isGst
                        ? '${t.totalItems(_totalQty)} · ${money(totals.subtotal)} + ${t.gst} ${money(totals.cgst + totals.sgst)}'
                        : t.totalItems(_totalQty),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(money(totals.total), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              ),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_editing ? t.saveChanges : t.submit),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _lineCard(BuildContext context, MastersState m, _Line l) {
    final t = context.t;
    final theme = Theme.of(context);
    final p = m.product(l.productId);
    final list = _listRate(m, l.productId);
    final rate = _lineRate(m, l);
    final overridden = l.overrideRate != null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(p?.name ?? '?', style: theme.textTheme.titleMedium)),
            IconButton(
              tooltip: t.remove,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _lines.remove(l)),
            ),
          ]),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              QtyStepper(
                value: l.quantity,
                unit: p?.unit,
                onChanged: (v) => setState(() => l.quantity = v),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _editRate(l),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (overridden)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Pill(label: t.rateChanged, bg: Colors.purple.shade100, fg: Colors.purple.shade900),
                        )
                      else if (list.isDefault)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Pill(label: t.defaultRate, bg: Colors.amber.shade100, fg: Colors.brown.shade800),
                        ),
                      Text('@ ${money(rate)}', style: theme.textTheme.bodyMedium),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: theme.colorScheme.primary, semanticLabel: t.changeRate),
                    ]),
                    if (overridden)
                      Text(t.listRateIs(money(list.rate)),
                          style: theme.textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough)),
                    Text(money(round2(l.quantity * rate)), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ],
          ),
          if (_triedSubmit && l.quantity <= 0)
            Text(t.errQuantityRequired, style: TextStyle(color: theme.colorScheme.error)),
        ]),
      ),
    );
  }
}
