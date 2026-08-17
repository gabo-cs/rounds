import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';

void main() {
  group('SettingsNotifier.defaultLanguageCode', () {
    test('Spanish devices start in Spanish, any region', () {
      expect(
        SettingsNotifier.defaultLanguageCode(const Locale('es', 'CO')),
        'es',
      );
      expect(
        SettingsNotifier.defaultLanguageCode(const Locale('es', 'MX')),
        'es',
      );
      expect(SettingsNotifier.defaultLanguageCode(const Locale('es')), 'es');
    });

    test('everything else starts in English', () {
      expect(
        SettingsNotifier.defaultLanguageCode(const Locale('en', 'US')),
        'en',
      );
      expect(SettingsNotifier.defaultLanguageCode(const Locale('pt')), 'en');
      expect(SettingsNotifier.defaultLanguageCode(const Locale('fr')), 'en');
    });
  });
}
