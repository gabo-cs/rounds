import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/extensions/date_extensions.dart';
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
        // [reconcileNotifications], independent of what's viewed.
        final activeBills = await ref.watch(activeBillsProvider.future);
        await instancesRepo.ensureInstancesExist(
          activeBills,
          month.year,
          month.month,
        );
      }

      yield* instancesRepo.watchInstancesForMonth(month.year, month.month);
    });

/// Bring the platform's notification schedule in line with the database.
///
/// Builds the reminders that *should* be armed across a three-month window —
/// the previous month (whose unpaid bills keep nagging), the current one, and
/// the next — and hands them to [NotificationService.reconcile], which issues
/// only the differences. The window is anchored to the device's date, not to
/// the month being browsed, and slides forward on its own.
///
/// Because the pass is a diff, running it costs a single platform call when
/// nothing has changed. That is what lets it run unconditionally on every
/// launch and still serve as the safety net that restores alarms lost to a
/// force-stop or an OEM battery killer — the previous design could only afford
/// to do that once a day, and paid for it with a storm of platform calls that
/// blocked touch input for seconds after startup.
Future<void> reconcileNotifications({
  required BillsRepository billsRepo,
  required BillInstancesRepository instancesRepo,
  required String languageCode,
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final current = DateTime(today.year, today.month);
  // Rolls the year over on its own in December.
  final next = DateTime(today.year, today.month + 1);
  final prev = current.previousMonth;

  // Instances are generated lazily when a month is viewed, so the months we
  // schedule for may not exist yet on a launch that never reaches them.
  final activeBills = await billsRepo.watchAllActiveBills().first;
  for (final month in [current, next]) {
    await instancesRepo.ensureInstancesExist(
      activeBills,
      month.year,
      month.month,
    );
  }

  final windowed = <BillInstanceWithBill>[];
  for (final month in [prev, current, next]) {
    windowed.addAll(
      await instancesRepo.watchInstancesForMonth(month.year, month.month).first,
    );
  }

  // Unpaid instances older than the window have outlived the nagging horizon.
  // Managing their IDs with nothing planned for them is what retires their
  // reminders, including repeats armed before this cutoff existed.
  final stale = await instancesRepo.getUnpaidInstancesBefore(
    prev.year,
    prev.month,
  );

  await NotificationService.instance.reconcile(
    plan: [
      monthlyKickoffPlan(now: today, languageCode: languageCode),
      for (final entry in windowed)
        ...plannedRemindersFor(entry, now: today, languageCode: languageCode),
    ],
    // Every instance in the window is managed, not just the ones with
    // reminders planned: that is what makes the pass convergent. A bill that
    // was paid or archived while a cancel was lost has its leftovers cleaned
    // up here instead of nagging forever.
    managedInstanceIds: {
      for (final entry in [...windowed, ...stale]) entry.instance.id,
    },
  );
}
