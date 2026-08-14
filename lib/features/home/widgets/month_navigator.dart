import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/extensions/date_extensions.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/widgets/round_ring.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

/// The Home anchor: display-size month name, navigation, and the Round —
/// the month drawn as a segmented ring, one segment per bill in due-day
/// order, with the settled count and the total still to pay beside it.
class MonthNavigator extends ConsumerWidget {
  const MonthNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rounds = RoundsColors.of(context);
    final selected = ref.watch(selectedMonthProvider);
    final now = DateTime.now();
    final selectedDt = DateTime(selected.year, selected.month);
    final isCurrentMonth =
        selected.year == now.year && selected.month == now.month;

    // Spanish month names arrive lowercase; as a display headline the month
    // deserves its capital.
    final rawMonth = DateFormat.MMMM().format(selectedDt);
    final monthLabel = rawMonth[0].toUpperCase() + rawMonth.substring(1);

    void select(DateTime dt) {
      ref.read(selectedMonthProvider.notifier).state = SelectedMonth(
        year: dt.year,
        month: dt.month,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthLabel,
                      style: theme.textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${selected.year} · ${l10n.roundNumber(selected.month)}',
                      style: AppTypography.monoMeta.copyWith(
                        color: rounds.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              // Nav cluster: chevrons always, Today only when off the
              // current month (it fades rather than reflows).
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: l10n.previousMonthTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => select(selectedDt.previousMonth),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isCurrentMonth ? 0 : 1,
                      child: TextButton(
                        onPressed:
                            isCurrentMonth ? null : () => select(now),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.colorScheme.primary,
                          textStyle: AppTypography.eyebrow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                        child: Text(l10n.todayButton.toUpperCase()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: l10n.nextMonthTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => select(selectedDt.nextMonth),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _MonthSummary(month: selected),
      ],
    );
  }
}

class _MonthSummary extends ConsumerWidget {
  const _MonthSummary({required this.month});

  final SelectedMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instances =
        ref.watch(monthInstancesProvider(month)).valueOrNull;

    // Collapse (instead of spinning) while loading or when the month is
    // empty — the header stays calm and the list below tells the story.
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: (instances == null || instances.isEmpty)
          ? const SizedBox(width: double.infinity)
          : _SummaryContent(month: month, instances: instances),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent({required this.month, required this.instances});

  final SelectedMonth month;
  final List<BillInstanceWithBill> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rounds = RoundsColors.of(context);
    final currency = ref.watch(settingsProvider.select((s) => s.currency));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // One ring segment per bill, in due-day order around the dial.
    final ordered = [...instances]
      ..sort((a, b) => a.bill.dueDayOfMonth.compareTo(b.bill.dueDayOfMonth));

    var paidCount = 0;
    var overdueCount = 0;
    var unpaidTotal = 0.0;
    final segmentColors = <Color>[];
    for (final entry in ordered) {
      if (entry.instance.isPaid) {
        paidCount++;
        segmentColors.add(rounds.paid);
        continue;
      }
      final due = DateTime(
        entry.instance.year,
        entry.instance.month,
        entry.bill.dueDayOfMonth,
      );
      final isOverdue = due.isBefore(today);
      if (isOverdue) overdueCount++;
      segmentColors.add(
        isOverdue ? theme.colorScheme.error : rounds.neutralDot,
      );
      unpaidTotal += entry.bill.amount ?? 0;
    }

    final allPaid = paidCount == instances.length;
    final detailSpans = <InlineSpan>[
      if (allPaid)
        TextSpan(
          text: l10n.allPaid,
          style: TextStyle(color: rounds.paid, fontWeight: FontWeight.w500),
        )
      else ...[
        if (unpaidTotal > 0)
          TextSpan(text: l10n.amountToGo(currency.format(unpaidTotal)))
        else
          TextSpan(text: l10n.pendingCount(instances.length - paidCount)),
        if (overdueCount > 0) ...[
          const TextSpan(text: ' · '),
          TextSpan(
            text: l10n.overdueCount(overdueCount),
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          RoundRing(
            size: 60,
            strokeWidth: 5,
            animate: true,
            segmentColors: segmentColors,
            trackColor: theme.colorScheme.outlineVariant,
            child: Text(
              '$paidCount/${instances.length}',
              style: AppTypography.money.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.paidOfTotal(paidCount, instances.length),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: AppTypography.monoMeta.copyWith(
                      color: rounds.textSecondary,
                    ),
                    children: detailSpans,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
