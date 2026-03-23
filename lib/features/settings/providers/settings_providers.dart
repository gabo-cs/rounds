import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyThemeMode = 'theme_mode';
const _keyNotifications = 'notifications_enabled';
const _keyLanguage = 'language_code';

class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'en',
  });

  final bool notificationsEnabled;
  final ThemeMode themeMode;
  final String languageCode;

  AppSettings copyWith({
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    String? languageCode,
  }) =>
      AppSettings(
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
        themeMode: themeMode ?? this.themeMode,
        languageCode: languageCode ?? this.languageCode,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static AppSettings _load(SharedPreferences prefs) {
    final index = prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    final notifications = prefs.getBool(_keyNotifications) ?? true;
    final language = prefs.getString(_keyLanguage) ?? 'en';
    return AppSettings(
      themeMode: ThemeMode.values[index],
      notificationsEnabled: notifications,
      languageCode: language,
    );
  }

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt(_keyThemeMode, mode.index);
    state = state.copyWith(themeMode: mode);
  }

  void setNotificationsEnabled(bool enabled) {
    _prefs.setBool(_keyNotifications, enabled);
    state = state.copyWith(notificationsEnabled: enabled);
  }

  void setLanguageCode(String code) {
    _prefs.setString(_keyLanguage, code);
    state = state.copyWith(languageCode: code);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(sharedPreferencesProvider));
});

// Initialized at startup in main.dart via ProviderScope overrides
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});
