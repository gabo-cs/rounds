enum PaymentMethod {
  cash,
  bankTransfer,
  card,
  autoDebit,
  other;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.bankTransfer => 'Bank Transfer',
        PaymentMethod.card => 'Card',
        PaymentMethod.autoDebit => 'Auto-debit',
        PaymentMethod.other => 'Other',
      };

  static PaymentMethod? fromString(String? value) {
    if (value == null) return null;
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.other,
    );
  }
}
