import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../state/session.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import 'order_form_page.dart';
import 'widgets/common.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final String orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  OrderDetail? _order;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final o = await context.read<Api>().getOrder(widget.orderId);
      if (mounted) setState(() => _order = o);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _setStatus(String status) async {
    final t = context.t;
    if (status == OrderStatus.cancelled &&
        !await confirm(context, title: t.cancelOrder, message: t.cancelOrderMessage, confirmLabel: t.cancelOrder, destructive: true)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<Api>().setOrderStatus(widget.orderId, status);
      await _load();
      if (mounted) showInfo(context, t.statusChangedTo(statusLabel(context, status)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => OrderFormPage(existing: _order)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final session = context.watch<SessionState>();
    final o = _order;

    if (o == null) {
      return Scaffold(
        appBar: AppBar(title: Text(t.order)),
        body: _error != null ? ErrorRetry(error: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()),
      );
    }
    final isAdmin = session.isAdmin;
    final canEdit = isAdmin || (o.createdBy == session.user!.id && o.status == OrderStatus.submitted);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline))),
            Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(o.orderNo),
        actions: [
          if (canEdit) IconButton(onPressed: _busy ? null : _edit, icon: const Icon(Icons.edit), tooltip: t.edit),
          if (isAdmin)
            PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: _setStatus,
              itemBuilder: (c) => [
                if (o.status != OrderStatus.delivered) PopupMenuItem(value: OrderStatus.delivered, child: Text(t.markDelivered)),
                if (o.status != OrderStatus.submitted) PopupMenuItem(value: OrderStatus.submitted, child: Text(t.markSubmitted)),
                if (o.status != OrderStatus.cancelled) PopupMenuItem(value: OrderStatus.cancelled, child: Text(t.cancelOrder)),
              ],
            ),
        ],
      ),
      body: PageWidth(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (_busy) const LinearProgressIndicator(),
            Row(children: [
              Expanded(child: Text(o.partyName, style: theme.textTheme.headlineSmall)),
              StatusChip(o.status),
            ]),
            const SizedBox(height: 12),
            row(t.dateTime, fmtDateTime(o.orderDatetime)),
            row(t.vehicle, o.vehicleDisplay ?? t.noVehicle),
            row(t.orderTaker, o.createdByName ?? '—'),
            if (o.notes != null) row(t.notes, o.notes!),
            const Divider(height: 32),
            for (final i in o.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i.productName, style: theme.textTheme.titleMedium),
                      Row(children: [
                        Text('${i.quantity} ${i.unit} × ${money(i.rate)}', style: theme.textTheme.bodyMedium),
                        if (i.isDefaultRate) ...[
                          const SizedBox(width: 6),
                          Pill(label: t.defaultRate, bg: Colors.amber.shade100, fg: Colors.brown.shade800),
                        ],
                      ]),
                    ]),
                  ),
                  Text(money(i.amount), style: theme.textTheme.titleMedium),
                ]),
              ),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(t.totalItems(o.totalQuantity), style: theme.textTheme.titleMedium)),
              Text(money(o.totalAmount), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 24),
            Text(t.history, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            for (final h in o.history)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history, size: 20),
                title: Text(h.fromStatus == null ? t.historyCreated : t.historyStatus(statusLabel(context, h.fromStatus!), statusLabel(context, h.toStatus))),
                subtitle: Text('${fmtDateTime(h.changedAt)} · ${h.changedByName ?? '—'}'),
              ),
            if (o.updatedAt.difference(o.createdAt).inSeconds > 1)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note, size: 20),
                title: Text(t.lastUpdated),
                subtitle: Text('${fmtDateTime(o.updatedAt)} · ${o.updatedByName ?? '—'}'),
              ),
          ]),
        ),
      ),
    );
  }
}
