import 'package:flutter/material.dart';
import 'package:rounds/core/theme/app_theme.dart';
import 'package:rounds/core/theme/rounds_colors.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:rounds/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

const _kRepoUrl = 'https://github.com/gabo-cs/rounds';

/// In-app FAQ: an offline app can't point at a help site, so the explanation
/// of how it works — and why it works that way — ships inside it.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _SectionLabel(label: l10n.faqSectionBasics),
          _FaqCard(question: l10n.faqQWhatIsRound, answer: l10n.faqAWhatIsRound),
          _FaqCard(question: l10n.faqQOffline, answer: l10n.faqAOffline),
          _FaqCard(
            question: l10n.faqQLanguage,
            answer: l10n.faqALanguage,
          ),
          _SectionLabel(label: l10n.faqSectionReminders),
          _FaqCard(
            question: l10n.faqQHowReminders,
            answer: l10n.faqAHowReminders,
          ),
          _FaqCard(
            question: l10n.faqQNoReminders,
            answer: l10n.faqANoReminders,
            trailing: const _CheckNotificationsButton(),
          ),
          _FaqCard(question: l10n.faqQBattery, answer: l10n.faqABattery),
          _SectionLabel(label: l10n.faqSectionData),
          _FaqCard(question: l10n.faqQBackup, answer: l10n.faqABackup),
          _FaqCard(question: l10n.faqQJsonFile, answer: l10n.faqAJsonFile),
          _FaqCard(question: l10n.faqQHistory, answer: l10n.faqAHistory),
          _SectionLabel(label: l10n.faqSectionProject),
          _FaqCard(
            question: l10n.faqQOpenSource,
            answer: l10n.faqAOpenSource,
            trailing: const _RepoLink(),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.eyebrow.copyWith(
          color: RoundsColors.of(context).textFaint,
        ),
      ),
    );
  }
}

/// One expandable question. Collapsed by default so the screen scans as an
/// index; the chevron and cross-fade keep the reveal quiet.
class _FaqCard extends StatefulWidget {
  const _FaqCard({
    required this.question,
    required this.answer,
    this.trailing,
  });

  final String question;
  final String answer;

  /// Optional interactive content under the answer (a button, a link).
  final Widget? trailing;

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounds = RoundsColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: rounds.textFaint,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.answer,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: rounds.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        if (widget.trailing != null) ...[
                          const SizedBox(height: 12),
                          widget.trailing!,
                        ],
                      ],
                    ),
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                  sizeCurve: Curves.easeOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckNotificationsButton extends StatelessWidget {
  const _CheckNotificationsButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      icon: const Icon(Icons.notifications_outlined, size: 18),
      label: Text(l10n.faqCheckNotifButton),
      onPressed: () async {
        final granted = await NotificationService.instance.requestPermission();
        final exactOk = granted &&
            await NotificationService.instance.requestExactAlarmsPermission();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted && exactOk ? l10n.faqNotifOk : l10n.faqNotifIssue,
            ),
          ),
        );
      },
    );
  }
}

class _RepoLink extends StatelessWidget {
  const _RepoLink();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(l10n.faqOpenRepoButton),
      onPressed: () async {
        final opened = await launchUrl(
          Uri.parse(_kRepoUrl),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).genericErrorMessage,
              ),
            ),
          );
        }
      },
    );
  }
}
