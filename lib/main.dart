import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/app.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  // Recover a snooze tap that cold-started the app from a terminated state.
  await NotificationService.instance.handleLaunchSnooze();
  final prefs = await SharedPreferences.getInstance();

  // The monthly "new round of bills" reminder is device-month based, so it's
  // scheduled once here rather than tied to any month being viewed.
  await NotificationService.instance.scheduleMonthlyKickoff(
    languageCode: prefs.getString('language_code') ?? 'en',
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const RoundsApp(),
    ),
  );
}
