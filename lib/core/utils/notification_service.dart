import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:rounds/data/repositories/bill_instances_repository.dart';
import 'package:rounds/l10n/app_localizations.dart';

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

// ── Action helpers ───────────────────────────────────────────────────────────

List<AndroidNotificationAction> _androidActions(AppLocalizations l10n) => [
      AndroidNotificationAction(_kActionSnooze30, l10n.snooze30Min,
          cancelNotification: true, showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze60, l10n.snooze1Hour,
          cancelNotification: true, showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze180, l10n.snooze3Hours,
          cancelNotification: true, showsUserInterface: true),
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
      android: AndroidInitializationSettings('@drawable/ic_stat_rounds'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.cancel(notifId);
  await plugin.zonedSchedule(
    notifId,
    title,
    body,
    snoozeTime,
    _reminderDetails(l10n),
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
        AndroidInitializationSettings('@drawable/ic_stat_rounds');
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

    for (final entry in instances) {
      if (entry.instance.isPaid) continue;
      await _scheduleRemindersForInstance(entry, year, month, l10n);
    }
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
    final upcoming = <int, String>{
      _kOffsetIn2Days: l10n.notificationIn2Days,
      _kOffsetTomorrow: l10n.notificationTomorrow,
      _kOffsetDueToday: l10n.notificationDueToday,
    };
    for (final offsetDays in upcoming.keys) {
      final fireDay = dueDate.subtract(Duration(days: offsetDays));
      await _scheduleOneShot(
        notifId: _notificationId(entry.instance.id, offsetDays),
        title: '${entry.bill.name} — ${upcoming[offsetDays]}',
        body: '$amountLabel — ${l10n.dueThe(dueDay)}',
        fireDay: fireDay,
        l10n: l10n,
        // If the app is opened on the due date after 9:00, still nudge instead
        // of silently dropping the "due today" reminder.
        catchUpSameDay: offsetDays == _kOffsetDueToday,
      );
    }

    // Overdue reminder.
    final overdueTitle = '${entry.bill.name} — ${l10n.overdue}';
    final overdueBody = '$amountLabel — ${l10n.overdueSince(dueDay)}';
    if (dueDate.isBefore(todayDate)) {
      // Already overdue → daily repeating reminder starting at the next 9:00.
      await _scheduleOverdueReminder(entry, l10n);
    } else {
      // Not yet overdue → schedule the first overdue ping for the day after
      // the due date so it fires even if the app is never reopened.
      await _scheduleOneShot(
        notifId: _notificationId(entry.instance.id, _kOffsetOverdue),
        title: overdueTitle,
        body: overdueBody,
        fireDay: dueDate.add(const Duration(days: 1)),
        l10n: l10n,
      );
    }
  }

  /// Schedule a single notification at 9:00 on [fireDay]. Skips days whose
  /// 9:00 slot is already in the past, unless [catchUpSameDay] is set and
  /// [fireDay] is today, in which case it fires shortly from now.
  Future<void> _scheduleOneShot({
    required int notifId,
    required String title,
    required String body,
    required DateTime fireDay,
    required AppLocalizations l10n,
    bool catchUpSameDay = false,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, fireDay.year, fireDay.month, fireDay.day, 9, 0);

    if (scheduledDate.isBefore(now)) {
      final isToday = fireDay.year == now.year &&
          fireDay.month == now.month &&
          fireDay.day == now.day;
      if (catchUpSameDay && isToday) {
        scheduledDate = now.add(const Duration(minutes: 1));
      } else {
        return; // don't schedule in the past
      }
    }

    final payload = jsonEncode({
      'notifId': notifId,
      'title': title,
      'body': body,
      'langCode': l10n.localeName,
    });

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      scheduledDate,
      _reminderDetails(l10n),
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
    final dueDay = entry.bill.dueDayOfMonth;
    final title = '${entry.bill.name} — ${l10n.overdue}';
    final body =
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : l10n.notificationBillLabel}'
        ' — ${l10n.overdueSince(dueDay)}';
    final notifId = _notificationId(entry.instance.id, _kOffsetOverdue);
    final payload = jsonEncode({
      'notifId': notifId,
      'title': title,
      'body': body,
      'langCode': l10n.localeName,
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
      _reminderDetails(l10n),
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

  /// Called from the foreground notification response handler.
  Future<void> _scheduleSnooze(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final notifId = data['notifId'] as int;
    final title = data['title'] as String;
    final body = data['body'] as String;
    final langCode = data['langCode'] as String;

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
      _reminderDetails(l10n),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(data),
    );
  }

  Future<void> cancelForInstance(int instanceId) async {
    if (!_initialized) return;
    for (final offset in _kAllOffsets) {
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
