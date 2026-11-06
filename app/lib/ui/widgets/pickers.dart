import 'package:flutter/material.dart';

import '../../util/l10n.dart';

/// Bottom sheet with a search box and a list; returns the tapped item.
Future<T?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? subtitle,
  T? selected,
  List<T> pinned = const [],
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => _PickerSheet<T>(
      title: title,
      items: items,
      label: label,
      subtitle: subtitle,
      selected: selected == null ? const {} : {selected},
      pinned: pinned,
      multi: false,
    ),
  );
}

/// Same, with checkboxes; returns the chosen items (null if dismissed).
Future<List<T>?> showMultiPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> items,
  required String Function(T) label,
  String Function(T)? subtitle,
}) {
  return showModalBottomSheet<List<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => _PickerSheet<T>(title: title, items: items, label: label, subtitle: subtitle, selected: const {}, multi: true),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.items,
    required this.label,
    this.subtitle,
    required this.selected,
    required this.multi,
    this.pinned = const [],
  });
  final String title;
  final List<T> items;
  final String Function(T) label;
  final String Function(T)? subtitle;
  final Set<T> selected;
  final bool multi;
  final List<T> pinned;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _q = '';
  late final Set<T> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final q = _q.toLowerCase();
    final filtered = widget.items
        .where((i) => q.isEmpty || widget.label(i).toLowerCase().contains(q) || (widget.subtitle?.call(i).toLowerCase().contains(q) ?? false))
        .toList();
    final list = q.isEmpty ? [...widget.pinned, ...filtered.where((i) => !widget.pinned.contains(i))] : filtered;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(children: [
              Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)),
              if (widget.multi)
                FilledButton(
                  onPressed: () => Navigator.pop(context, widget.items.where(_chosen.contains).toList()),
                  child: Text(_chosen.isEmpty ? t.done : t.addCount(_chosen.length)),
                )
              else
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: widget.items.length > 12,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t.searchHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(t.noMatches))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final item = list[i];
                      final sub = widget.subtitle?.call(item);
                      final subtitle = sub == null || sub.isEmpty ? null : Text(sub);
                      if (widget.multi) {
                        return CheckboxListTile(
                          value: _chosen.contains(item),
                          title: Text(widget.label(item)),
                          subtitle: subtitle,
                          onChanged: (v) => setState(() => v == true ? _chosen.add(item) : _chosen.remove(item)),
                        );
                      }
                      final sel = widget.selected.contains(item);
                      return ListTile(
                        minVerticalPadding: 14,
                        title: Text(widget.label(item), style: sel ? const TextStyle(fontWeight: FontWeight.bold) : null),
                        subtitle: subtitle,
                        trailing: sel ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

/// A form field that looks like a dropdown and opens a picker on tap.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.errorText,
    this.icon,
    this.onClear,
  });
  final String label;
  final String? value;
  final String? hint;
  final String? errorText;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: errorText,
          prefixIcon: icon == null ? null : Icon(icon),
          border: const OutlineInputBorder(),
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear)
              : const Icon(Icons.arrow_drop_down),
        ),
        child: value == null ? null : Text(value!, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
