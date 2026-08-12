import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/database/app_database.dart';
import 'package:rounds/data/repositories/bill_instances_repository.dart';

void main() {
  // The overdue copy formats its due date; in the app the localization
  // delegates do this before any reminder is built.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('es');
  });

  final createdAt = DateTime(2026, 1, 1);

  BillInstanceWithBill entry({
    int id = 1,
    int billId = 1,
    int year = 2026,
    int month = 7,
    bool isPaid = false,
    String name = 'Electricity',
    double? amount = 42.50,
    int dueDay = 16,
    bool isArchived = false,
  }) =>
      (
        instance: BillInstance(
          id: id,
          billId: billId,
          year: year,
          month: month,
          isPaid: isPaid,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
        bill: Bill(
          id: billId,
          name: name,
          amount: amount,
          dueDayOfMonth: dueDay,
          isArchived: isArchived,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
      );

  ReminderPlan planFor(
    BillInstanceWithBill e,
    DateTime now, {
    String languageCode = 'en',
  }) =>
      plannedRemindersFor(e, now: now, languageCode: languageCode);

  group('plannedRemindersFor', () {
    test('arms three upcoming reminders and a three-day ladder', () {
      final plan = planFor(entry(), DateTime(2026, 7, 1, 8));

      // Slots 1–3 for the upcoming reminders, then 0, 4 and 5 for the ladder.
      expect(plan.arm.map((n) => n.id).toList(), [12, 11, 13, 10, 14, 15]);
      expect(
        plan.arm.map((n) => n.fireAt).toList(),
        [
          DateTime(2026, 7, 14, 9), // in 2 days
          DateTime(2026, 7, 15, 9), // tomorrow
          DateTime(2026, 7, 16, 9), // due today
          DateTime(2026, 7, 17, 9), // overdue day 1
          DateTime(2026, 7, 18, 9), // overdue day 2
          DateTime(2026, 7, 19, 9), // overdue day 3
        ],
      );
      expect(plan.arm.every((n) => n.repeat == NotificationRepeat.none), isTrue);
      expect(plan.clear, isEmpty);
    });

    test('omits reminders whose 9:00 slot has already passed', () {
      // Mid-morning on the due date: the upcoming reminders and today's 9:00
      // are gone, only the ladder is left to arm.
      final plan = planFor(entry(), DateTime(2026, 7, 16, 10));

      expect(plan.arm.map((n) => n.id).toList(), [10, 14, 15]);
      expect(plan.arm.first.fireAt, DateTime(2026, 7, 17, 9));
    });

    test('replaces the ladder with one daily repeat once overdue', () {
      final plan = planFor(entry(), DateTime(2026, 7, 20, 12));

      expect(plan.arm, hasLength(1));
      expect(plan.arm.single.id, 10); // the frozen overdue slot
      expect(plan.arm.single.repeat, NotificationRepeat.daily);
      expect(plan.arm.single.overdue, isTrue);
      // Today's 9:00 is gone, so the repeat starts tomorrow.
      expect(plan.arm.single.fireAt, DateTime(2026, 7, 21, 9));
    });

    test('clears the ladder it supersedes, including the retired slots', () {
      final plan = planFor(entry(), DateTime(2026, 7, 20, 12));

      // 14–15 are the live ladder; 16–19 are days 4–7 of the seven-day ladder
      // an upgraded install may still have armed. Leaving either would double
      // up with the repeat on slot 10.
      expect(plan.clear, [14, 15, 16, 17, 18, 19]);
    });

    test('starts the overdue repeat today when 9:00 is still ahead', () {
      final plan = planFor(entry(), DateTime(2026, 7, 20, 7));

      expect(plan.arm.single.fireAt, DateTime(2026, 7, 20, 9));
    });

    test('keeps nagging for last month, dated so it reads unambiguously', () {
      // A June bill still unpaid in July.
      final plan = planFor(entry(month: 6), DateTime(2026, 7, 3, 12));

      expect(plan.arm, hasLength(1));
      expect(plan.arm.single.repeat, NotificationRepeat.daily);
      expect(plan.arm.single.body, contains('Jun'));
    });
  });

  group('the rolling window', () {
    // The horizon is what keeps the pass small enough to re-issue blindly on
    // every launch, so its edges are load-bearing.
    test('arms nothing for a bill beyond the horizon', () {
      final now = DateTime(2026, 8, 12, 10);
      final beyond = entry(year: 2026, month: 9, dueDay: 17);

      expect(now.add(kReminderHorizon).isBefore(DateTime(2026, 9, 17)), isTrue);
      expect(planFor(beyond, now).arm, isEmpty);
      expect(planFor(beyond, now).clear, isEmpty);
    });

    test('arms a bill that has just come into the horizon', () {
      final now = DateTime(2026, 8, 12, 10);
      final inRange = entry(year: 2026, month: 9, dueDay: 16);

      expect(planFor(inRange, now).arm, hasLength(6));
    });

    test('covers the next occurrence of every monthly bill', () {
      // The point of 35 days: due days are capped at 28, so consecutive due
      // dates are at most 31 days apart. Whatever the launch date, the next
      // occurrence of every bill is inside the window.
      for (var dueDay = 1; dueDay <= 28; dueDay++) {
        for (var day = 1; day <= 28; day++) {
          final now = DateTime(2026, 8, day, 12);
          final thisMonth = planFor(entry(month: 8, dueDay: dueDay), now);
          final nextMonth = planFor(entry(month: 9, dueDay: dueDay), now);

          expect(
            thisMonth.arm.isNotEmpty || nextMonth.arm.isNotEmpty,
            isTrue,
            reason: 'bill due day $dueDay went silent on Aug $day',
          );
        }
      }
    });
  });

  group('a bill that should have no reminders', () {
    test('arms nothing when paid or archived', () {
      final now = DateTime(2026, 7, 1, 8);

      expect(planFor(entry(isPaid: true), now).arm, isEmpty);
      expect(planFor(entry(isArchived: true), now).arm, isEmpty);
    });

    test('clears the overdue repeat if the due date has passed', () {
      // The backstop for a lost cancel: slot 0 is the only alarm that repeats
      // without end, so it is the only one that could nag forever.
      final now = DateTime(2026, 7, 20, 12);

      expect(planFor(entry(isPaid: true), now).clear, [10]);
      expect(planFor(entry(isArchived: true), now).clear, [10]);
    });

    test('clears nothing when the due date is still ahead', () {
      // No repeat can exist yet, and the one-shots expire on their own.
      final plan = planFor(entry(isPaid: true), DateTime(2026, 7, 1, 8));

      expect(plan.clear, isEmpty);
    });
  });

  group('payload', () {
    test('carries what the background snooze handler needs', () {
      final overdue = planFor(entry(), DateTime(2026, 7, 20, 12)).arm.single;
      final payload = jsonDecode(overdue.payload) as Map<String, dynamic>;

      expect(payload['notifId'], 10);
      expect(payload['langCode'], 'en');
      expect(payload['overdue'], isTrue);
      // Without this the handler would snooze the open-ended nag as a one-shot
      // and silently end it.
      expect(payload['repeating'], isTrue);
    });

    test('marks a one-shot as non-repeating', () {
      final upcoming = planFor(entry(), DateTime(2026, 7, 1, 8)).arm.first;
      final payload = jsonDecode(upcoming.payload) as Map<String, dynamic>;

      expect(payload['repeating'], isFalse);
      expect(payload['overdue'], isFalse);
    });
  });

  group('monthlyKickoffPlan', () {
    test('targets the next 1st at 9:00 and rolls the year over', () {
      expect(
        monthlyKickoffPlan(now: DateTime(2026, 7, 3), languageCode: 'en')
            .fireAt,
        DateTime(2026, 8, 1, 9),
      );
      expect(
        monthlyKickoffPlan(now: DateTime(2026, 12, 9), languageCode: 'en')
            .fireAt,
        DateTime(2027, 1, 1, 9),
      );
      // The 1st before 9:00 still belongs to today.
      expect(
        monthlyKickoffPlan(now: DateTime(2026, 7, 1, 8), languageCode: 'en')
            .fireAt,
        DateTime(2026, 7, 1, 9),
      );
    });

    test('stays clear of the instance ID space', () {
      final id = monthlyKickoffPlan(
        now: DateTime(2026, 7, 3),
        languageCode: 'en',
      ).id;

      expect(id ~/ 10, greaterThan(99999));
    });
  });
}
