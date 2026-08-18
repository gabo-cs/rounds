import 'dart:async';

import 'package:flutter/material.dart';

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

export 'app_localizations_en.dart';
export 'app_localizations_es.dart';

abstract class AppLocalizations {
  // ── Factory ────────────────────────────────────────────────────────────────

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = [Locale('en'), Locale('es')];

  // ── Locale name ─────────────────────────────────────────────────────────────

  String get localeName;

  // ── Navigation ───────────────────────────────────────────────────────────────

  /// The first tab is one month's round, not a "home" — named after the
  /// app's own vocabulary.
  String get navRound;
  String get navBills;
  String get navHistory;
  String get navSettings;

  // ── Common ───────────────────────────────────────────────────────────────────

  String get cancel;
  String get delete;
  String get edit;
  String get undo;
  String get archive;
  String get unarchive;
  String get paid;
  String itemsCount(int count);

  /// Friendly fallback shown when a screen fails to load its data.
  String get genericErrorMessage;

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  /// Full label shown on a pending bill card, e.g. "Due the 15th" / "Vence el 15".
  String dueThe(int day);

  /// Label for an overdue bill, e.g. "Was due the 24th" / "Venció el 24".
  String overdueSince(int day);

  /// Month-aware overdue label for notifications, e.g. "Was due Jun 5" /
  /// "Venció el 5 jun." — overdue nags can reference a past month's bill,
  /// where a bare day number would read as the current month's.
  String overdueSinceDate(DateTime date);

  /// Option shown in the due-day dropdown, e.g. "15th of the month" / "Día 15 del mes".
  String dueDayOption(int day);

  // ── Home screen ──────────────────────────────────────────────────────────────

  String get pending;
  String get overdue;
  String get noBillsYet;
  String get addFirstBill;
  String get addFirstBillHomeSubtitle;
  String get todayButton;
  String get previousMonthTooltip;
  String get nextMonthTooltip;

  /// Year-position tag under the month name, e.g. "round 8" / "ronda 8".
  String roundNumber(int month);

  /// Summary headline next to the Round, e.g. "5 of 8 paid" / "5 de 8 pagadas".
  String paidOfTotal(int paid, int total);

  /// Overdue tally in the summary line, e.g. "1 overdue" / "1 vencida".
  String overdueCount(int count);

  // ── Bills screen ─────────────────────────────────────────────────────────────

  String get billsTitle;

  /// Caption under the Bills title separating this screen's job (the
  /// recurring set-up) from the Round tab's (each month's status) — the two
  /// lists show the same names, so this heads off the confusion.
  String get billsScreenHint;
  String get archivedLabel;

  /// Count of bills set up, shown under the Bills title, e.g. "12 bills".
  String billsCount(int count);

  String get addFirstBillBillsSubtitle;
  String get deleteBillDialogTitle;
  String deleteBillDialogContent(String name);

  /// Info panel in the delete dialog nudging toward the reversible option.
  String get archiveInsteadHint;
  String get archiveInsteadButton;
  String get deleteBillButton;

  // ── Bill form ─────────────────────────────────────────────────────────────────

  String get editBillTitle;
  String get newBillTitle;
  String get thisArchivedBanner;
  String get billNameLabel;
  String get billNameHint;
  String get billNameRequired;
  String get billNameTooLong;
  String get amountLabel;
  String get amountHint;
  String get amountInvalid;
  String get dueDayLabel;
  String get categoryLabel;
  String get notesLabel;
  String get notesHint;
  String get saveChangesButton;
  String get addBillButton;
  String failedToSave(String e);
  String get archiveBillDialogTitle;
  String archiveBillDialogContent(String name);
  String get archiveButton;
  String get customCategoryChip;
  String get customCategoryHint;
  String get billNotFound;
  String get editBillTooltip;
  String get paymentHistoryTitle;
  String get noPaymentHistoryYet;
  String get archivedChipLabel;
  String dueOnDayEachMonth(int day);
  String get unpaid;

  // ── Mark paid sheet ───────────────────────────────────────────────────────────

  String get updatePaymentSubtitle;
  String get markAsPaidSubtitle;
  String get datePaidLabel;
  String get amountPaidLabel;
  String get amountPaidHint;
  String get paymentMethodLabel;
  String get referenceLabel;
  String get referenceHint;
  String get updatePaymentButton;
  String get confirmPaymentButton;
  String get undoPaymentButton;
  String get undoPaymentDialogTitle;
  String get undoPaymentDialogContent;
  String paidOnDate(DateTime date);

  /// Formats a date for display, e.g. "Mar 15" / "15 mar."
  String formatShortDate(DateTime date);

  // ── History screen ────────────────────────────────────────────────────────────

  String get historyTitle;
  String get exportDataTooltip;
  String billsPaidOf(int paid, int total);
  String get allPaid;
  String pendingCount(int count);
  String get noHistoryYet;
  String get noHistorySubtitle;
  String exportFailed(String e);
  String monthLabel(int year, int month);

  // ── Settings screen ───────────────────────────────────────────────────────────

  String get settingsTitle;
  String get appearanceSection;
  String get lightTheme;
  String get systemTheme;
  String get darkTheme;
  String get notificationsSection;
  String get billRemindersTitle;
  String get billRemindersSubtitle;
  String get notificationDenied;
  String get dataSection;
  String get exportDataTitle;
  String get exportDataSubtitle;
  String get importDataTitle;
  String get importDataSubtitle;

  /// The (?) beside the Data section header, and the sheet it opens.
  String get backupInfoTooltip;
  String get backupInfoTitle;
  String get backupInfoIntro;
  String get backupInfoWhatTitle;
  String get backupInfoWhatBody;
  String get backupInfoContentsTitle;
  String get backupInfoContentsBody;
  String get backupInfoImportTitle;
  String get backupInfoImportBody;
  String get backupInfoTip;
  String get backupInfoDismiss;
  String get aboutSection;
  String get appVersionLabel;

  // ── FAQ screen ───────────────────────────────────────────────────────────────

  String get faqTitle;

  /// Subtitle for the Settings tile that opens the FAQ.
  String get faqSettingsSubtitle;

  String get faqSectionBasics;
  String get faqSectionReminders;
  String get faqSectionData;
  String get faqSectionProject;

  String get faqQWhatIsRound;
  String get faqAWhatIsRound;
  String get faqQOffline;
  String get faqAOffline;
  String get faqQHowReminders;
  String get faqAHowReminders;
  String get faqQNoReminders;
  String get faqANoReminders;
  String get faqCheckNotifButton;
  String get faqNotifOk;
  String get faqNotifIssue;
  String get faqQBattery;
  String get faqABattery;
  String get faqQBackup;
  String get faqABackup;
  String get faqQJsonFile;
  String get faqAJsonFile;
  String get faqQHistory;
  String get faqAHistory;
  String get faqQOpenSource;
  String get faqAOpenSource;
  String get faqOpenRepoButton;

  // ── Onboarding ───────────────────────────────────────────────────────────────

  String get onboardTitle1;
  String get onboardBody1;
  String get onboardTitle2;
  String get onboardBody2;
  String get onboardTitle3;
  String get onboardBody3;
  String get onboardNext;
  String get onboardEnableReminders;
  String get onboardSkip;

  /// Sample bills on the onboarding's Bills page — deliberately the kind
  /// nobody can put on autopay, since those are the ones Rounds is for.
  String get onboardSampleRent;
  String get onboardSampleSchool;

  /// A category outside [AppConstants.categories], so the samples show that
  /// categories can be anything the user types.
  String get onboardSampleSchoolCategory;
  String get onboardSampleCreditCard;
  String get importDataDialogTitle;
  String get importDataDialogContent;
  String get importAndReplaceButton;

  /// Post-import confirmation with what actually arrived, e.g.
  /// "Imported 14 bills and 42 payment records."
  String importSuccessSummary(int bills, int records);
  String get importErrorInvalidFile;
  String get importErrorUnsupportedVersion;
  String get importErrorReadFailed;
  String get importErrorGeneric;
  String get languageSection;
  String get englishLanguage;
  String get spanishLanguage;
  String get currencySection;
  String get testNotificationTitle;
  String get testNotificationSubtitle;
  String get noBillsThisMonth;
  String testNotificationScheduled(String name);
  String testNotificationFailed(String e);

  // ── Notifications ──────────────────────────────────────────────────────────────

  String get notificationDueToday;
  String get notificationTomorrow;
  String get notificationBillLabel;

  /// General reminder fired on the 1st of every month.
  String get monthlyReminderTitle;
  String get monthlyReminderBody;

  String get snooze30Min;
  String get snooze1Hour;
  String get snooze3Hours;

  /// Snooze confirmation, e.g. "Reminder rescheduled for 2:45 PM".
  String reminderRescheduledFor(String time);

  // ── Payment methods ────────────────────────────────────────────────────────────

  String get paymentCash;
  String get paymentBankTransfer;
  String get paymentCard;
  String get paymentAutoDebit;
  String get paymentOther;

  // ── Categories ─────────────────────────────────────────────────────────────────

  /// Translates a known English category key; returns the key itself for unknowns.
  String translateCategory(String key);
}

// ─────────────────────────────────────────────────────────────────────────────
// Delegate
// ─────────────────────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'es'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    switch (locale.languageCode) {
      case 'es':
        return AppLocalizationsEs();
      default:
        return AppLocalizationsEn();
    }
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
