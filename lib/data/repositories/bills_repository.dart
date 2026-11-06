import 'package:drift/drift.dart';
import 'package:rounds/data/database/app_database.dart';

class BillsRepository {
  BillsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Bill>> watchAllActiveBills() {
    return (_db.select(_db.bills)
          ..where((b) => b.isArchived.equals(false))
          ..orderBy([(b) => OrderingTerm.asc(b.dueDayOfMonth)]))
        .watch();
  }

  Stream<List<Bill>> watchAllBills() {
    return (_db.select(_db.bills)
          ..orderBy([(b) => OrderingTerm.asc(b.dueDayOfMonth)]))
        .watch();
  }

  Stream<Bill?> watchBillById(int id) {
    return (_db.select(_db.bills)..where((b) => b.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<Bill> getBillById(int id) {
    return (_db.select(_db.bills)..where((b) => b.id.equals(id))).getSingle();
  }

  Future<int> createBill({
    required String name,
    double? amount,
    required int dueDayOfMonth,
    String? category,
    String? notes,
  }) {
    final now = DateTime.now();
    return _db.into(_db.bills).insert(
          BillsCompanion.insert(
            name: name,
            amount: Value(amount),
            dueDayOfMonth: dueDayOfMonth,
            category: Value(category),
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> updateBill({
    required int id,
    required String name,
    double? amount,
    required int dueDayOfMonth,
    String? category,
    String? notes,
  }) {
    return (_db.update(_db.bills)..where((b) => b.id.equals(id))).write(
      BillsCompanion(
        name: Value(name),
        amount: Value(amount),
        dueDayOfMonth: Value(dueDayOfMonth),
        category: Value(category),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Archive [id] and drop its unpaid instances in the months after this one.
  /// Returns the IDs of the dropped instances, whose reminders the caller
  /// must cancel.
  ///
  /// Instances are pre-generated a year ahead, so flipping the flag alone
  /// would leave the bill sitting in every upcoming month. The current month
  /// stays — it may still be owed, and keeps its reminders until it is paid —
  /// and so do paid rows and past months; unarchiving regenerates the rest
  /// lazily.
  Future<List<int>> archiveBill(int id, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return _db.transaction(() async {
      await (_db.update(_db.bills)..where((b) => b.id.equals(id))).write(
        BillsCompanion(
          isArchived: const Value(true),
          updatedAt: Value(today),
        ),
      );
      Expression<bool> upcomingUnpaid($BillInstancesTable i) =>
          i.billId.equals(id) &
          i.isPaid.equals(false) &
          (i.year.isBiggerThanValue(today.year) |
              (i.year.equals(today.year) &
                  i.month.isBiggerThanValue(today.month)));
      final dropped = await (_db.select(_db.billInstances)
            ..where(upcomingUnpaid))
          .get();
      await (_db.delete(_db.billInstances)..where(upcomingUnpaid)).go();
      return [for (final instance in dropped) instance.id];
    });
  }

  Future<void> unarchiveBill(int id) {
    return (_db.update(_db.bills)..where((b) => b.id.equals(id))).write(
      BillsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteBill(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.billInstances)
            ..where((i) => i.billId.equals(id)))
          .go();
      await (_db.delete(_db.bills)..where((b) => b.id.equals(id))).go();
    });
  }
}
