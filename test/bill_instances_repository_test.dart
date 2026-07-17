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
      expect(result.map((e) => e.instance.id), isNot(contains(archivedJune.id)));
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
    test('returns only unpaid instances from strictly earlier months',
        () async {
      final billId = await createBill('Internet');
      final may = await instanceFor(billId, 2026, 5);
      final june = await instanceFor(billId, 2026, 6);
      final july = await instanceFor(billId, 2026, 7);

      final lingering = await instancesRepo.getUnpaidInstancesBefore(2026, 7);

      final ids = lingering.map((e) => e.instance.id).toList();
      expect(ids, containsAll([may.id, june.id]));
      expect(ids, isNot(contains(july.id)),
          reason: 'the current month is handled by the sliding window');
    });

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
}
