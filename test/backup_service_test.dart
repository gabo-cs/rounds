import 'dart:convert';
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

    test('a realistic dataset survives export → import → re-export unchanged',
        () async {
      // Shaped like a real device: a dozen-plus bills, accented names, an
      // archived bill, a custom category, COP-sized amounts, and notes with
      // quotes and newlines, across three months of history.
      for (var i = 0; i < 12; i++) {
        await billsRepo.createBill(
          name: 'Factura $i',
          amount: i.isEven ? 699300.0 + i : null,
          dueDayOfMonth: (i % 28) + 1,
          category: i % 3 == 0 ? 'Utilities' : null,
        );
      }
      await billsRepo.createBill(
        name: 'Teléfono Móvil',
        amount: 1234567.89,
        dueDayOfMonth: 28,
        category: 'Mi Categoría',
        notes: 'Pagué con "PSE"\nsegunda línea',
      );
      final archivedId = await billsRepo.createBill(
        name: 'Gimnasio Viejo',
        dueDayOfMonth: 3,
      );
      await billsRepo.archiveBill(archivedId);

      final active = (await instancesRepo.getAllBills())
          .where((b) => !b.isArchived)
          .toList();
      for (final month in [5, 6, 7]) {
        await instancesRepo.ensureInstancesExist(active, 2026, month);
      }
      final instances = await instancesRepo.getAllInstances();
      for (final (i, instance) in instances.indexed) {
        if (i.isOdd) continue;
        await instancesRepo.markPaid(
          instanceId: instance.id,
          paidAt: DateTime(2026, instance.month, 3),
          paymentMethod: i % 4 == 0 ? PaymentMethod.bankTransfer : null,
          referenceNote: i % 6 == 0 ? 'ref "áéí" #$i' : null,
          amountPaid: i % 4 == 0 ? 150000.5 : null,
        );
      }

      final exported = await service.buildBackupJson();

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      final repo2 = BillInstancesRepository(db2);
      final error = await BackupService(repo2)
          .importFromFile(await writeTempJson(exported));
      expect(error, isNull);

      // The strongest fidelity statement available: what the imported
      // database exports is exactly what went in, field for field.
      final reExported = await BackupService(repo2).buildBackupJson();
      final a = jsonDecode(exported) as Map<String, dynamic>;
      final b = jsonDecode(reExported) as Map<String, dynamic>;
      List<dynamic> sortedById(dynamic rows) => (rows as List<dynamic>)
        ..sort((x, y) => (x['id'] as int).compareTo(y['id'] as int));
      expect(sortedById(b['bills']), sortedById(a['bills']));
      expect(sortedById(b['billInstances']), sortedById(a['billInstances']));

      expect(a['bills'] as List<dynamic>, hasLength(14));
      expect(
        (a['billInstances'] as List<dynamic>).length,
        greaterThanOrEqualTo(36),
      );
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

    test('a backup referencing a missing bill rolls back completely', () async {
      // The scary case: parseable JSON that fails *inside* the replace
      // transaction, after the delete-everything step. The FK violation must
      // abort the whole transaction, not leave a half-wiped database.
      await billsRepo.createBill(name: 'Keep Me', dueDayOfMonth: 3);
      const json = '{"version": 1, "bills": [], "billInstances": ['
          '{"id": 1, "billId": 99, "year": 2026, "month": 7, "isPaid": false, '
          '"paidAt": null, "paymentMethod": null, "amountPaid": null, '
          '"referenceNote": null, "createdAt": "2026-01-01T00:00:00.000Z", '
          '"updatedAt": "2026-01-01T00:00:00.000Z"}]}';

      final error = await service.importFromFile(await writeTempJson(json));

      expect(error, isNotNull);
      final bills = await instancesRepo.getAllBills();
      expect(bills.single.name, 'Keep Me',
          reason: 'the in-transaction wipe must have rolled back');
      expect(await instancesRepo.getAllInstances(), isEmpty,
          reason: 'the orphan instance must not have been kept');
    });

    test('a v1 backup written by an older build still imports', () async {
      // Frozen fixture — never regenerate it from current code. Its whole
      // point is to catch the exporter drifting away from what backups
      // already sitting in people's storage look like.
      const fixture = '''
{
  "version": 1,
  "exportedAt": "2026-01-15T14:30:00.000Z",
  "bills": [
    {"id": 7, "name": "Rent", "amount": 1200000.0, "dueDayOfMonth": 5,
     "category": "Housing", "notes": null, "isArchived": false,
     "createdAt": "2025-11-01T12:00:00.000Z",
     "updatedAt": "2025-11-01T12:00:00.000Z"}
  ],
  "billInstances": [
    {"id": 41, "billId": 7, "year": 2026, "month": 1, "isPaid": true,
     "paidAt": "2026-01-05T09:00:00.000Z", "paymentMethod": "bankTransfer",
     "amountPaid": 1200000.0, "referenceNote": "TX-991",
     "createdAt": "2026-01-01T00:00:00.000Z",
     "updatedAt": "2026-01-05T09:00:00.000Z"}
  ]
}''';

      final error = await service.importFromFile(await writeTempJson(fixture));

      expect(error, isNull);
      final bill = (await instancesRepo.getAllBills()).single;
      expect(bill.id, 7);
      expect(bill.name, 'Rent');
      expect(bill.amount, 1200000.0);
      final instance = (await instancesRepo.getAllInstances()).single;
      expect(instance.id, 41);
      expect(instance.isPaid, isTrue);
      expect(instance.paymentMethod, 'bankTransfer');
      expect(instance.referenceNote, 'TX-991');
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
