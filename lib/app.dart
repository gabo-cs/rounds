import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/routing/app_router.dart';

class RoundsApp extends ConsumerWidget {
  const RoundsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );
    return MaterialApp.router(
      title: 'Rounds',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
