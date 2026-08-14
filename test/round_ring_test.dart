import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/widgets/round_ring.dart';

void main() {
  double degrees(double radians) => radians * 180 / math.pi;

  group('ringSegmentAngles', () {
    test('no bills, no segments', () {
      expect(ringSegmentAngles(0), isEmpty);
      expect(ringSegmentAngles(-1), isEmpty);
    });

    test('a single bill nearly closes the circle', () {
      final segments = ringSegmentAngles(1);
      expect(segments, hasLength(1));
      expect(degrees(segments.single.sweep), closeTo(348, 0.001));
    });

    test('segments and gaps tile the full circle exactly', () {
      for (final count in [2, 3, 5, 8, 12, 31]) {
        final segments = ringSegmentAngles(count);
        expect(segments, hasLength(count));

        final slot = 360 / count;
        for (var i = 0; i < count; i++) {
          expect(
            degrees(segments[i].sweep),
            closeTo(degrees(segments[0].sweep), 0.001),
            reason: 'all sweeps equal for count=$count',
          );
          if (i > 0) {
            expect(
              degrees(segments[i].start - segments[i - 1].start),
              closeTo(slot, 0.001),
              reason: 'segments evenly spaced for count=$count',
            );
          }
        }

        // Sweeps plus gaps cover the circle with nothing left over.
        final totalSweep =
            segments.fold(0.0, (sum, s) => sum + degrees(s.sweep));
        final gap = slot - degrees(segments[0].sweep);
        expect(totalSweep + gap * count, closeTo(360, 0.001));
      }
    });

    test('the dial starts at 12 o\'clock, offset by half a gap', () {
      final segments = ringSegmentAngles(8);
      final gap = 360 / 8 - degrees(segments[0].sweep);
      expect(degrees(segments.first.start), closeTo(-90 + gap / 2, 0.001));
    });

    test('gap shrinks on busy months so arcs never vanish', () {
      final many = ringSegmentAngles(40);
      final slot = 360 / 40;
      final gap = slot - degrees(many.first.sweep);
      expect(gap, closeTo(slot * 0.35, 0.001));
      expect(degrees(many.first.sweep), greaterThan(0));
    });
  });
}
