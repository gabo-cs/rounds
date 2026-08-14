import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

/// Card for a bill that still needs attention. The due date leads the right
/// column — amounts are optional, so the date is the one datum every bill
/// has — with the amount as a secondary mono line when the bill carries one.
class BillCard extends ConsumerWidget {
  const BillCard({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
    this.isOverdue = false,
  });

  final BillInstanceWithBill entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isOverdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final amount = entry.bill.amount;

    return Card(
      color: isOverdue ? rounds.overdueSurface : null,
      shape: isOverdue
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: rounds.overdueBorder),
            )
          : null,
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
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.bill.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.bill.category != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l10n.translateCategory(entry.bill.category!),
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: rounds.textFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOverdue
                        ? l10n.overdueSince(entry.bill.dueDayOfMonth)
                        : l10n.dueThe(entry.bill.dueDayOfMonth),
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: isOverdue ? cs.error : null,
                    ),
                  ),
                  if (amount != null) ...[
                    const SizedBox(height: 2),
                    _AmountText(amount: amount),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountText extends ConsumerWidget {
  const _AmountText({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(settingsProvider.select((s) => s.currency));
    return Text(
      currency.format(amount),
      style: AppTypography.money.copyWith(
        fontSize: 13,
        color: RoundsColors.of(context).textSecondary,
      ),
    );
  }
}

/// Ledger row for a settled bill — deliberately quieter and denser than the
/// cards above it: done items get out of the way.
class PaidBillRow extends ConsumerWidget {
  const PaidBillRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final BillInstanceWithBill entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final currency = ref.watch(settingsProvider.select((s) => s.currency));

    final amount = entry.instance.amountPaid ?? entry.bill.amount;
    final paidAt = entry.instance.paidAt;
    // Amount when known; otherwise the payment date keeps the row honest.
    final trailing = amount != null
        ? currency.format(amount)
        : paidAt != null
            ? l10n.paidOnDate(paidAt)
            : l10n.paid;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            BillIcon(
              name: entry.bill.name,
              category: entry.bill.category,
              isPaid: true,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.bill.name,
                style: theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: rounds.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              trailing,
              style: AppTypography.monoMeta.copyWith(
                color: rounds.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
