import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/backup_service.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/features/home/providers/home_providers.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // APPEARANCE
          const _SectionLabel(label: 'Appearance'),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
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

          // NOTIFICATIONS
          const _SectionLabel(label: 'Notifications'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Bill Reminders',
                subtitle: 'Get notified 2 days and 1 day before each bill is due',
                trailing: Switch(
                  value: settings.notificationsEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      final granted = await NotificationService.instance
                          .requestPermission();
                      if (!granted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Notification permission denied. '
                              'Enable it in system settings.',
                            ),
                          ),
                        );
                        return;
                      }
                    } else {
                      await NotificationService.instance.cancelAll();
                    }
                    notifier.setNotificationsEnabled(enabled);
                  },
                ),
              ),
            ],
          ),

          // DATA
          const _SectionLabel(label: 'Data'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.upload_outlined,
                title: 'Export data',
                subtitle: 'Save a JSON backup or share it',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _export(context, ref),
              ),
              const Divider(height: 1, indent: 64, endIndent: 0),
              _SettingsTile(
                icon: Icons.download_outlined,
                title: 'Import data',
                subtitle: 'Restore from a JSON backup',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _import(context, ref),
              ),
            ],
          ),

          // ABOUT
          const _SectionLabel(label: 'About'),
          _SettingsCard(
            children: [
              const _SettingsTile(
                icon: Icons.info_outline,
                title: 'Rounds',
                subtitle: 'Version 1.0.0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final service =
          BackupService(ref.read(billInstancesRepositoryProvider));
      await service.exportAndShare();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    // Ask for confirmation before replacing data
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import data?'),
        content: const Text(
          'This will replace ALL current data with the contents of the '
          'backup file. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Import & Replace'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'To import, share your backup JSON file to Rounds from '
          'your file manager or another app.',
        ),
        duration: Duration(seconds: 5),
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
