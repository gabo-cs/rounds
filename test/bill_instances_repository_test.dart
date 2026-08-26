import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/data/repositories/bills_repository.dart';

void main() {
  late AppDatabase db;
  late BillsRepository billsRepo;
  late BillInstancesRepository instancesRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    billsRepo = BillsRepository(db);
    instancesRepo = BillInstancesRepository(db);
  });

  tearDown(() => db.close());

  Future<int> createBill(String name, {int dueDay = 10}) =>
      billsRepo.createBill(name: name, dueDayOfMonth: dueDay);

  Future<BillInstance> instanceFor(int billId, int year, int month) async {
    final bills = await instancesRepo.getAllBills();
    await instancesRepo.ensureInstancesExist(bills, year, month);
    return (await instancesRepo.getAllInstances()).firstWhere(
      (i) => i.billId == billId && i.year == year && i.month == month,
    );
  }

  group('ensureInstancesExist', () {
    // The gap an import leaves behind: a backup ending in May, restored in
    // August, has no rows for June or July and nothing that would ever
    // generate them — generation only runs from the current month forward.
    // The Round screen offers to build such a month, which is this call.
    test('builds a past month, leaving what was recorded untouched', () async {
      final rentId = await createBill('Rent', dueDay: 1);
      final schoolId = await createBill('School fees', dueDay: 10);
      final may = await instanceFor(rentId, 2026, 5);
      await instancesRepo.markPaid(
        instanceId: may.id,
        paidAt: DateTime(2026, 5, 2),
      );

      await instancesRepo.ensureInstancesExist(
        await instancesRepo.getAllBills(),
        2026,
        6,
      );

      final all = await instancesRepo.getAllInstances();
      final june = all.where((i) => i.year == 2026 && i.month == 6);
      expect(june.map((i) => i.billId), unorderedEquals([rentId, schoolId]));
      expect(june.every((i) => !i.isPaid), isTrue);
      expect(all.firstWhere((i) => i.id == may.id).isPaid, isTrue);
    });

    test('adds only the bills a month is missing', () async {
      final rentId = await createBill('Rent');
      await instanceFor(rentId, 2026, 6);
      final schoolId = await createBill('School fees');

      await instancesRepo.ensureInstancesExist(
        await instancesRepo.getAllBills(),
        2026,
        6,
      );
      // Twice: the button is tappable again while the stream catches up.
      await instancesRepo.ensureInstancesExist(
        await instancesRepo.getAllBills(),
        2026,
        6,
      );

      final june = (await instancesRepo.getAllInstances())
          .where((i) => i.year == 2026 && i.month == 6)
          .toList();
      expect(june.map((i) => i.billId), unorderedEquals([rentId, schoolId]));
    });
  });

  group('markManyPaid', () {
    test('settles every listed instance in one batch', () async {
      final rentId = await createBill('Rent', dueDay: 1);
      final schoolId = await createBill('School fees', dueDay: 10);
      final rent = await instanceFor(rentId, 2026, 6);
      final school = await instanceFor(schoolId, 2026, 6);

      await instancesRepo.markManyPaid({
        rent.id: DateTime(2026, 6, 1),
        school.id: DateTime(2026, 6, 10),
      });

      final all = await instancesRepo.getAllInstances();
      expect(
        all.firstWhere((i) => i.id == rent.id).paidAt,
        DateTime(2026, 6, 1),
      );
      expect(
        all.firstWhere((i) => i.id == school.id).paidAt,
        DateTime(2026, 6, 10),
      );
      expect(all.every((i) => i.isPaid), isTrue);
    });

    test('leaves an already-paid instance exactly as it was', () async {
      final billId = await createBill('Rent', dueDay: 1);
      final june = await instanceFor(billId, 2026, 6);
      await instancesRepo.markPaid(
        instanceId: june.id,
        paidAt: DateTime(2026, 6, 3),
        referenceNote: 'cash',
        amountPaid: 1200,
      );

      await instancesRepo.markManyPaid({june.id: DateTime(2026, 6, 1)});

      final after = (await instancesRepo.getAllInstances()).firstWhere(
        (i) => i.id == june.id,
      );
      expect(after.paidAt, DateTime(2026, 6, 3));
      expect(after.referenceNote, 'cash');
      expect(after.amountPaid, 1200);
    });

    test('is a no-op for an empty round', () async {
      await instancesRepo.markManyPaid({});

      expect(await instancesRepo.getAllInstances(), isEmpty);
    });
  });

  group('getUnpaidInstancesForMonth', () {
    test('returns only that month, unpaid, non-archived', () async {
      final billId = await createBill('Internet');
      final archivedId = await createBill('Old Gym');
      final june = await instanceFor(billId, 2026, 6);
      await instanceFor(billId, 2026, 5);
      await instanceFor(billId, 2026, 7);
      final archivedJune = await instanceFor(archivedId, 2026, 6);
      await billsRepo.archiveBill(archivedId);

      final result = await instancesRepo.getUnpaidInstancesForMonth(2026, 6);

      expect(result.map((e) => e.instance.id), [june.id]);
      expect(
        result.map((e) => e.instance.id),
        isNot(contains(archivedJune.id)),
      );
    });

    test('excludes paid instances', () async {
      final billId = await createBill('Water');
      final june = await instanceFor(billId, 2026, 6);
      await instancesRepo.markPaid(
        instanceId: june.id,
        paidAt: DateTime(2026, 7, 1),
      );

      expect(await instancesRepo.getUnpaidInstancesForMonth(2026, 6), isEmpty);
    });
  });

  group('getUnpaidInstancesBefore', () {
    test(
      'returns only unpaid instances from strictly earlier months',
      () async {
        final billId = await createBill('Internet');
        final may = await instanceFor(billId, 2026, 5);
        final june = await instanceFor(billId, 2026, 6);
        final july = await instanceFor(billId, 2026, 7);

        final lingering = await instancesRepo.getUnpaidInstancesBefore(2026, 7);

        final ids = lingering.map((e) => e.instance.id).toList();
        expect(ids, containsAll([may.id, june.id]));
        expect(
          ids,
          isNot(contains(july.id)),
          reason: 'the current month is handled by the sliding window',
        );
      },
    );

    test('year boundary: December counts as before January', () async {
      final billId = await createBill('Rent');
      final december = await instanceFor(billId, 2025, 12);

      final lingering = await instancesRepo.getUnpaidInstancesBefore(2026, 1);

      expect(lingering.map((e) => e.instance.id), contains(december.id));
    });

    test('excludes paid instances', () async {
      final billId = await createBill('Water');
      final june = await instanceFor(billId, 2026, 6);
      await instancesRepo.markPaid(
        instanceId: june.id,
        paidAt: DateTime(2026, 7, 1),
      );

      final lingering = await instancesRepo.getUnpaidInstancesBefore(2026, 7);

      expect(lingering, isEmpty);
    });

    test('excludes instances of archived bills', () async {
      final billId = await createBill('Old Gym');
      await instanceFor(billId, 2026, 6);
      await billsRepo.archiveBill(billId);

      final lingering = await instancesRepo.getUnpaidInstancesBefore(2026, 7);

      expect(lingering, isEmpty);
    });
  });

  group('getInstanceIdsForBill', () {
    test('returns all instance IDs for the bill and only that bill', () async {
      final targetId = await createBill('Internet');
      final otherId = await createBill('Rent');
      final june = await instanceFor(targetId, 2026, 6);
      final july = await instanceFor(targetId, 2026, 7);
      final otherJune = await instanceFor(otherId, 2026, 6);

      final ids = await instancesRepo.getInstanceIdsForBill(targetId);

      expect(ids, unorderedEquals([june.id, july.id]));
      expect(ids, isNot(contains(otherJune.id)));
    });

    test('returns an empty list for a bill without instances', () async {
      final billId = await createBill('Brand New');
      expect(await instancesRepo.getInstanceIdsForBill(billId), isEmpty);
    });
  });

  group('watchInstancesForMonth', () {
    test('unpaid by due day first, then paid newest-settled first', () async {
      final rentId = await createBill('Rent', dueDay: 1);
      final waterId = await createBill('Water', dueDay: 5);
      final powerId = await createBill('Power', dueDay: 20);
      final phoneId = await createBill('Phone', dueDay: 25);

      final water = await instanceFor(waterId, 2026, 6);
      final phone = await instanceFor(phoneId, 2026, 6);
      // Settled out of due-day order: the phone bill, due last, was paid first.
      await instancesRepo.markPaid(
        instanceId: phone.id,
        paidAt: DateTime(2026, 6, 3),
      );
      await instancesRepo.markPaid(
        instanceId: water.id,
        paidAt: DateTime(2026, 6, 6),
      );

      final rows = await instancesRepo.watchInstancesForMonth(2026, 6).first;

      expect(
        rows.map((r) => r.bill.id),
        [rentId, powerId, waterId, phoneId],
      );
    });
  });
}
