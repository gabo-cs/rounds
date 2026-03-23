import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              BillIcon(
                name: entry.bill.name,
                category: entry.bill.category,
                isPaid: isPaid,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.bill.name,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPaid
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.5)
                            : null,
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
    final cs = theme.colorScheme;

    final displayAmount = isPaid
        ? (entry.instance.amountPaid ?? entry.bill.amount)
        : entry.bill.amount;

    if (displayAmount == null) return const SizedBox.shrink();

    return Text(
      '\$${displayAmount.toStringAsFixed(displayAmount == displayAmount.truncateToDouble() ? 0 : 2)}',
      style: theme.textTheme.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        color: isPaid
            ? cs.onSurface.withValues(alpha: 0.4)
            : cs.onSurface,
      ),
    );
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
    final subtitleColor = cs.onSurface.withValues(alpha: 0.55);

    if (isPaid) {
      final paidAt = entry.instance.paidAt;
      final method = PaymentMethod.fromString(entry.instance.paymentMethod);
      final parts = <String>[];
      if (paidAt != null) parts.add('Paid ${DateFormat.MMMd().format(paidAt)}');
      if (method != null) parts.add(method.label);
      return Text(
        parts.isEmpty ? 'Paid' : parts.join(' · '),
        style: theme.textTheme.bodySmall!.copyWith(color: subtitleColor),
      );
    }

    final dueDay = entry.bill.dueDayOfMonth;
    final category = entry.bill.category;
    final parts = ['Due the ${_ordinal(dueDay)}'];
    if (category != null) parts.add(category);

    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall!.copyWith(color: subtitleColor),
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
