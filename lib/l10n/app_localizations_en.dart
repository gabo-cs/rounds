import 'package:intl/intl.dart';

import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  @override
  String get localeName => 'en';

  // ── Navigation ───────────────────────────────────────────────────────────────

  @override
  String get navHome => 'HOME';
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

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  @override
  String dueThe(int day) => 'Due the ${_ordinal(day)}';

  @override
  String overdueSince(int day) => 'Was due the ${_ordinal(day)}';

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
  String errorLoadingBills(String e) => 'Error loading bills: $e';

  // ── Bills screen ─────────────────────────────────────────────────────────────

  @override
  String get billsTitle => 'Bills';
  @override
  String get active => 'Active';
  @override
  String get archivedLabel => 'Archived';
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
  String failedToLoadHistory(String e) => 'Failed to load history: $e';
  @override
  String billsPaidOf(int paid, int total) => '$paid of $total bills paid';
  @override
  String get allPaid => 'All paid';
  @override
  String pendingCount(int count) =>
      count == 1 ? '1 pending' : '$count pending';
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
      'Get notified 2 days and 1 day before each bill is due';
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
  String get aboutSection => 'About';
  @override
  String get appVersionLabel => 'Version 1.0.0';
  @override
  String get importDataDialogTitle => 'Import data?';
  @override
  String get importDataDialogContent =>
      'This will replace ALL current data with the contents of the '
      'backup file. This cannot be undone.';
  @override
  String get importAndReplaceButton => 'Import & Replace';
  @override
  String get importInstructions =>
      'To import, share your backup JSON file to Rounds from '
      'your file manager or another app.';
  @override
  String get languageSection => 'Language';
  @override
  String get englishLanguage => 'English';
  @override
  String get spanishLanguage => 'Spanish';

  // ── Notifications ──────────────────────────────────────────────────────────────

  @override
  String get notificationTomorrow => 'due tomorrow';
  @override
  String get notificationIn2Days => 'due in 2 days';
  @override
  String get notificationBillLabel => 'Bill';
  @override
  String get snooze30Min => '30 min';
  @override
  String get snooze1Hour => '1 hour';
  @override
  String get snooze3Hours => '3 hours';

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
