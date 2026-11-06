import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/masters.dart';
import '../state/session.dart';
import '../state/sync.dart';
import '../util/l10n.dart';
import 'account_page.dart';
import 'admin/admin_home.dart';
import 'my_orders_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final session = context.read<SessionState>();
    context.read<SyncState>().start(session.user!.id);
    context.read<MastersState>().refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _initialised = true;
      // Admins on a wide screen (the web panel) land on the admin area.
      if (context.read<SessionState>().isAdmin && MediaQuery.of(context).size.width >= 900) _index = 1;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SyncState>().syncNow();
      context.read<SessionState>().refreshProfile();
      context.read<MastersState>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isAdmin = context.select<SessionState, bool>((s) => s.isAdmin);
    final pending = context.select<SyncState, int>((s) => s.pendingCount);

    final pages = <Widget>[
      const MyOrdersPage(),
      if (isAdmin) const AdminHome(),
      const AccountPage(),
    ];
    final dests = <(IconData, IconData, String, int)>[
      (Icons.receipt_long_outlined, Icons.receipt_long, t.myOrders, pending),
      if (isAdmin) (Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, t.admin, 0),
      (Icons.person_outline, Icons.person, t.account, 0),
    ];
    final index = _index.clamp(0, pages.length - 1);

    Widget icon(IconData i, int count) => count > 0 ? Badge.count(count: count, child: Icon(i)) : Icon(i);

    final wide = MediaQuery.of(context).size.width >= 900;
    final body = IndexedStack(index: index, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.water_drop, color: Theme.of(context).colorScheme.primary, size: 32),
            ),
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: icon(d.$1, d.$4), selectedIcon: icon(d.$2, d.$4), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in dests) NavigationDestination(icon: icon(d.$1, d.$4), selectedIcon: icon(d.$2, d.$4), label: d.$3),
        ],
      ),
    );
  }
}
