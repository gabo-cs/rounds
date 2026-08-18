import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/currency.dart';
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
      error: (e, _) =>
          Scaffold(body: Center(child: Text(l10n.genericErrorMessage))),
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
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    l10n.paymentHistoryTitle.toUpperCase(),
                    style: AppTypography.eyebrow.copyWith(
                      color: RoundsColors.of(context).textFaint,
                    ),
                  ),
                ),
              ),
              instancesAsync.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SliverFillRemaining(
                  child: Center(child: Text(l10n.genericErrorMessage)),
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
                          const SizedBox(height: 2),
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

class _BillInfoCard extends ConsumerWidget {
  const _BillInfoCard({required this.bill});

  final Bill bill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      kAppCurrency.format(bill.amount!),
                      style: AppTypography.money.copyWith(
                        fontSize: 26,
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

class _InstanceRow extends ConsumerWidget {
  const _InstanceRow({required this.entry, required this.onTap});

  final BillInstanceWithBill entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final instance = entry.instance;
    final isPaid = instance.isPaid;

    final label = l10n.monthLabel(instance.year, instance.month);

    final rounds = RoundsColors.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isPaid ? rounds.paid : cs.outlineVariant,
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
                      fontWeight: FontWeight.w600,
                      color: isPaid ? null : rounds.textSecondary,
                    ),
                  ),
                  if (isPaid && _paidSubtitle(instance, l10n) != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _paidSubtitle(instance, l10n)!,
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: rounds.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isPaid && instance.amountPaid != null)
              Text(
                kAppCurrency.format(instance.amountPaid!),
                style: AppTypography.money.copyWith(
                  fontSize: 13,
                  color: rounds.textSecondary,
                ),
              )
            else if (!isPaid)
              Text(
                l10n.unpaid.toUpperCase(),
                style: AppTypography.eyebrow.copyWith(
                  fontSize: 10,
                  color: rounds.textFaint,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // The amount now trails the row on its own, so the subtitle carries the
  // remaining payment details only.
  String? _paidSubtitle(BillInstance instance, AppLocalizations l10n) {
    final parts = <String>[];
    if (instance.paidAt != null) {
      parts.add(l10n.formatShortDate(instance.paidAt!));
    }
    final method = PaymentMethod.fromString(instance.paymentMethod);
    if (method != null) {
      parts.add(_methodLabel(method, l10n));
    }
    if (instance.referenceNote != null &&
        instance.referenceNote!.isNotEmpty) {
      parts.add(instance.referenceNote!);
    }
    return parts.isEmpty ? null : parts.join(' · ');
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

