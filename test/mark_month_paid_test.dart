import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/currency.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/data/repositories/bills_repository.dart';
import 'package:rounds/features/round/providers/mark_month_paid_providers.dart';

/// Records what would have been sent to the platform.
class _FakeNotifications implements NotificationService {
  final cancelled = <int>[];
  final applied = <ReminderPlan>[];

  @override
  Future<void> cancelForInstances(Iterable<int> instanceIds) async =>
      cancelled.addAll(instanceIds);

  @override
  Future<void> applyReminderPlans(Iterable<ReminderPlan> plans) async =>
      applied.addAll(plans);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

    test('records today when paying a future round ahead', () {
      // Its due date hasn't come yet; recording it would date the payment in
      // the future.
      final now = DateTime(2026, 11, 7, 9);

      expect(bulkPaidAt(entry(year: 2026, month: 12, dueDay: 10), now), now);
    });

    test('a January round settled in December is ahead, not past', () {
      final now = DateTime(2026, 12, 30);

      expect(bulkPaidAt(entry(year: 2027, month: 1, dueDay: 5), now), now);
    });

    test('records today for a bill not yet due this month', () {
      // Settling the current round early is a real payday gesture, and the
      // payment happened today whatever the due day says.
      final now = DateTime(2026, 8, 18);

      expect(bulkPaidAt(entry(year: 2026, month: 8, dueDay: 28), now), now);
    });
  });

  group('undoing a bulk settle', () {
    late AppDatabase db;
    late BillsRepository billsRepo;
    late BillInstancesRepository instancesRepo;
    late _FakeNotifications notifications;

    setUpAll(() => initializeDateFormatting());

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      billsRepo = BillsRepository(db);
      instancesRepo = BillInstancesRepository(db);
      notifications = _FakeNotifications();
    });

    tearDown(() => db.close());

    MarkMonthPaidNotifier notifier({bool notificationsEnabled = true}) =>
        MarkMonthPaidNotifier(
          instancesRepo,
          notifications,
          languageCode: 'en',
          notificationsEnabled: notificationsEnabled,
          currency: Currency.cop,
        );

    Future<List<BillInstanceWithBill>> novemberRound() async {
      await billsRepo.createBill(name: 'Rent', dueDayOfMonth: 1);
      await billsRepo.createBill(name: 'Internet', dueDayOfMonth: 20);
      await instancesRepo.ensureInstancesExist(
        await instancesRepo.getAllBills(),
        2026,
        11,
      );
      return instancesRepo.watchInstancesForMonth(2026, 11).first;
    }

    test('puts the round back to unpaid and re-arms it', () async {
      final now = DateTime(2026, 11, 7, 10);
      final round = await novemberRound();
      final sut = notifier();

      final settled = await sut.settle(round, now: now);
      expect(await sut.unsettle(settled!, now: now), isTrue);

      final after = await instancesRepo.getAllInstances();
      expect(after.every((i) => !i.isPaid && i.paidAt == null), isTrue);
      final armedIds = {
        for (final plan in notifications.applied)
          for (final n in plan.arm) n.id ~/ 10,
      };
      expect(
        armedIds,
        unorderedEquals(round.map((e) => e.instance.id)),
        reason: 'the overdue Rent and the upcoming Internet both re-arm',
      );
    });

    test('leaves a bill settled again in the meantime alone', () async {
      final now = DateTime(2026, 11, 7, 10);
      final round = await novemberRound();
      final sut = notifier();
      final settled = await sut.settle(round, now: now);
      final rent = round.firstWhere((e) => e.bill.name == 'Rent');
      await instancesRepo.markPaid(
        instanceId: rent.instance.id,
        paidAt: DateTime(2026, 11, 2),
        referenceNote: 'bank transfer',
      );

      await sut.unsettle(settled!, now: now);

      final after = await instancesRepo.getAllInstances();
      final rentAfter = after.firstWhere((i) => i.id == rent.instance.id);
      expect(rentAfter.isPaid, isTrue);
      expect(rentAfter.referenceNote, 'bank transfer');
      expect(after.where((i) => !i.isPaid), hasLength(1));
    });

    test('arms nothing when notifications are off', () async {
      final now = DateTime(2026, 11, 7, 10);
      final sut = notifier(notificationsEnabled: false);
      final settled = await sut.settle(await novemberRound(), now: now);

      await sut.unsettle(settled!, now: now);

      expect(notifications.applied, isEmpty);
    });

    test('still works after the month page is disposed', () async {
      final now = DateTime(2026, 11, 7, 10);
      final sut = notifier();
      final settled = await sut.settle(await novemberRound(), now: now);
      sut.dispose();

      expect(await sut.unsettle(settled!, now: now), isTrue);
    });
  });
}
