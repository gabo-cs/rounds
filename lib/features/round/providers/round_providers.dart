import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/extensions/date_extensions.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/models/currency.dart';
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
        // [refreshReminderSchedule], independent of what's viewed.
        final activeBills = await ref.watch(activeBillsProvider.future);
        await instancesRepo.ensureInstancesExist(
          activeBills,
          month.year,
          month.month,
        );
      }

      yield* instancesRepo.watchInstancesForMonth(month.year, month.month);
    });

/// Whether enough time has passed since the last *completed* re-arm pass for
/// another to be worth running. Pure so the clock edges are testable.
bool reminderPassIsDue({
  required int? lastCompletedMillis,
  required DateTime now,
  required Duration minInterval,
}) {
  if (lastCompletedMillis == null) return true;
  final last = DateTime.fromMillisecondsSinceEpoch(lastCompletedMillis);
  // A clock set backwards would otherwise defer the pass indefinitely.
  if (last.isAfter(now)) return true;
  return now.difference(last) >= minInterval;
}

/// Re-arm the rolling window of reminders. Runs when the app is backgrounded —
/// the moment the Android main thread, which serves both these platform calls
/// and touch input, has no scrolling to fight — with a stale-launch fallback
/// for sessions that never get there (see main.dart).
///
/// The pass is unconditional and blind — it re-issues everything due within
/// [kReminderHorizon] rather than asking the platform what is already armed.
/// It has to be: alarms are cancelled without notice by a force-stop or an OEM
/// battery manager, and Android cannot be asked whether one survived. Re-arming
/// is the only repair, so it runs every time.
///
/// What makes that cheap is the horizon. The cost tracks how many bills fall
/// due soon — a handful — not how many bills exist times how many months are
/// pre-scheduled. An earlier design pre-armed three months at ten slots per
/// bill, which is what made a blind pass unaffordable and pushed us into
/// trusting a platform mirror that lies.
Future<void> refreshReminderSchedule({
  required BillsRepository billsRepo,
  required BillInstancesRepository instancesRepo,
  required String languageCode,
  required Currency currency,
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final current = DateTime(today.year, today.month);
  // Rolls the year over on its own in December.
  final next = DateTime(today.year, today.month + 1);
  final prev = current.previousMonth;

  // Instances are generated lazily when a month is viewed, so the months the
  // horizon reaches into may not exist yet on a launch that never opens them.
  final activeBills = await billsRepo.watchAllActiveBills().first;
  for (final month in [current, next]) {
    await instancesRepo.ensureInstancesExist(
      activeBills,
      month.year,
      month.month,
    );
  }

  // These three months are what the horizon can touch: back one for overdue
  // nagging, forward one because 35 days crosses a month boundary. Which of
  // their instances actually cost a platform call is decided per-instance by
  // [plannedRemindersFor], not here.
  final candidates = <BillInstanceWithBill>[];
  for (final month in [prev, current, next]) {
    candidates.addAll(
      await instancesRepo.watchInstancesForMonth(month.year, month.month).first,
    );
  }

  await NotificationService.instance.scheduleMonthlyKickoff(
    languageCode: languageCode,
  );
  await NotificationService.instance.applyReminderPlans([
    for (final entry in candidates)
      plannedRemindersFor(
        entry,
        now: today,
        languageCode: languageCode,
        currency: currency,
      ),
  ]);

  // Unpaid instances older than the previous month have outlived the nagging
  // horizon. Retire them outright, including any open-ended overdue repeat
  // armed before this cutoff existed.
  final stale = await instancesRepo.getUnpaidInstancesBefore(
    prev.year,
    prev.month,
  );
  if (stale.isNotEmpty) {
    await NotificationService.instance.cancelForInstances(
      [for (final entry in stale) entry.instance.id],
    );
  }
}
