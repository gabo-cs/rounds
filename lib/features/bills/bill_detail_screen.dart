import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/extensions/currency_extensions.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/bills/providers/bills_providers.dart';
import 'package:rounds/features/mark_paid/mark_paid_sheet.dart';
import 'package:rounds/l10n/app_localizations.dart';

class BillDetailScreen extends ConsumerWidget {
  const BillDetailScreen({super.key, required this.billId});

  final int billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(billDetailProvider(billId));
    final instancesAsync = ref.watch(billInstancesForBillProvider(billId));
    final l10n = AppLocalizations.of(context);

    return billAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (bill) {
        if (bill == null) {
          return Scaffold(
              body: Center(child: Text(l10n.billNotFound)));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(bill.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.editBillTooltip,
                onPressed: () =>
                    context.push('/bills/${bill.id}/edit'),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _BillInfoCard(bill: bill),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l10n.paymentHistoryTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              instancesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text('Error: $e')),
                ),
                data: (instances) {
                  if (instances.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(child: Text(l10n.noPaymentHistoryYet)),
                    );
                  }

                  return SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: instances.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final entry = instances[i];
                        return _InstanceRow(
                          entry: entry,
                          onTap: () =>
                              _openMarkPaid(context, entry),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
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

class _BillInfoCard extends StatelessWidget {
  const _BillInfoCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (bill.amount != null)
                  Expanded(
                    child: Text(
                      bill.amount!.asCurrency,
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (bill.isArchived)
                  Chip(
                    label: Text(l10n.archivedChipLabel),
                    labelStyle: TextStyle(color: cs.onErrorContainer),
                    backgroundColor: cs.errorContainer,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: l10n.dueOnDayEachMonth(bill.dueDayOfMonth),
            ),
            if (bill.category != null) ...[
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.label_outline,
                label: l10n.translateCategory(bill.category!),
              ),
            ],
            if (bill.notes != null && bill.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.notes_outlined,
                label: bill.notes!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
          ),
        ),
      ],
    );
  }
}

class _InstanceRow extends StatelessWidget {
  const _InstanceRow({required this.entry, required this.onTap});

  final BillInstanceWithBill entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final instance = entry.instance;
    final isPaid = instance.isPaid;

    final label = l10n.monthLabel(instance.year, instance.month);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: cs.surface,
        ),
        child: Row(
          children: [
            Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isPaid ? cs.primary : cs.outlineVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isPaid) ...[
                    const SizedBox(height: 2),
                    Text(
                      _buildPaidSubtitle(instance, l10n),
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _StatusChip(isPaid: isPaid),
          ],
        ),
      ),
    );
  }

  String _buildPaidSubtitle(BillInstance instance, AppLocalizations l10n) {
    final parts = <String>[];
    if (instance.paidAt != null) {
      parts.add(l10n.formatShortDate(instance.paidAt!));
    }
    if (instance.amountPaid != null) {
      parts.add('\$${instance.amountPaid!.toStringAsFixed(2)}');
    }
    final method = PaymentMethod.fromString(instance.paymentMethod);
    if (method != null) {
      parts.add(_methodLabel(method, l10n));
    }
    if (instance.referenceNote != null &&
        instance.referenceNote!.isNotEmpty) {
      parts.add(instance.referenceNote!);
    }
    return parts.join(' · ');
  }

  String _methodLabel(PaymentMethod method, AppLocalizations l10n) =>
      switch (method) {
        PaymentMethod.cash => l10n.paymentCash,
        PaymentMethod.bankTransfer => l10n.paymentBankTransfer,
        PaymentMethod.card => l10n.paymentCard,
        PaymentMethod.autoDebit => l10n.paymentAutoDebit,
        PaymentMethod.other => l10n.paymentOther,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isPaid});

  final bool isPaid;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPaid ? l10n.paid : l10n.unpaid,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: isPaid ? cs.onPrimaryContainer : cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
