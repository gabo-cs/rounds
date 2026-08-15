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

import 'package:rounds/data/models/currency.dart';
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
const _kOffsetDueToday = 3;

// Slots for the proactive overdue ladder: one-shot pings on the 2nd and 3rd day
// after the due date (the 1st day reuses the frozen overdue slot 0). Still
// within the instanceId*10+offset scheme, so no collisions with other kinds.
const _kOffsetsOverdueLadder = [4, 5];

// Retired slots. Nothing plans them any more, but an install upgrading from a
// version that did still has them armed — so every path that clears an
// instance keeps clearing them until they expire on their own. Slot 2 held
// the due−2 reminder (one nag two days ahead was judged one too many); 6–9
// carried days 4–7 of the original seven-day overdue ladder.
const _kOffsetRetiredIn2Days = 2;
const _kOffsetsRetired = [_kOffsetRetiredIn2Days, 6, 7, 8, 9];

// Every slot an instance can occupy, for the paths that retire it wholesale.
const _kEveryOffset = [
  _kOffsetOverdue,
  _kOffsetTomorrow,
  _kOffsetDueToday,
  ..._kOffsetsOverdueLadder,
  ..._kOffsetsRetired,
];

/// How far ahead reminders are armed.
///
/// This is the rolling window, and it is the whole reason the schedule stays
/// small enough to re-arm blindly on every launch. It is a span of *days*, not
/// a count of months: what it costs depends on how many bills fall due soon,
/// not on how many bills exist.
///
/// 35 days because a monthly bill's due dates are at most 31 days apart (the
/// due day is capped at 28). So the next occurrence of every bill is always
/// armed, with slack — the app can go unopened for a month and stay useful.
const kReminderHorizon = Duration(days: 35);

/// The proactive overdue schedule for a bill due on [dueDate]: one ping per day
/// for the three days after it. Kept pure so the date math (month and year
/// rollovers) is unit-testable.
///
/// A repeating notification cannot express "daily starting on a future date":
/// the plugin snaps a repeating schedule to the next time-of-day match on both
/// platforms, which would cry "overdue" before the bill is even due. Hence a
/// ladder of one-shots. It only has to bridge the gap until the app is next
/// opened, at which point the open-ended daily repeat takes over and nags
/// without limit (see [plannedRemindersFor]).
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

/// Pause between the individual platform calls of a bulk pass.
///
/// Every zonedSchedule/cancel is handled on the *Android main thread*, where
/// flutter_local_notifications rewrites its entire persisted schedule (a Gson
/// load + save of the whole list) for each call. That thread is also the one
/// that forwards touch events to the UI isolate, so an uninterrupted run of
/// calls swallows input.
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

/// What one instance needs done to it: notifications to arm, and IDs to clear
/// first. [clear] is never derived from what the platform reports — see
/// [NotificationService.applyReminderPlans] for why that isn't knowable.
typedef ReminderPlan = ({List<PlannedNotification> arm, List<int> clear});

/// One notification the app wants armed, described completely.
///
/// Pure data, so the entire schedule can be computed and tested without a
/// platform.
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

  /// The payload stored alongside the notification. It has to be
  /// self-contained: the background snooze handler runs in a fresh isolate and
  /// can read nothing else from the app.
  String get payload => jsonEncode({
        'notifId': id,
        'title': title,
        'body': body,
        'langCode': languageCode,
        'overdue': overdue,
        'repeating': repeat == NotificationRepeat.daily,
      });

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

/// What [entry] should have armed right now: the notifications to (re-)issue,
/// and the IDs to clear first.
///
/// Pure, so the whole schedule is built and unit-tested without a single
/// platform call. Reminders whose 9:00 slot has already passed are omitted —
/// there is nothing left to arm for them.
///
/// The same function covers a previous-month instance: its upcoming reminders
/// have all lapsed, leaving exactly the open-ended overdue repeat that keeps
/// the nagging alive past month rollover.
ReminderPlan plannedRemindersFor(
  BillInstanceWithBill entry, {
  required DateTime now,
  required String languageCode,
  required Currency currency,
}) {
  final l10n = _l10nFor(languageCode);
  final langCode = l10n.localeName;
  final dueDate = DateTime(
    entry.instance.year,
    entry.instance.month,
    entry.bill.dueDayOfMonth,
  );
  final today = DateTime(now.year, now.month, now.day);

  if (entry.instance.isPaid || entry.bill.isArchived) {
    // Marking paid, archiving and deleting all cancel outright, so this is
    // only a backstop for a cancel that was lost. Clear the overdue slot and
    // nothing else: it holds the one alarm that repeats without end, and so is
    // the only one that could nag forever. The rest are one-shots that expire.
    return (
      arm: const [],
      clear: dueDate.isBefore(today)
          ? [_notificationId(entry.instance.id, _kOffsetOverdue)]
          : const [],
    );
  }

  // Past the horizon there is nothing to arm yet — a later launch picks it up
  // once the bill comes into range. This is what keeps the pass small enough
  // to re-issue blindly.
  if (dueDate.isAfter(today.add(kReminderHorizon))) {
    return (arm: const [], clear: const []);
  }

  final amountLabel = entry.bill.amount != null
      ? currency.format(entry.bill.amount!)
      : l10n.notificationBillLabel;

  final plan = <PlannedNotification>[];
  final clear = <int>[];

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
    (idOffset: _kOffsetTomorrow, daysBefore: 1),
    (idOffset: _kOffsetDueToday, daysBefore: 0),
  ];
  final labels = [
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
    // Already overdue → an open-ended daily repeat from the next 9:00. This is
    // the takeover: it replaces the ladder, so the ladder's remaining pings
    // must be cleared or they double up with it.
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
    clear.addAll([
      for (final offset in [..._kOffsetsOverdueLadder, ..._kOffsetsRetired])
        _notificationId(entry.instance.id, offset),
    ]);
  } else {
    // Not yet overdue → one-shot pings for the days after the due date, so the
    // nagging starts even if the app is never reopened. A launch once it is
    // overdue replaces them with the open-ended repeat above.
    for (final step in overdueLadder(dueDate)) {
      addOneShot(
        offset: step.offset,
        title: overdueTitle,
        body: overdueBody,
        fireDay: step.fireDay,
        overdue: true,
      );
    }
    // An upgraded install may still have the retired due−2 ping armed for
    // this not-yet-due bill; nothing overwrites that slot any more, so it
    // would fire once unless cleared here.
    clear.add(_notificationId(entry.instance.id, _kOffsetRetiredIn2Days));
  }

  return (arm: plan, clear: clear);
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

  /// Apply [plans]: clear what each supersedes, then arm what it asks for.
  ///
  /// **Deliberately blind.** It re-issues every notification whether or not the
  /// platform already has it, and never asks what is armed.
  ///
  /// It cannot usefully ask. An alarm can be cancelled without the app being
  /// told — a force-stop, or an OEM battery manager — and Android offers no way
  /// to query whether one still exists. `pendingNotificationRequests()` looks
  /// like that query but answers from the plugin's own SharedPreferences
  /// mirror, which a force-stop leaves perfectly intact. Trusting it means
  /// concluding everything is fine and repairing nothing, forever: only a
  /// reboot or an app update re-registers the alarms, and a force-stopped app
  /// doesn't even receive the boot broadcast.
  ///
  /// So re-issuing *is* the repair, and it has to happen every session. What
  /// makes that affordable is [kReminderHorizon] keeping the schedule small.
  Future<void> applyReminderPlans(Iterable<ReminderPlan> plans) async {
    if (!await _ready()) return;

    var issued = 0;
    Future<void> pace() async {
      if (issued++ > 0) {
        await Future<void>.delayed(kNotificationSchedulePacing);
      }
    }

    for (final plan in plans) {
      for (final id in plan.clear) {
        await pace();
        await _plugin.cancel(id);
      }
      for (final notification in plan.arm) {
        await pace();
        await _schedule(notification);
      }
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
  /// bill turns out to be past due again, so the effect is immediate instead of
  /// waiting for the next launch.
  Future<void> scheduleOverdueReminderForInstance(
    BillInstanceWithBill entry, {
    String languageCode = 'en',
    required Currency currency,
  }) =>
      applyReminderPlans([
        plannedRemindersFor(
          entry,
          now: DateTime.now(),
          languageCode: languageCode,
          currency: currency,
        ),
      ]);

  Future<void> scheduleTestNotification(
    BillInstanceWithBill entry, {
    int secondsFromNow = 10,
    String languageCode = 'en',
    required Currency currency,
  }) async {
    if (!await _ready()) return;
    final l10n = _l10nFor(languageCode);
    final langCode = l10n.localeName;
    final title = '${entry.bill.name} — ${l10n.notificationTomorrow}';
    final amountLabel = entry.bill.amount != null
        ? currency.format(entry.bill.amount!)
        : l10n.notificationBillLabel;
    final body = '$amountLabel — ${l10n.dueThe(entry.bill.dueDayOfMonth)}';
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

  /// Retire every reminder of [instanceIds] — for bills being paid, archived or
  /// deleted. Clears every slot an instance can occupy, including the retired
  /// ladder slots that an upgraded install may still have armed.
  Future<void> cancelForInstances(Iterable<int> instanceIds) =>
      applyReminderPlans([
        for (final instanceId in instanceIds)
          (
            arm: const [],
            clear: [
              for (final offset in _kEveryOffset)
                _notificationId(instanceId, offset),
            ],
          ),
      ]);

  Future<void> cancelForInstance(int instanceId) =>
      cancelForInstances([instanceId]);

  Future<void> cancelAll() async {
    if (!await _ready()) return;
    await _plugin.cancelAll();
  }
}
