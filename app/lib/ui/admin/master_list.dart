import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/masters.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';

/// Shared scaffold for admin master-data lists: search, show-inactive toggle,
/// add button, pull-to-refresh.
class MasterList<T> extends StatefulWidget {
  const MasterList({
    super.key,
    required this.title,
    required this.load,
    required this.isActive,
    required this.searchText,
    required this.tile,
    required this.onAdd,
    this.addLabel,
  });

  final String title;
  final Future<List<T>> Function() load;
  final bool Function(T) isActive;
  final String Function(T) searchText;
  final Widget Function(BuildContext, T, VoidCallback reload) tile;
  final Future<bool?> Function(BuildContext) onAdd;
  final String? addLabel;

  @override
  State<MasterList<T>> createState() => MasterListState<T>();
}

class MasterListState<T> extends State<MasterList<T>> {
  List<T>? _items;
  Object? _error;
  bool _showInactive = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _error = null);
    try {
      final l = await widget.load();
      if (mounted) setState(() => _items = l);
      if (mounted) context.read<MastersState>().refresh(); // keep the order form cache current
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final items = (_items ?? [])
        .where((i) => _showInactive || widget.isActive(i))
        .where((i) => _q.isEmpty || widget.searchText(i).toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final inactiveCount = (_items ?? []).where((i) => !widget.isActive(i)).length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await widget.onAdd(context) == true) reload();
        },
        icon: const Icon(Icons.add),
        label: Text(widget.addLabel ?? t.add),
      ),
      body: PageWidth(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search), hintText: t.searchHint),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              if (inactiveCount > 0) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(t.showInactive(inactiveCount)),
                  selected: _showInactive,
                  onSelected: (v) => setState(() => _showInactive = v),
                ),
              ],
            ]),
          ),
          Expanded(
            child: _error != null
                ? ErrorRetry(error: _error!, onRetry: reload)
                : _items == null
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: reload,
                        child: items.isEmpty
                            ? ListView(children: [EmptyState(icon: Icons.inbox_outlined, message: t.nothingHereYet)])
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 88),
                                itemCount: items.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (c, i) => widget.tile(c, items[i], reload),
                              ),
                      ),
          ),
        ]),
      ),
    );
  }
}

/// Small "Inactive" marker.
class InactiveTag extends StatelessWidget {
  const InactiveTag({super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(label: context.t.inactive, bg: Colors.grey.shade300, fg: Colors.grey.shade800);
}
