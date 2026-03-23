import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/constants/app_constants.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/features/bills/providers/bills_providers.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key, this.billId});

  final int? billId;

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  int _dueDayOfMonth = 1;
  String? _selectedCategory;
  bool _isCustomCategory = false;
  final _customCategoryController = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.billId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _populateFromBill(Bill bill) {
    _nameController.text = bill.name;
    _amountController.text =
        bill.amount != null ? bill.amount!.toStringAsFixed(2) : '';
    _notesController.text = bill.notes ?? '';
    _dueDayOfMonth = bill.dueDayOfMonth;

    final category = bill.category;
    if (category != null) {
      if (AppConstants.categories.contains(category)) {
        _selectedCategory = category;
      } else {
        _isCustomCategory = true;
        _customCategoryController.text = category;
      }
    }
  }

  Future<void> _save(Bill? existingBill) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final rawAmount = _amountController.text.trim();
    final amount = rawAmount.isEmpty
        ? null
        : double.tryParse(rawAmount.replaceAll(',', '.'));
    final notes =
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
    String? category;
    if (_isCustomCategory) {
      final custom = _customCategoryController.text.trim();
      if (custom.isNotEmpty) category = custom;
    } else {
      category = _selectedCategory;
    }

    try {
      final repo = ref.read(billsRepositoryProvider);
      if (_isEditing && existingBill != null) {
        await repo.updateBill(
          id: existingBill.id,
          name: name,
          amount: amount,
          dueDayOfMonth: _dueDayOfMonth,
          category: category,
          notes: notes,
        );
      } else {
        await repo.createBill(
          name: name,
          amount: amount,
          dueDayOfMonth: _dueDayOfMonth,
          category: category,
          notes: notes,
        );
        // Ensure new bill gets an instance in the current month
        final selected = ref.read(selectedMonthProvider);
        final instanceRepo = ref.read(billInstancesRepositoryProvider);
        final allActive =
            await repo.watchAllActiveBills().first;
        await instanceRepo.ensureInstancesExist(
          allActive,
          selected.year,
          selected.month,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToSave(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _archive(Bill bill) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.archiveBillDialogTitle),
        content: Text(l10n.archiveBillDialogContent(bill.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.archiveButton),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(billsRepositoryProvider).archiveBill(bill.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      final billAsync = ref.watch(billDetailProvider(widget.billId!));
      return billAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) =>
            Scaffold(body: Center(child: Text('Error: $e'))),
        data: (bill) {
          if (bill == null) {
            final l10n = AppLocalizations.of(context);
            return Scaffold(
                body: Center(child: Text(l10n.billNotFound)));
          }
          // Populate once
          if (_nameController.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _populateFromBill(bill));
            });
          }
          return _buildForm(bill);
        },
      );
    }
    return _buildForm(null);
  }

  Widget _buildForm(Bill? existingBill) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isArchived = existingBill?.isArchived ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editBillTitle : l10n.newBillTitle),
        actions: [
          if (_isEditing && existingBill != null)
            IconButton(
              icon: Icon(
                isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              tooltip: isArchived ? l10n.unarchive : l10n.archive,
              onPressed: () => isArchived
                  ? ref
                      .read(billsRepositoryProvider)
                      .unarchiveBill(existingBill.id)
                  : _archive(existingBill),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (isArchived)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined,
                        color: theme.colorScheme.onErrorContainer, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.thisArchivedBanner,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            _SectionLabel(label: l10n.billNameLabel),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.billNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.billNameRequired;
                if (v.trim().length > 120) return l10n.billNameTooLong;
                return null;
              },
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.amountLabel),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: l10n.amountHint,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return l10n.amountInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.dueDayLabel),
            const SizedBox(height: 6),
            _DueDayPicker(
              value: _dueDayOfMonth,
              onChanged: (day) => setState(() => _dueDayOfMonth = day),
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.categoryLabel),
            const SizedBox(height: 6),
            _CategoryPicker(
              selected: _isCustomCategory ? null : _selectedCategory,
              isCustom: _isCustomCategory,
              customController: _customCategoryController,
              onChanged: (category, isCustom) => setState(() {
                _selectedCategory = category;
                _isCustomCategory = isCustom;
              }),
            ),
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.notesLabel),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: l10n.notesHint,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed:
                  _isSaving ? null : () => _save(existingBill),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? l10n.saveChangesButton : l10n.addBillButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge!.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
    );
  }
}

class _DueDayPicker extends StatelessWidget {
  const _DueDayPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(),
      items: List.generate(
        AppConstants.maxDueDay,
        (i) => DropdownMenuItem(
          value: i + 1,
          child: Text(l10n.dueDayOption(i + 1)),
        ),
      ),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.selected,
    required this.isCustom,
    required this.customController,
    required this.onChanged,
  });

  final String? selected;
  final bool isCustom;
  final TextEditingController customController;
  final void Function(String? category, bool isCustom) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...AppConstants.categories.map((cat) {
              final isSelected = !isCustom && cat == selected;
              return FilterChip(
                label: Text(l10n.translateCategory(cat)),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (val) =>
                    onChanged(val ? cat : null, false),
              );
            }),
            FilterChip(
              label: Text(l10n.customCategoryChip),
              selected: isCustom,
              showCheckmark: false,
              onSelected: (val) => onChanged(null, val),
            ),
          ],
        ),
        if (isCustom) ...[
          const SizedBox(height: 8),
          TextField(
            controller: customController,
            decoration: InputDecoration(
              hintText: l10n.customCategoryHint,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ],
    );
  }
}
