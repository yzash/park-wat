import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/api.dart';
import '../state/masters.dart';
import '../state/session.dart';
import '../state/sync.dart';
import '../util/format.dart';
import '../util/l10n.dart';
import 'widgets/common.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final t = context.t;
    final cur = TextEditingController();
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.changePassword),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: cur, obscureText: true, decoration: InputDecoration(labelText: t.currentPassword), validator: (v) => requiredText(c, v)),
            const SizedBox(height: 12),
            TextFormField(
              controller: p1,
              obscureText: true,
              decoration: InputDecoration(labelText: t.newPassword),
              validator: (v) => (v ?? '').length < 8 ? t.passwordTooShort : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: p2,
              obscureText: true,
              decoration: InputDecoration(labelText: t.confirmPassword),
              validator: (v) => v != p1.text ? t.passwordsDontMatch : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, true) : null, child: Text(t.save)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<Api>().changePassword(cur.text, p1.text);
      if (context.mounted) showInfo(context, t.passwordChanged);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final t = context.t;
    final pending = context.read<SyncState>().pendingCount;
    final ok = await confirm(
      context,
      title: t.logOut,
      message: pending > 0 ? t.logoutPendingWarning(pending) : t.logoutConfirm,
      confirmLabel: t.logOut,
      destructive: pending > 0,
    );
    if (ok && context.mounted) {
      context.read<SyncState>().stop();
      await context.read<SessionState>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final user = context.watch<SessionState>().user!;
    final sync = context.watch<SyncState>();
    final masters = context.watch<MastersState>();
    return Scaffold(
      appBar: AppBar(title: Text(t.account)),
      body: PageWidth(
        child: ListView(children: [
          ListTile(
            leading: CircleAvatar(child: Text(user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase())),
            title: Text(user.fullName),
            subtitle: Text('${user.userId} · ${user.isAdmin ? t.roleAdmin : t.roleOrderTaker}'),
          ),
          const Divider(),
          ListTile(
            leading: Icon(sync.pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined),
            title: Text(sync.pendingCount > 0 ? t.pendingOrders(sync.pendingCount) : t.allSynced),
            subtitle: Text(sync.online ? t.online : t.offline),
            trailing: sync.syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(icon: const Icon(Icons.sync), onPressed: sync.syncNow),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: Text(t.masterData),
            subtitle: Text(masters.error ??
                (masters.fetchedAt == null ? t.neverUpdated : t.updatedAt(fmtDateTime(masters.fetchedAt!)))),
            trailing: masters.loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : IconButton(icon: const Icon(Icons.refresh), onPressed: masters.refresh),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.password), title: Text(t.changePassword), onTap: () => _changePassword(context)),
          ListTile(leading: const Icon(Icons.logout), title: Text(t.logOut), onTap: () => _logout(context)),
        ]),
      ),
    );
  }
}
