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

  String get navHome;
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

  // ── Due-date helpers ─────────────────────────────────────────────────────────

  /// Full label shown on a pending bill card, e.g. "Due the 15th" / "Vence el 15".
  String dueThe(int day);

  /// Label for an overdue bill, e.g. "Was due the 24th" / "Venció el 24".
  String overdueSince(int day);

  /// Option shown in the due-day dropdown, e.g. "15th of the month" / "Día 15 del mes".
  String dueDayOption(int day);

  // ── Home screen ──────────────────────────────────────────────────────────────

  String get pending;
  String get overdue;
  String get noBillsYet;
  String get addFirstBill;
  String get addFirstBillHomeSubtitle;
  String errorLoadingBills(String e);

  // ── Bills screen ─────────────────────────────────────────────────────────────

  String get billsTitle;
  String get active;
  String get archivedLabel;
  String get addFirstBillBillsSubtitle;
  String get deleteBillDialogTitle;
  String deleteBillDialogContent(String name);
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
  String failedToLoadHistory(String e);
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
  String get aboutSection;
  String get appVersionLabel;
  String get importDataDialogTitle;
  String get importDataDialogContent;
  String get importAndReplaceButton;
  String get importInstructions;
  String get languageSection;
  String get englishLanguage;
  String get spanishLanguage;

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
  bool isSupported(Locale locale) =>
      ['en', 'es'].contains(locale.languageCode);

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
