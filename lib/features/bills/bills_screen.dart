import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
import 'package:rounds/core/widgets/screen_header.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBillsAsync = ref.watch(_allBillsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // How many bills are set up (active), shown up front under the title.
    final activeCount = allBillsAsync.valueOrNull
            ?.where((b) => !b.isArchived)
            .length ??
        0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: l10n.billsTitle,
              subtitle: activeCount > 0 ? l10n.billsCount(activeCount) : null,
            ),
            Expanded(
              child: allBillsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.genericErrorMessage,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                data: (allBills) {
                  final active =
                      allBills.where((b) => !b.isArchived).toList();
                  final archived =
                      allBills.where((b) => b.isArchived).toList();

                  if (allBills.isEmpty) {
                    return _EmptyState(onAdd: () => context.push('/bills/new'));
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    children: [
                      ...active.map(
                        (bill) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _BillRow(
                            bill: bill,
                            onTap: () =>
                                context.push('/bills/${bill.id}/edit'),
                          ),
                        ),
                      ),
                      if (archived.isNotEmpty) ...[
                        if (active.isNotEmpty) const SizedBox(height: 12),
                        _ArchivedHeader(count: archived.length),
                        ...archived.map(
                          (bill) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _BillRow(
                              bill: bill,
                              onTap: () =>
                                  context.push('/bills/${bill.id}/edit'),
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
}

final _allBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsRepositoryProvider).watchAllBills();
});

class _ArchivedHeader extends StatelessWidget {
  const _ArchivedHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Icon(Icons.archive_outlined, size: 13, color: rounds.textFaint),
          const SizedBox(width: 8),
          Text(
            l10n.archivedLabel.toUpperCase(),
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

class _BillRow extends ConsumerWidget {
  const _BillRow({required this.bill, required this.onTap});

  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rounds = RoundsColors.of(context);
    final isArchived = bill.isArchived;
    final l10n = AppLocalizations.of(context);

    final subtitle = [
      l10n.dueThe(bill.dueDayOfMonth),
      if (bill.category != null) l10n.translateCategory(bill.category!),
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Opacity(
                opacity: isArchived ? 0.45 : 1,
                child: BillIcon(
                  name: bill.name,
                  category: bill.category,
                  size: 44,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: isArchived ? rounds.textFaint : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: rounds.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (bill.amount != null) ...[
                const SizedBox(width: 12),
                Text(
                  ref
                      .watch(settingsProvider.select((s) => s.currency))
                      .format(bill.amount!),
                  style: AppTypography.money.copyWith(
                    fontSize: 13,
                    color: isArchived
                        ? rounds.textFaint
                        : rounds.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
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
            const SizedBox(height: 8),
            Text(
              l10n.addFirstBillBillsSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(l10n.addFirstBill),
            ),
          ],
        ),
      ),
    );
  }
}
