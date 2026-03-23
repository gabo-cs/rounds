import 'package:flutter/material.dart';

class BillIcon extends StatelessWidget {
  const BillIcon({
    super.key,
    required this.name,
    this.category,
    this.isPaid = false,
    this.size = 44.0,
  });

  final String name;
  final String? category;
  final bool isPaid;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPaid) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF27AE60).withValues(alpha: isDark ? 0.25 : 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color: const Color(0xFF27AE60),
          size: size * 0.5,
        ),
      );
    }

    final icon = _resolveIcon(name, category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: cs.onPrimaryContainer, size: size * 0.5),
    );
  }

  static IconData _resolveIcon(String name, String? category) {
    // Pad with spaces so we can do whole-word matching on ambiguous terms.
    // e.g. ' sport ' won't match 'transportation', ' car ' won't match 'credit card'.
    final key = ' ${(category ?? name).toLowerCase()} ';

    // Housing
    if (key.contains('rent') || key.contains('mortgage') || key.contains('housing')) {
      return Icons.home_outlined;
    }
    // Streaming / video
    if (key.contains('netflix') || key.contains('hulu') || key.contains('disney') ||
        key.contains('streaming') || key.contains('video') || key.contains('youtube')) {
      return Icons.tv_outlined;
    }
    // Music / audio
    if (key.contains('spotify') || key.contains('tidal') || key.contains('podcast') ||
        key.contains(' music') || key.contains('audio')) {
      return Icons.headphones;
    }
    // Electricity / power
    if (key.contains('electric') || key.contains('power') || key.contains('energy') ||
        key.contains('utility') || key.contains('utilities')) {
      return Icons.flash_on;
    }
    // Gym / fitness — use ' sport' (leading space) so it matches "sport" or "sports"
    // but NOT "transportation" (which has 'sport' mid-word, not preceded by a space)
    if (key.contains(' gym') || key.contains('fitness') || key.contains('workout') ||
        key.contains(' sport') || key.contains('yoga') || key.contains('pilates') ||
        key.contains('crossfit')) {
      return Icons.fitness_center;
    }
    // Internet / connectivity
    if (key.contains('internet') || key.contains('wifi') || key.contains('wi-fi') ||
        key.contains('fiber') || key.contains('broadband') || key.contains(' cable')) {
      return Icons.wifi;
    }
    // Phone / mobile
    if (key.contains('phone') || key.contains('mobile') || key.contains(' cell') ||
        key.contains('wireless') || key.contains('cellular')) {
      return Icons.smartphone;
    }
    // Water
    if (key.contains('water') || key.contains('sewer')) {
      return Icons.water_drop_outlined;
    }
    // Gas / heating
    if (key.contains(' gas') || key.contains('heating') || key.contains('propane')) {
      return Icons.local_fire_department_outlined;
    }
    // Insurance
    if (key.contains('insurance') || key.contains('insur')) {
      return Icons.shield_outlined;
    }
    // Credit / loan — must come BEFORE car check because 'credit card' contains 'car'
    if (key.contains('credit') || key.contains(' loan') || key.contains(' debt')) {
      return Icons.credit_card_outlined;
    }
    // Transportation / car — use ' car ' (spaces) so 'credit card' doesn't match
    if (key.contains('transport') || key.contains(' car ') || key.contains(' auto ') ||
        key.contains('vehicle') || key.contains('parking') || key.contains('uber') ||
        key.contains('lyft') || key.contains('toll')) {
      return Icons.directions_car_outlined;
    }
    return Icons.receipt_outlined;
  }
}
