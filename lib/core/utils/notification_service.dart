import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:rounds/data/repositories/bill_instances_repository.dart';

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
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
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
    int month,
  ) async {
    if (!_initialized) return;

    for (final entry in instances) {
      if (entry.instance.isPaid) continue;
      await _scheduleRemindersForInstance(entry, year, month);
    }
  }

  Future<void> _scheduleRemindersForInstance(
    BillInstanceWithBill entry,
    int year,
    int month,
  ) async {
    final dueDay = entry.bill.dueDayOfMonth;
    final dueDate = DateTime(year, month, dueDay);

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
      final dayLabel = offsetDays == 1 ? 'tomorrow' : 'in 2 days';

      await _plugin.zonedSchedule(
        notifId,
        '${entry.bill.name} due $dayLabel',
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : 'Bill'} due on the ${_ordinal(dueDay)}',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_reminders_v2',
            'Bill Reminders',
            channelDescription: 'Reminders for upcoming bill due dates',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> scheduleTestNotification(
    BillInstanceWithBill entry, {
    int secondsFromNow = 10,
  }) async {
    if (!_initialized) return;
    final scheduledDate = tz.TZDateTime.now(tz.local).add(
      Duration(seconds: secondsFromNow),
    );
    await _plugin.zonedSchedule(
      999999,
      '${entry.bill.name} due tomorrow',
      '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : 'Bill'} due on the ${_ordinal(entry.bill.dueDayOfMonth)}',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bill_reminders_v2',
          'Bill Reminders',
          channelDescription: 'Reminders for upcoming bill due dates',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
