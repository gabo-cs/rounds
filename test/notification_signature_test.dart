import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/home/providers/home_providers.dart';

void main() {
  final createdAt = DateTime(2026, 1, 1);

  BillInstanceWithBill entry({
    int id = 1,
    int billId = 1,
    bool isPaid = false,
    String name = 'Electricity',
    double? amount = 42.50,
    int dueDay = 16,
    bool isArchived = false,
  }) =>
      (
        instance: BillInstance(
          id: id,
          billId: billId,
          year: 2026,
          month: 7,
          isPaid: isPaid,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        bill: Bill(
          id: billId,
          name: name,
          amount: amount,
          dueDayOfMonth: dueDay,
          isArchived: isArchived,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  group('monthNotificationSignature', () {
    test('is identical across calls with the same inputs', () {
      final a = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [entry(), entry(id: 2, billId: 2, name: 'Rent')],
      );
      final b = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [entry(), entry(id: 2, billId: 2, name: 'Rent')],
      );

      expect(a, b);
    });

    test('does not depend on instance ordering', () {
      final first = entry();
      final second = entry(id: 2, billId: 2, name: 'Rent');
      final a = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [first, second],
      );
      final b = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [second, first],
      );

      expect(a, b);
    });

    test('changes when a reminder-relevant field changes', () {
      final base = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [entry()],
      );

      final variants = [
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'en',
          instances: [entry(isPaid: true)],
        ),
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'en',
          instances: [entry(name: 'Water')],
        ),
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'en',
          instances: [entry(amount: 99.99)],
        ),
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'en',
          instances: [entry(dueDay: 20)],
        ),
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'en',
          instances: [entry(isArchived: true)],
        ),
        monthNotificationSignature(
          today: DateTime(2026, 7, 19),
          languageCode: 'es',
          instances: [entry()],
        ),
      ];

      for (final variant in variants) {
        expect(variant, isNot(base));
      }
    });

    test('changes when the day changes, so each day re-arms once', () {
      final saturday = monthNotificationSignature(
        today: DateTime(2026, 7, 18),
        languageCode: 'en',
        instances: [entry()],
      );
      final sunday = monthNotificationSignature(
        today: DateTime(2026, 7, 19),
        languageCode: 'en',
        instances: [entry()],
      );

      expect(sunday, isNot(saturday));
    });

    test('ignores time of day, so same-day relaunches can skip', () {
      final morning = monthNotificationSignature(
        today: DateTime(2026, 7, 19, 8, 55),
        languageCode: 'en',
        instances: [entry()],
      );
      final evening = monthNotificationSignature(
        today: DateTime(2026, 7, 19, 22, 10),
        languageCode: 'en',
        instances: [entry()],
      );

      expect(morning, evening);
    });
  });
}
