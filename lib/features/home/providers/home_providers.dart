import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/data/repositories/bills_repository.dart';

// --- Root providers ---

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(ref.watch(appDatabaseProvider));
});

final billInstancesRepositoryProvider = Provider<BillInstancesRepository>((
  ref,
) {
  return BillInstancesRepository(ref.watch(appDatabaseProvider));
});

// --- Selected month ---

class SelectedMonth {
  const SelectedMonth({required this.year, required this.month});

  final int year;
  final int month;

  SelectedMonth copyWith({int? year, int? month}) =>
      SelectedMonth(year: year ?? this.year, month: month ?? this.month);

  // Value equality so it can key the [monthInstancesProvider] family.
  @override
  bool operator ==(Object other) =>
      other is SelectedMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

final selectedMonthProvider = StateProvider<SelectedMonth>((ref) {
  final now = DateTime.now();
  return SelectedMonth(year: now.year, month: now.month);
});

// --- Active bills (for the FAB and form) ---

final activeBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsRepositoryProvider).watchAllActiveBills();
});

// --- Month instances ---

// A family keyed by month: each month page owns its own stream, so the
// PageView can keep neighbouring months alive and pre-built. autoDispose frees
// a month's query stream once its page leaves the PageView's cache window.
final monthInstancesProvider = StreamProvider.autoDispose
    .family<List<BillInstanceWithBill>, SelectedMonth>((ref, month) async* {
      final instancesRepo = ref.watch(billInstancesRepositoryProvider);

      // Auto-generate instances for the current month and the next 12 months so
      // browsing ahead shows the recurring bills. This horizon is relative to today
      // (not a fixed date) so it keeps sliding forward and never expires. Past
      // months show only what was explicitly recorded.
      final now = DateTime.now();
      final selectedDate = DateTime(month.year, month.month);
      final currentMonth = DateTime(now.year, now.month);
      final cutoff = DateTime(now.year, now.month + 12);
      final shouldGenerate =
          !selectedDate.isBefore(currentMonth) && !selectedDate.isAfter(cutoff);

      if (shouldGenerate) {
        // Reuse the shared active-bills stream rather than opening a fresh query
        // per month page. On cold start the PageView builds several pages at
        // once, and one shared subscription avoids piling redundant round-trips
        // onto the just-spawned drift isolate. Notification scheduling is *not*
        // done here — it's device-month based and handled at startup by
        // [scheduleUpcomingReminders], independent of what's viewed.
        final activeBills = await ref.watch(activeBillsProvider.future);
        await instancesRepo.ensureInstancesExist(
          activeBills,
          month.year,
          month.month,
        );
      }

      yield* instancesRepo.watchInstancesForMonth(month.year, month.month);
    });

/// Schedule per-bill reminders for the current and next month, based on the
/// device's date. Called once at startup: it's a sliding window anchored to
/// "now", so each launch re-arms the current + upcoming month regardless of
/// which month the user browses to.
Future<void> scheduleUpcomingReminders({
  required BillsRepository billsRepo,
  required BillInstancesRepository instancesRepo,
  required String languageCode,
}) async {
  final now = DateTime.now();
  final months = <(int, int)>[
    (now.year, now.month),
    (
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
    ),
  ];

  final activeBills = await billsRepo.watchAllActiveBills().first;
  for (final (year, month) in months) {
    await instancesRepo.ensureInstancesExist(activeBills, year, month);
    await _syncMonthNotifications(instancesRepo, year, month, languageCode);
  }
}

// Signature of the notifications last scheduled for each month, so re-arming a
// month whose bills are unchanged does no platform work. The signature changes
// whenever a bill is added, edited, paid, or the language switches.
final _scheduledSignatures = <String, int>{};

Future<void> _syncMonthNotifications(
  BillInstancesRepository instancesRepo,
  int year,
  int month,
  String languageCode,
) async {
  final instances = await instancesRepo
      .watchInstancesForMonth(year, month)
      .first;

  final signature = Object.hashAll([
    languageCode,
    for (final e in instances)
      Object.hash(
        e.instance.id,
        e.instance.isPaid,
        e.bill.name,
        e.bill.amount,
        e.bill.dueDayOfMonth,
      ),
  ]);
  final key = '$year-$month';
  if (_scheduledSignatures[key] == signature) return;
  _scheduledSignatures[key] = signature;

  await NotificationService.instance.scheduleForMonth(
    instances,
    year,
    month,
    languageCode: languageCode,
  );
}

// --- Month summary (derived synchronously from instances) ---

final monthSummaryProvider = Provider.autoDispose<MonthSummary?>((ref) {
  final selected = ref.watch(selectedMonthProvider);
  final instancesAsync = ref.watch(monthInstancesProvider(selected));
  return instancesAsync.whenOrNull(
    data: (instances) {
      if (instances.isEmpty) return null;
      int pendingCount = 0;
      for (final entry in instances) {
        if (!entry.instance.isPaid) pendingCount++;
      }
      return MonthSummary(
        year: selected.year,
        month: selected.month,
        pendingCount: pendingCount,
        totalCount: instances.length,
      );
    },
  );
});
