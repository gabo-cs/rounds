import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
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
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          // APPEARANCE
          _SectionLabel(label: l10n.appearanceSection),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  },
                ),
              ),
              const Divider(height: 1, indent: 64, endIndent: 0),
              _SettingsTile(
                icon: Icons.bug_report_outlined,
                title: 'Send test notification',
                subtitle: 'Uses last bill — fires in 10 seconds',
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final instances = ref.read(monthInstancesProvider).valueOrNull;
                  final last = instances?.isNotEmpty == true
                      ? instances!.reduce((a, b) =>
                          a.instance.id > b.instance.id ? a : b)
                      : null;
                  if (last == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No bills found for this month')),
                      );
                    }
                    return;
                  }
                  try {
                    await NotificationService.instance.requestExactAlarmsPermission();
                    final languageCode = ref.read(settingsProvider).languageCode;
                    await NotificationService.instance.scheduleTestNotification(last, languageCode: languageCode);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test notification for "${last.bill.name}" fires in 10 seconds')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          // DATA
          _SectionLabel(label: l10n.dataSection),
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
                icon: Icons.info_outline,
                title: 'Rounds',
                subtitle: l10n.appVersionLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service =
          BackupService(ref.read(billInstancesRepositoryProvider));
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importDataDialogTitle),
        content: Text(l10n.importDataDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.importAndReplaceButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.importInstructions),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
      ),
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
