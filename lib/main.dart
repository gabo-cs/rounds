import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/app.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never let a notification-setup failure strand the app on the splash screen
  // — notifications are non-essential to launching, so degrade gracefully.
  try {
    await NotificationService.instance.initialize();
    // Recover a snooze tap that cold-started the app from a terminated state.
    await NotificationService.instance.handleLaunchSnooze();
  } catch (e, st) {
    debugPrint('Notification init failed: $e\n$st');
  }
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString('language_code') ?? 'en';
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

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

  // Notification scheduling fires dozens of platform-channel calls whose
  // responses land back on the UI isolate. Doing that during cold start floods
  // the UI thread right when the user's first swipe wants those frames, which
  // shows up as early stutter that clears once the calls drain. Defer it until
  // after the first frame and a short settle — the reminders are for future
  // days, so the delay is immaterial.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Respect the in-app toggle: scheduling here would silently re-arm
    // reminders the user turned off.
    if (!notificationsEnabled) return;
    Future.delayed(const Duration(seconds: 2), () async {
      await NotificationService.instance.scheduleMonthlyKickoff(
        languageCode: languageCode,
      );
      await scheduleUpcomingReminders(
        billsRepo: container.read(billsRepositoryProvider),
        instancesRepo: container.read(billInstancesRepositoryProvider),
        prefs: prefs,
        languageCode: languageCode,
      );
    });
  });
}
