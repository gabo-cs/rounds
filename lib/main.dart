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
  await NotificationService.instance.initialize();
  // Recover a snooze tap that cold-started the app from a terminated state.
  await NotificationService.instance.handleLaunchSnooze();
  final prefs = await SharedPreferences.getInstance();
  final languageCode = prefs.getString('language_code') ?? 'en';

  // The monthly "new round of bills" reminder is device-month based, so it's
  // scheduled once here rather than tied to any month being viewed.
  await NotificationService.instance.scheduleMonthlyKickoff(
    languageCode: languageCode,
  );

  // Share one container with the app so startup scheduling and the UI use the
  // same database instance.
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Arm per-bill reminders for the current + next month as a sliding window
  // anchored to today. Off the critical path so it doesn't delay first frame.
  unawaited(scheduleUpcomingReminders(
    billsRepo: container.read(billsRepositoryProvider),
    instancesRepo: container.read(billInstancesRepositoryProvider),
    languageCode: languageCode,
  ));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RoundsApp(),
    ),
  );
}
