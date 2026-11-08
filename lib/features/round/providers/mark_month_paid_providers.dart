import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/models/currency.dart';
import 'package:rounds/data/providers.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/features/round/providers/round_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';

/// Whether [month] is a round already behind [now] — the one case where a
/// bulk settle records something other than today.
bool isPastRound(SelectedMonth month, DateTime now) =>
    monthsFromNow(month, now: now) < 0;

/// The date a bulk settle records for one instance.
///
/// For a round already past, the bill's own due date in its own month: a June
/// bill settled in August was not paid in August, and dating it so would put
/// the payment outside the round it belongs to. Otherwise today — for the
/// current round that's when the payment is happening, and settling a future
/// round is paying ahead, which also happens today. Its due date would record
/// a payment on a day that hasn't come yet.
///
/// Pure so the month-boundary cases can be tested without a clock.
DateTime bulkPaidAt(BillInstanceWithBill entry, DateTime now) {
  final instance = entry.instance;
  final round = SelectedMonth(year: instance.year, month: instance.month);
  if (!isPastRound(round, now)) return now;
  // Due days are capped at 28, so this is always a real date.
  return DateTime(instance.year, instance.month, entry.bill.dueDayOfMonth);
}

/// What one bulk settle wrote — enough to take it back.
class BulkSettlement {
  const BulkSettlement({required this.entries, required this.paidAt});

  /// The instances as they were before the settle, unpaid.
  final List<BillInstanceWithBill> entries;

  /// The date recorded for each, keyed by instance id.
  final Map<int, DateTime> paidAt;

  int get count => entries.length;
}

/// Settling a whole round is a repo write plus a pile of notification
/// cancels, so it's orchestrated here rather than in a widget callback — and
/// so is taking it back.
///
/// The state is just "a pass is running" — enough to keep the button from
/// being tapped twice while the batch is in flight.
class MarkMonthPaidNotifier extends StateNotifier<bool> {
  MarkMonthPaidNotifier(
    this._repo,
    this._notifications, {
    required this.languageCode,
    required this.notificationsEnabled,
    required this.currency,
  }) : super(false);

  final BillInstancesRepository _repo;
  final NotificationService _notifications;
  final String languageCode;
  final bool notificationsEnabled;
  final Currency currency;

  /// Returns what was settled, or null if the write failed.
  Future<BulkSettlement?> settle(
    List<BillInstanceWithBill> unpaid, {
    DateTime? now,
  }) async {
    if (state || unpaid.isEmpty) return null;
    state = true;
    final at = now ?? DateTime.now();
    final paidAt = {
      for (final entry in unpaid) entry.instance.id: bulkPaidAt(entry, at),
    };
    try {
      await _repo.markManyPaid(paidAt);
    } catch (e) {
      return null;
    } finally {
      // The month page can leave the PageView's cache window mid-write.
      if (mounted) state = false;
    }

    // A settled bill must stop nagging, and the re-arm pass is no backstop:
    // it only clears slot 0, so the rest of the ladder would still fire for
    // every bill in the round.
    //
    // Deliberately not awaited. This is ten paced platform calls per bill —
    // over a second for a full round — and the write is what the user is
    // waiting on. Holding the confirmation behind the housekeeping is what
    // made the whole action feel slow.
    unawaited(
      _notifications
          .cancelForInstances(paidAt.keys)
          .catchError((Object e) => debugPrint('Cancel after settle: $e')),
    );
    return BulkSettlement(entries: unpaid, paidAt: paidAt);
  }

  /// Take back a [settle], for the undo on its confirmation. Returns false if
  /// the write failed.
  ///
  /// Doesn't touch [state]: the undo can arrive after the month page — and
  /// this notifier with it — has been disposed, and only the repo and the
  /// service are needed.
  Future<bool> unsettle(BulkSettlement settlement, {DateTime? now}) async {
    try {
      await _repo.unmarkManyPaid(settlement.paidAt);
    } catch (e) {
      return false;
    }

    // Re-arm every reverted bill rather than only the overdue ones the
    // single-bill undo restores: a whole round going back to unpaid would
    // otherwise sit silent until the next pass. The plans are the pass's
    // own, so this arms exactly what it would.
    if (notificationsEnabled) {
      final at = now ?? DateTime.now();
      unawaited(
        _notifications
            .applyReminderPlans([
              for (final entry in settlement.entries)
                plannedRemindersFor(
                  entry,
                  now: at,
                  languageCode: languageCode,
                  currency: currency,
                ),
            ])
            .catchError((Object e) => debugPrint('Re-arm after undo: $e')),
      );
    }
    return true;
  }
}

// autoDispose.family: one per month page, freed with the page itself.
final markMonthPaidProvider = StateNotifierProvider.autoDispose
    .family<MarkMonthPaidNotifier, bool, SelectedMonth>((ref, month) {
      final settings = ref.read(settingsProvider);
      return MarkMonthPaidNotifier(
        ref.watch(billInstancesRepositoryProvider),
        ref.watch(notificationServiceProvider),
        languageCode: settings.languageCode,
        notificationsEnabled: settings.notificationsEnabled,
        currency: kAppCurrency,
      );
    });
