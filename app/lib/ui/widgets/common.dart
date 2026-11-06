import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../../data/models.dart';
import '../../util/l10n.dart';

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(errorMessage(e)),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
}

Future<bool> confirm(BuildContext context, {required String title, required String message, String? confirmLabel, bool destructive = false}) async {
  final t = context.t;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel ?? t.ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (Color bg, Color fg, String label) = switch (status) {
      OrderStatus.delivered => (Colors.green.shade100, Colors.green.shade900, t.statusDelivered),
      OrderStatus.cancelled => (Colors.red.shade100, Colors.red.shade900, t.statusCancelled),
      _ => (Colors.blue.shade100, Colors.blue.shade900, t.statusSubmitted),
    };
    return Pill(label: label, bg: bg, fg: fg);
  }
}

String statusLabel(BuildContext context, String s) => switch (s) {
      OrderStatus.delivered => context.t.statusDelivered,
      OrderStatus.cancelled => context.t.statusCancelled,
      _ => context.t.statusSubmitted,
    };

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.bg, required this.fg, this.icon});
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.gst});
  final bool gst;
  @override
  Widget build(BuildContext context) => gst
      ? Pill(label: context.t.categoryGst, bg: Colors.teal.shade100, fg: Colors.teal.shade900)
      : Pill(label: context.t.categoryGeneral, bg: Colors.grey.shade200, fg: Colors.grey.shade800);
}

class RateChangedChip extends StatelessWidget {
  const RateChangedChip({super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(label: context.t.rateChanged, bg: Colors.purple.shade100, fg: Colors.purple.shade900);
}

class PendingBadge extends StatelessWidget {
  const PendingBadge({super.key, this.failed = false});
  final bool failed;
  @override
  Widget build(BuildContext context) => failed
      ? Pill(label: context.t.syncFailed, bg: Colors.red.shade100, fg: Colors.red.shade900, icon: Icons.error_outline)
      : Pill(label: context.t.pendingSync, bg: Colors.orange.shade100, fg: Colors.orange.shade900, icon: Icons.cloud_upload_outlined);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off,
        message: errorMessage(error),
        action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.t.retry)),
      );
}

/// Constrains page content on wide (web) screens.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

String? requiredText(BuildContext context, String? v) => (v == null || v.trim().isEmpty) ? context.t.required : null;
