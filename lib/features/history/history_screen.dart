import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/core/widgets/round_ring.dart';
import 'package:rounds/core/widgets/screen_header.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/history/providers/history_providers.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsAsync = ref.watch(historyMonthsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: l10n.historyTitle,
              actions: [
                IconButton(
                  icon: const Icon(Icons.upload_outlined),
                  tooltip: l10n.exportDataTooltip,
                  onPressed: () => _export(context, ref),
                ),
              ],
            ),
            Expanded(
              child: monthsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.genericErrorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                data: (months) {
                  if (months.isEmpty) {
                    return const _EmptyHistory();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: months.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      return _MonthRow(
                        summary: months[i],
                        onTap: () => _navigateToMonth(context, ref, months[i]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
    final l10n = AppLocalizations.of(context);
    try {
      final backupService = BackupService(
        ref.read(billInstancesRepositoryProvider),
      );
      await backupService.exportAndShare();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
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
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final allPaid = summary.pendingCount == 0;
    final label = l10n.monthLabel(summary.year, summary.month);

    // Miniature Round for the month: paid segments first, then what's left.
    // Unpaid in a month that's already over means missed, so it reads red;
    // the current (or a future) month's unpaid is just pending.
    final now = DateTime.now();
    final isPast = DateTime(summary.year, summary.month)
        .isBefore(DateTime(now.year, now.month));
    final unpaidColor = isPast ? cs.error : rounds.neutralDot;
    final segmentColors = [
      for (var i = 0; i < summary.paidCount; i++) rounds.paid,
      for (var i = 0; i < summary.pendingCount; i++) unpaidColor,
    ];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              RoundRing(
                size: 38,
                strokeWidth: 3.5,
                segmentColors: segmentColors,
                trackColor: cs.outlineVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.billsPaidOf(summary.paidCount, summary.totalCount),
                      style: AppTypography.monoMeta.copyWith(
                        color: rounds.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                (allPaid
                        ? l10n.allPaid
                        : l10n.pendingCount(summary.pendingCount))
                    .toUpperCase(),
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 10,
                  color: allPaid ? rounds.paid : unpaidColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
          Text(l10n.noHistoryYet, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            l10n.noHistorySubtitle,
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
