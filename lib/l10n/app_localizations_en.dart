import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  @override
  String get localeName => 'en';

  // ── Navigation ───────────────────────────────────────────────────────────────

  @override
  String get navRound => 'ROUND';
  @override
  String get navBills => 'BILLS';
  @override
  String get navHistory => 'HISTORY';
  @override
  String get navSettings => 'SETTINGS';

  // ── Common ───────────────────────────────────────────────────────────────────

  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get undo => 'Undo';
  @override
  String get archive => 'Archive';
  @override
  String get unarchive => 'Unarchive';
  @override
  String get paid => 'Paid';

  @override
  String itemsCount(int count) => count == 1 ? '1 item' : '$count items';
  @override
  String get genericErrorMessage => 'Something went wrong. Please try again.';

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  @override
  String dueThe(int day) => 'Due the ${_ordinal(day)}';

  @override
  String overdueSince(int day) => 'Was due the ${_ordinal(day)}';

  @override
  String overdueSinceDate(DateTime date) =>
      'Was due ${DateFormat.MMMd('en').format(date)}';

  @override
  String dueDayOption(int day) {
    if (day >= 11 && day <= 13) return '${day}th of the month';
    final suffix = switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    };
    return '$day$suffix of the month';
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  // ── Home screen ──────────────────────────────────────────────────────────────

  @override
  String get pending => 'Pending';
  @override
  String get overdue => 'Overdue';
  @override
  String get noBillsYet => 'No bills yet';
  @override
  String get addFirstBill => 'Add your first bill';
  @override
  String get addFirstBillHomeSubtitle =>
      'Add your recurring bills to start tracking your monthly payments.';
  @override
  String get noRoundRecordedTitle => 'No round recorded';
  @override
  String get noRoundRecordedSubtitle =>
      'Rounds only keeps the months it was open for. You can build this one '
      'from your bills as they stand today, then mark what you paid.';
  @override
  String get buildRoundButton => 'Build this round';
  @override
  String get roundMenuTooltip => 'Round options';
  @override
  String get markAllPaidAction => 'Mark all as paid';
  @override
  String get markAllPaidDialogTitle => 'Mark the round as paid?';
  @override
  String markAllPaidCurrentMessage(int count) => count == 1
      ? 'The bill still open in this round will be recorded as paid today. '
            'You can open it afterwards to add the amount or the method.'
      : 'All $count bills still open in this round will be recorded as paid '
            'today. You can open any of them afterwards to add the amount or '
            'the method.';
  @override
  String markAllPaidPastMessage(int count) => count == 1
      ? 'The bill still open in this round will be recorded as paid on its '
            'own due date, since the round is already past. You can open it '
            'afterwards to adjust the details.'
      : 'All $count bills still open in this round will be recorded as paid '
            'on their own due dates, since the round is already past. You '
            'can open any of them afterwards to adjust the details.';
  @override
  String get markAllPaidConfirm => 'Mark all as paid';
  @override
  String markAllPaidDone(int count) =>
      count == 1 ? '1 bill marked as paid' : '$count bills marked as paid';
  @override
  String get todayButton => 'Today';
  @override
  String get previousMonthTooltip => 'Previous month';
  @override
  String get nextMonthTooltip => 'Next month';
  @override
  String roundNumber(int month) => 'round $month';
  @override
  String paidOfTotal(int paid, int total) => '$paid of $total paid';
  @override
  String overdueCount(int count) => count == 1 ? '1 overdue' : '$count overdue';

  // ── Bills screen ─────────────────────────────────────────────────────────────

  @override
  String get billsTitle => 'Bills';
  @override
  String get billsScreenHint =>
      'Your recurring bills and their settings — name, amount, due day. '
      'Each month\'s status (paid, pending, overdue) is on the Round tab.';
  @override
  String get archivedLabel => 'Archived';
  @override
  String billsCount(int count) => count == 1 ? '1 bill' : '$count bills';
  @override
  String get addFirstBillBillsSubtitle =>
      'Add your recurring bills to start tracking.';
  @override
  String get deleteBillDialogTitle => 'Delete bill?';
  @override
  String deleteBillDialogContent(String name) =>
      'Delete "$name" permanently?\n\n'
      'This will also erase all payment history for this bill. '
      'This cannot be undone.';
  @override
  String get deleteBillButton => 'Delete';
  @override
  String get archiveInsteadHint =>
      'Want to keep the history? Archiving hides this bill from new months '
      'but keeps everything already recorded — and you can unarchive it '
      'anytime.';
  @override
  String get archiveInsteadButton => 'Archive instead';

  // ── Bill form ─────────────────────────────────────────────────────────────────

  @override
  String get editBillTitle => 'Edit Bill';
  @override
  String get newBillTitle => 'New Bill';
  @override
  String get thisArchivedBanner => 'This bill is archived';
  @override
  String get billNameLabel => 'Bill name';
  @override
  String get billNameHint => 'e.g. Internet, Rent, Netflix';
  @override
  String get billNameRequired => 'Name is required';
  @override
  String get billNameTooLong => 'Name is too long';
  @override
  String get amountLabel => 'Amount (optional)';
  @override
  String get amountHint => 'Leave blank if it varies';
  @override
  String get amountInvalid => 'Enter a valid amount greater than 0';
  @override
  String get dueDayLabel => 'Due day of month';
  @override
  String get categoryLabel => 'Category (optional)';
  @override
  String get notesLabel => 'Notes (optional)';
  @override
  String get notesHint => 'Any additional details about this bill';
  @override
  String get saveChangesButton => 'Save Changes';
  @override
  String get addBillButton => 'Add Bill';
  @override
  String failedToSave(String e) => 'Failed to save: $e';
  @override
  String get archiveBillDialogTitle => 'Archive bill?';
  @override
  String archiveBillDialogContent(String name) =>
      '"$name" will no longer appear in future months. '
      'Payment history is preserved.';
  @override
  String get archiveButton => 'Archive';
  @override
  String get customCategoryChip => 'Custom…';
  @override
  String get customCategoryHint => 'Enter custom category';
  @override
  String get billNotFound => 'Bill not found';
  @override
  String get editBillTooltip => 'Edit bill';
  @override
  String get paymentHistoryTitle => 'Payment History';
  @override
  String get noPaymentHistoryYet => 'No payment history yet.';
  @override
  String get archivedChipLabel => 'Archived';
  @override
  String dueOnDayEachMonth(int day) =>
      'Due on the ${_ordinal(day)} of each month';
  @override
  String get unpaid => 'Unpaid';

  // ── Mark paid sheet ───────────────────────────────────────────────────────────

  @override
  String get updatePaymentSubtitle => 'Update payment';
  @override
  String get markAsPaidSubtitle => 'Mark as paid';
  @override
  String get datePaidLabel => 'Date paid';
  @override
  String get amountPaidLabel => 'Amount paid (optional)';
  @override
  String get amountPaidHint => 'Leave blank if not tracking amounts';
  @override
  String get paymentMethodLabel => 'Payment method (optional)';
  @override
  String get referenceLabel => 'Reference / note (optional)';
  @override
  String get referenceHint => 'Transaction ID, confirmation #, etc.';
  @override
  String get updatePaymentButton => 'Update Payment';
  @override
  String get confirmPaymentButton => 'Confirm Payment';
  @override
  String get undoPaymentButton => 'Undo Payment';
  @override
  String get undoPaymentDialogTitle => 'Undo payment?';
  @override
  String get undoPaymentDialogContent =>
      'This will mark the bill as unpaid and remove payment details.';
  @override
  String paidOnDate(DateTime date) =>
      'Paid ${DateFormat.MMMd('en').format(date)}';

  @override
  String formatShortDate(DateTime date) => DateFormat.MMMd('en').format(date);

  // ── History screen ────────────────────────────────────────────────────────────

  @override
  String get historyTitle => 'History';
  @override
  String get exportDataTooltip => 'Export data';
  @override
  String billsPaidOf(int paid, int total) => '$paid of $total bills paid';
  @override
  String get allPaid => 'All paid';
  @override
  String pendingCount(int count) => count == 1 ? '1 pending' : '$count pending';
  @override
  String get noHistoryYet => 'No history yet';
  @override
  String get noHistorySubtitle =>
      'Past months will appear here once you start tracking payments.';
  @override
  String exportFailed(String e) => 'Export failed: $e';
  @override
  String monthLabel(int year, int month) =>
      DateFormat.yMMMM('en').format(DateTime(year, month));

  // ── Settings screen ───────────────────────────────────────────────────────────

  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearanceSection => 'Appearance';
  @override
  String get lightTheme => 'Light';
  @override
  String get systemTheme => 'System';
  @override
  String get darkTheme => 'Dark';
  @override
  String get notificationsSection => 'Notifications';
  @override
  String get billRemindersTitle => 'Bill Reminders';
  @override
  String get billRemindersSubtitle =>
      'Get notified before each bill is due, on the due date, and while it\'s overdue';
  @override
  String get notificationDenied =>
      'Notification permission denied. Enable it in system settings.';
  @override
  String get dataSection => 'Data';
  @override
  String get exportDataTitle => 'Export data';
  @override
  String get exportDataSubtitle => 'Save a JSON backup or share it';
  @override
  String get importDataTitle => 'Import data';
  @override
  String get importDataSubtitle => 'Restore from a JSON backup';
  @override
  String get backupInfoTooltip => 'About backups';
  @override
  String get backupInfoTitle => 'About backups';
  @override
  String get backupInfoIntro =>
      'Export writes everything Rounds knows into a single file that you '
      'keep. Import reads one back in.';
  @override
  String get backupInfoWhatTitle => 'It\'s a JSON file';
  @override
  String get backupInfoWhatBody =>
      'JSON is a plain-text format for exchanging data — open, widely used, '
      'and owned by no company. You can open the file in any text editor. '
      'It is simply your own data written out, so nothing stays locked '
      'inside Rounds.';
  @override
  String get backupInfoContentsTitle => 'What it contains';
  @override
  String get backupInfoContentsBody =>
      'Every bill, every month of your rounds, and every payment you '
      'recorded — amounts, dates, methods and notes included. Rounds writes '
      'the file and reads it back, so an export always imports cleanly into '
      'another install.';
  @override
  String get backupInfoImportTitle => 'Importing replaces everything';
  @override
  String get backupInfoImportBody =>
      'A backup is restored as-is over your current data — it is never '
      'merged. Reminders are rebuilt afterwards, so a restored phone goes '
      'back to nagging you on schedule.';
  @override
  String get backupInfoTip =>
      'Rounds is offline, so this file is your only copy. Export every few '
      'months and keep it somewhere you won\'t lose it.';
  @override
  String get infoSheetDismiss => 'Got it';
  @override
  String get aboutSection => 'About';
  @override
  String get appVersionLabel => 'Version 1.0.0';

  // ── FAQ screen ───────────────────────────────────────────────────────────────

  @override
  String get faqTitle => 'FAQ';
  @override
  String get faqSettingsSubtitle => 'Reminders, privacy, battery, backups';
  @override
  String get faqSectionBasics => 'The basics';
  @override
  String get faqSectionReminders => 'Reminders & battery';
  @override
  String get faqSectionData => 'Your data';
  @override
  String get faqSectionProject => 'The project';
  @override
  String get faqQWhatIsRound => 'What is a "round"?';
  @override
  String get faqAWhatIsRound =>
      'Every month is a new round of the same bills. The Round tab shows how '
      'the current month is going — what is paid, pending, or overdue — while '
      'the Bills tab holds the recurring set itself: names, amounts, and due '
      'days.';
  @override
  String get faqQOffline => 'Does Rounds use the internet?';
  @override
  String get faqAOffline =>
      'No. Rounds is fully offline: no accounts, no cloud, no tracking. '
      'Everything lives in a database on this phone, and nothing ever leaves '
      'it unless you export it yourself.';
  @override
  String get faqQLanguage => 'What does changing the language change?';
  @override
  String get faqALanguage =>
      'The wording the app itself uses — labels, buttons, notifications, this '
      'page. What you typed is left alone: bill names, notes and payment '
      'references are your records, not app text, so Rounds never rewrites '
      'them. Switching is safe at any time and changes no data. Reminders '
      'already handed to your phone keep their old wording until the app '
      'refreshes them, the next time you leave it.';
  @override
  String get faqQHowReminders => 'How do reminders work?';
  @override
  String get faqAHowReminders =>
      'Reminders are handed to your phone in advance, so the system shows '
      'them on its own — no internet and no background work needed. Each '
      'unpaid bill reminds you the day before, on the due day, and for three '
      'days after; once overdue, Rounds nags daily until you mark it paid. '
      'Marking a bill paid stops its reminders immediately.';
  @override
  String get faqQNoReminders => 'I\'m not getting reminders';
  @override
  String get faqANoReminders =>
      'Two system permissions matter: notifications, and "Alarms & '
      'reminders" (exact alarms). The button below checks both. Some phones '
      'also shut down apps aggressively to save battery — if reminders still '
      'go missing, allow Rounds to run unrestricted in your battery '
      'settings.';
  @override
  String get faqCheckNotifButton => 'Check notification settings';
  @override
  String get faqNotifOk => 'Notifications are ready.';
  @override
  String get faqNotifIssue =>
      'Check notifications and "Alarms & reminders" for Rounds in system '
      'settings.';
  @override
  String get faqQBattery => 'Does Rounds drain battery?';
  @override
  String get faqABattery =>
      'No. Rounds runs no background services and does no periodic work — '
      'the system fires reminders by itself, and the app refreshes its '
      'schedule in the moment you leave it. If your phone ever force-stops '
      'the app, simply opening it again repairs everything.';
  @override
  String get faqQBackup => 'What if I lose or change my phone?';
  @override
  String get faqABackup =>
      'Because Rounds is offline, there is no cloud copy — your data exists '
      'only on this device. Export a backup from Settings every few months '
      '(it\'s a small file you can keep anywhere), and import it on a new '
      'phone to pick up right where you left off, reminders included.';
  @override
  String get faqQJsonFile => 'What exactly is the backup file?';
  @override
  String get faqAJsonFile =>
      'A JSON file: plain text in an open, widely used exchange format that '
      'any text editor can open and no company owns. It holds your bills, '
      'your rounds and your payments, and Rounds is what writes it and '
      'reads it back — so a file exported here always imports cleanly '
      'somewhere else. Keep it anywhere you like; it is yours.';
  @override
  String get faqQHistory => 'Does old history pile up forever?';
  @override
  String get faqAHistory =>
      'Yes, on purpose — past rounds are your payment record, and the '
      'History tab is built from them. Storage-wise it\'s negligible: a full '
      'year of bills weighs a few kilobytes, so even a decade of history '
      'stays feather-light. Deleting a bill is the only thing that erases '
      'its history, which is why archiving is usually the better choice.';
  @override
  String get faqQOpenSource => 'Can I request features or see the code?';
  @override
  String get faqAOpenSource =>
      'Rounds is open source. Feature ideas, bug reports, and forks are all '
      'welcome — the project lives on GitHub.';
  @override
  String get faqOpenRepoButton => 'Open on GitHub';

  // ── Onboarding ───────────────────────────────────────────────────────────────

  @override
  String get onboardTitle1 => 'Every month is a round';
  @override
  String get onboardBody1 =>
      'Your bills repeat — rent, internet, streaming. Rounds tracks each '
      'month as one round: see what\'s paid, pending, or overdue at a '
      'glance, and tap a bill to mark it paid.';
  @override
  String get onboardTitle2 => 'Set up your bills once';
  @override
  String get onboardBody2 =>
      'Add each recurring bill with its due day — the amount is optional. '
      'The Bills tab holds the set; every new month builds its round from '
      'it. Archive instead of deleting to keep your history.';
  @override
  String get onboardTitle3 => 'Reminders that just work';
  @override
  String get onboardBody3 =>
      'Fully offline, handled by your phone itself: a heads-up the day '
      'before, on the due day, and daily once overdue — until you mark the '
      'bill paid. Allow notifications so they can reach you.';
  @override
  String get onboardNext => 'Next';
  @override
  String get onboardEnableReminders => 'Turn on reminders';
  @override
  String get onboardSkip => 'Maybe later';
  @override
  String get onboardSampleRent => 'Rent';
  @override
  String get onboardSampleSchool => 'School fees';
  @override
  String get onboardSampleSchoolCategory => 'Education';
  @override
  String get onboardSampleCreditCard => 'Credit card';
  @override
  String get importDataDialogTitle => 'Import data?';
  @override
  String get importDataDialogContent =>
      'This will replace ALL current data with the contents of the '
      'backup file. This cannot be undone.';
  @override
  String get importAndReplaceButton => 'Import & Replace';
  @override
  String importSuccessSummary(int bills, int records) {
    final recordsLabel = records == 1
        ? '1 payment record'
        : '$records payment records';
    return 'Imported ${billsCount(bills)} and $recordsLabel.';
  }

  @override
  String get importErrorInvalidFile => 'The file is not a valid Rounds backup.';
  @override
  String get importErrorUnsupportedVersion =>
      'This backup was created by a newer version of Rounds.';
  @override
  String get importErrorReadFailed => 'Could not read the file.';
  @override
  String get importErrorGeneric => 'Import failed.';
  @override
  String get languageSection => 'Language';
  @override
  String get englishLanguage => 'English';
  @override
  String get spanishLanguage => 'Spanish';

  @override
  String get testNotificationTitle => 'Send test notification';
  @override
  String get testNotificationSubtitle => 'Uses last bill — fires in 10 seconds';
  @override
  String get noBillsThisMonth => 'No bills found for this month';
  @override
  String testNotificationScheduled(String name) =>
      'Test notification for "$name" fires in 10 seconds';
  @override
  String testNotificationFailed(String e) => 'Error: $e';

  // ── Notifications ──────────────────────────────────────────────────────────────

  @override
  String get notificationDueToday => 'due today';
  @override
  String get notificationTomorrow => 'due tomorrow';
  @override
  String get notificationBillLabel => 'Bill';
  @override
  String get monthlyReminderTitle => 'A new round of bills';
  @override
  String get monthlyReminderBody =>
      'A new month is starting — get ready for another round of bills.';
  @override
  String get snooze30Min => '30 min';
  @override
  String get snooze1Hour => '1 hour';
  @override
  String get snooze3Hours => '3 hours';
  @override
  String reminderRescheduledFor(String time) =>
      'Reminder rescheduled for $time';

  // ── Payment methods ────────────────────────────────────────────────────────────

  @override
  String get paymentCash => 'Cash';
  @override
  String get paymentBankTransfer => 'Bank Transfer';
  @override
  String get paymentCard => 'Card';
  @override
  String get paymentAutoDebit => 'Auto-debit';
  @override
  String get paymentOther => 'Other';

  // ── Categories ─────────────────────────────────────────────────────────────────

  @override
  String translateCategory(String key) => key;
}
