import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Pulsing placeholder block shown while data loads. The pulse stops when the
/// platform asks to reduce motion.
class SkeletonBox extends StatefulWidget {
  /// Creates a placeholder; a null [width] fills the available width.
  const SkeletonBox({this.width, this.height = 16, this.radius = 8, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.outlineVariant;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final color = Color.lerp(
            base.withValues(alpha: 0.55),
            base,
            _controller.value,
          );
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          );
        },
      ),
    );
  }
}

/// Column of card-shaped skeleton rows for list screens.
class SkeletonList extends StatelessWidget {
  /// Creates a skeleton list.
  const SkeletonList({this.itemCount = 5, this.itemHeight = 96, super.key});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.screen),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
        itemBuilder: (_, _) =>
            SkeletonBox(height: itemHeight, radius: Radii.card),
      ),
    );
  }
}
