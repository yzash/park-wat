import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../util/format.dart';
import '../../util/l10n.dart';
import '../../util/save_file.dart';
import '../order_detail_page.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

const _pageSize = 100;

/// Admin: every order, combinable filters, summary toggle and Excel export.
class AllOrdersPage extends StatefulWidget {
  const AllOrdersPage({super.key});
  @override
  State<AllOrdersPage> createState() => _AllOrdersPageState();
}

class _AllOrdersPageState extends State<AllOrdersPage> {
  late OrderFilters _f = OrderFilters(fromDate: DateTime.utc(plantToday().year, plantToday().month, 1), toDate: plantToday());
  bool _summary = false;
  String _groupBy = 'party';

  List<OrderSummary> _rows = [];
  List<TotalRow> _totals = [];
  ({int count, int qty, double amount})? _grand;
  int _totalCount = 0;
  bool _loading = false;
  bool _exporting = false;
  Object? _error;
  final _search = TextEditingController();

  // filter options (all, including inactive, so history can be filtered)
  List<Party> _parties = [];
  List<Product> _products = [];
  List<Vehicle> _vehicles = [];
  List<AppUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final api = context.read<Api>();
    try {
      final r = await Future.wait([api.parties(), api.products(), api.vehicles(), api.users()]);
      if (!mounted) return;
      setState(() {
        _parties = r[0] as List<Party>;
        _products = r[1] as List<Product>;
        _vehicles = r[2] as List<Vehicle>;
        _users = r[3] as List<AppUser>;
      });
    } catch (_) {}
  }

  Future<void> _load({bool more = false}) async {
    final api = context.read<Api>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_summary) {
        final r = await Future.wait([api.orderTotals(_groupBy, _f), api.orderTotals('user', _f)]);
        _totals = r[0];
        _setGrand(r[1]);
      } else {
        final r = await Future.wait([
          api.searchOrders(_f, limit: _pageSize, offset: more ? _rows.length : 0),
          if (!more) api.orderTotals('user', _f),
        ]);
        final page = r[0] as List<OrderSummary>;
        _rows = more ? [..._rows, ...page] : page;
        if (page.isNotEmpty) _totalCount = page.first.totalCount;
        if (!more && page.isEmpty) _totalCount = 0;
        if (!more) _setGrand(r[1] as List<TotalRow>);
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setGrand(List<TotalRow> byUser) {
    _grand = (
      count: byUser.fold(0, (s, r) => s + r.orderCount),
      qty: byUser.fold(0, (s, r) => s + r.totalQuantity),
      amount: byUser.fold(0.0, (s, r) => s + r.totalAmount),
    );
  }

  void _apply(OrderFilters f) {
    setState(() => _f = f);
    _load();
  }

  Future<void> _export() async {
    final t = context.t;
    setState(() => _exporting = true);
    try {
      final r = await context.read<Api>().exportOrders(_f);
      await saveBytes(r.filename, r.bytes, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      if (mounted) showInfo(context, t.exported(r.filename));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDates() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(2024),
      lastDate: plantToday().add(const Duration(days: 1)),
      initialDateRange: _f.fromDate != null && _f.toDate != null ? DateTimeRange(start: _f.fromDate!, end: _f.toDate!) : null,
    );
    if (r != null) {
      _apply(_f.copyWith(
        fromDate: DateTime.utc(r.start.year, r.start.month, r.start.day),
        toDate: DateTime.utc(r.end.year, r.end.month, r.end.day),
      ));
    }
  }

  Future<T?> _pick<T>(String title, List<T> items, String Function(T) label, {String Function(T)? sub}) =>
      showSearchPicker<T>(context, title: title, items: items, label: label, subtitle: sub);

  String _inactive(String s, bool active) => active ? s : '$s (${context.t.inactive})';

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final wide = MediaQuery.of(context).size.width >= 900;

    String? nameOf<T>(List<T> l, bool Function(T) match, String Function(T) label) {
      final x = l.where(match).firstOrNull;
      return x == null ? null : label(x);
    }

    final dateLabel = _f.fromDate == null
        ? t.allDates
        : sameDay(_f.fromDate!, _f.toDate ?? _f.fromDate!)
            ? fmtDate(_f.fromDate!)
            : '${fmtDate(_f.fromDate!)} – ${fmtDate(_f.toDate!)}';

    final chips = <Widget>[
      InputChip(
        avatar: const Icon(Icons.date_range, size: 18),
        label: Text(dateLabel),
        onPressed: _pickDates,
        onDeleted: _f.fromDate == null ? null : () => _apply(_f.copyWith(fromDate: null, toDate: null)),
      ),
      _FilterChip(
        icon: Icons.storefront,
        label: t.party,
        value: nameOf<Party>(_parties, (p) => p.id == _f.partyId, (p) => p.name),
        onPick: () async {
          final p = await _pick<Party>(t.party, _parties, (p) => _inactive(p.name, p.isActive));
          if (p != null) _apply(_f.copyWith(partyId: p.id));
        },
        onClear: () => _apply(_f.copyWith(partyId: null)),
      ),
      _FilterChip(
        icon: Icons.inventory_2_outlined,
        label: t.product,
        value: nameOf<Product>(_products, (p) => p.id == _f.productId, (p) => p.name),
        onPick: () async {
          final p = await _pick<Product>(t.product, _products, (p) => _inactive(p.name, p.isActive));
          if (p != null) _apply(_f.copyWith(productId: p.id));
        },
        onClear: () => _apply(_f.copyWith(productId: null)),
      ),
      _FilterChip(
        icon: Icons.local_shipping_outlined,
        label: t.vehicle,
        value: _f.vehicleId == 'none' ? t.noVehicle : nameOf<Vehicle>(_vehicles, (v) => v.id == _f.vehicleId, (v) => v.vehicleNumber),
        onPick: () async {
          final none = Vehicle(id: 'none', vehicleNumber: t.noVehicle, isActive: true);
          final v = await _pick<Vehicle>(t.vehicle, [none, ..._vehicles], (v) => _inactive(v.display, v.isActive));
          if (v != null) _apply(_f.copyWith(vehicleId: v.id));
        },
        onClear: () => _apply(_f.copyWith(vehicleId: null)),
      ),
      _FilterChip(
        icon: Icons.person_outline,
        label: t.orderTaker,
        value: nameOf<AppUser>(_users, (u) => u.id == _f.userId, (u) => u.fullName),
        onPick: () async {
          final u = await _pick<AppUser>(t.orderTaker, _users, (u) => _inactive(u.fullName, u.isActive), sub: (u) => u.userId);
          if (u != null) _apply(_f.copyWith(userId: u.id));
        },
        onClear: () => _apply(_f.copyWith(userId: null)),
      ),
      _FilterChip(
        icon: Icons.flag_outlined,
        label: t.status,
        value: _f.status == null ? null : statusLabel(context, _f.status!),
        onPick: () async {
          final s = await _pick<String>(t.status, OrderStatus.all, (s) => statusLabel(context, s));
          if (s != null) _apply(_f.copyWith(status: s));
        },
        onClear: () => _apply(_f.copyWith(status: null)),
      ),
      SizedBox(
        width: 220,
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
            hintText: t.searchOrders,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _search.clear();
                      _apply(_f.copyWith(search: null));
                    }),
          ),
          onSubmitted: (v) => _apply(_f.copyWith(search: v)),
        ),
      ),
      TextButton(
        onPressed: () {
          _search.clear();
          _apply(const OrderFilters());
        },
        child: Text(t.clearFilters),
      ),
    ];

    final groups = <String, String>{
      'party': t.party,
      'product': t.product,
      'vehicle': t.vehicle,
      'user': t.orderTaker,
      'day': t.day,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.allOrders),
        actions: [
          IconButton(onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.refresh), tooltip: t.refresh),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _exporting ? null : _export,
              icon: _exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download),
              label: Text(t.exportExcel),
            ),
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: chips),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.list), label: Text(t.orders)),
                ButtonSegment(value: true, icon: const Icon(Icons.summarize_outlined), label: Text(t.summary)),
              ],
              selected: {_summary},
              onSelectionChanged: (s) {
                setState(() => _summary = s.first);
                _load();
              },
            ),
            if (_summary)
              DropdownButton<String>(
                value: _groupBy,
                items: [for (final e in groups.entries) DropdownMenuItem(value: e.key, child: Text(t.byGroup(e.value)))],
                onChanged: (v) {
                  setState(() => _groupBy = v!);
                  _load();
                },
              ),
            if (_grand != null)
              Text(
                '${t.ordersCount(_grand!.count)} · ${t.totalItems(_grand!.qty)} · ${money(_grand!.amount)}',
                style: theme.textTheme.titleSmall,
              ),
          ]),
        ),
        if (_loading) const LinearProgressIndicator() else const SizedBox(height: 4),
        Expanded(
          child: _error != null
              ? ErrorRetry(error: _error!, onRetry: _load)
              : _summary
                  ? _summaryView(context)
                  : (_rows.isEmpty && !_loading)
                      ? EmptyState(icon: Icons.search_off, message: t.noOrdersMatch)
                      : wide
                          ? _table(context)
                          : _list(context),
        ),
      ]),
    );
  }

  Future<void> _open(OrderSummary o) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id)));
    _load();
  }

  Widget _loadMore() {
    if (_rows.length >= _totalCount) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: OutlinedButton(
          onPressed: _loading ? null : () => _load(more: true),
          child: Text(context.t.loadMore(_rows.length, _totalCount)),
        ),
      ),
    );
  }

  Widget _table(BuildContext context) {
    final t = context.t;
    return SingleChildScrollView(
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 28,
            headingRowColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHigh),
            columns: [
              DataColumn(label: Text(t.orderNo)),
              DataColumn(label: Text(t.dateTime)),
              DataColumn(label: Text(t.party)),
              DataColumn(label: Text(t.products)),
              DataColumn(label: Text(t.quantity), numeric: true),
              DataColumn(label: Text(t.total), numeric: true),
              DataColumn(label: Text(t.vehicle)),
              DataColumn(label: Text(t.orderTaker)),
              DataColumn(label: Text(t.status)),
            ],
            rows: [
              for (final o in _rows)
                DataRow(
                  onSelectChanged: (_) => _open(o),
                  cells: [
                    DataCell(Text(o.orderNo)),
                    DataCell(Text(fmtDateTime(o.orderDatetime))),
                    DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: Text(o.partyName, overflow: TextOverflow.ellipsis))),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Tooltip(message: o.productsSummary ?? '', child: Text(o.productsSummary ?? '', overflow: TextOverflow.ellipsis)),
                    )),
                    DataCell(Text(number(o.totalQuantity))),
                    DataCell(Text(money(o.totalAmount))),
                    DataCell(Text(o.vehicleNumber ?? t.noVehicle)),
                    DataCell(Text(o.createdByName ?? '')),
                    DataCell(StatusChip(o.status)),
                  ],
                ),
            ],
          ),
        ),
        _loadMore(),
      ]),
    );
  }

  Widget _list(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    return ListView.builder(
      itemCount: _rows.length + 1,
      itemBuilder: (c, i) {
        if (i == _rows.length) return _loadMore();
        final o = _rows[i];
        return ListTile(
          onTap: () => _open(o),
          title: Row(children: [
            Expanded(child: Text(o.partyName, overflow: TextOverflow.ellipsis)),
            Text(money(o.totalAmount), style: theme.textTheme.titleMedium),
          ]),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.productsSummary ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${o.orderNo} · ${fmtDateTime(o.orderDatetime)} · ${o.vehicleNumber ?? t.noVehicle} · ${o.createdByName ?? ''}',
                style: theme.textTheme.bodySmall),
          ]),
          trailing: StatusChip(o.status),
          isThreeLine: true,
        );
      },
    );
  }

  Widget _summaryView(BuildContext context) {
    final t = context.t;
    if (_totals.isEmpty && !_loading) return EmptyState(icon: Icons.search_off, message: t.noOrdersMatch);
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHigh),
            columns: [
              DataColumn(label: Text(t.group)),
              DataColumn(label: Text(t.orders), numeric: true),
              DataColumn(label: Text(t.quantity), numeric: true),
              DataColumn(label: Text(t.total), numeric: true),
            ],
            rows: [
              for (final r in _totals)
                DataRow(cells: [
                  DataCell(Text(r.label)),
                  DataCell(Text(number(r.orderCount))),
                  DataCell(Text(number(r.totalQuantity))),
                  DataCell(Text(money(r.totalAmount))),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.icon, required this.label, required this.value, required this.onPick, required this.onClear});
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => InputChip(
        avatar: Icon(icon, size: 18),
        label: Text(value == null ? label : '$label: $value'),
        selected: value != null,
        showCheckmark: false,
        onPressed: onPick,
        onDeleted: value == null ? null : onClear,
      );
}
