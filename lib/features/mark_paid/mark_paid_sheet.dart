import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/mark_paid/providers/mark_paid_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

class MarkPaidSheet extends ConsumerStatefulWidget {
  const MarkPaidSheet({super.key, required this.entry});

  final BillInstanceWithBill entry;

  @override
  ConsumerState<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<MarkPaidSheet> {
  late final TextEditingController _noteController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    final instance = widget.entry.instance;
    _noteController = TextEditingController(
      text: instance.referenceNote ?? '',
    );
    _amountController = TextEditingController(
      text: instance.amountPaid != null
          ? instance.amountPaid!.toStringAsFixed(2)
          : '',
    );

    if (instance.isPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final notifier = ref.read(markPaidProvider(instance.id).notifier);
        if (instance.paidAt != null) notifier.setDate(instance.paidAt!);
        notifier.setPaymentMethod(
            PaymentMethod.fromString(instance.paymentMethod));
        notifier.setReferenceNote(instance.referenceNote ?? '');
        if (instance.amountPaid != null) {
          notifier.setAmountPaid(instance.amountPaid);
        }
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instance = widget.entry.instance;
    final bill = widget.entry.bill;
    final state = ref.watch(markPaidProvider(instance.id));
    final notifier = ref.read(markPaidProvider(instance.id).notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header row: bill name + close button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        bill.name,
                        style: theme.textTheme.headlineMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Subtitle
                Text(
                  instance.isPaid
                      ? l10n.updatePaymentSubtitle
                      : l10n.markAsPaidSubtitle,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),

                // Date paid
                _FieldLabel(label: l10n.datePaidLabel),
                const SizedBox(height: 6),
                _DatePickerField(
                  date: state.paidAt,
                  onChanged: notifier.setDate,
                ),
                const SizedBox(height: 16),

                // Amount paid (optional)
                _FieldLabel(label: l10n.amountPaidLabel),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    hintText: l10n.amountPaidHint,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    notifier.setAmountPaid(parsed);
                  },
                ),
                const SizedBox(height: 16),

                // Payment method
                _FieldLabel(label: l10n.paymentMethodLabel),
                const SizedBox(height: 6),
                _PaymentMethodSelector(
                  selected: state.paymentMethod,
                  onChanged: notifier.setPaymentMethod,
                ),
                const SizedBox(height: 16),

                // Reference note
                _FieldLabel(label: l10n.referenceLabel),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  onChanged: notifier.setReferenceNote,
                  decoration: InputDecoration(
                    hintText: l10n.referenceHint,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),

                // Error message
                if (state.errorMessage != null) ...[
                  Text(
                    state.errorMessage!,
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],

                // Primary action button
                FilledButton.icon(
                  onPressed: state.isSubmitting
                      ? null
                      : () async {
                          final success = await notifier.submit();
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  icon: state.isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    instance.isPaid
                        ? l10n.updatePaymentButton
                        : l10n.confirmPaymentButton,
                  ),
                ),

                // Undo button
                if (instance.isPaid) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () async {
                            final confirmed = await _confirmUndo(context);
                            if (confirmed && context.mounted) {
                              final success = await notifier.undoPaid();
                              if (success && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          },
                    child: Text(l10n.undoPaymentButton),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmUndo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.undoPaymentDialogTitle),
        content: Text(l10n.undoPaymentDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.undo),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
            letterSpacing: 1.0,
          ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onChanged});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 31)),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF141F30)
              : const Color(0xFFE4EDF6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.formatShortDate(date),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  final PaymentMethod? selected;
  final ValueChanged<PaymentMethod?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((method) {
        final isSelected = method == selected;
        return FilterChip(
          label: Text(_methodLabel(method, l10n)),
          selected: isSelected,
          onSelected: (val) => onChanged(val ? method : null),
          showCheckmark: false,
        );
      }).toList(),
    );
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
