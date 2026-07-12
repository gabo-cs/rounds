import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/payment_method.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/data/repositories/bills_repository.dart';

void main() {
  late AppDatabase db;
  late BillsRepository billsRepo;
  late BillInstancesRepository instancesRepo;
  late BackupService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    billsRepo = BillsRepository(db);
    instancesRepo = BillInstancesRepository(db);
    service = BackupService(instancesRepo);
  });

  tearDown(() => db.close());

  Future<String> writeTempJson(String content) async {
    final dir = await Directory.systemTemp.createTemp('rounds_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/backup.json');
    await file.writeAsString(content);
    return file.path;
  }

  group('export → import round-trip', () {
    test('restores all data and preserves IDs', () async {
      final internetId = await billsRepo.createBill(
        name: 'Internet',
        amount: 49.99,
        dueDayOfMonth: 15,
        category: 'Utilities',
        notes: 'Fiber plan',
      );
      final powerId = await billsRepo.createBill(
        name: 'Electricity',
        dueDayOfMonth: 5,
      );
      final bills = await instancesRepo.getAllBills();
      await instancesRepo.ensureInstancesExist(bills, 2026, 7);
      final instance = (await instancesRepo.getAllInstances())
          .firstWhere((i) => i.billId == internetId);
      await instancesRepo.markPaid(
        instanceId: instance.id,
        paidAt: DateTime(2026, 7, 10),
        paymentMethod: PaymentMethod.card,
        referenceNote: 'ref-123',
        amountPaid: 50.25,
      );

      final json = await service.buildBackupJson();

      // Import into a fresh database.
      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final repo2 = BillInstancesRepository(db2);
      final error =
          await BackupService(repo2).importFromFile(await writeTempJson(json));
      expect(error, isNull);

      final importedBills = await repo2.getAllBills();
      expect(importedBills, hasLength(2));

      final internet = importedBills.singleWhere((b) => b.id == internetId);
      expect(internet.name, 'Internet');
      expect(internet.amount, 49.99);
      expect(internet.dueDayOfMonth, 15);
      expect(internet.category, 'Utilities');
      expect(internet.notes, 'Fiber plan');
      expect(internet.isArchived, isFalse);

      final power = importedBills.singleWhere((b) => b.id == powerId);
      expect(power.amount, isNull, reason: 'nullable amount must survive');

      final importedInstances = await repo2.getAllInstances();
      expect(importedInstances, hasLength(2));

      final paid = importedInstances.singleWhere((i) => i.id == instance.id);
      expect(paid.isPaid, isTrue);
      expect(paid.paidAt!.isAtSameMomentAs(DateTime(2026, 7, 10)), isTrue);
      expect(paid.paymentMethod, 'card');
      expect(paid.referenceNote, 'ref-123');
      expect(paid.amountPaid, 50.25);

      final unpaid = importedInstances.singleWhere((i) => i.billId == powerId);
      expect(unpaid.isPaid, isFalse);
      expect(unpaid.paidAt, isNull);
    });

    test('replaces existing data instead of merging', () async {
      await billsRepo.createBill(name: 'Old Bill', dueDayOfMonth: 1);
      final json = await service.buildBackupJson();

      // Mutate after export, then import the backup on top.
      await billsRepo.createBill(name: 'Added After Export', dueDayOfMonth: 2);
      final error = await service.importFromFile(await writeTempJson(json));

      expect(error, isNull);
      final bills = await instancesRepo.getAllBills();
      expect(bills, hasLength(1));
      expect(bills.single.name, 'Old Bill');
    });
  });

  group('import errors', () {
    test('non-JSON content → invalidFile', () async {
      final error =
          await service.importFromFile(await writeTempJson('not json'));
      expect(error, ImportError.invalidFile);
    });

    test('JSON that is not an object → invalidFile', () async {
      final error = await service.importFromFile(await writeTempJson('[1,2]'));
      expect(error, ImportError.invalidFile);
    });

    test('missing bills/billInstances keys → invalidFile', () async {
      final error =
          await service.importFromFile(await writeTempJson('{"version": 1}'));
      expect(error, ImportError.invalidFile);
    });

    test('wrongly-typed fields → invalidFile', () async {
      const json = '{"version": 1, "bills": [{"id": "not-an-int"}], '
          '"billInstances": []}';
      final error = await service.importFromFile(await writeTempJson(json));
      expect(error, ImportError.invalidFile);
    });

    test('newer backup version → unsupportedVersion', () async {
      const json = '{"version": 999, "bills": [], "billInstances": []}';
      final error = await service.importFromFile(await writeTempJson(json));
      expect(error, ImportError.unsupportedVersion);
    });

    test('nonexistent file → readFailed', () async {
      final error =
          await service.importFromFile('/nonexistent/rounds_backup.json');
      expect(error, ImportError.readFailed);
    });

    test('a failed import leaves existing data untouched', () async {
      await billsRepo.createBill(name: 'Keep Me', dueDayOfMonth: 3);
      final error =
          await service.importFromFile(await writeTempJson('not json'));
      expect(error, ImportError.invalidFile);
      final bills = await instancesRepo.getAllBills();
      expect(bills.single.name, 'Keep Me');
    });
  });
}
