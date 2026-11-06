import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'master_list.dart';

class VehiclesPage extends StatelessWidget {
  const VehiclesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return MasterList<Vehicle>(
      title: t.vehicles,
      addLabel: t.addVehicle,
      load: context.read<Api>().vehicles,
      isActive: (v) => v.isActive,
      searchText: (v) => v.display,
      onAdd: (c) => _edit(c, null),
      tile: (c, v, reload) => ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Row(children: [Text(v.vehicleNumber), if (!v.isActive) ...[const SizedBox(width: 8), const InactiveTag()]]),
        subtitle: v.label == null ? null : Text(v.label!),
        onTap: () async {
          if (await _edit(c, v) == true) reload();
        },
      ),
    );
  }

  Future<bool?> _edit(BuildContext context, Vehicle? v) {
    final t = context.t;
    final number = TextEditingController(text: v?.vehicleNumber);
    final label = TextEditingController(text: v?.label);
    var active = v?.isActive ?? true;
    final form = GlobalKey<FormState>();
    var busy = false;
    return showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: Text(v == null ? t.addVehicle : t.editVehicle),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: t.vehicleNumber, hintText: 'GJ01AB1234'),
                  validator: (x) => requiredText(c, x),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: label, decoration: InputDecoration(labelText: t.labelOptional, hintText: t.vehicleLabelHint)),
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
                        await c.read<Api>().saveVehicle(id: v?.id, number: number.text, label: label.text, isActive: active);
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
