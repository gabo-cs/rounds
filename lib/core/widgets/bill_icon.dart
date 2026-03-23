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
    final key = (category ?? name).toLowerCase();
    if (key.contains('rent') || key.contains('mortgage') || key.contains('housing')) {
      return Icons.home_outlined;
    }
    if (key.contains('netflix') || key.contains('hulu') || key.contains('disney') ||
        key.contains('streaming') || key.contains('video')) {
      return Icons.tv_outlined;
    }
    if (key.contains('spotify') || key.contains('music') || key.contains('apple')) {
      return Icons.headphones;
    }
    if (key.contains('electric') || key.contains('power') || key.contains('energy')) {
      return Icons.flash_on;
    }
    if (key.contains('gym') || key.contains('fitness') || key.contains('sport')) {
      return Icons.fitness_center;
    }
    if (key.contains('internet') || key.contains('wifi') ||
        key.contains('fiber') || key.contains('broadband')) {
      return Icons.wifi;
    }
    if (key.contains('phone') || key.contains('mobile') || key.contains('cell')) {
      return Icons.smartphone;
    }
    if (key.contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (key.contains('gas') || key.contains('heating')) {
      return Icons.local_fire_department_outlined;
    }
    if (key.contains('insurance')) {
      return Icons.shield_outlined;
    }
    if (key.contains('car') || key.contains('auto')) {
      return Icons.directions_car_outlined;
    }
    if (key.contains('loan') || key.contains('credit')) {
      return Icons.credit_card_outlined;
    }
    return Icons.receipt_outlined;
  }
}
