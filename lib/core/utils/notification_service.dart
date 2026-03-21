import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

      // Don't schedule notifications in the past
      if (notifyDate.isBefore(DateTime.now())) continue;

      final scheduledDate = tz.TZDateTime.from(
        DateTime(notifyDate.year, notifyDate.month, notifyDate.day, 9, 0),
        tz.local,
      );

      final notifId = _notificationId(entry.instance.id, offsetDays);
      final dayLabel = offsetDays == 1 ? 'tomorrow' : 'in 2 days';

      await _plugin.zonedSchedule(
        notifId,
        '${entry.bill.name} due $dayLabel',
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : 'Bill'} due on the ${_ordinal(dueDay)}',
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'bill_reminders',
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
