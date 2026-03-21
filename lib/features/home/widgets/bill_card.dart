import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
                _AmountLabel(entry: entry, isPaid: isPaid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({required this.entry, required this.isPaid});

  final BillInstanceWithBill entry;
  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // For paid instances, prefer amountPaid over bill.amount
    final displayAmount = isPaid
        ? (entry.instance.amountPaid ?? entry.bill.amount)
        : entry.bill.amount;

    if (displayAmount == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Text(
      '\$${displayAmount.toStringAsFixed(displayAmount == displayAmount.truncateToDouble() ? 0 : 2)}',
      style: theme.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: isPaid
            ? cs.onSurface.withValues(alpha: 0.5)
            : cs.onSurface,
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
      return Icon(Icons.check_circle_rounded, color: cs.primary, size: 22);
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
        parts.isEmpty ? 'Paid' : parts.join(' · '),
        style: theme.textTheme.bodySmall!.copyWith(
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      );
    }

    final dueDay = entry.bill.dueDayOfMonth;
    final category = entry.bill.category;

    return Row(
      children: [
        Text(
          'Due on the ${_ordinal(dueDay)}',
          style: theme.textTheme.bodySmall!.copyWith(
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
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
