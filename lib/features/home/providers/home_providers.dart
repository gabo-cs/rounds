import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/data/repositories/bills_repository.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';

// --- Root providers ---

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final billsRepositoryProvider = Provider<BillsRepository>((ref) {
  return BillsRepository(ref.watch(appDatabaseProvider));
});

final billInstancesRepositoryProvider =
    Provider<BillInstancesRepository>((ref) {
  return BillInstancesRepository(ref.watch(appDatabaseProvider));
});

// --- Selected month ---

class SelectedMonth {
  const SelectedMonth({required this.year, required this.month});

  final int year;
  final int month;

  SelectedMonth copyWith({int? year, int? month}) =>
      SelectedMonth(year: year ?? this.year, month: month ?? this.month);
}

final selectedMonthProvider =
    StateProvider<SelectedMonth>((ref) {
  final now = DateTime.now();
  return SelectedMonth(year: now.year, month: now.month);
});

// --- Active bills (for the FAB and form) ---

final activeBillsProvider = StreamProvider<List<Bill>>((ref) {
  return ref.watch(billsRepositoryProvider).watchAllActiveBills();
});

// --- Month instances ---

final monthInstancesProvider =
    StreamProvider<List<BillInstanceWithBill>>((ref) async* {
  final selected = ref.watch(selectedMonthProvider);
  final instancesRepo = ref.watch(billInstancesRepositoryProvider);
  final billsRepo = ref.watch(billsRepositoryProvider);

  // Auto-generate instances for the current month and future months
  // through end of 2026. Past months show only what was explicitly recorded.
  final now = DateTime.now();
  final selectedDate = DateTime(selected.year, selected.month);
  final currentMonth = DateTime(now.year, now.month);
  final cutoff = DateTime(2026, 12);
  final shouldGenerate =
      !selectedDate.isBefore(currentMonth) && !selectedDate.isAfter(cutoff);

  if (shouldGenerate) {
    final activeBills = await billsRepo.watchAllActiveBills().first;
    await instancesRepo.ensureInstancesExist(
      activeBills,
      selected.year,
      selected.month,
    );
    final instances = await instancesRepo
        .watchInstancesForMonth(selected.year, selected.month)
        .first;
    final languageCode = ref.read(settingsProvider).languageCode;
    await NotificationService.instance.scheduleForMonth(
      instances,
      selected.year,
      selected.month,
      languageCode: languageCode,
    );
  }

  yield* instancesRepo.watchInstancesForMonth(selected.year, selected.month);
});

// --- Month summary (derived synchronously from instances) ---

final monthSummaryProvider = Provider<MonthSummary?>((ref) {
  final instancesAsync = ref.watch(monthInstancesProvider);
  return instancesAsync.whenOrNull(
    data: (instances) {
      if (instances.isEmpty) return null;
      int pendingCount = 0;
      for (final entry in instances) {
        if (!entry.instance.isPaid) pendingCount++;
      }
      final selected = ref.watch(selectedMonthProvider);
      return MonthSummary(
        year: selected.year,
        month: selected.month,
        pendingCount: pendingCount,
        totalCount: instances.length,
      );
    },
  );
});
