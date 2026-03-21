import 'package:drift/drift.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/payment_method.dart';

typedef BillInstanceWithBill = ({BillInstance instance, Bill bill});

class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month,
    required this.pendingCount,
    required this.totalCount,
  });

  final int year;
  final int month;
  final int pendingCount;
  final int totalCount;

  int get paidCount => totalCount - pendingCount;
}

class BillInstancesRepository {
  BillInstancesRepository(this._db);

  final AppDatabase _db;

  Stream<List<BillInstanceWithBill>> watchInstancesForMonth(
    int year,
    int month,
  ) {
    final query = _db.select(_db.billInstances).join([
      innerJoin(
        _db.bills,
        _db.bills.id.equalsExp(_db.billInstances.billId),
      ),
    ])
      ..where(_db.billInstances.year.equals(year) &
          _db.billInstances.month.equals(month))
      ..orderBy([
        OrderingTerm.asc(_db.billInstances.isPaid),
        OrderingTerm.asc(_db.bills.dueDayOfMonth),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => (
                  instance: row.readTable(_db.billInstances),
                  bill: row.readTable(_db.bills),
                ),
              )
              .toList(),
        );
  }

  Stream<List<BillInstanceWithBill>> watchInstancesForBill(int billId) {
    final query = _db.select(_db.billInstances).join([
      innerJoin(
        _db.bills,
        _db.bills.id.equalsExp(_db.billInstances.billId),
      ),
    ])
      ..where(_db.billInstances.billId.equals(billId))
      ..orderBy([
        OrderingTerm.desc(_db.billInstances.year),
        OrderingTerm.desc(_db.billInstances.month),
      ]);

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => (
                  instance: row.readTable(_db.billInstances),
                  bill: row.readTable(_db.bills),
                ),
              )
              .toList(),
        );
  }

  /// Only returns months where at least one bill has been marked as paid.
  Stream<List<MonthSummary>> watchAllMonthSummaries() {
    final query = _db.select(_db.billInstances).join([
      innerJoin(
        _db.bills,
        _db.bills.id.equalsExp(_db.billInstances.billId),
      ),
    ]);

    return query.watch().map((rows) {
      final Map<(int, int), _MonthAccumulator> accumulators = {};

      for (final row in rows) {
        final instance = row.readTable(_db.billInstances);
        final key = (instance.year, instance.month);
        accumulators.putIfAbsent(
          key,
          () => _MonthAccumulator(instance.year, instance.month),
        );
        accumulators[key]!.add(instance.isPaid);
      }

      final summaries = accumulators.values
          .map((a) => a.toSummary())
          .where((s) => s.paidCount > 0)
          .toList()
        ..sort((a, b) {
          final yearCmp = b.year.compareTo(a.year);
          return yearCmp != 0 ? yearCmp : b.month.compareTo(a.month);
        });

      return summaries;
    });
  }

  Future<void> ensureInstancesExist(
    List<Bill> activeBills,
    int year,
    int month,
  ) async {
    if (activeBills.isEmpty) return;

    await _db.transaction(() async {
      for (final bill in activeBills) {
        final existing = await (_db.select(_db.billInstances)
              ..where(
                (i) =>
                    i.billId.equals(bill.id) &
                    i.year.equals(year) &
                    i.month.equals(month),
              ))
            .getSingleOrNull();

        if (existing == null) {
          final now = DateTime.now();
          await _db.into(_db.billInstances).insert(
                BillInstancesCompanion.insert(
                  billId: bill.id,
                  year: year,
                  month: month,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    });
  }

  Future<void> markPaid({
    required int instanceId,
    required DateTime paidAt,
    PaymentMethod? paymentMethod,
    String? referenceNote,
    double? amountPaid,
  }) {
    return (_db.update(_db.billInstances)
          ..where((i) => i.id.equals(instanceId)))
        .write(
      BillInstancesCompanion(
        isPaid: const Value(true),
        paidAt: Value(paidAt),
        paymentMethod: Value(paymentMethod?.name),
        referenceNote: Value(referenceNote),
        amountPaid: Value(amountPaid),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> unmarkPaid(int instanceId) {
    return (_db.update(_db.billInstances)
          ..where((i) => i.id.equals(instanceId)))
        .write(
      BillInstancesCompanion(
        isPaid: const Value(false),
        paidAt: const Value(null),
        paymentMethod: const Value(null),
        referenceNote: const Value(null),
        amountPaid: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<BillInstance?> getInstanceById(int id) {
    return (_db.select(_db.billInstances)..where((i) => i.id.equals(id)))
        .getSingleOrNull();
  }

  // --- Backup / restore ---

  Future<List<Bill>> getAllBills() => _db.select(_db.bills).get();

  Future<List<BillInstance>> getAllInstances() =>
      _db.select(_db.billInstances).get();

  Future<void> replaceAllData({
    required List<BillsCompanion> bills,
    required List<BillInstancesCompanion> instances,
  }) async {
    await _db.transaction(() async {
      await _db.delete(_db.billInstances).go();
      await _db.delete(_db.bills).go();
      await _db.batch((batch) {
        batch.insertAll(_db.bills, bills);
      });
      await _db.batch((batch) {
        batch.insertAll(_db.billInstances, instances);
      });
    });
  }
}

class _MonthAccumulator {
  _MonthAccumulator(this.year, this.month);

  final int year;
  final int month;
  int pendingCount = 0;
  int totalCount = 0;

  void add(bool isPaid) {
    totalCount++;
    if (!isPaid) pendingCount++;
  }

  MonthSummary toSummary() => MonthSummary(
        year: year,
        month: month,
        pendingCount: pendingCount,
        totalCount: totalCount,
      );
}
