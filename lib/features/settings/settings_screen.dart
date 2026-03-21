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
        children: [
          _SectionHeader(label: 'Notifications'),
          SwitchListTile(
            title: const Text('Bill reminders'),
            subtitle: const Text(
              'Get notified 2 days and 1 day before each bill is due',
            ),
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
          const Divider(),
          _SectionHeader(label: 'Data'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export data'),
            subtitle: const Text('Save a JSON backup or share it'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import data'),
            subtitle: const Text('Restore from a JSON backup'),
            onTap: () => _import(context, ref),
          ),
          const Divider(),
          _SectionHeader(label: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Rounds'),
            subtitle: Text('Version 1.0.0'),
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

    // For file picking we show a snackbar directing the user — full file
    // picker integration requires file_picker package which is outside our
    // current dependency set. The import logic is fully implemented in
    // BackupService.importFromFile(path) and can be wired to any file picker.
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
