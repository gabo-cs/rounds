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

  List<PlannedNotification> planFor(
    BillInstanceWithBill e,
    DateTime now, {
    String languageCode = 'en',
  }) =>
      plannedRemindersFor(e, now: now, languageCode: languageCode);

  Map<String, dynamic> payloadOf(PlannedNotification n) =>
      jsonDecode(n.payload) as Map<String, dynamic>;

  group('plannedRemindersFor', () {
    test('arms the full ladder for a bill that is not yet due', () {
      final plan = planFor(entry(), DateTime(2026, 7, 1, 8));

      // Slots 1–3 for the upcoming reminders, then 0 and 4–9 for the week of
      // overdue pings.
      expect(
        plan.map((n) => n.id).toList(),
        [12, 11, 13, 10, 14, 15, 16, 17, 18, 19],
      );
      expect(
        plan.map((n) => n.fireAt).toList(),
        [
          DateTime(2026, 7, 14, 9), // in 2 days
          DateTime(2026, 7, 15, 9), // tomorrow
          DateTime(2026, 7, 16, 9), // due today
          for (var day = 17; day <= 23; day++) DateTime(2026, 7, day, 9),
        ],
      );
      expect(plan.every((n) => n.repeat == NotificationRepeat.none), isTrue);
    });

    test('plans nothing for a paid or archived bill', () {
      final now = DateTime(2026, 7, 1, 8);

      expect(planFor(entry(isPaid: true), now), isEmpty);
      expect(planFor(entry(isArchived: true), now), isEmpty);
    });

    test('omits reminders whose 9:00 slot has already passed', () {
      // Mid-morning on the due date: the two upcoming reminders and today's
      // 9:00 are gone, only the overdue ladder is left to arm.
      final plan = planFor(entry(), DateTime(2026, 7, 16, 10));

      expect(plan.map((n) => n.id).toList(), [10, 14, 15, 16, 17, 18, 19]);
      expect(plan.first.fireAt, DateTime(2026, 7, 17, 9));
    });

    test('replaces the ladder with one daily repeat once overdue', () {
      final plan = planFor(entry(), DateTime(2026, 7, 20, 12));

      expect(plan, hasLength(1));
      expect(plan.single.id, 10); // the frozen overdue slot
      expect(plan.single.repeat, NotificationRepeat.daily);
      expect(plan.single.overdue, isTrue);
      // Today's 9:00 is gone, so the repeat starts tomorrow.
      expect(plan.single.fireAt, DateTime(2026, 7, 21, 9));
    });

    test('starts the overdue repeat today when 9:00 is still ahead', () {
      final plan = planFor(entry(), DateTime(2026, 7, 20, 7));

      expect(plan.single.fireAt, DateTime(2026, 7, 20, 9));
    });

    test('keeps nagging for last month, dated so it reads unambiguously', () {
      // A June bill still unpaid in July — the previous month stays inside the
      // scheduling window.
      final plan = planFor(entry(month: 6), DateTime(2026, 7, 3, 12));

      expect(plan, hasLength(1));
      expect(plan.single.repeat, NotificationRepeat.daily);
      expect(plan.single.body, contains('Jun'));
    });
  });

  group('payload fingerprint', () {
    // reconcile() re-arms a notification exactly when the payload it would
    // write differs from the armed one, so these properties are what keep a
    // launch from re-issuing the whole schedule.
    test('is identical across calls with the same inputs', () {
      final now = DateTime(2026, 7, 1, 8);
      final a = planFor(entry(), now).map((n) => n.payload).toList();
      final b = planFor(entry(), now).map((n) => n.payload).toList();

      expect(a, b);
    });

    test('is stable across the day, so relaunching re-arms nothing', () {
      final morning = planFor(entry(), DateTime(2026, 7, 1, 7));
      final evening = planFor(entry(), DateTime(2026, 7, 1, 22));

      expect(
        morning.map((n) => n.payload).toList(),
        evening.map((n) => n.payload).toList(),
      );
    });

    test('is stable day to day for the overdue repeat', () {
      // The repeat only honours its time of day, so its fingerprint must not
      // move with the calendar — otherwise every launch would re-arm it.
      final monday = planFor(entry(), DateTime(2026, 7, 20, 12)).single;
      final tuesday = planFor(entry(), DateTime(2026, 7, 21, 12)).single;

      expect(monday.fireAt, isNot(tuesday.fireAt));
      expect(monday.payload, tuesday.payload);
    });

    test('changes when a reminder-relevant field changes', () {
      final now = DateTime(2026, 7, 1, 8);
      String fingerprint(BillInstanceWithBill e, {String lang = 'en'}) =>
          planFor(e, now, languageCode: lang).map((n) => n.payload).join();

      final base = fingerprint(entry());

      expect(fingerprint(entry(name: 'Water')), isNot(base));
      expect(fingerprint(entry(amount: 99.99)), isNot(base));
      expect(fingerprint(entry(amount: null)), isNot(base));
      expect(fingerprint(entry(dueDay: 20)), isNot(base));
      expect(fingerprint(entry(), lang: 'es'), isNot(base));
    });

    test('differs from a snoozed reminder, so the next pass restores 9:00', () {
      final planned = planFor(entry(), DateTime(2026, 7, 1, 8)).first;
      // What the snooze handlers write back: the same map, marked.
      final snoozed = jsonEncode({...payloadOf(planned), 'snoozed': true});

      expect(snoozed, isNot(planned.payload));
    });

    test('carries what the background snooze handler needs', () {
      final overdue = planFor(entry(), DateTime(2026, 7, 20, 12)).single;
      final payload = payloadOf(overdue);

      expect(payload['notifId'], 10);
      expect(payload['langCode'], 'en');
      expect(payload['overdue'], isTrue);
      // Without this the handler would snooze the open-ended nag as a one-shot
      // and silently end it.
      expect(payload['repeating'], isTrue);
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

    test('keeps a stable fingerprint as the target date moves', () {
      final july = monthlyKickoffPlan(
        now: DateTime(2026, 7, 3),
        languageCode: 'en',
      );
      final august = monthlyKickoffPlan(
        now: DateTime(2026, 8, 3),
        languageCode: 'en',
      );

      expect(july.fireAt, isNot(august.fireAt));
      expect(july.payload, august.payload);
    });

    test('changes with the language', () {
      final en = monthlyKickoffPlan(
        now: DateTime(2026, 7, 3),
        languageCode: 'en',
      );
      final es = monthlyKickoffPlan(
        now: DateTime(2026, 7, 3),
        languageCode: 'es',
      );

      expect(es.payload, isNot(en.payload));
    });

    test('stays clear of the instance ID space', () {
      final id = monthlyKickoffPlan(
        now: DateTime(2026, 7, 3),
        languageCode: 'en',
      ).id;

      // Cancelling it would need instance 100000 to exist and be managed.
      expect(id ~/ 10, greaterThan(99999));
    });
  });
}
