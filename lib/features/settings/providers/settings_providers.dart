import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings({
    this.notificationsEnabled = true,
  });

  final bool notificationsEnabled;

  AppSettings copyWith({bool? notificationsEnabled}) => AppSettings(
        notificationsEnabled:
            notificationsEnabled ?? this.notificationsEnabled,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void setNotificationsEnabled(bool enabled) {
    state = state.copyWith(notificationsEnabled: enabled);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
