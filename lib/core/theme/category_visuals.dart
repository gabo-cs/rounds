import 'package:flutter/material.dart';

/// Icon + hue for a bill, resolved together from the same keyword match so
/// they can never disagree. Hues are muted picks tuned to sit on both the
/// navy dark surface and the cool light one; the paid green and the error
/// red are reserved for status and never appear here.
class CategoryVisual {
  const CategoryVisual({
    required this.icon,
    required this.darkColor,
    required this.lightColor,
  });

  final IconData icon;
  final Color darkColor;
  final Color lightColor;

  Color colorFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;

  /// Tinted circle behind the icon — derived, so the pair stays in sync.
  Color containerFor(Brightness brightness) => colorFor(brightness)
      .withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.13);

  static const _housing = CategoryVisual(
    icon: Icons.home_outlined,
    darkColor: Color(0xFFE28D6B),
    lightColor: Color(0xFFB45A2D),
  );
  static const _power = CategoryVisual(
    icon: Icons.flash_on,
    darkColor: Color(0xFFE9B949),
    lightColor: Color(0xFFA47B10),
  );
  static const _water = CategoryVisual(
    icon: Icons.water_drop_outlined,
    darkColor: Color(0xFF52C5DE),
    lightColor: Color(0xFF1F7E96),
  );
  static const _gas = CategoryVisual(
    icon: Icons.local_fire_department_outlined,
    darkColor: Color(0xFFED9660),
    lightColor: Color(0xFFB05A1F),
  );
  static const _internet = CategoryVisual(
    icon: Icons.wifi,
    darkColor: Color(0xFF8E9EF7),
    lightColor: Color(0xFF4A5BC4),
  );
  static const _phone = CategoryVisual(
    icon: Icons.smartphone,
    darkColor: Color(0xFF8E9EF7),
    lightColor: Color(0xFF4A5BC4),
  );
  static const _streaming = CategoryVisual(
    icon: Icons.tv_outlined,
    darkColor: Color(0xFFE77BB1),
    lightColor: Color(0xFFB3487F),
  );
  static const _music = CategoryVisual(
    icon: Icons.headphones,
    darkColor: Color(0xFFE77BB1),
    lightColor: Color(0xFFB3487F),
  );
  static const _fitness = CategoryVisual(
    icon: Icons.fitness_center,
    darkColor: Color(0xFF62D39C),
    lightColor: Color(0xFF1E8F5D),
  );
  static const _insurance = CategoryVisual(
    icon: Icons.shield_outlined,
    darkColor: Color(0xFF5FC8BE),
    lightColor: Color(0xFF17807A),
  );
  static const _finance = CategoryVisual(
    icon: Icons.credit_card_outlined,
    darkColor: Color(0xFFC77DDE),
    lightColor: Color(0xFF8C3CAA),
  );
  static const _transport = CategoryVisual(
    icon: Icons.directions_car_outlined,
    darkColor: Color(0xFFCFA85E),
    lightColor: Color(0xFF8A6B26),
  );
  static const _fallback = CategoryVisual(
    icon: Icons.receipt_outlined,
    darkColor: Color(0xFF5BB8E8),
    lightColor: Color(0xFF1B5278),
  );

  static CategoryVisual resolve(String name, String? category) {
    // Pad with spaces so we can do whole-word matching on ambiguous terms.
    // e.g. ' sport ' won't match 'transportation', ' car ' won't match 'credit card'.
    final key = ' ${(category ?? name).toLowerCase()} ';

    if (key.contains('rent') || key.contains('mortgage') || key.contains('housing')) {
      return _housing;
    }
    if (key.contains('netflix') || key.contains('hulu') || key.contains('disney') ||
        key.contains('streaming') || key.contains('video') || key.contains('youtube') ||
        key.contains('subscription')) {
      return _streaming;
    }
    if (key.contains('spotify') || key.contains('tidal') || key.contains('podcast') ||
        key.contains(' music') || key.contains('audio')) {
      return _music;
    }
    if (key.contains('electric') || key.contains('power') || key.contains('energy') ||
        key.contains('utility') || key.contains('utilities')) {
      return _power;
    }
    // Use ' sport' (leading space) so it matches "sport" or "sports" but NOT
    // "transportation" (which has 'sport' mid-word, not preceded by a space).
    if (key.contains(' gym') || key.contains('fitness') || key.contains('workout') ||
        key.contains(' sport') || key.contains('yoga') || key.contains('pilates') ||
        key.contains('crossfit')) {
      return _fitness;
    }
    if (key.contains('internet') || key.contains('wifi') || key.contains('wi-fi') ||
        key.contains('fiber') || key.contains('broadband') || key.contains(' cable')) {
      return _internet;
    }
    if (key.contains('phone') || key.contains('mobile') || key.contains(' cell') ||
        key.contains('wireless') || key.contains('cellular')) {
      return _phone;
    }
    if (key.contains('water') || key.contains('sewer')) {
      return _water;
    }
    if (key.contains(' gas') || key.contains('heating') || key.contains('propane')) {
      return _gas;
    }
    if (key.contains('insurance') || key.contains('insur')) {
      return _insurance;
    }
    // Must come BEFORE the car check because 'credit card' contains 'car'.
    if (key.contains('credit') || key.contains(' loan') || key.contains(' debt')) {
      return _finance;
    }
    if (key.contains('transport') || key.contains(' car ') || key.contains(' auto ') ||
        key.contains('vehicle') || key.contains('parking') || key.contains('uber') ||
        key.contains('lyft') || key.contains('toll')) {
      return _transport;
    }
    return _fallback;
  }
}
