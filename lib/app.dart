import 'package:flutter/material.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/routing/app_router.dart';

class RoundsApp extends StatelessWidget {
  const RoundsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Rounds',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
