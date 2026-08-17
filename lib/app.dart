import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/features/onboarding/onboarding_screen.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';
import 'package:rounds/routing/app_router.dart';

class RoundsApp extends ConsumerStatefulWidget {
  const RoundsApp({super.key});

  @override
  ConsumerState<RoundsApp> createState() => _RoundsAppState();
}

class _RoundsAppState extends ConsumerState<RoundsApp> {
  // Created once — recreating a GoRouter on rebuild would reset navigation.
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _router = createAppRouter(
      showOnboarding: !(prefs.getBool(kOnboardingDoneKey) ?? false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      settingsProvider.select((s) => s.themeMode),
    );
    final languageCode = ref.watch(
      settingsProvider.select((s) => s.languageCode),
    );
    return MaterialApp.router(
      title: 'Rounds',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: Locale(languageCode),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
