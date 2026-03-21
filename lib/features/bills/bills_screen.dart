import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBillsAsync = ref.watch(_allBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bills'),
      ),
      body: allBillsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allBills) {
          final active = allBills.where((b) => !b.isArchived).toList();
          final archived = allBills.where((b) => b.isArchived).toList();

          if (allBills.isEmpty) {
            return _EmptyState(onAdd: () => context.push('/bills/new'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                      onTap: () => context.push('/bills/${bill.id}/edit'),
                      onDelete: () => _confirmDelete(context, ref, bill),
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
                      onTap: () => context.push('/bills/${bill.id}/edit'),
                      onDelete: () => _confirmDelete(context, ref, bill),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/bills/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
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
      children: [
        Text(
          label,
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
          child: Text('$count', style: theme.textTheme.labelSmall),
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

    return Opacity(
      opacity: isArchived ? 0.55 : 1.0,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bill.name,
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (bill.amount != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '\$${bill.amount!.toStringAsFixed(bill.amount! == bill.amount!.truncateToDouble() ? 0 : 2)}',
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _InfoChip(
                            label: 'Due ${_ordinal(bill.dueDayOfMonth)}',
                            icon: Icons.calendar_today_outlined,
                          ),
                          if (bill.category != null)
                            _InfoChip(label: bill.category!),
                          if (isArchived)
                            _InfoChip(
                              label: 'Archived',
                              color: cs.errorContainer,
                              textColor: cs.onErrorContainer,
                            ),
                        ],
                      ),
                      if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          bill.notes!,
                          style: theme.textTheme.bodySmall!.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit',
                      iconSize: 20,
                      onPressed: onTap,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: cs.error),
                      tooltip: 'Delete',
                      iconSize: 20,
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    this.icon,
    this.color,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.surfaceContainerHighest;
    final fg = textColor ?? cs.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
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
