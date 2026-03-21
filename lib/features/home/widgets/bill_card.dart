import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/extensions/currency_extensions.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final BillInstanceWithBill entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPaid = entry.instance.isPaid;

    return Opacity(
      opacity: isPaid ? 0.55 : 1.0,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _StatusIndicator(isPaid: isPaid),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.bill.name,
                        style: theme.textTheme.titleMedium!.copyWith(
                          decoration:
                              isPaid ? TextDecoration.lineThrough : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _SubtitleRow(entry: entry, isPaid: isPaid),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.bill.amount.asCurrency,
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isPaid
                        ? cs.onSurface.withValues(alpha: 0.5)
                        : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isPaid) {
      return Icon(Icons.check_circle_rounded,
          color: cs.primary, size: 22);
    }
    return Icon(Icons.radio_button_unchecked_rounded,
        color: cs.outlineVariant, size: 22);
  }
}

class _SubtitleRow extends StatelessWidget {
  const _SubtitleRow({required this.entry, required this.isPaid});

  final BillInstanceWithBill entry;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (isPaid) {
      final paidAt = entry.instance.paidAt;
      final method = PaymentMethod.fromString(entry.instance.paymentMethod);
      final parts = <String>[];
      if (paidAt != null) parts.add('Paid ${DateFormat.MMMd().format(paidAt)}');
      if (method != null) parts.add(method.label);
      return Text(
        parts.join(' · '),
        style: theme.textTheme.bodySmall!.copyWith(
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      );
    }

    final dueDay = entry.bill.dueDayOfMonth;
    final now = DateTime.now();
    final dueDate = DateTime(
      entry.instance.year,
      entry.instance.month,
      dueDay,
    );
    final daysUntil = dueDate.difference(now).inDays;

    String dueLabel;
    Color labelColor = cs.onSurface.withValues(alpha: 0.6);
    if (daysUntil < 0) {
      dueLabel = 'Overdue';
      labelColor = Theme.of(context).colorScheme.error;
    } else if (daysUntil == 0) {
      dueLabel = 'Due today';
      labelColor = Theme.of(context).colorScheme.error;
    } else if (daysUntil <= 3) {
      dueLabel = 'Due in $daysUntil day${daysUntil == 1 ? '' : 's'}';
      labelColor = Theme.of(context).colorScheme.tertiary;
    } else {
      dueLabel = 'Due on the ${_ordinal(dueDay)}';
    }

    final category = entry.bill.category;

    return Row(
      children: [
        Text(
          dueLabel,
          style: theme.textTheme.bodySmall!.copyWith(color: labelColor),
        ),
        if (category != null) ...[
          Text(
            ' · ',
            style: theme.textTheme.bodySmall!
                .copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
          ),
          Text(
            category,
            style: theme.textTheme.bodySmall!.copyWith(
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
