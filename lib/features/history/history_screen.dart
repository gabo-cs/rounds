import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/extensions/currency_extensions.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/history/providers/history_providers.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:go_router/go_router.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(historyMonthsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: 'Export data',
            onPressed: () => _export(context, ref),
          ),
        ],
      ),
      body: monthsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load history: $e')),
        data: (months) {
          if (months.isEmpty) {
            return _EmptyHistory();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: months.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              return _MonthRow(
                summary: months[i],
                onTap: () => _navigateToMonth(context, ref, months[i]),
              );
            },
          );
        },
      ),
    );
  }

  void _navigateToMonth(
    BuildContext context,
    WidgetRef ref,
    MonthSummary summary,
  ) {
    ref.read(selectedMonthProvider.notifier).state =
        SelectedMonth(year: summary.year, month: summary.month);
    context.go('/');
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final backupService = BackupService(
        ref.read(billInstancesRepositoryProvider),
      );
      await backupService.exportAndShare();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.summary, required this.onTap});

  final MonthSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final allPaid = summary.pendingCount == 0;
    final monthLabel = DateFormat.yMMMM()
        .format(DateTime(summary.year, summary.month));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthLabel,
                    style: theme.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.paidCount} of ${summary.totalCount} paid'
                    ' · ${summary.totalDue.asCurrency} total',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  summary.totalPaid.asCurrency,
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: allPaid ? cs.primary : cs.onSurface,
                  ),
                ),
                if (!allPaid)
                  Text(
                    '${summary.pendingCount} pending',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: cs.error,
                    ),
                  )
                else
                  Text(
                    'All paid',
                    style: theme.textTheme.labelSmall!.copyWith(
                      color: cs.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_outlined,
            size: 72,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text('No history yet', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Past months will appear here once you start tracking payments.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
