import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

class MarkPaidState {
  const MarkPaidState({
    required this.paidAt,
    this.paymentMethod,
    this.referenceNote = '',
    this.amountPaid,
    this.isSubmitting = false,
    this.errorMessage,
  });

  final DateTime paidAt;
  final PaymentMethod? paymentMethod;
  final String referenceNote;
  final double? amountPaid;
  final bool isSubmitting;
  final String? errorMessage;

  MarkPaidState copyWith({
    DateTime? paidAt,
    PaymentMethod? paymentMethod,
    bool clearPaymentMethod = false,
    String? referenceNote,
    double? amountPaid,
    bool clearAmountPaid = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) =>
      MarkPaidState(
        paidAt: paidAt ?? this.paidAt,
        paymentMethod:
            clearPaymentMethod ? null : paymentMethod ?? this.paymentMethod,
        referenceNote: referenceNote ?? this.referenceNote,
        amountPaid: clearAmountPaid ? null : amountPaid ?? this.amountPaid,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class MarkPaidNotifier extends StateNotifier<MarkPaidState> {
  MarkPaidNotifier(this._repo, this._instanceId)
      : super(MarkPaidState(paidAt: DateTime.now()));

  final BillInstancesRepository _repo;
  final int _instanceId;

  void setDate(DateTime date) => state = state.copyWith(paidAt: date);

  void setPaymentMethod(PaymentMethod? method) =>
      state = state.copyWith(paymentMethod: method);

  void setReferenceNote(String note) =>
      state = state.copyWith(referenceNote: note);

  void setAmountPaid(double? amount) => state = amount == null
      ? state.copyWith(clearAmountPaid: true)
      : state.copyWith(amountPaid: amount);

  Future<bool> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.markPaid(
        instanceId: _instanceId,
        paidAt: state.paidAt,
        paymentMethod: state.paymentMethod,
        referenceNote:
            state.referenceNote.trim().isEmpty ? null : state.referenceNote.trim(),
        amountPaid: state.amountPaid,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to save. Please try again.',
      );
      return false;
    }
  }

  Future<bool> undoPaid() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      await _repo.unmarkPaid(_instanceId);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to undo. Please try again.',
      );
      return false;
    }
  }
}

final markPaidProvider = StateNotifierProvider.family
    .autoDispose<MarkPaidNotifier, MarkPaidState, int>((ref, instanceId) {
  return MarkPaidNotifier(
    ref.watch(billInstancesRepositoryProvider),
    instanceId,
  );
});
