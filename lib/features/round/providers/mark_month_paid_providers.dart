import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/round/providers/round_providers.dart';

/// The date a bulk settle records for one instance.
///
/// Today, when the round being settled is the one we're living in — that's
/// when the payment is actually happening. Otherwise the bill's own due date
/// in its own month: a June bill settled in August was not paid in August,
/// and dating it so would put the payment outside the round it belongs to.
///
/// Pure so the month-boundary cases can be tested without a clock.
DateTime bulkPaidAt(BillInstanceWithBill entry, DateTime now) {
  final instance = entry.instance;
  if (instance.year == now.year && instance.month == now.month) return now;
  // Due days are capped at 28, so this is always a real date.
  return DateTime(instance.year, instance.month, entry.bill.dueDayOfMonth);
}

/// Settling a whole round is a repo write plus a pile of notification
/// cancels, so it's orchestrated here rather than in a widget callback.
///
/// The state is just "a pass is running" — enough to keep the button from
/// being tapped twice while the batch is in flight.
class MarkMonthPaidNotifier extends StateNotifier<bool> {
  MarkMonthPaidNotifier(this._repo) : super(false);

  final BillInstancesRepository _repo;

  /// Returns the number settled, or null if the write failed.
  Future<int?> settle(
    List<BillInstanceWithBill> unpaid, {
    DateTime? now,
  }) async {
    if (state || unpaid.isEmpty) return null;
    state = true;
    final at = now ?? DateTime.now();
    try {
      await _repo.markManyPaid({
        for (final entry in unpaid) entry.instance.id: bulkPaidAt(entry, at),
      });
      // A settled bill must stop nagging. The re-arm pass is no backstop
      // here: it only clears slot 0, so the rest of the ladder would still
      // fire for every bill in the round.
      await NotificationService.instance.cancelForInstances([
        for (final entry in unpaid) entry.instance.id,
      ]);
      return unpaid.length;
    } catch (e) {
      return null;
    } finally {
      // The month page can leave the PageView's cache window mid-write.
      if (mounted) state = false;
    }
  }
}

// autoDispose.family: one per month page, freed with the page itself.
final markMonthPaidProvider = StateNotifierProvider.autoDispose
    .family<MarkMonthPaidNotifier, bool, SelectedMonth>((ref, month) {
      return MarkMonthPaidNotifier(ref.watch(billInstancesRepositoryProvider));
    });
