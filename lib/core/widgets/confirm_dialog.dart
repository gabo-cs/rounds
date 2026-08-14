import 'package:flutter/material.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/l10n/app_localizations.dart';

enum ConfirmDialogResult { confirmed, alternative, cancelled }

/// The one confirmation-dialog language of the app: icon lockup, centered
/// copy, and stacked full-width pill buttons — a row of text buttons can't
/// survive Spanish label lengths. Destructive intents get the error
/// treatment; reversible ones stay on primary.
///
/// [note] renders as a quiet info panel between the message and the buttons;
/// [alternativeLabel] adds a tonal middle action for dialogs that offer a
/// gentler way out (delete → archive instead).
Future<ConfirmDialogResult> showConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String? note,
  IconData? noteIcon,
  String? alternativeLabel,
}) async {
  final result = await showDialog<ConfirmDialogResult>(
    context: context,
    builder: (ctx) => _ConfirmDialog(
      icon: icon,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      note: note,
      noteIcon: noteIcon,
      alternativeLabel: alternativeLabel,
    ),
  );
  return result ?? ConfirmDialogResult.cancelled;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    this.note,
    this.noteIcon,
    this.alternativeLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final String? note;
  final IconData? noteIcon;
  final String? alternativeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = destructive ? cs.error : cs.primary;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium!.copyWith(
                color: rounds.textSecondary,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      noteIcon ?? Icons.info_outline,
                      size: 18,
                      color: rounds.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note!,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: rounds.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(ConfirmDialogResult.confirmed),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                    )
                  : null,
              child: Text(confirmLabel),
            ),
            if (alternativeLabel != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () =>
                    Navigator.of(context).pop(ConfirmDialogResult.alternative),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: cs.surfaceContainerHigh,
                  foregroundColor: cs.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(alternativeLabel!),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ConfirmDialogResult.cancelled),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: rounds.textSecondary,
              ),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
