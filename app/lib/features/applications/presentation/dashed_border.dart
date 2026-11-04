import 'package:flutter/material.dart';

/// Rounded-rectangle dashed outline, used to mark the next step in the status
/// flow.
class DashedBorder extends StatelessWidget {
  /// Wraps [child] with a dashed border.
  const DashedBorder({
    required this.child,
    required this.color,
    this.radius = 14,
    this.strokeWidth = 2,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(color, radius, strokeWidth),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter(this.color, this.radius, this.strokeWidth);

  final Color color;
  final double radius;
  final double strokeWidth;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}
