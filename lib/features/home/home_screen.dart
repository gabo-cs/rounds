import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/home/widgets/bill_card.dart';
import 'package:rounds/features/home/widgets/month_navigator.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bills/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// One month's bill list. Each page owns its [monthInstancesProvider] instance,
/// so the PageView keeps neighbouring months alive and pre-built.
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
              color: Theme.of(context).colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
            ),
          ),
        ),
      ),
      data: (instances) {
        if (instances.isEmpty) {
          return _EmptyState(onAddBill: () => context.push('/bills/new'));
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

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          children: [
            if (overdue.isNotEmpty) ...[
              _SectionHeader(title: l10n.overdue, count: overdue.length),
              const SizedBox(height: 14),
              ...overdue.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
              if (overdue.isNotEmpty) const SizedBox(height: 20),
              _SectionHeader(title: l10n.pending, count: pending.length),
              const SizedBox(height: 14),
              ...pending.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                const SizedBox(height: 20),
              _SectionHeader(title: l10n.paid, count: paid.length),
              const SizedBox(height: 14),
              ...paid.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BillCard(
                    entry: entry,
                    onTap: () => _openMarkPaid(context, entry),
                    onLongPress: () => context.push('/bills/${entry.bill.id}'),
                  ),
                ),
              ),
            ],
          ],
        );
      },
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            l10n.itemsCount(count),
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddBill});

  final VoidCallback onAddBill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noBillsYet, style: theme.textTheme.titleLarge),
            const SizedBox(height: 14),
            Text(
              l10n.addFirstBillHomeSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddBill,
              icon: const Icon(Icons.add),
              label: Text(l10n.addFirstBill),
            ),
          ],
        ),
      ),
    );
  }
}
