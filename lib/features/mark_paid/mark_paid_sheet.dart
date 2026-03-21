import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:rounds/core/extensions/currency_extensions.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/mark_paid/providers/mark_paid_providers.dart';

class MarkPaidSheet extends ConsumerStatefulWidget {
  const MarkPaidSheet({super.key, required this.entry});

  final BillInstanceWithBill entry;

  @override
  ConsumerState<MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<MarkPaidSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final instance = widget.entry.instance;
    _noteController = TextEditingController(
      text: instance.referenceNote ?? '',
    );

    // If already paid, pre-populate the form state from the instance
    if (instance.isPaid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier =
            ref.read(markPaidProvider(instance.id).notifier);
        if (instance.paidAt != null) notifier.setDate(instance.paidAt!);
        final method = PaymentMethod.fromString(instance.paymentMethod);
        notifier.setPaymentMethod(method);
        notifier.setReferenceNote(instance.referenceNote ?? '');
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
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

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Bill name + amount header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bill.name,
                            style: theme.textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            instance.isPaid
                                ? 'Update payment details'
                                : 'Mark as paid',
                            style: theme.textTheme.bodyMedium!.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      bill.amount.asCurrency,
                      style: theme.textTheme.headlineSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date paid
                _FieldLabel(label: 'Date paid'),
                const SizedBox(height: 6),
                _DatePickerField(
                  date: state.paidAt,
                  onChanged: notifier.setDate,
                ),
                const SizedBox(height: 16),

                // Payment method
                _FieldLabel(label: 'Payment method'),
                const SizedBox(height: 6),
                _PaymentMethodSelector(
                  selected: state.paymentMethod,
                  onChanged: notifier.setPaymentMethod,
                ),
                const SizedBox(height: 16),

                // Reference note
                _FieldLabel(label: 'Reference / note (optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  onChanged: notifier.setReferenceNote,
                  decoration: const InputDecoration(
                    hintText: 'Transaction ID, confirmation #, etc.',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () async {
                          final success = await notifier.submit();
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: state.isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          instance.isPaid ? 'Update Payment' : 'Mark as Paid',
                        ),
                ),

                // Undo button (only for already-paid instances)
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
                    child: const Text('Undo Payment'),
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
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Undo payment?'),
        content: const Text(
          'This will mark the bill as unpaid and remove payment details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Undo'),
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
      label,
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
    return InkWell(
      borderRadius: BorderRadius.circular(10),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
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
              DateFormat.yMMMd().format(date),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PaymentMethod.values.map((method) {
        final isSelected = method == selected;
        return FilterChip(
          label: Text(method.label),
          selected: isSelected,
          onSelected: (val) => onChanged(val ? method : null),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
