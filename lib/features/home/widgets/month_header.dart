import 'package:flutter/material.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';

class MonthHeader extends StatelessWidget {
  const MonthHeader({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allPaid = summary.pendingCount == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          Icon(
            allPaid
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: allPaid ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            allPaid
                ? 'All ${summary.totalCount} bills paid'
                : '${summary.paidCount} of ${summary.totalCount} paid'
                    ' · ${summary.pendingCount} remaining',
            style: theme.textTheme.bodyMedium!.copyWith(
              color: allPaid
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.65),
              fontWeight: allPaid ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
