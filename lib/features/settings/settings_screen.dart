import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/core/widgets/confirm_dialog.dart';
import 'package:rounds/core/widgets/screen_header.dart';
import 'package:rounds/data/models/currency.dart';
import 'package:rounds/features/round/providers/round_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(title: l10n.settingsTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // APPEARANCE
                  _SectionLabel(label: l10n.appearanceSection),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(l10n.lightTheme),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(l10n.systemTheme),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(l10n.darkTheme),
                            ),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (selected) {
                            notifier.setThemeMode(selected.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          expandedInsets: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),

                  // LANGUAGE
                  _SectionLabel(label: l10n.languageSection),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'en',
                              label: Text(l10n.englishLanguage),
                            ),
                            ButtonSegment(
                              value: 'es',
                              label: Text(l10n.spanishLanguage),
                            ),
                          ],
                          selected: {settings.languageCode},
                          onSelectionChanged: (selected) {
                            notifier.setLanguageCode(selected.first);
                          },
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                          ),
                          expandedInsets: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),

                  // CURRENCY
                  _SectionLabel(label: l10n.currencySection),
                  _SettingsCard(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        // ISO codes need no translation, and what the choice
                        // actually changes is the symbol and the separators —
                        // so that's what each option shows.
                        child: DropdownButtonFormField<Currency>(
                          initialValue: settings.currency,
                          decoration: const InputDecoration(),
                          items: [
                            for (final currency in Currency.values)
                              DropdownMenuItem(
                                value: currency,
                                child: Text(
                                  '${currency.code} · '
                                  '${currency.format(1500)}',
                                ),
                              ),
                          ],
                          onChanged: (currency) {
                            if (currency != null) {
                              notifier.setCurrency(currency);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // NOTIFICATIONS
                  _SectionLabel(label: l10n.notificationsSection),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: l10n.billRemindersTitle,
                        subtitle: l10n.billRemindersSubtitle,
                        trailing: Switch(
                          value: settings.notificationsEnabled,
                          onChanged: (enabled) async {
                            if (enabled) {
                              final granted = await NotificationService.instance
                                  .requestPermission();
                              if (!granted && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.notificationDenied),
                                  ),
                                );
                                return;
                              }
                              await NotificationService.instance
                                  .requestExactAlarmsPermission();
                            } else {
                              await NotificationService.instance.cancelAll();
                            }
                            notifier.setNotificationsEnabled(enabled);
                            if (enabled) {
                              // Re-arm now — startup scheduling only runs on launch, so
                              // without this the toggle wouldn't take effect until the
                              // next app start.
                              await refreshReminderSchedule(
                                billsRepo: ref.read(billsRepositoryProvider),
                                instancesRepo: ref.read(
                                  billInstancesRepositoryProvider,
                                ),
                                languageCode: ref
                                    .read(settingsProvider)
                                    .languageCode,
                                currency: ref.read(settingsProvider).currency,
                              );
                            }
                          },
                        ),
                      ),
                      // Debug-only diagnostics: compile-time constant, so the
                      // release build tree-shakes the whole tile away.
                      if (kDebugMode) ...[
                        const Divider(height: 1, indent: 64, endIndent: 0),
                        _SettingsTile(
                          icon: Icons.bug_report_outlined,
                          title: l10n.testNotificationTitle,
                          subtitle: l10n.testNotificationSubtitle,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final selected = ref.read(selectedMonthProvider);
                            final instances = ref
                                .read(monthInstancesProvider(selected))
                                .valueOrNull;
                            final last = instances?.isNotEmpty == true
                                ? instances!.reduce(
                                    (a, b) =>
                                        a.instance.id > b.instance.id ? a : b,
                                  )
                                : null;
                            if (last == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.noBillsThisMonth),
                                  ),
                                );
                              }
                              return;
                            }
                            try {
                              await NotificationService.instance
                                  .requestExactAlarmsPermission();
                              final current = ref.read(settingsProvider);
                              await NotificationService.instance
                                  .scheduleTestNotification(
                                    last,
                                    languageCode: current.languageCode,
                                    currency: current.currency,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.testNotificationScheduled(
                                        last.bill.name,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.testNotificationFailed('$e'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ],
                  ),

                  // DATA
                  _SectionLabel(
                    label: l10n.dataSection,
                    action: const _BackupInfoButton(),
                  ),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.upload_outlined,
                        title: l10n.exportDataTitle,
                        subtitle: l10n.exportDataSubtitle,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _export(context, ref),
                      ),
                      const Divider(height: 1, indent: 64, endIndent: 0),
                      _SettingsTile(
                        icon: Icons.download_outlined,
                        title: l10n.importDataTitle,
                        subtitle: l10n.importDataSubtitle,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _import(context, ref),
                      ),
                    ],
                  ),

                  // ABOUT
                  _SectionLabel(label: l10n.aboutSection),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline,
                        title: l10n.faqTitle,
                        subtitle: l10n.faqSettingsSubtitle,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/faq'),
                      ),
                      const Divider(height: 1, indent: 64, endIndent: 0),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: 'Rounds',
                        subtitle: l10n.appVersionLabel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = BackupService(ref.read(billInstancesRepositoryProvider));
      await service.exportAndShare();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context,
      icon: Icons.download_outlined,
      destructive: true,
      title: l10n.importDataDialogTitle,
      message: l10n.importDataDialogContent,
      confirmLabel: l10n.importAndReplaceButton,
    );

    if (confirmed != ConfirmDialogResult.confirmed || !context.mounted) return;

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    final service = BackupService(ref.read(billInstancesRepositoryProvider));
    final error = await service.importFromFile(path);

    if (error == null) {
      // Reminders scheduled before the import reference instance IDs from the
      // replaced data — rebuild the schedule from scratch.
      await NotificationService.instance.cancelAll();
      final settings = ref.read(settingsProvider);
      if (settings.notificationsEnabled) {
        await refreshReminderSchedule(
          billsRepo: ref.read(billsRepositoryProvider),
          instancesRepo: ref.read(billInstancesRepositoryProvider),
          languageCode: settings.languageCode,
          currency: settings.currency,
        );
      }
    }

    if (!context.mounted) return;
    final message = switch (error) {
      null => l10n.importSuccess,
      ImportError.invalidFile => l10n.importErrorInvalidFile,
      ImportError.unsupportedVersion => l10n.importErrorUnsupportedVersion,
      ImportError.readFailed => l10n.importErrorReadFailed,
      ImportError.unknown => l10n.importErrorGeneric,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.action});

  final String label;

  /// Optional affordance riding beside the label (the Data section's "?").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label.toUpperCase(),
      style: AppTypography.eyebrow.copyWith(
        color: RoundsColors.of(context).textFaint,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: action == null
          ? text
          : Row(children: [text, const SizedBox(width: 2), action!]),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// Backups hand the user a file and a format — the one place this app asks
/// them to understand something technical — so the explanation sits next to
/// the export/import buttons instead of only in the FAQ.
class _BackupInfoButton extends StatelessWidget {
  const _BackupInfoButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: l10n.backupInfoTooltip,
      child: InkResponse(
        radius: 20,
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const _BackupInfoSheet(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.help_outline,
            size: 16,
            color: RoundsColors.of(context).textFaint,
          ),
        ),
      ),
    );
  }
}

class _BackupInfoSheet extends StatelessWidget {
  const _BackupInfoSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rounds = RoundsColors.of(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l10n.backupInfoTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                l10n.backupInfoIntro,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: rounds.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              _BackupInfoPoint(
                icon: Icons.data_object,
                title: l10n.backupInfoWhatTitle,
                body: l10n.backupInfoWhatBody,
              ),
              _BackupInfoPoint(
                icon: Icons.inventory_2_outlined,
                title: l10n.backupInfoContentsTitle,
                body: l10n.backupInfoContentsBody,
              ),
              _BackupInfoPoint(
                icon: Icons.swap_horiz,
                title: l10n.backupInfoImportTitle,
                body: l10n.backupInfoImportBody,
              ),
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
                      Icons.lightbulb_outline,
                      size: 18,
                      color: rounds.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.backupInfoTip,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: rounds.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.backupInfoDismiss),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupInfoPoint extends StatelessWidget {
  const _BackupInfoPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rounds = RoundsColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: rounds.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
