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
        // The paid section reads as a ledger, so it runs newest-settled first.
        // Unpaid rows all carry a null paidAt and tie here, falling through to
        // the due day; a paid row without one (pre-payment-details data) sorts
        // last, since SQLite ranks NULL below every value.
        OrderingTerm.desc(_db.billInstances.paidAt),
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

    // One query for everything already in this month, then insert only what's
    // missing. This is the common path on every month switch, so avoid the
    // per-bill query loop — usually nothing is missing and we return early.
    final existing = await (_db.select(_db.billInstances)
          ..where((i) => i.year.equals(year) & i.month.equals(month)))
        .get();
    final existingBillIds = existing.map((i) => i.billId).toSet();
    final missing =
        activeBills.where((b) => !existingBillIds.contains(b.id)).toList();
    if (missing.isEmpty) return;

    final now = DateTime.now();
    // insertOrIgnore so this is race-safe: several callers (a re-running month
    // provider, its previous in-flight run, the startup warm-up) can all read
    // "missing" for the same month at once and try to insert the same row. The
    // UNIQUE(bill_id, year, month) constraint makes the losers no-ops instead
    // of throwing.
    await _db.batch((batch) {
      batch.insertAll(
        _db.billInstances,
        [
          for (final bill in missing)
            BillInstancesCompanion.insert(
              billId: bill.id,
              year: year,
              month: month,
              createdAt: now,
              updatedAt: now,
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
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

  /// Settle several instances at once, each with its own payment date.
  ///
  /// One batch, so the month's stream emits once instead of once per bill,
  /// and a half-applied round can't survive a failure mid-way. The companion
  /// is deliberately partial: these instances are unpaid, so their payment
  /// details are already null and there is nothing to clear.
  Future<void> markManyPaid(Map<int, DateTime> paidAtByInstanceId) async {
    if (paidAtByInstanceId.isEmpty) return;

    final now = DateTime.now();
    await _db.batch((batch) {
      for (final entry in paidAtByInstanceId.entries) {
        batch.update(
          _db.billInstances,
          BillInstancesCompanion(
            isPaid: const Value(true),
            paidAt: Value(entry.value),
            updatedAt: Value(now),
          ),
          // Guarded on isPaid so a bill settled individually while the
          // confirmation was open keeps the details it was settled with.
          where: (i) => i.id.equals(entry.key) & i.isPaid.equals(false),
        );
      }
    });
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

  /// Unpaid instances of active bills in exactly [year]/[month]. Used to keep
  /// last month's overdue reminders alive after the scheduling window slides
  /// past them — overdue nagging reaches back one month, no further.
  Future<List<BillInstanceWithBill>> getUnpaidInstancesForMonth(
    int year,
    int month,
  ) async {
    final query = _db.select(_db.billInstances).join([
      innerJoin(
        _db.bills,
        _db.bills.id.equalsExp(_db.billInstances.billId),
      ),
    ])
      ..where(_db.billInstances.isPaid.equals(false) &
          _db.bills.isArchived.equals(false) &
          _db.billInstances.year.equals(year) &
          _db.billInstances.month.equals(month));

    final rows = await query.get();
    return rows
        .map(
          (row) => (
            instance: row.readTable(_db.billInstances),
            bill: row.readTable(_db.bills),
          ),
        )
        .toList();
  }

  /// Unpaid instances from months strictly before [year]/[month], for bills
  /// that are still active. Used to *retire* reminders older than the nagging
  /// horizon, so ancient unpaid instances don't nag forever.
  Future<List<BillInstanceWithBill>> getUnpaidInstancesBefore(
    int year,
    int month,
  ) async {
    final query = _db.select(_db.billInstances).join([
      innerJoin(
        _db.bills,
        _db.bills.id.equalsExp(_db.billInstances.billId),
      ),
    ])
      ..where(_db.billInstances.isPaid.equals(false) &
          _db.bills.isArchived.equals(false) &
          (_db.billInstances.year.isSmallerThanValue(year) |
              (_db.billInstances.year.equals(year) &
                  _db.billInstances.month.isSmallerThanValue(month))));

    final rows = await query.get();
    return rows
        .map(
          (row) => (
            instance: row.readTable(_db.billInstances),
            bill: row.readTable(_db.bills),
          ),
        )
        .toList();
  }

  /// IDs of every instance belonging to [billId] — used to cancel their
  /// scheduled notifications when the bill is deleted or archived.
  Future<List<int>> getInstanceIdsForBill(int billId) async {
    final query = _db.selectOnly(_db.billInstances)
      ..addColumns([_db.billInstances.id])
      ..where(_db.billInstances.billId.equals(billId));
    final rows = await query.get();
    return rows.map((row) => row.read(_db.billInstances.id)!).toList();
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
