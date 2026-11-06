import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../util/l10n.dart';

/// Whole-number stepper with big − / + buttons and a keypad-editable field.
class QtyStepper extends StatefulWidget {
  const QtyStepper({super.key, required this.value, required this.onChanged, this.unit});
  final int value;
  final ValueChanged<int> onChanged;
  final String? unit;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final TextEditingController _c = TextEditingController(text: _text(widget.value));
  final _focus = FocusNode();

  String _text(int v) => v == 0 ? '' : '$v';

  @override
  void didUpdateWidget(covariant QtyStepper old) {
    super.didUpdateWidget(old);
    final cur = int.tryParse(_c.text) ?? 0;
    if (cur != widget.value) _c.text = _text(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int v) {
    if (v < 0) v = 0;
    _c.text = _text(v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final v = int.tryParse(_c.text) ?? 0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton.filledTonal(
        iconSize: 26,
        tooltip: context.t.decrease,
        onPressed: v > 0 ? () => _set(v - 1) : null,
        icon: const Icon(Icons.remove),
      ),
      SizedBox(
        width: 72,
        child: TextField(
          controller: _c,
          focusNode: _focus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(isDense: true, hintText: '0', border: OutlineInputBorder()),
          onChanged: (s) => widget.onChanged(int.tryParse(s) ?? 0),
        ),
      ),
      IconButton.filledTonal(iconSize: 26, tooltip: context.t.increase, onPressed: () => _set(v + 1), icon: const Icon(Icons.add)),
      if (widget.unit != null) ...[
        const SizedBox(width: 6),
        Text(widget.unit!, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ]);
  }
}
