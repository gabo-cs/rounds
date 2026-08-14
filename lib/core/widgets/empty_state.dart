import 'package:flutter/material.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/widgets/round_ring.dart';

/// Shared empty-state lockup drawn with the app's own motif: a hollow Round
/// — a month with nothing in it yet — instead of a stock grey glyph.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounds = RoundsColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RoundRing(
              size: 88,
              strokeWidth: 5,
              segmentColors: List.filled(8, theme.colorScheme.outlineVariant),
              trackColor: theme.colorScheme.outlineVariant,
              child: Icon(icon, size: 30, color: rounds.textFaint),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: rounds.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
