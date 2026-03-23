import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  final bool notificationsEnabled;
  final ThemeMode themeMode;

  AppSettings copyWith({bool? notificationsEnabled, ThemeMode? themeMode}) =>
      AppSettings(
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
