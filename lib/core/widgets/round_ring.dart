import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// One contiguous arc of the Round, in radians. Angles follow
/// Canvas.drawArc conventions (0 at 3 o'clock, clockwise positive); the
/// layout starts at 12 o'clock so the ring reads like a dial.
typedef RingArc<T> = ({T state, double start, double sweep});

/// Angular layout for the Round. Each entry in [states] is one bill, but
/// consecutive equal states merge into a single smooth arc — the ring shows
/// runs of state, not a dotted bead per bill. Arc length stays proportional
/// to how many bills a run contains. Pure so the geometry is testable
/// without a canvas.
List<RingArc<T>> ringArcs<T>(List<T> states, {double gapDegrees = 10}) {
  if (states.isEmpty) return const [];

  final runs = <({T state, int count})>[];
  for (final state in states) {
    if (runs.isNotEmpty && runs.last.state == state) {
      runs.last = (state: state, count: runs.last.count + 1);
    } else {
      runs.add((state: state, count: 1));
    }
  }

  // A single run closes into a full, unbroken circle.
  if (runs.length == 1) {
    return [
      (state: runs.single.state, start: _radians(-90), sweep: _radians(360)),
    ];
  }

  // The gap shrinks when single-bill runs get narrow, so no arc can ever
  // collapse into its separators.
  final unit = 360 / states.length;
  final gap = math.min(gapDegrees, unit * 0.5);

  final arcs = <RingArc<T>>[];
  var cursor = -90 + gap / 2;
  for (final run in runs) {
    arcs.add((
      state: run.state,
      start: _radians(cursor),
      sweep: _radians(run.count * unit - gap),
    ));
    cursor += run.count * unit;
  }
  return arcs;
}

double _radians(double degrees) => degrees * math.pi / 180;

/// The Round — a month drawn as a circle, one unit per bill, merged into
/// smooth state arcs. The signature element of the app.
class RoundRing extends StatelessWidget {
  const RoundRing({
    super.key,
    required this.size,
    required this.segmentColors,
    required this.trackColor,
    this.strokeWidth = 5,
    this.animate = false,
    this.child,
  });

  /// One color per bill, grouped by state by the caller. An empty list
  /// paints just the faint track.
  final List<Color> segmentColors;
  final Color trackColor;
  final double size;
  final double strokeWidth;

  /// Sweep the arcs in whenever the underlying data changes. Off by
  /// default so list-embedded mini rings stay still.
  final bool animate;

  /// Centered content, typically the settled count.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return _paint(1);
    }
    return TweenAnimationBuilder<double>(
      // Re-keying on the data restarts the sweep on real changes only —
      // a new month, a bill marked paid — not on incidental rebuilds.
      key: ValueKey(Object.hashAll(segmentColors)),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => _paint(progress),
    );
  }

  Widget _paint(double progress) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RoundRingPainter(
          segmentColors: segmentColors,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
          progress: progress,
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
    this.progress = 1,
  });

  final List<Color> segmentColors;
  final Color trackColor;
  final double strokeWidth;

  /// Fraction of each sweep drawn — the draw-in animation.
  final double progress;

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

    for (final arc in ringArcs(segmentColors)) {
      paint.color = arc.state;
      canvas.drawArc(rect, arc.start, arc.sweep * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_RoundRingPainter oldDelegate) =>
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progress != progress ||
      !listEquals(oldDelegate.segmentColors, segmentColors);
}
