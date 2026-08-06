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

  // Nothing about notifications is on the path to the first frame, and all of
  // it is expensive: initializing the timezone database is hundreds of
  // milliseconds of parsing on the UI isolate, and every platform call behind
  // it is serviced by the Android main thread — the same thread that delivers
  // touch events. Run it after the first frame, then let the UI settle before
  // touching the platform, so the app is interactive from the moment it
  // appears. The reminders are for future days; seconds of delay are
  // immaterial.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(
      const Duration(seconds: 2),
      () => _setUpNotifications(container, prefs),
    );
  });
}

Future<void> _setUpNotifications(
  ProviderContainer container,
  SharedPreferences prefs,
) async {
  final languageCode = prefs.getString('language_code') ?? 'en';

  // A notification-setup failure must never take the app down with it —
  // notifications are non-essential to using it.
  try {
    await NotificationService.instance.initialize();
    // Recover a snooze tap that cold-started the app from a terminated state.
    await NotificationService.instance.handleLaunchSnooze();

    // Respect the in-app toggle: scheduling here would silently re-arm
    // reminders the user turned off.
    if (!(prefs.getBool('notifications_enabled') ?? true)) return;
    await reconcileNotifications(
      billsRepo: container.read(billsRepositoryProvider),
      instancesRepo: container.read(billInstancesRepositoryProvider),
      languageCode: languageCode,
    );
  } catch (e, st) {
    debugPrint('Notification setup failed: $e\n$st');
  }
}
