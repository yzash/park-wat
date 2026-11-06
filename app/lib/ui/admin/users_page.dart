import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../state/session.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'master_list.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<RoleInfo> _roles = const [RoleInfo(Roles.admin, 'Admin'), RoleInfo(Roles.orderTaker, 'Order Taker')];

  @override
  void initState() {
    super.initState();
    context.read<Api>().roles().then((r) {
      if (mounted && r.isNotEmpty) setState(() => _roles = r);
    }).catchError((_) {});
  }

  String _roleLabel(String code) => _roles.where((r) => r.code == code).firstOrNull?.label ?? code;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final me = context.read<SessionState>().user!.id;
    return MasterList<AppUser>(
      title: t.users,
      addLabel: t.addUser,
      load: context.read<Api>().users,
      isActive: (u) => u.isActive,
      searchText: (u) => '${u.fullName} ${u.userId}',
      onAdd: (c) => _create(c),
      tile: (c, u, reload) => ListTile(
        leading: CircleAvatar(child: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person)),
        title: Row(children: [
          Flexible(child: Text(u.fullName)),
          if (u.id == me) ...[const SizedBox(width: 8), Pill(label: t.you, bg: Colors.blue.shade50, fg: Colors.blue.shade900)],
          if (!u.isActive) ...[const SizedBox(width: 8), const InactiveTag()],
        ]),
        subtitle: Text('${u.userId} · ${_roleLabel(u.role)}'),
        trailing: const Icon(Icons.more_vert),
        onTap: () async {
          if (await _manage(c, u, me) == true) reload();
        },
      ),
    );
  }

  Widget _roleField(BuildContext c, String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: c.t.role),
        items: [for (final r in _roles) DropdownMenuItem(value: r.code, child: Text(r.label))],
        onChanged: (v) => onChanged(v!),
      );

  Future<bool?> _create(BuildContext context) {
    final t = context.t;
    final name = TextEditingController();
    final userId = TextEditingController();
    final pass = TextEditingController();
    var role = Roles.orderTaker;
    final form = GlobalKey<FormState>();
    var busy = false;
    return showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(t.addUser),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: name, decoration: InputDecoration(labelText: t.fullName), validator: (v) => requiredText(c, v)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: userId,
                  autocorrect: false,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._-]'))],
                  decoration: InputDecoration(labelText: t.userId, helperText: t.userIdHelp),
                  validator: (v) => (v ?? '').trim().length < 2 ? t.userIdHelp : null,
                ),
                const SizedBox(height: 12),
                _roleField(c, role, (v) => role = v),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pass,
                  decoration: InputDecoration(labelText: t.initialPassword),
                  validator: (v) => (v ?? '').length < 8 ? t.passwordTooShort : null,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setS(() => busy = true);
                      try {
                        await c.read<Api>().createUser(
                            userId: userId.text.trim().toLowerCase(), fullName: name.text.trim(), role: role, password: pass.text);
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        if (c.mounted) showError(c, e);
                        setS(() => busy = false);
                      }
                    },
              child: Text(t.create),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _manage(BuildContext context, AppUser u, String me) {
    final t = context.t;
    final name = TextEditingController(text: u.fullName);
    var role = u.role;
    final form = GlobalKey<FormState>();
    var busy = false;

    Future<void> run(BuildContext c, void Function(bool) setBusy, Future<void> Function() fn, String done) async {
      setBusy(true);
      try {
        await fn();
        if (c.mounted) {
          showInfo(c, done);
          Navigator.pop(c, true);
        }
      } catch (e) {
        if (c.mounted) showError(c, e);
        setBusy(false);
      }
    }

    return showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          void setBusy(bool b) => setS(() => busy = b);
          final api = c.read<Api>();
          return AlertDialog(
            title: Text('${u.fullName} (${u.userId})'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: form,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(controller: name, decoration: InputDecoration(labelText: t.fullName), validator: (v) => requiredText(c, v)),
                  const SizedBox(height: 12),
                  _roleField(c, role, (v) => role = v),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.password),
                    label: Text(t.resetPassword),
                    onPressed: busy
                        ? null
                        : () async {
                            final p = await _askPassword(c);
                            if (p != null && c.mounted) {
                              await run(c, setBusy, () => api.resetPassword(u.id, p), t.passwordResetDone);
                            }
                          },
                  ),
                  const SizedBox(height: 8),
                  if (u.id != me)
                    OutlinedButton.icon(
                      icon: Icon(u.isActive ? Icons.block : Icons.check_circle_outline),
                      style: u.isActive ? OutlinedButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error) : null,
                      label: Text(u.isActive ? t.deactivate : t.reactivate),
                      onPressed: busy
                          ? null
                          : () async {
                              if (u.isActive &&
                                  !await confirm(c, title: t.deactivate, message: t.deactivateMessage(u.fullName), destructive: true, confirmLabel: t.deactivate)) {
                                return;
                              }
                              if (c.mounted) await run(c, setBusy, () => api.setUserActive(u.id, !u.isActive), t.saved);
                            },
                    ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        if (!form.currentState!.validate()) return;
                        run(c, setBusy, () => api.updateUser(u.id, fullName: name.text.trim(), role: role), t.saved);
                      },
                child: Text(t.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _askPassword(BuildContext context) {
    final t = context.t;
    final p = TextEditingController();
    final form = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.resetPassword),
        content: Form(
          key: form,
          child: TextFormField(
            controller: p,
            autofocus: true,
            decoration: InputDecoration(labelText: t.newPassword),
            validator: (v) => (v ?? '').length < 8 ? t.passwordTooShort : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t.cancel)),
          FilledButton(onPressed: () => form.currentState!.validate() ? Navigator.pop(c, p.text) : null, child: Text(t.save)),
        ],
      ),
    );
  }
}
