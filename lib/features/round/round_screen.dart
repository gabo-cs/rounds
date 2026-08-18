import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/widgets/confirm_dialog.dart';
import 'package:rounds/core/widgets/empty_state.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/round/providers/mark_month_paid_providers.dart';
import 'package:rounds/features/round/providers/round_providers.dart';
import 'package:rounds/features/round/widgets/bill_card.dart';
import 'package:rounds/features/round/widgets/month_navigator.dart';
import 'package:rounds/features/mark_paid/mark_paid_sheet.dart';
import 'package:rounds/l10n/app_localizations.dart';

// Fixed origin for the month <-> page-index mapping. Any month maps to a stable
// non-negative page index, so the PageView can page through months directly.
const _originYear = 2000;
const _lastYear = 2100;

int _pageForMonth(SelectedMonth m) =>
    (m.year - _originYear) * 12 + (m.month - 1);

SelectedMonth _monthForPage(int page) =>
    SelectedMonth(year: _originYear + page ~/ 12, month: page % 12 + 1);

class RoundScreen extends ConsumerStatefulWidget {
  const RoundScreen({super.key});

  @override
  ConsumerState<RoundScreen> createState() => _RoundScreenState();
}

class _RoundScreenState extends ConsumerState<RoundScreen> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: _pageForMonth(ref.read(selectedMonthProvider)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Drive the PageView from the shared selected-month state so the nav
    // arrows, the "Today" button and history deep-links all move the pager.
    // Single-step moves animate; larger jumps snap to avoid scrolling through
    // every month in between.
    ref.listen<SelectedMonth>(selectedMonthProvider, (_, next) {
      if (!_controller.hasClients) return;
      final target = _pageForMonth(next);
      final current = _controller.page?.round() ?? target;
      if (current == target) return;
      if ((current - target).abs() > 1) {
        _controller.jumpToPage(target);
      } else {
        _controller.animateToPage(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const MonthNavigator(),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                // Pre-build the neighbouring months so a swipe or arrow tap
                // lands on an already-built page — no build/relayout mid-swipe.
                allowImplicitScrolling: true,
                itemCount: (_lastYear - _originYear) * 12,
                onPageChanged: (page) {
                  final month = _monthForPage(page);
                  if (ref.read(selectedMonthProvider) != month) {
                    ref.read(selectedMonthProvider.notifier).state = month;
                  }
                },
                itemBuilder: (context, page) =>
                    _MonthPage(month: _monthForPage(page)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One month's bill list. Each page owns its [monthInstancesProvider] instance,
/// so the PageView keeps neighbouring months alive and pre-built.
/// An empty month means one of two things, and they need different offers.
///
/// Instances are only generated from the current month forward, so a past
/// month is blank whenever the app went unopened through it — or whenever an
/// imported backup ends before it. Nothing generates those rows later, so the
/// month would stay blank forever while claiming there are no bills at all.
/// Building it is offered rather than done automatically: the rows arrive
/// unpaid, and inventing a stack of overdue bills nobody asked for is worse
/// than an honest gap.
class _EmptyMonth extends ConsumerWidget {
  const _EmptyMonth({required this.month});

  final SelectedMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final activeBills = ref.watch(activeBillsProvider).valueOrNull;
    final now = DateTime.now();
    final isPast = DateTime(
      month.year,
      month.month,
    ).isBefore(DateTime(now.year, now.month));

    if (isPast && activeBills != null && activeBills.isNotEmpty) {
      return EmptyState(
        icon: Icons.history_toggle_off,
        title: l10n.noRoundRecordedTitle,
        subtitle: l10n.noRoundRecordedSubtitle,
        action: FilledButton.icon(
          // No reminder scheduling here, as with every other generation path:
          // the schedule is device-month based and owned by the re-arm pass.
          onPressed: () => ref
              .read(billInstancesRepositoryProvider)
              .ensureInstancesExist(activeBills, month.year, month.month),
          icon: const Icon(Icons.event_repeat),
          label: Text(l10n.buildRoundButton),
        ),
      );
    }

    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: l10n.noBillsYet,
      subtitle: l10n.addFirstBillHomeSubtitle,
      action: FilledButton.icon(
        onPressed: () => context.push('/bills/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.addFirstBill),
      ),
    );
  }
}

class _MonthPage extends ConsumerWidget {
  const _MonthPage({required this.month});

  final SelectedMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instancesAsync = ref.watch(monthInstancesProvider(month));
    final l10n = AppLocalizations.of(context);

    return instancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.genericErrorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
      data: (instances) {
        if (instances.isEmpty) {
          return _EmptyMonth(month: month);
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final unpaid = instances.where((e) => !e.instance.isPaid).toList();
        final paid = instances.where((e) => e.instance.isPaid).toList();

        final overdue = unpaid.where((e) {
          final due = DateTime(
            e.instance.year,
            e.instance.month,
            e.bill.dueDayOfMonth,
          );
          return due.isBefore(today);
        }).toList();
        final pending = unpaid.where((e) {
          final due = DateTime(
            e.instance.year,
            e.instance.month,
            e.bill.dueDayOfMonth,
          );
          return !due.isBefore(today);
        }).toList();

        final rounds = RoundsColors.of(context);
        return ListView(
          // No FAB on this screen, so the list only needs breathing room.
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (unpaid.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: _MarkAllPaidButton(
                  busy: ref.watch(markMonthPaidProvider(month)),
                  onPressed: () => _markAllPaid(context, ref, unpaid),
                ),
              ),
            if (overdue.isNotEmpty) ...[
              _SectionHeader(
                title: l10n.overdue,
                count: overdue.length,
                dotColor: Theme.of(context).colorScheme.error,
              ),
              ...overdue.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillCard(
                    entry: entry,
                    isOverdue: true,
                    onTap: () => _openMarkPaid(context, entry),
                    onLongPress: () => context.push('/bills/${entry.bill.id}'),
                  ),
                ),
              ),
            ],
            if (pending.isNotEmpty) ...[
              if (overdue.isNotEmpty) const SizedBox(height: 12),
              _SectionHeader(
                title: l10n.pending,
                count: pending.length,
                dotColor: rounds.neutralDot,
              ),
              ...pending.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BillCard(
                    entry: entry,
                    onTap: () => _openMarkPaid(context, entry),
                    onLongPress: () => context.push('/bills/${entry.bill.id}'),
                  ),
                ),
              ),
            ],
            if (paid.isNotEmpty) ...[
              if (overdue.isNotEmpty || pending.isNotEmpty)
                const SizedBox(height: 12),
              _SectionHeader(
                title: l10n.paid,
                count: paid.length,
                dotColor: rounds.paid,
              ),
              ...paid.map(
                (entry) => PaidBillRow(
                  entry: entry,
                  onTap: () => _openMarkPaid(context, entry),
                  onLongPress: () => context.push('/bills/${entry.bill.id}'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Settling a whole round at once. Offered for any month with something
  /// open — reconstructing a month the app missed and clearing a payday's
  /// worth of bills are the same gesture — but what gets recorded differs,
  /// so the confirmation says which it will be.
  Future<void> _markAllPaid(
    BuildContext context,
    WidgetRef ref,
    List<BillInstanceWithBill> unpaid,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final isCurrentRound = month.year == now.year && month.month == now.month;

    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.done_all,
      title: l10n.markAllPaidDialogTitle,
      message: isCurrentRound
          ? l10n.markAllPaidCurrentMessage(unpaid.length)
          : l10n.markAllPaidPastMessage(unpaid.length),
      confirmLabel: l10n.markAllPaidConfirm,
    );
    if (confirmed != ConfirmDialogResult.confirmed) return;

    final settled = await ref
        .read(markMonthPaidProvider(month).notifier)
        .settle(unpaid);
    if (settled == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.genericErrorMessage)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.markAllPaidDone(settled))),
    );
  }

  void _openMarkPaid(BuildContext context, BillInstanceWithBill entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MarkPaidSheet(entry: entry),
    );
  }
}

class _MarkAllPaidButton extends StatelessWidget {
  const _MarkAllPaidButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.done_all, size: 18),
      label: Text(l10n.markAllPaidAction),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.dotColor,
  });

  final String title;
  final int count;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final rounds = RoundsColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: AppTypography.eyebrow.copyWith(color: rounds.textFaint),
          ),
          const Spacer(),
          Text(
            '$count',
            style: AppTypography.monoMeta.copyWith(color: rounds.textFaint),
          ),
        ],
      ),
    );
  }
}
