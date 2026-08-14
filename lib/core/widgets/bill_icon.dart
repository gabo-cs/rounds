import 'package:flutter/material.dart';
import 'package:rounds/core/theme/category_visuals.dart';
import 'package:rounds/core/theme/rounds_colors.dart';

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
    final brightness = Theme.of(context).brightness;

    if (isPaid) {
      final rounds = RoundsColors.of(context);
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: rounds.paidContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          color: rounds.paid,
          size: size * 0.5,
        ),
      );
    }

    final visual = CategoryVisual.resolve(name, category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: visual.containerFor(brightness),
        shape: BoxShape.circle,
      ),
      child: Icon(
        visual.icon,
        color: visual.colorFor(brightness),
        size: size * 0.5,
      ),
    );
  }
}
