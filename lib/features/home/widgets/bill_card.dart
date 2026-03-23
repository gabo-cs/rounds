import 'package:flutter/material.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/l10n/app_localizations.dart';

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
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              BillIcon(
                name: entry.bill.name,
                category: entry.bill.category,
                isPaid: isPaid,
                size: 48,
              ),
              const SizedBox(width: 14),
              // Left column: name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.bill.name,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPaid
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    if (isPaid) ...[
                      const SizedBox(height: 3),
                      _PaidSubtitle(entry: entry),
                    ] else if (entry.bill.category != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        l10n.translateCategory(entry.bill.category!),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right column: due date (pending) or amount (paid)
              if (!isPaid)
                _DueDateLabel(dueDay: entry.bill.dueDayOfMonth)
              else
                _AmountLabel(entry: entry),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueDateLabel extends StatelessWidget {
  const _DueDateLabel({required this.dueDay});

  final int dueDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.dueThe(dueDay),
      textAlign: TextAlign.right,
      style: theme.textTheme.titleSmall!.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({required this.entry});

  final BillInstanceWithBill entry;

  @override
  Widget build(BuildContext context) {
    final displayAmount =
        entry.instance.amountPaid ?? entry.bill.amount;
    if (displayAmount == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Text(
      '\$${displayAmount.toStringAsFixed(displayAmount == displayAmount.truncateToDouble() ? 0 : 2)}',
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
    );
  }
}

class _PaidSubtitle extends StatelessWidget {
  const _PaidSubtitle({required this.entry});

  final BillInstanceWithBill entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final paidAt = entry.instance.paidAt;
    final method = PaymentMethod.fromString(entry.instance.paymentMethod);
    final parts = <String>[];
    if (paidAt != null) parts.add(l10n.paidOnDate(paidAt));
    if (method != null) parts.add(_methodLabel(method, l10n));

    return Text(
      parts.isEmpty ? l10n.paid : parts.join(' · '),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
    );
  }

  String _methodLabel(PaymentMethod method, AppLocalizations l10n) =>
      switch (method) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.bankTransfer => l10n.paymentBankTransfer,
        PaymentMethod.card => l10n.paymentCard,
        PaymentMethod.autoDebit => l10n.paymentAutoDebit,
        PaymentMethod.other => l10n.paymentOther,
      };
}
