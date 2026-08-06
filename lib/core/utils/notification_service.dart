import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// The 10-year database, not latest_all: initializing it parses the whole blob
// synchronously on the UI isolate, and latest_all's is six times bigger for
// transitions we can never reach — nothing here is scheduled more than about
// thirteen months out.
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/l10n/app_localizations.dart';

/// Wired into [MaterialApp.scaffoldMessengerKey] so the notification response
/// handler — which runs outside the widget tree — can show snooze confirmations.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ── Snooze action IDs ────────────────────────────────────────────────────────

const _kActionSnooze30 = 'snooze_30';
const _kActionSnooze60 = 'snooze_60';
const _kActionSnooze180 = 'snooze_180';

// ── Notification offsets ─────────────────────────────────────────────────────
// Each instance reserves a small range of notification IDs, one per reminder
// stage. See [_notificationId].

// Overdue stays at offset 0 (its value in earlier versions) so that an already
// scheduled overdue reminder is overwritten rather than duplicated on upgrade.
const _kOffsetOverdue = 0;
const _kOffsetTomorrow = 1;
const _kOffsetIn2Days = 2;
const _kOffsetDueToday = 3;

const _kAllOffsets = [
  _kOffsetOverdue,
  _kOffsetTomorrow,
  _kOffsetIn2Days,
  _kOffsetDueToday,
];

// Slots for the proactive overdue ladder: one-shot pings on the 2nd–7th day
// after the due date (the 1st day reuses the frozen overdue slot 0). Still
// within the instanceId*10+offset scheme, so no collisions with other kinds.
const _kOffsetsOverdueLadder = [4, 5, 6, 7, 8, 9];

/// The proactive overdue schedule for a bill due on [dueDate]: one ping per
/// day for the week after the due date. Kept pure so the date math (month and
/// year rollovers) is unit-testable.
///
/// A repeating notification cannot express "daily starting on a future date":
/// the plugin snaps a repeating schedule to the next time-of-day match on both
/// platforms, which would cry "overdue" before the bill is even due. Hence a
/// ladder of one-shots; launches while the bill is overdue take over with the
/// open-ended daily repeat (see [NotificationService._scheduleOverdueReminder]).
List<({int offset, DateTime fireDay})> overdueLadder(DateTime dueDate) => [
      (
        offset: _kOffsetOverdue,
        fireDay: DateTime(dueDate.year, dueDate.month, dueDate.day + 1),
      ),
      for (var i = 0; i < _kOffsetsOverdueLadder.length; i++)
        (
          offset: _kOffsetsOverdueLadder[i],
          fireDay: DateTime(dueDate.year, dueDate.month, dueDate.day + i + 2),
        ),
    ];

// Fixed ID for the monthly "new round of bills" reminder. Well clear of the
// instanceId*10+offset range and the test notification (999999).
const _kMonthlyKickoffId = 1000001;

/// Pause between per-instance bursts of platform calls in bulk scheduling
/// passes. Each unpaid instance costs up to ten zonedSchedule/cancel
/// round-trips whose responses all land on the UI isolate; spacing the bursts
/// a frame apart keeps a big re-arm pass from starving frames while the user
/// is already scrolling (the same stutter the post-frame + 2s deferral in
/// main.dart works around). The reminders are for future days, so stretching
/// the pass by a few hundred milliseconds is immaterial.
const kNotificationSchedulePacing = Duration(milliseconds: 16);

// ── Action helpers ───────────────────────────────────────────────────────────

// Snooze actions bring the app to the foreground so the reschedule runs on the
// main isolate and we can show an in-app confirmation. The cold-start case
// (app was terminated) is picked up from getNotificationAppLaunchDetails in
// [handleLaunchSnooze].
List<AndroidNotificationAction> _androidActions(AppLocalizations l10n) => [
      AndroidNotificationAction(_kActionSnooze30, l10n.snooze30Min,
          showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze60, l10n.snooze1Hour,
          showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze180, l10n.snooze3Hours,
          showsUserInterface: true),
    ];

/// Shared [NotificationDetails] for every bill reminder, so the channel,
/// actions and iOS category stay identical across scheduling paths.
NotificationDetails _reminderDetails(
  AppLocalizations l10n, {
  Importance importance = Importance.defaultImportance,
  Priority priority = Priority.defaultPriority,
}) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        'bill_reminders_v2',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming bill due dates',
        importance: importance,
        priority: priority,
        actions: _androidActions(l10n),
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'bill_reminder_${l10n.localeName}',
      ),
    );

/// [NotificationDetails] for overdue reminders. They get their own
/// high-importance channel so the daily nag surfaces as heads-up and can be
/// tuned independently of regular reminders in system settings. (Importance is
/// per-channel on Android 8+, so escalating an existing channel's notification
/// wouldn't work — a dedicated channel is the only real escalation mechanism.)
NotificationDetails _overdueDetails(AppLocalizations l10n) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        'overdue_alerts_v1',
        'Overdue Bills',
        channelDescription: 'Daily reminders for bills that are overdue',
        importance: Importance.high,
        priority: Priority.high,
        actions: _androidActions(l10n),
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'bill_reminder_${l10n.localeName}',
      ),
    );

/// [NotificationDetails] for general (non-bill) reminders — no snooze actions.
NotificationDetails _generalDetails() => const NotificationDetails(
      android: AndroidNotificationDetails(
        'bill_reminders_v2',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming bill due dates',
      ),
      iOS: DarwinNotificationDetails(),
    );

DarwinNotificationCategory _darwinCategory(
  String categoryId,
  AppLocalizations l10n,
) =>
    DarwinNotificationCategory(
      categoryId,
      actions: [
        DarwinNotificationAction.plain(_kActionSnooze30, l10n.snooze30Min),
        DarwinNotificationAction.plain(_kActionSnooze60, l10n.snooze1Hour),
        DarwinNotificationAction.plain(_kActionSnooze180, l10n.snooze3Hours),
      ],
    );

// ── Notification response handlers ───────────────────────────────────────────

void _onNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || !actionId.startsWith('snooze_')) return;
  NotificationService.instance._scheduleSnooze(response);
}

@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  final actionId = response.actionId;
  if (actionId == null || !actionId.startsWith('snooze_')) return;
  _handleSnoozeInBackground(response);
}

/// Background isolate handler — must initialize everything from scratch.
Future<void> _handleSnoozeInBackground(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null) return;

  final data = jsonDecode(payload) as Map<String, dynamic>;
  final notifId = data['notifId'] as int;
  final title = data['title'] as String;
  final body = data['body'] as String;
  final langCode = data['langCode'] as String;
  // Older payloads predate the flag; they were all regular reminders.
  final isOverdue = data['overdue'] as bool? ?? false;

  tz.initializeTimeZones();
  try {
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone));
  } catch (_) {}

  final snoozeTime = _computeSnoozeTime(response.actionId!);
  if (snoozeTime == null) return;

  final l10n =
      langCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_rounds'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.cancel(notifId);
  await plugin.zonedSchedule(
    notifId,
    title,
    body,
    snoozeTime,
    isOverdue ? _overdueDetails(l10n) : _reminderDetails(l10n),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    payload: jsonEncode(data),
  );
}

tz.TZDateTime? _computeSnoozeTime(String actionId) {
  final now = tz.TZDateTime.now(tz.local);
  return switch (actionId) {
    _kActionSnooze30 => now.add(const Duration(minutes: 30)),
    _kActionSnooze60 => now.add(const Duration(hours: 1)),
    _kActionSnooze180 => now.add(const Duration(hours: 3)),
    _ => null,
  };
}

// ── Service ──────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone));
    } catch (_) {
      // fall back to UTC if timezone detection fails
    }

    const androidSettings =
        AndroidInitializationSettings('ic_stat_rounds');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        _darwinCategory('bill_reminder_en', AppLocalizationsEn()),
        _darwinCategory('bill_reminder_es', AppLocalizationsEs()),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    _initialized = true;
  }

  Future<bool> requestExactAlarmsPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // not Android, nothing to do
    final canSchedule = await android.canScheduleExactNotifications();
    if (canSchedule ?? false) return true;
    await android.requestExactAlarmsPermission();
    return await android.canScheduleExactNotifications() ?? false;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    final darwin = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      final granted = await darwin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Schedule reminders for all pending instances in the given month.
  ///
  /// For each unpaid instance this schedules, at 9:00 local time:
  ///   • "due in 2 days" and "due tomorrow" reminders,
  ///   • a "due today" reminder on the due date, and
  ///   • an overdue reminder for the day after the due date.
  ///
  /// All of these are scheduled *proactively* from the due date, so they fire
  /// even if the app is never reopened after the bill rolls over. If a bill is
  /// already past due at scheduling time, the overdue reminder becomes a daily
  /// repeating notification instead of a single ping.
  Future<void> scheduleForMonth(
    List<BillInstanceWithBill> instances,
    int year,
    int month, {
    String languageCode = 'en',
  }) async {
    if (!_initialized) return;

    final l10n = languageCode == 'es'
        ? AppLocalizationsEs()
        : AppLocalizationsEn();

    var scheduledAny = false;
    for (final entry in instances) {
      // Archived bills keep their instances visible but must not nag —
      // archiving cancels their reminders, and re-arming here would undo that.
      if (entry.instance.isPaid || entry.bill.isArchived) continue;
      if (scheduledAny) {
        await Future<void>.delayed(kNotificationSchedulePacing);
      }
      scheduledAny = true;
      await _scheduleRemindersForInstance(entry, year, month, l10n);
    }
  }

  /// Schedule the general "a new round of bills" reminder that repeats on the
  /// 1st of every month at 9:00 local time. This is device-month based and has
  /// nothing to do with the month being viewed, so it's scheduled once at
  /// startup (and again on a language change). The fixed ID means re-calling it
  /// simply overwrites the existing schedule.
  Future<void> scheduleMonthlyKickoff({String languageCode = 'en'}) async {
    if (!_initialized) return;
    final l10n =
        languageCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, 1, 9, 0);
    if (scheduledDate.isBefore(now)) {
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      scheduledDate = tz.TZDateTime(tz.local, nextYear, nextMonth, 1, 9, 0);
    }

    await _plugin.zonedSchedule(
      _kMonthlyKickoffId,
      l10n.monthlyReminderTitle,
      l10n.monthlyReminderBody,
      scheduledDate,
      _generalDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> _scheduleRemindersForInstance(
    BillInstanceWithBill entry,
    int year,
    int month,
    AppLocalizations l10n,
  ) async {
    final dueDay = entry.bill.dueDayOfMonth;
    final dueDate = DateTime(year, month, dueDay);
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final amountLabel = entry.bill.amount != null
        ? '\$${entry.bill.amount!.toStringAsFixed(2)}'
        : l10n.notificationBillLabel;

    // Upcoming + due-today reminders (one-shot, at 9:00 on their day).
    // Each entry pairs a notification-ID slot with how many days before the
    // due date it fires — the two are independent (the ID slot stays fixed for
    // upgrade compatibility, the days-before drives the date).
    final upcoming = <({int idOffset, int daysBefore, String label})>[
      (idOffset: _kOffsetIn2Days, daysBefore: 2, label: l10n.notificationIn2Days),
      (idOffset: _kOffsetTomorrow, daysBefore: 1, label: l10n.notificationTomorrow),
      (idOffset: _kOffsetDueToday, daysBefore: 0, label: l10n.notificationDueToday),
    ];
    for (final reminder in upcoming) {
      final fireDay = dueDate.subtract(Duration(days: reminder.daysBefore));
      await _scheduleOneShot(
        notifId: _notificationId(entry.instance.id, reminder.idOffset),
        title: '${entry.bill.name} — ${reminder.label}',
        body: '$amountLabel — ${l10n.dueThe(dueDay)}',
        fireDay: fireDay,
        l10n: l10n,
      );
    }

    // Overdue reminder — a daily nag until the bill is paid.
    if (dueDate.isBefore(todayDate)) {
      // Already overdue → open-ended daily repeating reminder from the next
      // 9:00 (a repeating schedule always snaps to the next time-of-day
      // match, which is exactly right here).
      await _scheduleOverdueReminder(entry, l10n);
    } else {
      // Not yet overdue → a week of one-shot pings starting the day after the
      // due date, so nagging continues even if the app is never reopened.
      // Launches during that week (or after it) replace this with the
      // open-ended repeat above.
      final overdueTitle = '${entry.bill.name} — ${l10n.overdue}';
      final overdueBody =
          '$amountLabel — ${l10n.overdueSinceDate(dueDate)}';
      for (final step in overdueLadder(dueDate)) {
        await _scheduleOneShot(
          notifId: _notificationId(entry.instance.id, step.offset),
          title: overdueTitle,
          body: overdueBody,
          fireDay: step.fireDay,
          l10n: l10n,
          overdue: true,
        );
      }
    }
  }

  /// Schedule a single notification at 9:00 on [fireDay]. Days whose 9:00 slot
  /// is already in the past are skipped.
  Future<void> _scheduleOneShot({
    required int notifId,
    required String title,
    required String body,
    required DateTime fireDay,
    required AppLocalizations l10n,
    bool overdue = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate =
        tz.TZDateTime(tz.local, fireDay.year, fireDay.month, fireDay.day, 9, 0);

    if (scheduledDate.isBefore(now)) return; // don't schedule in the past

    final payload = jsonEncode({
      'notifId': notifId,
      'title': title,
      'body': body,
      'langCode': l10n.localeName,
      'overdue': overdue,
    });

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      scheduledDate,
      overdue ? _overdueDetails(l10n) : _reminderDetails(l10n),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> _scheduleOverdueReminder(
    BillInstanceWithBill entry,
    AppLocalizations l10n,
  ) async {
    // The month matters in the copy: the past-month re-arm pass nags for old
    // instances, and "was due the 5th" alone reads as this month's bill.
    final dueDate = DateTime(
      entry.instance.year,
      entry.instance.month,
      entry.bill.dueDayOfMonth,
    );
    final title = '${entry.bill.name} — ${l10n.overdue}';
    final body =
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : l10n.notificationBillLabel}'
        ' — ${l10n.overdueSinceDate(dueDate)}';
    final notifId = _notificationId(entry.instance.id, _kOffsetOverdue);

    // Take over from any still-pending ladder pings — the open-ended repeat
    // replaces slot 0, and the remaining one-shots would double up with it.
    for (final offset in _kOffsetsOverdueLadder) {
      await _plugin.cancel(_notificationId(entry.instance.id, offset));
    }
    // 'repeating' lets the snooze handler know this schedule is the open-ended
    // daily repeat — after the ladder takeover it's the *only* reminder left
    // for this bill, so a snooze must re-arm it as repeating, not downgrade it
    // to a one-shot that would end the nagging for good.
    final payload = jsonEncode({
      'notifId': notifId,
      'title': title,
      'body': body,
      'langCode': l10n.localeName,
      'overdue': true,
      'repeating': true,
    });

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      scheduledDate,
      _overdueDetails(l10n),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Public entry point for rescheduling an overdue reminder outside of
  /// [scheduleForMonth] — used when a payment is undone on a past-due bill.
  Future<void> scheduleOverdueReminderForInstance(
    BillInstanceWithBill entry, {
    String languageCode = 'en',
  }) async {
    if (!_initialized) return;
    final l10n =
        languageCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();
    await _scheduleOverdueReminder(entry, l10n);
  }

  Future<void> scheduleTestNotification(
    BillInstanceWithBill entry, {
    int secondsFromNow = 10,
    String languageCode = 'en',
  }) async {
    if (!_initialized) return;
    final l10n = languageCode == 'es'
        ? AppLocalizationsEs()
        : AppLocalizationsEn();
    final langCode = l10n.localeName;
    final title = '${entry.bill.name} — ${l10n.notificationTomorrow}';
    final body =
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : l10n.notificationBillLabel} — ${l10n.dueThe(entry.bill.dueDayOfMonth)}';
    final payload = jsonEncode({
      'notifId': 999999,
      'title': title,
      'body': body,
      'langCode': langCode,
    });

    final scheduledDate = tz.TZDateTime.now(tz.local).add(
      Duration(seconds: secondsFromNow),
    );
    await _plugin.zonedSchedule(
      999999,
      title,
      body,
      scheduledDate,
      _reminderDetails(l10n, importance: Importance.high, priority: Priority.high),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Handle a snooze action that launched the app from a terminated state.
  /// The foreground response callback isn't invoked in that case, so the tap
  /// has to be recovered from the launch details. Call once on startup.
  Future<void> handleLaunchSnooze() async {
    if (!_initialized) return;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return;
    final response = details.notificationResponse;
    final actionId = response?.actionId;
    if (response == null || actionId == null || !actionId.startsWith('snooze_')) {
      return;
    }
    await _scheduleSnooze(response);
  }

  /// Called from the foreground notification response handler.
  Future<void> _scheduleSnooze(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final notifId = data['notifId'] as int;
    final title = data['title'] as String;
    final body = data['body'] as String;
    final langCode = data['langCode'] as String;
    // Older payloads predate the flag; they were all regular reminders.
    final isOverdue = data['overdue'] as bool? ?? false;
    // Snoozing shares the notification ID with the original schedule, so
    // rescheduling overwrites it. For the open-ended daily overdue repeat that
    // must not mean a one-shot: the ladder takeover already cancelled every
    // other reminder for the bill, and a one-shot here would silently end the
    // nagging once it fired. Keep it repeating — it nags at the snoozed time
    // until the next launch's scheduling pass snaps it back to 9:00.
    final isRepeating = data['repeating'] as bool? ?? false;

    final snoozeTime = _computeSnoozeTime(response.actionId!);
    if (snoozeTime == null) return;

    final l10n =
        langCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();

    await _plugin.cancel(notifId);
    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      snoozeTime,
      isOverdue ? _overdueDetails(l10n) : _reminderDetails(l10n),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: isRepeating ? DateTimeComponents.time : null,
      payload: jsonEncode(data),
    );

    _showSnoozeConfirmation(snoozeTime, l10n);
  }

  /// Show an in-app confirmation that the reminder was rescheduled. Runs on the
  /// main isolate; if the widget tree isn't mounted yet (cold start), it waits
  /// for the first frame.
  void _showSnoozeConfirmation(tz.TZDateTime snoozeTime, AppLocalizations l10n) {
    void show() {
      final messenger = rootScaffoldMessengerKey.currentState;
      final context = rootScaffoldMessengerKey.currentContext;
      if (messenger == null || context == null) return;
      final timeLabel = TimeOfDay.fromDateTime(snoozeTime).format(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.reminderRescheduledFor(timeLabel))),
        );
    }

    if (rootScaffoldMessengerKey.currentState != null) {
      show();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    }
  }

  Future<void> cancelForInstance(int instanceId) async {
    if (!_initialized) return;
    for (final offset in [..._kAllOffsets, ..._kOffsetsOverdueLadder]) {
      await _plugin.cancel(_notificationId(instanceId, offset));
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  int _notificationId(int instanceId, int offset) {
    // Combine instanceId and reminder offset into a unique int.
    // instanceId * 10 + offset (offset is one of _kAllOffsets, 0..3).
    return instanceId * 10 + offset;
  }
}
