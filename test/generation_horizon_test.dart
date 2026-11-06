import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/features/round/providers/round_providers.dart';

void main() {
  SelectedMonth m(int year, int month) =>
      SelectedMonth(year: year, month: month);

  group('monthsFromNow', () {
    final now = DateTime(2026, 11, 6);

    test('is zero for the current month, negative for past ones', () {
      expect(monthsFromNow(m(2026, 11), now: now), 0);
      expect(monthsFromNow(m(2026, 10), now: now), -1);
    });

    test('counts across year boundaries', () {
      expect(monthsFromNow(m(2027, 1), now: now), 2);
      expect(monthsFromNow(m(2025, 12), now: now), -11);
    });

    test('December: next January is one month away', () {
      expect(monthsFromNow(m(2027, 1), now: DateTime(2026, 12, 31)), 1);
    });
  });

  test('the horizon ends exactly one year past the current month', () {
    // The last generated round is the same month next year; the one after it
    // is the first to show as planned.
    final now = DateTime(2026, 12, 15);

    expect(monthsFromNow(m(2027, 12), now: now), kGenerationHorizonMonths);
    expect(
      monthsFromNow(m(2028, 1), now: now),
      greaterThan(kGenerationHorizonMonths),
    );
  });
}
