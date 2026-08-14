import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One arc of a segmented ring, in radians. Angles follow Canvas.drawArc
/// conventions (0 at 3 o'clock, clockwise positive); the layout starts at
/// 12 o'clock so the ring reads like a dial.
typedef RingSegment = ({double start, double sweep});

/// Angular layout for the Round: [count] equal arcs separated by small gaps,
/// clockwise from 12 o'clock. Pure so the geometry is testable without a
/// canvas.
///
/// The gap narrows as segments multiply (35% of a slot at most) so arcs never
/// collapse into their separators on a busy month.
List<RingSegment> ringSegmentAngles(int count, {double gapDegrees = 12}) {
  if (count <= 0) return const [];
  final slot = 360 / count;
  final gap = math.min(gapDegrees, slot * 0.35);
  final sweep = slot - gap;
  const top = -90.0;
  return [
    for (var i = 0; i < count; i++)
      (
        start: _radians(top + gap / 2 + i * slot),
        sweep: _radians(sweep),
      ),
  ];
}

double _radians(double degrees) => degrees * math.pi / 180;

/// The Round — a month drawn as a circle, one segment per bill, ordered by
/// due day and colored by state. The signature element of the app.
class RoundRing extends StatelessWidget {
  const RoundRing({
    super.key,
    required this.size,
    required this.segmentColors,
    required this.trackColor,
    this.strokeWidth = 5,
    this.child,
  });

  /// Colors in due-day order. An empty list paints just the faint track.
  final List<Color> segmentColors;
  final Color trackColor;
  final double size;
  final double strokeWidth;

  /// Centered content, typically the settled count.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RoundRingPainter(
          segmentColors: segmentColors,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RoundRingPainter extends CustomPainter {
  _RoundRingPainter({
    required this.segmentColors,
    required this.trackColor,
    required this.strokeWidth,
  });

  final List<Color> segmentColors;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height)
        .deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (segmentColors.isEmpty) {
      paint
        ..color = trackColor
        ..strokeCap = StrokeCap.butt;
      canvas.drawOval(rect, paint);
      return;
    }

    final segments = ringSegmentAngles(segmentColors.length);
    for (var i = 0; i < segments.length; i++) {
      paint.color = segmentColors[i];
      canvas.drawArc(rect, segments[i].start, segments[i].sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RoundRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      !listEquals(oldDelegate.segmentColors, segmentColors);
}
