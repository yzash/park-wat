import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api.dart';
import '../data/local_store.dart';
import '../data/models.dart';
import '../state/masters.dart';
import '../state/session.dart';
import '../state/sync.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import 'order_detail_page.dart';
import 'order_form_page.dart';
import 'widgets/common.dart';

/// Order taker's home: today's orders by default, queued orders on top.
class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});
  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late DateTimeRange _range = DateTimeRange(start: plantToday(), end: plantToday());
  List<OrderSummary> _orders = [];
  bool _loading = true;
  bool _fromCache = false;
  Object? _error;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    final uid = context.read<SessionState>().user!.id;
    _orders = context.read<LocalStore>().cachedMyOrders(uid).where((o) => _inRange(o.orderDatetime)).toList();
    _syncSub = context.read<SyncState>().synced.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  bool get _isToday => sameDay(_range.start, plantToday()) && sameDay(_range.end, plantToday());

  bool _inRange(DateTime utc) {
    final p = toPlant(utc);
    final d = DateTime.utc(p.year, p.month, p.day);
    return !d.isBefore(_range.start) && !d.isAfter(_range.end);
  }

  Future<void> _load() async {
    final api = context.read<Api>();
    final store = context.read<LocalStore>();
    final uid = context.read<SessionState>().user!.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final l = await api
          .searchOrders(OrderFilters(fromDate: _range.start, toDate: _range.end, userId: uid), limit: 500)
          .timeout(const Duration(seconds: 20));
      if (_isToday) await store.setCachedMyOrders(uid, l);
      if (!mounted) return;
      setState(() {
        _orders = l;
        _fromCache = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _fromCache = _orders.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime.utc(2024),
      lastDate: plantToday(),
      initialDateRange: _range,
    );
    if (r == null) return;
    setState(() => _range = DateTimeRange(start: DateTime.utc(r.start.year, r.start.month, r.start.day), end: DateTime.utc(r.end.year, r.end.month, r.end.day)));
    _load();
  }

  Future<void> _newOrder() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderFormPage()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sync = context.watch<SyncState>();
    final masters = context.watch<MastersState>();
    final pending = sync.pending.reversed.toList();
    final total = _orders.where((o) => o.status != OrderStatus.cancelled).fold<double>(0, (s, o) => s + o.totalAmount);
    final rangeLabel = _isToday
        ? t.today
        : sameDay(_range.start, _range.end)
            ? fmtDate(_range.start)
            : '${fmtShortDate(_range.start)} – ${fmtShortDate(_range.end)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.myOrders),
        actions: [
          if (!sync.online) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.error)),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: t.refresh),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: masters.isEmpty && masters.loading ? null : _newOrder,
        icon: const Icon(Icons.add),
        label: Text(t.newOrder),
      ),
      body: PageWidth(
        child: RefreshIndicator(
          onRefresh: () async {
            await sync.syncNow();
            await _load();
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(children: [
                  ActionChip(avatar: const Icon(Icons.calendar_today, size: 18), label: Text(rangeLabel), onPressed: _pickRange),
                  if (!_isToday) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      label: Text(t.today),
                      onPressed: () {
                        setState(() => _range = DateTimeRange(start: plantToday(), end: plantToday()));
                        _load();
                      },
                    ),
                  ],
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(t.ordersCount(_orders.length), style: Theme.of(context).textTheme.bodySmall),
                    Text(money(total), style: Theme.of(context).textTheme.titleMedium),
                  ]),
                ]),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_fromCache)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(t.showingCached, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              for (final p in pending) _PendingTile(order: p),
              for (final o in _orders)
                _OrderTile(
                  order: o,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailPage(orderId: o.id)));
                    _load();
                  },
                ),
              if (!_loading && _orders.isEmpty && pending.isEmpty)
                _error != null
                    ? ErrorRetry(error: _error!, onRetry: _load)
                    : EmptyState(icon: Icons.inbox_outlined, message: _isToday ? t.noOrdersToday : t.noOrdersInRange),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.onTap});
  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(order.partyName, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              Text(money(order.totalAmount), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            if (order.productsSummary != null)
              Text(order.productsSummary!, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${order.orderNo} · ${fmtTime(order.orderDatetime)}', style: theme.textTheme.bodySmall),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_shipping_outlined, size: 14),
                const SizedBox(width: 2),
                Text(order.vehicleNumber ?? t.noVehicle, style: theme.textTheme.bodySmall),
              ]),
              StatusChip(order.status),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.order});
  final PendingOrder order;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final masters = context.watch<MastersState>();
    final sync = context.read<SyncState>();
    final failed = order.lastError != null;
    final summary = order.items.map((i) => '${masters.product(i.productId)?.name ?? '?'} × ${i.quantity}').join(', ');
    return Card(
      color: failed ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(masters.party(order.partyId)?.name ?? '?', style: theme.textTheme.titleMedium)),
            Text(money(order.estimatedTotal), style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 4),
          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            PendingBadge(failed: failed),
            const SizedBox(width: 8),
            Text(fmtTime(order.orderDatetime), style: theme.textTheme.bodySmall),
            const Spacer(),
            if (failed) ...[
              TextButton(onPressed: () => sync.retry(order.id), child: Text(t.retry)),
              TextButton(
                onPressed: () async {
                  if (await confirm(context, title: t.discardOrder, message: t.discardOrderMessage, destructive: true, confirmLabel: t.discard)) {
                    sync.discard(order.id);
                  }
                },
                child: Text(t.discard),
              ),
            ],
          ]),
          if (failed) Text(order.lastError!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
        ]),
      ),
    );
  }
}
