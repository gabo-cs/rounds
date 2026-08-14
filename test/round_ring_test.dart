import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/widgets/round_ring.dart';

void main() {
  double degrees(double radians) => radians * 180 / math.pi;

  group('ringArcs', () {
    test('no bills, no arcs', () {
      expect(ringArcs(<String>[]), isEmpty);
    });

    test('a uniform month closes into one full circle', () {
      for (final states in [
        ['paid'],
        ['paid', 'paid', 'paid'],
        List.filled(12, 'pending'),
      ]) {
        final arcs = ringArcs(states);
        expect(arcs, hasLength(1));
        expect(arcs.single.state, states.first);
        expect(degrees(arcs.single.start), closeTo(-90, 0.001));
        expect(degrees(arcs.single.sweep), closeTo(360, 0.001));
      }
    });

    test('consecutive equal states merge into one arc', () {
      final arcs = ringArcs(['a', 'a', 'a', 'b', 'b', 'c']);
      expect(arcs, hasLength(3));
      expect([for (final arc in arcs) arc.state], ['a', 'b', 'c']);
    });

    test('arc length stays proportional to the bills in the run', () {
      const gap = 10.0;
      final arcs = ringArcs(['a', 'a', 'a', 'b', 'b', 'c'], gapDegrees: gap);
      const unit = 360 / 6;
      expect(degrees(arcs[0].sweep), closeTo(3 * unit - gap, 0.001));
      expect(degrees(arcs[1].sweep), closeTo(2 * unit - gap, 0.001));
      expect(degrees(arcs[2].sweep), closeTo(1 * unit - gap, 0.001));
    });

    test('arcs and gaps tile the full circle exactly', () {
      final arcs = ringArcs(['a', 'a', 'b', 'c', 'c', 'c', 'd', 'a']);
      final totalSweep = arcs.fold(0.0, (sum, arc) => sum + degrees(arc.sweep));
      expect(totalSweep + 10.0 * arcs.length, closeTo(360, 0.001));
    });

    test('the dial starts at 12 o\'clock, offset by half a gap', () {
      final arcs = ringArcs(['a', 'b'], gapDegrees: 10);
      expect(degrees(arcs.first.start), closeTo(-90 + 5, 0.001));
    });

    test('each arc starts where the previous run\'s slots end', () {
      final arcs = ringArcs(['a', 'a', 'b', 'c'], gapDegrees: 10);
      const unit = 360 / 4;
      expect(
        degrees(arcs[1].start - arcs[0].start),
        closeTo(2 * unit, 0.001),
      );
      expect(
        degrees(arcs[2].start - arcs[1].start),
        closeTo(unit, 0.001),
      );
    });

    test('gap shrinks on busy months so single-bill arcs never vanish', () {
      // 40 alternating bills: every run is one narrow slot.
      final states = [for (var i = 0; i < 40; i++) i.isEven ? 'a' : 'b'];
      final arcs = ringArcs(states);
      const unit = 360 / 40;
      expect(degrees(arcs.first.sweep), closeTo(unit / 2, 0.001));
      expect(degrees(arcs.first.sweep), greaterThan(0));
    });
  });
}
