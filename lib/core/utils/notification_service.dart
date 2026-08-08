import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// latest_all, despite being the biggest of the three bundled databases: it is
// the only one carrying the full 596 zones. `latest` and `latest_10y` ship 431
// — they drop legacy aliases (Asia/Calcutta, US/Michigan) but also current
// canonical zones (America/Ciudad_Juarez, America/Nuuk, America/Punta_Arenas,
// Asia/Yangon, Pacific/Bougainville). A device reporting one of those would
// fail the lookup below and silently fall back, putting every reminder hours
// off. Initialization is deferred well past the first frame, so its parse cost
// buys nothing worth that risk.
import 'package:timezone/data/latest_all.dart' as tz;
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
/// open-ended daily repeat (see [plannedRemindersFor]).
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
const _kTestNotificationId = 999999;

// IDs outside the instanceId*10+offset scheme. [NotificationService.reconcile]
// must never mistake them for an instance's slot and cancel them.
const _kReservedIds = {_kMonthlyKickoffId, _kTestNotificationId};

/// Pause between the individual platform calls of a bulk scheduling pass.
///
/// Every zonedSchedule/cancel is handled on the *Android main thread*, where
/// flutter_local_notifications rewrites its entire persisted schedule (a Gson
/// load + save of the whole list) for each call. That thread is also the one
/// that forwards touch events to the UI isolate, so an uninterrupted run of
/// calls swallows input. Yielding between calls keeps the thread reachable.
/// [NotificationService.reconcile] makes such runs rare; the pacing is what
/// keeps the rare ones from being felt.
const kNotificationSchedulePacing = Duration(milliseconds: 16);

/// The `Etc/GMT` zone closest to [offset], for when the device's real zone
/// can't be resolved.
///
/// A synthetic [tz.Location] would not survive the trip: iOS is handed the zone
/// *name* as text and re-resolves it against Apple's database, so the fallback
/// has to be a name both databases know. The `Etc/GMT` zones qualify.
///
/// Two limits, each far smaller than the UTC this replaces. The names exist on
/// whole hours only, so a half-hour zone lands up to 30 minutes off. And they
/// carry no DST, so a reminder on the far side of the next transition is an
/// hour off.
String etcGmtZoneName(Duration offset) {
  // POSIX sign convention, inverted from the usual one: Etc/GMT+5 is UTC-5.
  // The names run from Etc/GMT+12 (UTC-12) to Etc/GMT-14 (UTC+14).
  final hours = (offset.inMinutes / 60).round().clamp(-12, 14);
  return hours <= 0 ? 'Etc/GMT+${-hours}' : 'Etc/GMT-$hours';
}

AppLocalizations _l10nFor(String languageCode) =>
    languageCode == 'es' ? AppLocalizationsEs() : AppLocalizationsEn();

int _notificationId(int instanceId, int offset) => instanceId * 10 + offset;

// ── The desired schedule ─────────────────────────────────────────────────────

/// How a notification recurs. Drives `matchDateTimeComponents`, which the
/// plugin snaps to the *next* component match — see [overdueLadder].
enum NotificationRepeat { none, daily, monthly }

/// One notification the app wants armed, described completely.
///
/// Pure data, so the entire desired schedule can be computed and compared
/// against what the platform already has before any channel call is made.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.languageCode,
    this.overdue = false,
    this.repeat = NotificationRepeat.none,
    this.snoozable = true,
  });

  final int id;
  final String title;
  final String body;

  /// Local wall-clock time of the first firing. For a repeating notification
  /// only the recurring components matter (time of day, plus day of month for
  /// [NotificationRepeat.monthly]) — the plugin ignores the rest.
  final DateTime fireAt;
  final String languageCode;
  final bool overdue;
  final NotificationRepeat repeat;
  final bool snoozable;

  /// The payload stored alongside the notification.
  ///
  /// It carries everything the background snooze handler needs — which must be
  /// self-contained — *and* doubles as the armed-state fingerprint: [reconcile]
  /// re-arms only when the payload it would write differs from the one already
  /// armed. So every field that affects the copy or the schedule belongs here,
  /// and the key order must stay fixed for the comparison to be meaningful.
  ///
  /// Snoozing re-encodes this map with a `snoozed` marker, which makes the
  /// fingerprint differ and lets the next pass snap the reminder back to its
  /// canonical time.
  String get payload => jsonEncode({
        'notifId': id,
        'title': title,
        'body': body,
        'langCode': languageCode,
        'overdue': overdue,
        'repeating': repeat == NotificationRepeat.daily,
        'at': _scheduleKey,
      });

  // Only the parts of [fireAt] the plugin actually honours, so a repeating
  // reminder's fingerprint stays stable from one day (or month) to the next
  // instead of churning a re-arm out of every pass.
  String get _scheduleKey => switch (repeat) {
        NotificationRepeat.none => fireAt.toIso8601String(),
        NotificationRepeat.daily => 'daily@${fireAt.hour}:${fireAt.minute}',
        NotificationRepeat.monthly =>
          'monthly@${fireAt.day}T${fireAt.hour}:${fireAt.minute}',
      };

  DateTimeComponents? get _matchComponents => switch (repeat) {
        NotificationRepeat.none => null,
        NotificationRepeat.daily => DateTimeComponents.time,
        NotificationRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
      };

  NotificationDetails _details() {
    final l10n = _l10nFor(languageCode);
    if (overdue) return _overdueDetails(l10n);
    return snoozable ? _reminderDetails(l10n) : _generalDetails();
  }
}

/// Every reminder [entry] should currently have armed, or an empty list if it
/// should have none (paid, or belonging to an archived bill).
///
/// The full ladder — "in 2 days", "tomorrow", "due today", then the overdue
/// nagging — is a pure function of the instance, the bill and today's date, so
/// the whole desired schedule can be built without a single platform call.
/// Reminders whose 9:00 slot has already passed are omitted: there is nothing
/// left to arm for them.
///
/// The same function covers a previous-month instance: its upcoming reminders
/// have all lapsed, leaving exactly the open-ended overdue repeat that keeps
/// the nagging alive past month rollover.
List<PlannedNotification> plannedRemindersFor(
  BillInstanceWithBill entry, {
  required DateTime now,
  required String languageCode,
}) {
  if (entry.instance.isPaid || entry.bill.isArchived) return const [];

  final l10n = _l10nFor(languageCode);
  final langCode = l10n.localeName;
  final dueDate = DateTime(
    entry.instance.year,
    entry.instance.month,
    entry.bill.dueDayOfMonth,
  );
  final today = DateTime(now.year, now.month, now.day);
  final amountLabel = entry.bill.amount != null
      ? '\$${entry.bill.amount!.toStringAsFixed(2)}'
      : l10n.notificationBillLabel;

  final plan = <PlannedNotification>[];

  void addOneShot({
    required int offset,
    required String title,
    required String body,
    required DateTime fireDay,
    bool overdue = false,
  }) {
    final fireAt = DateTime(fireDay.year, fireDay.month, fireDay.day, 9);
    if (fireAt.isBefore(now)) return;
    plan.add(
      PlannedNotification(
        id: _notificationId(entry.instance.id, offset),
        title: title,
        body: body,
        fireAt: fireAt,
        languageCode: langCode,
        overdue: overdue,
      ),
    );
  }

  // Upcoming + due-today reminders. Each entry pairs a notification-ID slot
  // with how many days before the due date it fires — the two are independent
  // (the ID slot stays fixed for upgrade compatibility, the days-before drives
  // the date).
  const upcoming = <({int idOffset, int daysBefore})>[
    (idOffset: _kOffsetIn2Days, daysBefore: 2),
    (idOffset: _kOffsetTomorrow, daysBefore: 1),
    (idOffset: _kOffsetDueToday, daysBefore: 0),
  ];
  final labels = [
    l10n.notificationIn2Days,
    l10n.notificationTomorrow,
    l10n.notificationDueToday,
  ];
  for (var i = 0; i < upcoming.length; i++) {
    addOneShot(
      offset: upcoming[i].idOffset,
      title: '${entry.bill.name} — ${labels[i]}',
      body: '$amountLabel — ${l10n.dueThe(entry.bill.dueDayOfMonth)}',
      fireDay: dueDate.subtract(Duration(days: upcoming[i].daysBefore)),
    );
  }

  // The month matters in the overdue copy: the previous month is inside the
  // scheduling window, and "was due the 5th" alone would read as this month's
  // bill.
  final overdueTitle = '${entry.bill.name} — ${l10n.overdue}';
  final overdueBody = '$amountLabel — ${l10n.overdueSinceDate(dueDate)}';

  if (dueDate.isBefore(today)) {
    // Already overdue → an open-ended daily repeat from the next 9:00. The
    // ladder's remaining pings are not planned, so [reconcile] retires them
    // and they can't double up with this.
    var start = DateTime(now.year, now.month, now.day, 9);
    if (start.isBefore(now)) {
      start = DateTime(now.year, now.month, now.day + 1, 9);
    }
    plan.add(
      PlannedNotification(
        id: _notificationId(entry.instance.id, _kOffsetOverdue),
        title: overdueTitle,
        body: overdueBody,
        fireAt: start,
        languageCode: langCode,
        overdue: true,
        repeat: NotificationRepeat.daily,
      ),
    );
  } else {
    // Not yet overdue → a week of one-shot pings starting the day after the
    // due date, so nagging continues even if the app is never reopened. A
    // launch during that week replaces them with the open-ended repeat above.
    for (final step in overdueLadder(dueDate)) {
      addOneShot(
        offset: step.offset,
        title: overdueTitle,
        body: overdueBody,
        fireDay: step.fireDay,
        overdue: true,
      );
    }
  }

  return plan;
}

/// The general "a new round of bills" reminder, repeating on the 1st of every
/// month at 9:00. Device-month based and unrelated to the month being viewed.
PlannedNotification monthlyKickoffPlan({
  required DateTime now,
  required String languageCode,
}) {
  final l10n = _l10nFor(languageCode);
  var first = DateTime(now.year, now.month, 1, 9);
  // Rolls the year over on its own when now is in December.
  if (first.isBefore(now)) first = DateTime(now.year, now.month + 1, 1, 9);
  return PlannedNotification(
    id: _kMonthlyKickoffId,
    title: l10n.monthlyReminderTitle,
    body: l10n.monthlyReminderBody,
    fireAt: first,
    languageCode: l10n.localeName,
    repeat: NotificationRepeat.monthly,
    snoozable: false,
  );
}

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

  final l10n = _l10nFor(langCode);
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
    payload: jsonEncode(_markSnoozed(data)),
  );
}

/// Tag a payload as rescheduled by the user. The marker makes it differ from
/// the payload [NotificationService.reconcile] would write, which is what lets
/// the next scheduling pass snap the reminder back to its canonical 9:00.
Map<String, dynamic> _markSnoozed(Map<String, dynamic> payload) =>
    {...payload, 'snoozed': true};

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

  Future<void>? _initialization;

  /// Set up the timezone database and the plugin. Idempotent, and safe to call
  /// concurrently — later callers await the first call's result.
  Future<void> initialize() async {
    final pending = _initialization;
    if (pending != null) return pending;

    final started = _initialize();
    _initialization = started;
    try {
      await started;
    } catch (_) {
      // A failed setup must not be cached as done: the next caller retries.
      _initialization = null;
      rethrow;
    }
  }

  /// Guard for every entry point that talks to the plugin.
  ///
  /// Startup initialization is deferred until after the first frame, so a user
  /// action can easily arrive first — marking a bill paid seconds after launch
  /// has to cancel its reminders, and dropping that would leave them nagging
  /// for a paid bill. Awaiting here makes the action wait for setup instead.
  /// Notifications are non-essential, so a failure degrades to a no-op.
  Future<bool> _ready() async {
    try {
      await initialize();
      return true;
    } catch (e, st) {
      debugPrint('Notification init failed: $e\n$st');
      return false;
    }
  }

  Future<void> _initialize() async {
    tz.initializeTimeZones();
    await _setLocalTimezone();

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
  }

  /// Point [tz.local] at the device's zone, or as close as we can get.
  ///
  /// Detection can fail, and the database can lack the reported zone. Falling
  /// back to UTC — as this used to — fires every reminder at 9:00 UTC, which is
  /// the middle of the night across much of the world. The device's own offset
  /// is a far better guess.
  Future<void> _setLocalTimezone() async {
    try {
      tz.setLocalLocation(
        tz.getLocation(await FlutterTimezone.getLocalTimezone()),
      );
      return;
    } catch (e) {
      debugPrint('Timezone lookup failed ($e); using the device offset');
    }

    try {
      tz.setLocalLocation(
        tz.getLocation(etcGmtZoneName(DateTime.now().timeZoneOffset)),
      );
    } catch (e) {
      debugPrint('Offset fallback failed ($e); using UTC');
      tz.setLocalLocation(tz.UTC);
    }
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

  /// Drive the platform's schedule to match [plan], issuing only the calls that
  /// actually change something.
  ///
  /// Every zonedSchedule and cancel is handled on the Android main thread,
  /// where the plugin rewrites its whole persisted schedule per call — so a
  /// blind re-arm of a few hundred reminders monopolises the very thread that
  /// forwards touch events, and the app stops responding for seconds. Since
  /// both the IDs and the copy are pure functions of the database, the armed
  /// state can simply be read back once and diffed: in the steady state this
  /// pass costs a single platform call and issues nothing.
  ///
  /// [managedInstanceIds] scopes what may be *retired*: any armed notification
  /// in those instances' ID ranges that [plan] doesn't ask for is cancelled.
  /// Instances outside the set are left untouched, so a pass over one month
  /// can't disarm another's.
  ///
  /// The first run after an upgrade that changes the payload format re-arms
  /// everything once, because no armed payload can match. That is the intended
  /// cost of making the fingerprint exact.
  Future<void> reconcile({
    required List<PlannedNotification> plan,
    required Set<int> managedInstanceIds,
  }) async {
    if (!await _ready()) return;

    final pending = await _plugin.pendingNotificationRequests();
    final armed = {for (final request in pending) request.id: request.payload};
    final desiredIds = {for (final notification in plan) notification.id};

    // Only slots belonging to the managed instances are ours to cancel. The
    // reserved IDs are excluded because they fall inside some hypothetical
    // instance's range (1000001 would be instance 100000, slot 1) and must
    // outlive any pass.
    final managedIds = <int>{
      for (final instanceId in managedInstanceIds)
        for (var offset = 0; offset < 10; offset++)
          _notificationId(instanceId, offset),
    }..removeAll(_kReservedIds);

    var issued = 0;
    Future<void> pace() async {
      if (issued++ > 0) {
        await Future<void>.delayed(kNotificationSchedulePacing);
      }
    }

    for (final notification in plan) {
      if (armed[notification.id] == notification.payload) continue;
      await pace();
      await _schedule(notification);
    }

    for (final id in armed.keys) {
      if (desiredIds.contains(id) || !managedIds.contains(id)) continue;
      await pace();
      await _plugin.cancel(id);
    }
  }

  Future<void> _schedule(PlannedNotification notification) async {
    final fireAt = tz.TZDateTime(
      tz.local,
      notification.fireAt.year,
      notification.fireAt.month,
      notification.fireAt.day,
      notification.fireAt.hour,
      notification.fireAt.minute,
    );
    await _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      fireAt,
      notification._details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: notification._matchComponents,
      payload: notification.payload,
    );
  }

  /// Re-emit the monthly kickoff, used when the language changes. Unconditional
  /// rather than reconciled: it's a single call on a rare user action.
  Future<void> scheduleMonthlyKickoff({String languageCode = 'en'}) async {
    if (!await _ready()) return;
    await _schedule(
      monthlyKickoffPlan(now: DateTime.now(), languageCode: languageCode),
    );
  }

  /// Re-arm one instance's reminders — used when a payment is undone and the
  /// bill turns out to be past due again. Reconciled over that instance alone,
  /// so the ladder pings the open-ended overdue repeat replaces are retired
  /// with it.
  Future<void> scheduleOverdueReminderForInstance(
    BillInstanceWithBill entry, {
    String languageCode = 'en',
  }) async {
    await reconcile(
      plan: plannedRemindersFor(
        entry,
        now: DateTime.now(),
        languageCode: languageCode,
      ),
      managedInstanceIds: {entry.instance.id},
    );
  }

  Future<void> scheduleTestNotification(
    BillInstanceWithBill entry, {
    int secondsFromNow = 10,
    String languageCode = 'en',
  }) async {
    if (!await _ready()) return;
    final l10n = _l10nFor(languageCode);
    final langCode = l10n.localeName;
    final title = '${entry.bill.name} — ${l10n.notificationTomorrow}';
    final body =
        '${entry.bill.amount != null ? '\$${entry.bill.amount!.toStringAsFixed(2)}' : l10n.notificationBillLabel} — ${l10n.dueThe(entry.bill.dueDayOfMonth)}';
    final payload = jsonEncode({
      'notifId': _kTestNotificationId,
      'title': title,
      'body': body,
      'langCode': langCode,
    });

    final scheduledDate = tz.TZDateTime.now(tz.local).add(
      Duration(seconds: secondsFromNow),
    );
    await _plugin.zonedSchedule(
      _kTestNotificationId,
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
    if (!await _ready()) return;
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

    final l10n = _l10nFor(langCode);

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
      payload: jsonEncode(_markSnoozed(data)),
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

  /// Retire every reminder of [instanceIds] — for bills being paid, archived or
  /// deleted. Reconciled against an empty plan, so only the slots actually
  /// armed cost a call: deleting a bill with a year of instances issues a
  /// handful of cancels instead of ten per instance.
  Future<void> cancelForInstances(Iterable<int> instanceIds) =>
      reconcile(plan: const [], managedInstanceIds: instanceIds.toSet());

  Future<void> cancelForInstance(int instanceId) =>
      cancelForInstances([instanceId]);

  Future<void> cancelAll() async {
    if (!await _ready()) return;
    await _plugin.cancelAll();
  }
}
