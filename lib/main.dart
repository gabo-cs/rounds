import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/app.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/data/models/currency.dart';
import 'package:rounds/features/round/providers/round_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Re-arm pass timing ───────────────────────────────────────────────────────
// The pass's 30–60 platform calls are all serviced by the Android main thread,
// which also delivers touch events — running them right after launch is what
// used to make the first seconds of scrolling stutter. So the pass runs when
// the app is *hidden* instead: backgrounding always passes through that state,
// so every normally-ended session re-arms, and at that moment there is no
// input to fight.

/// Debounce between hide-triggered passes, so rapid app-switching (share
/// sheets, pickers) doesn't re-run a pass that just completed.
const _kReminderPassMinInterval = Duration(minutes: 15);

/// Launch fallback threshold: if no pass has completed in this long, the
/// session before this one ended without reaching the hide listener (a crash,
/// a dead battery) — run one shortly after launch instead, the old way. The
/// 35-day horizon means a single missed pass has a month of slack, so a day
/// is comfortably tight enough.
const _kReminderPassStaleAfter = Duration(hours: 24);

const _kLastReminderPassKey = 'last_reminder_pass_millis';

// Held so the listener is rooted for the life of the process.
AppLifecycleListener? _lifecycleListener;
bool _reminderPassRunning = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The only thing the first frame genuinely waits on: the theme and locale
  // come from here, so reading it later would mean rendering the wrong ones
  // and flashing.
  final prefs = await SharedPreferences.getInstance();

  // Share one container with the app so startup scheduling and the UI use the
  // same database instance.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Kick the drift background isolate awake and start loading the shared active
  // bills now, before the first frame's month pages need them — so the initial
  // pages (and the first swipe's neighbour) don't wait on a cold DB spawn.
  container.read(activeBillsProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RoundsApp(),
    ),
  );

  // Only what can't wait for the user to leave runs near launch: plugin init
  // (which includes the timezone database parse — hundreds of milliseconds on
  // the UI isolate) and cold-start snooze recovery. Deferred past the first
  // frame plus a settle so the app is interactive from the moment it appears.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(
      const Duration(seconds: 2),
      () => _initNotifications(container, prefs),
    );
  });

  _lifecycleListener = AppLifecycleListener(
    onHide: () => _runReminderPassIfDue(
      container,
      prefs,
      minInterval: _kReminderPassMinInterval,
    ),
  );
}

Future<void> _initNotifications(
  ProviderContainer container,
  SharedPreferences prefs,
) async {
  // A notification-setup failure must never take the app down with it —
  // notifications are non-essential to using it.
  try {
    await NotificationService.instance.initialize();
    // Recover a snooze tap that cold-started the app from a terminated state.
    await NotificationService.instance.handleLaunchSnooze();
  } catch (e, st) {
    debugPrint('Notification setup failed: $e\n$st');
  }

  // The stale-launch fallback: normally the hide listener keeps the schedule
  // fresh and this is a no-op.
  await _runReminderPassIfDue(
    container,
    prefs,
    minInterval: _kReminderPassStaleAfter,
  );
}

Future<void> _runReminderPassIfDue(
  ProviderContainer container,
  SharedPreferences prefs, {
  required Duration minInterval,
}) async {
  // Respect the in-app toggle: scheduling here would silently re-arm
  // reminders the user turned off.
  if (!(prefs.getBool('notifications_enabled') ?? true)) return;
  if (_reminderPassRunning) return;

  final now = DateTime.now();
  final due = reminderPassIsDue(
    lastCompletedMillis: prefs.getInt(_kLastReminderPassKey),
    now: now,
    minInterval: minInterval,
  );
  if (!due) return;

  _reminderPassRunning = true;
  try {
    // Read straight from prefs rather than through the settings notifier: this
    // runs outside the widget tree, and the stored name is the same source.
    final languageCode = prefs.getString('language_code') ?? 'en';
    final currency = Currency.values.firstWhere(
      (c) => c.name == prefs.getString('currency'),
      orElse: () => Currency.cop,
    );
    await refreshReminderSchedule(
      billsRepo: container.read(billsRepositoryProvider),
      instancesRepo: container.read(billInstancesRepositoryProvider),
      languageCode: languageCode,
      currency: currency,
    );
    // Only a completed pass counts — an interrupted one must stay due.
    await prefs.setInt(_kLastReminderPassKey, now.millisecondsSinceEpoch);
  } catch (e, st) {
    debugPrint('Reminder pass failed: $e\n$st');
  } finally {
    _reminderPassRunning = false;
  }
}
