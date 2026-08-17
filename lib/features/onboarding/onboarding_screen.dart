import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/core/widgets/bill_icon.dart';
import 'package:rounds/core/widgets/round_ring.dart';
import 'package:rounds/features/settings/providers/settings_providers.dart';
import 'package:rounds/l10n/app_localizations.dart';

/// Set once the intro has been seen; the router starts here until it is.
const kOnboardingDoneKey = 'onboarding_done';

/// First-run intro: three pages that teach the round/bills split, then end
/// on the notification permission ask — requested with its context in view
/// instead of as a cold prompt at launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;
  var _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool enableReminders}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    var enabled = false;
    if (enableReminders) {
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        await NotificationService.instance.requestExactAlarmsPermission();
        enabled = true;
      }
    }
    if (!enabled) {
      // Keep the stored toggle honest: without permission nothing would
      // display, and the Settings toggle re-requests when flipped back on.
      await NotificationService.instance.cancelAll();
      if (mounted) {
        ref.read(settingsProvider.notifier).setNotificationsEnabled(false);
      }
    }

    await ref.read(sharedPreferencesProvider).setBool(kOnboardingDoneKey, true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rounds = RoundsColors.of(context);
    final isLast = _page == 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (page) => setState(() => _page = page),
                children: const [
                  _RoundPage(),
                  _BillsPage(),
                  _RemindersPage(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : rounds.textFaint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _finishing
                        ? null
                        : () {
                            if (isLast) {
                              _finish(enableReminders: true);
                            } else {
                              _controller.nextPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                    child: Text(
                      isLast ? l10n.onboardEnableReminders : l10n.onboardNext,
                    ),
                  ),
                  // Kept in the tree on every page so the button block
                  // doesn't jump when the last page reveals it.
                  Opacity(
                    opacity: isLast ? 1 : 0,
                    child: TextButton(
                      onPressed: (_finishing || !isLast)
                          ? null
                          : () => _finish(enableReminders: false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        foregroundColor: rounds.textSecondary,
                      ),
                      child: Text(l10n.onboardSkip),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  const _PageScaffold({
    required this.visual,
    required this.title,
    required this.body,
  });

  final Widget visual;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 3),
          visual,
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium!.copyWith(
              color: RoundsColors.of(context).textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(flex: 4),
        ],
      ),
    );
  }
}

class _RoundPage extends StatelessWidget {
  const _RoundPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rounds = RoundsColors.of(context);
    final cs = Theme.of(context).colorScheme;
    return _PageScaffold(
      visual: RoundRing(
        size: 150,
        strokeWidth: 10,
        animate: true,
        segmentColors: [
          ...List.filled(5, rounds.paid),
          ...List.filled(2, rounds.neutralDot),
          cs.error,
        ],
        trackColor: cs.outlineVariant,
        child: Text('5/8', style: AppTypography.money.copyWith(fontSize: 24)),
      ),
      title: l10n.onboardTitle1,
      body: l10n.onboardBody1,
    );
  }
}

class _BillsPage extends StatelessWidget {
  const _BillsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PageScaffold(
      visual: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SampleBillRow(name: l10n.onboardSampleRent, dueDay: 1),
              _SampleBillRow(name: 'Internet', dueDay: 18),
              _SampleBillRow(name: 'Netflix', dueDay: 27),
            ],
          ),
        ),
      ),
      title: l10n.onboardTitle2,
      body: l10n.onboardBody2,
    );
  }
}

class _SampleBillRow extends StatelessWidget {
  const _SampleBillRow({required this.name, required this.dueDay});

  final String name;
  final int dueDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          BillIcon(name: name, size: 38),
          const SizedBox(width: 12),
          Text(name, style: theme.textTheme.titleMedium),
          const Spacer(),
          const SizedBox(width: 16),
          Text(
            l10n.dueThe(dueDay),
            style: AppTypography.monoMeta.copyWith(
              color: RoundsColors.of(context).textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemindersPage extends StatelessWidget {
  const _RemindersPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return _PageScaffold(
      visual: RoundRing(
        size: 150,
        strokeWidth: 10,
        segmentColors: const [],
        trackColor: cs.outlineVariant,
        child: Icon(
          Icons.notifications_outlined,
          size: 48,
          color: cs.primary,
        ),
      ),
      title: l10n.onboardTitle3,
      body: l10n.onboardBody3,
    );
  }
}
