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

// ── Action helpers ───────────────────────────────────────────────────────────

List<AndroidNotificationAction> _androidActions(AppLocalizations l10n) => [
      AndroidNotificationAction(_kActionSnooze30, l10n.snooze30Min,
          cancelNotification: true, showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze60, l10n.snooze1Hour,
          cancelNotification: true, showsUserInterface: true),
      AndroidNotificationAction(_kActionSnooze180, l10n.snooze3Hours,
          cancelNotification: true, showsUserInterface: true),
    ];

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
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin.cancel(notifId);
  await plugin.zonedSchedule(
    notifId,
    title,
    body,
    snoozeTime,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'bill_reminders_v2',
        'Bill Reminders',
        channelDescription: 'Reminders for upcoming bill due dates',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        actions: _androidActions(l10n),
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: 'bill_reminder_$langCode',
      ),
    ),
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
        AndroidInitializationSettings('@mipmap/ic_launcher');
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
  /// Sends notifications 2 days before and 1 day before the due date.
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
    final langCode = l10n.localeName;

    final offsets = [2, 1]; // days before due
    for (final offsetDays in offsets) {
      final notifyDate = dueDate.subtract(Duration(days: offsetDays));
      final scheduledDate = tz.TZDateTime.from(
        DateTime(notifyDate.year, notifyDate.month, notifyDate.day, 9, 0),
        tz.local,
      );

      // Don't schedule notifications in the past
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final notifId = _notificationId(entry.instance.id, offsetDays);
      final dayLabel = offsetDays == 1
          ? l10n.notificationTomorrow
          : l10n.notificationIn2Days;
      final title = '${entry.bill.name} — $dayLabel';
      final body =
          '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : l10n.notificationBillLabel} — ${l10n.dueThe(dueDay)}';
      final payload = jsonEncode({
        'notifId': notifId,
        'title': title,
        'body': body,
        'langCode': langCode,
      });

      await _plugin.zonedSchedule(
        notifId,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_reminders_v2',
            'Bill Reminders',
            channelDescription: 'Reminders for upcoming bill due dates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            actions: _androidActions(l10n),
          ),
          iOS: DarwinNotificationDetails(
            categoryIdentifier: 'bill_reminder_$langCode',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders_v2',
          'Bill Reminders',
          channelDescription: 'Reminders for upcoming bill due dates',
          importance: Importance.high,
          priority: Priority.high,
          actions: _androidActions(l10n),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'bill_reminder_$langCode',
        ),
      ),
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders_v2',
          'Bill Reminders',
          channelDescription: 'Reminders for upcoming bill due dates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          actions: _androidActions(l10n),
        ),
        iOS: DarwinNotificationDetails(
          categoryIdentifier: 'bill_reminder_$langCode',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(data),
    );
  }

  Future<void> cancelForInstance(int instanceId) async {
    if (!_initialized) return;
    for (final offset in [1, 2]) {
      await _plugin.cancel(_notificationId(instanceId, offset));
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  int _notificationId(int instanceId, int offsetDays) {
    // Combine instanceId and offset into a unique int.
    // instanceId * 10 + offset (offset is 1 or 2)
    return instanceId * 10 + offsetDays;
  }
}
