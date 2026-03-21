import 'package:flutter/material.dart';
import 'package:rounds/core/extensions/currency_extensions.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';

class MonthHeader extends StatelessWidget {
  const MonthHeader({super.key, required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final progress = summary.totalDue > 0
        ? summary.totalPaid / summary.totalDue
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.remaining > 0
                          ? '${summary.remaining.asCurrency} remaining'
                          : 'All paid!',
                      style: theme.textTheme.headlineSmall!.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.paidCount} of ${summary.totalCount} bills paid'
                      ' · ${summary.totalDue.asCurrency} total',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (summary.pendingCount == 0)
                Icon(Icons.check_circle_rounded,
                    color: cs.onPrimaryContainer, size: 32),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimaryContainer),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
