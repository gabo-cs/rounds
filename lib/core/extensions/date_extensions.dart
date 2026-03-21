extension DateTimeExtensions on DateTime {
  DateTime get firstDayOfMonth => DateTime(year, month, 1);

  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;

  DateTime get nextMonth {
    if (month == 12) return DateTime(year + 1, 1);
    return DateTime(year, month + 1);
  }

  DateTime get previousMonth {
    if (month == 1) return DateTime(year - 1, 12);
    return DateTime(year, month - 1);
  }
}
