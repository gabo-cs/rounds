import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/home/widgets/bill_card.dart';
import 'package:rounds/features/home/widgets/month_header.dart';
import 'package:rounds/features/home/widgets/month_navigator.dart';
import 'package:rounds/features/mark_paid/mark_paid_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instancesAsync = ref.watch(monthInstancesProvider);
    final summary = ref.watch(monthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rounds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add bill',
            onPressed: () => context.push('/bills/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          const MonthNavigator(),
          if (summary != null) MonthHeader(summary: summary),
          const SizedBox(height: 8),
          Expanded(
            child: instancesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Error loading bills: $e'),
              ),
              data: (instances) {
                if (instances.isEmpty) {
                  return _EmptyState(
                    onAddBill: () => context.push('/bills/new'),
                  );
                }

                final pending =
                    instances.where((e) => !e.instance.isPaid).toList();
                final paid =
                    instances.where((e) => e.instance.isPaid).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Pending',
                        count: pending.length,
                      ),
                      const SizedBox(height: 8),
                      ...pending.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BillCard(
                            entry: entry,
                            onTap: () => _openMarkPaid(context, entry),
                            onLongPress: () => context
                                .push('/bills/${entry.bill.id}'),
                          ),
                        ),
                      ),
                    ],
                    if (paid.isNotEmpty) ...[
                      if (pending.isNotEmpty) const SizedBox(height: 8),
                      _SectionHeader(
                        title: 'Paid',
                        count: paid.length,
                      ),
                      const SizedBox(height: 8),
                      ...paid.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: BillCard(
                            entry: entry,
                            onTap: () => _openMarkPaid(context, entry),
                            onLongPress: () => context
                                .push('/bills/${entry.bill.id}'),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }

  void _openMarkPaid(
    BuildContext context,
    BillInstanceWithBill entry,
  ) {
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall,
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
            Text(
              'No bills yet',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your recurring bills to start tracking your monthly payments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddBill,
              icon: const Icon(Icons.add),
              label: const Text('Add your first bill'),
            ),
          ],
        ),
      ),
    );
  }
}
