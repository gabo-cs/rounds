import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBillsAsync = ref.watch(_allBillsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bills',
                    style: theme.textTheme.headlineMedium!
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 3,
                    width: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: allBillsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (allBills) {
                  final active =
                      allBills.where((b) => !b.isArchived).toList();
                  final archived =
                      allBills.where((b) => b.isArchived).toList();

                  if (allBills.isEmpty) {
                    return _EmptyState(onAdd: () => context.push('/bills/new'));
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      if (active.isNotEmpty) ...[
                        _SectionHeader(
                          label: 'Active',
                          count: active.length,
                        ),
                        const SizedBox(height: 8),
                        ...active.map(
                          (bill) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BillRow(
                              bill: bill,
                              onTap: () =>
                                  context.push('/bills/${bill.id}/edit'),
                              onDelete: () =>
                                  _confirmDelete(context, ref, bill),
                            ),
                          ),
                        ),
                      ],
                      if (archived.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _SectionHeader(
                          label: 'Archived',
                          count: archived.length,
                        ),
                        const SizedBox(height: 8),
                        ...archived.map(
                          (bill) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BillRow(
                              bill: bill,
                              onTap: () =>
                                  context.push('/bills/${bill.id}/edit'),
                              onDelete: () =>
                                  _confirmDelete(context, ref, bill),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/bills/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Bill bill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete bill?'),
        content: Text(
          'Delete "${bill.name}" permanently?\n\n'
          'This will also erase all payment history for this bill. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(billsRepositoryProvider).deleteBill(bill.id);
    }
  }
}

final _allBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsRepositoryProvider).watchAllBills();
});

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: theme.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$count ${count == 1 ? 'item' : 'items'}',
          style: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.bill,
    required this.onTap,
    required this.onDelete,
  });

  final Bill bill;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isArchived = bill.isArchived;

    final subtitle = [
      'Due the ${_ordinal(bill.dueDayOfMonth)}',
      if (bill.category != null) bill.category!,
      if (isArchived) 'Archived',
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            children: [
              BillIcon(
                name: bill.name,
                category: bill.category,
                size: 48,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isArchived
                            ? cs.onSurface.withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: cs.onSurface.withValues(alpha: isArchived ? 0.4 : 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (bill.amount != null) ...[
                const SizedBox(width: 8),
                Text(
                  '\$${bill.amount!.toStringAsFixed(bill.amount! == bill.amount!.truncateToDouble() ? 0 : 2)}',
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isArchived
                        ? cs.primary.withValues(alpha: 0.4)
                        : cs.primary,
                  ),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                iconSize: 18,
                onPressed: onTap,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: 'Delete',
                iconSize: 18,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

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
            Text('No bills yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your recurring bills to start tracking.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first bill'),
            ),
          ],
        ),
      ),
    );
  }
}
