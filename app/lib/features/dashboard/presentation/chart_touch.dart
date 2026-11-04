import 'package:flutter/widgets.dart';

/// Press / hover / drag preview and tap for a chart (CHARTS.md §1.5, §2.4).
///
/// It listens to raw pointer events instead of joining the gesture arena, so
/// the dashboard keeps scrolling: once the pointer moves more than
/// [cancelDistance] vertically the preview is cleared and the touch no longer
/// counts as a tap.
class ChartTouchRegion extends StatefulWidget {
  /// Creates the region.
  const ChartTouchRegion({
    required this.onPreview,
    required this.onTap,
    required this.child,
    this.cancelDistance = 12,
    super.key,
  });

  /// Called with the local pointer position while pressed or hovering, and
  /// with null when the preview ends.
  final ValueChanged<Offset?> onPreview;

  /// Called with the local position of a completed tap.
  final ValueChanged<Offset> onTap;

  final Widget child;
  final double cancelDistance;

  @override
  State<ChartTouchRegion> createState() => _ChartTouchRegionState();
}

class _ChartTouchRegionState extends State<ChartTouchRegion> {
  Offset? _downAt;
  bool _cancelled = false;
  bool _dragged = false;

  void _down(PointerDownEvent e) {
    _downAt = e.position;
    _cancelled = false;
    _dragged = false;
    widget.onPreview(e.localPosition);
  }

  void _move(PointerMoveEvent e) {
    final start = _downAt;
    if (start == null || _cancelled) return;
    final delta = e.position - start;
    if (delta.dy.abs() > widget.cancelDistance) {
      _cancelled = true;
      widget.onPreview(null);
      return;
    }
    if (delta.distance > widget.cancelDistance) _dragged = true;
    widget.onPreview(e.localPosition);
  }

  void _up(PointerUpEvent e) {
    final isTap = _downAt != null && !_cancelled && !_dragged;
    _downAt = null;
    if (isTap) widget.onTap(e.localPosition);
    widget.onPreview(null);
  }

  void _cancel(PointerCancelEvent e) {
    _downAt = null;
    widget.onPreview(null);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) {
        if (_downAt == null) widget.onPreview(null);
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        onPointerHover: (e) => widget.onPreview(e.localPosition),
        child: widget.child,
      ),
    );
  }
}
