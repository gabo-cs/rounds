import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/utils/notification_service.dart';

void main() {
  group('overdueLadder', () {
    test('covers the 3 days after the due date, one ping per day', () {
      final ladder = overdueLadder(DateTime(2026, 7, 10));

      expect(ladder, hasLength(3));
      expect(
        ladder.map((s) => s.fireDay).toList(),
        [for (var d = 11; d <= 13; d++) DateTime(2026, 7, d)],
      );
    });

    test('day 1 uses the frozen overdue slot 0, days 2–3 use slots 4–5', () {
      final ladder = overdueLadder(DateTime(2026, 7, 10));

      expect(ladder.first.offset, 0);
      expect(ladder.skip(1).map((s) => s.offset).toList(), [4, 5]);
    });

    test('offsets never collide with the upcoming-reminder slots 1–3', () {
      final ladder = overdueLadder(DateTime(2026, 7, 10));

      for (final step in ladder) {
        expect(step.offset, isNot(isIn([1, 2, 3])));
        expect(step.offset, lessThan(10),
            reason: 'must stay inside the instanceId*10+offset scheme');
      }
    });

    test('rolls over a month boundary', () {
      final ladder = overdueLadder(DateTime(2026, 7, 30));

      expect(
        ladder.map((s) => s.fireDay).toList(),
        [DateTime(2026, 7, 31), DateTime(2026, 8, 1), DateTime(2026, 8, 2)],
      );
    });

    test('rolls over a year boundary', () {
      final ladder = overdueLadder(DateTime(2026, 12, 30));

      expect(ladder.first.fireDay, DateTime(2026, 12, 31));
      expect(ladder.last.fireDay, DateTime(2027, 1, 2));
    });

    test('handles February in a non-leap year', () {
      final ladder = overdueLadder(DateTime(2026, 2, 27));

      expect(
        ladder.map((s) => s.fireDay).toList(),
        [DateTime(2026, 2, 28), DateTime(2026, 3, 1), DateTime(2026, 3, 2)],
      );
    });
  });
}
