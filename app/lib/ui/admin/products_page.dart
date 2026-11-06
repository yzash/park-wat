import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../util/format.dart';
import '../../util/l10n.dart';
import '../widgets/common.dart';
import 'master_list.dart';

final moneyInput = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))];

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return MasterList<Product>(
      title: t.products,
      addLabel: t.addProduct,
      load: context.read<Api>().products,
      isActive: (p) => p.isActive,
      searchText: (p) => '${p.name} ${p.unit}',
      onAdd: (c) => editProduct(c, null),
      tile: (c, p, reload) => ListTile(
        title: Row(children: [Flexible(child: Text(p.name)), if (!p.isActive) ...[const SizedBox(width: 8), const InactiveTag()]]),
        subtitle: Text('${t.unit}: ${p.unit}${p.hsnCode == null ? '' : ' · HSN ${p.hsnCode}'}'),
        trailing: Text(money(p.defaultRate), style: Theme.of(c).textTheme.titleMedium),
        onTap: () async {
          if (await editProduct(c, p) == true) reload();
        },
      ),
    );
  }
}

Future<bool?> editProduct(BuildContext context, Product? p) {
  final t = context.t;
  final name = TextEditingController(text: p?.name);
  final unit = TextEditingController(text: p?.unit);
  final rate = TextEditingController(text: p == null ? '' : p.defaultRate.toStringAsFixed(2));
  final hsn = TextEditingController(text: p?.hsnCode);
  var active = p?.isActive ?? true;
  final form = GlobalKey<FormState>();
  var busy = false;
  return showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => AlertDialog(
        title: Text(p == null ? t.addProduct : t.editProduct),
        content: SizedBox(
          width: 400,
          child: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: name, decoration: InputDecoration(labelText: t.name), validator: (v) => requiredText(c, v)),
              const SizedBox(height: 12),
              TextFormField(
                controller: unit,
                decoration: InputDecoration(labelText: t.unit, hintText: t.unitHint),
                validator: (v) => requiredText(c, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: moneyInput,
                decoration: InputDecoration(labelText: t.defaultRate, helperText: t.defaultRateHelp, prefixText: '₹ '),
                validator: (v) => double.tryParse(v ?? '') == null ? t.required : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: hsn,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.hsnCode, helperText: t.hsnHelp),
              ),
              SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t.active), value: active, onChanged: (v) => setS(() => active = v)),
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
                      await c.read<Api>().saveProduct(
                          id: p?.id, name: name.text, unit: unit.text, defaultRate: double.parse(rate.text), hsnCode: hsn.text, isActive: active);
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
