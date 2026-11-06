import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'master_list.dart';

class DriversPage extends StatelessWidget {
  const DriversPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return MasterList<Driver>(
      title: t.drivers,
      addLabel: t.addDriver,
      load: context.read<Api>().drivers,
      isActive: (d) => d.isActive,
      searchText: (d) => '${d.name} ${d.phone ?? ''}',
      onAdd: (c) => _edit(c, null),
      tile: (c, d, reload) => ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Row(children: [Flexible(child: Text(d.name)), if (!d.isActive) ...[const SizedBox(width: 8), const InactiveTag()]]),
        subtitle: d.phone == null ? null : Text(d.phone!),
        onTap: () async {
          if (await _edit(c, d) == true) reload();
        },
      ),
    );
  }

  Future<bool?> _edit(BuildContext context, Driver? d) {
    final t = context.t;
    final name = TextEditingController(text: d?.name);
    final phone = TextEditingController(text: d?.phone);
    var active = d?.isActive ?? true;
    final form = GlobalKey<FormState>();
    var busy = false;
    return showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(d == null ? t.addDriver : t.editDriver),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: t.name),
                  validator: (x) => requiredText(c, x),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t.phone)),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t.active), value: active, onChanged: (x) => setS(() => active = x)),
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
                        await c.read<Api>().saveDriver(id: d?.id, name: name.text, phone: phone.text, isActive: active);
                        if (c.mounted) Navigator.pop(c, true);
                      } catch (e) {
                        if (c.mounted) showError(c, e);
                        setS(() => busy = false);
                      }
                    },
              child: Text(t.save),
            ),
          ],
        ),
      ),
    );
  }
}
