import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/round/providers/mark_month_paid_providers.dart';

void main() {
  final epoch = DateTime(2026, 1, 1);

  BillInstanceWithBill entry({
    required int year,
    required int month,
    required int dueDay,
  }) => (
    instance: BillInstance(
      id: 1,
      billId: 1,
      year: year,
      month: month,
      isPaid: false,
      createdAt: epoch,
      updatedAt: epoch,
    ),
    bill: Bill(
      id: 1,
      name: 'Rent',
      dueDayOfMonth: dueDay,
      isArchived: false,
      createdAt: epoch,
      updatedAt: epoch,
    ),
  );

  group('bulkPaidAt', () {
    test('records today when settling the round we are living in', () {
      final now = DateTime(2026, 8, 18, 14, 30);

      expect(bulkPaidAt(entry(year: 2026, month: 8, dueDay: 1), now), now);
    });

    test('records the due date when the round is already past', () {
      // A June bill settled in August was not paid in August — dating it so
      // would drop the payment outside the round it belongs to.
      final paidAt = bulkPaidAt(
        entry(year: 2026, month: 6, dueDay: 5),
        DateTime(2026, 8, 18),
      );

      expect(paidAt, DateTime(2026, 6, 5));
    });

    test('handles a past round in a previous year', () {
      final paidAt = bulkPaidAt(
        entry(year: 2025, month: 12, dueDay: 28),
        DateTime(2026, 1, 3),
      );

      expect(paidAt, DateTime(2025, 12, 28));
    });

    test('a same-month-different-year round counts as past', () {
      final paidAt = bulkPaidAt(
        entry(year: 2025, month: 8, dueDay: 10),
        DateTime(2026, 8, 18),
      );

      expect(paidAt, DateTime(2025, 8, 10));
    });

    test('records today for a bill not yet due this month', () {
      // Settling the current round early is a real payday gesture, and the
      // payment happened today whatever the due day says.
      final now = DateTime(2026, 8, 18);

      expect(bulkPaidAt(entry(year: 2026, month: 8, dueDay: 28), now), now);
    });
  });
}
