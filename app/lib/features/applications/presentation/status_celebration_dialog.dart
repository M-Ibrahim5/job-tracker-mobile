import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../domain/enums/enums.dart';

/// Whether moving to [status] deserves a message (offer or rejection).
bool hasStatusMessage(ApplicationStatus status) =>
    status == ApplicationStatus.offer || status == ApplicationStatus.rejected;

/// Shows a congratulation (offer) or encouragement (rejected) dialog for
/// [company]. Resolves when the user dismisses it.
Future<void> showStatusCelebration(
  BuildContext context, {
  required ApplicationStatus status,
  required String company,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => StatusCelebrationDialog(status: status, company: company),
  );
}

/// Dialog with an animated badge (and confetti for an offer).
class StatusCelebrationDialog extends StatefulWidget {
  /// Creates the dialog; [status] must be offer or rejected.
  const StatusCelebrationDialog({
    required this.status,
    required this.company,
    super.key,
  });

  final ApplicationStatus status;
  final String company;

  @override
  State<StatusCelebrationDialog> createState() =>
      _StatusCelebrationDialogState();
}

class _StatusCelebrationDialogState extends State<StatusCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  bool get _offer => widget.status == ApplicationStatus.offer;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(widget.status, theme.brightness);
    final badge = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.35, curve: Curves.elasticOut),
    );
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (_offer)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, _) =>
                      CustomPaint(painter: _ConfettiPainter(_controller.value)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.xl,
              Spacing.xl,
              Spacing.xl,
              Spacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: badge,
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: style.chipBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _offer
                          ? Icons.emoji_events_rounded
                          : Icons.favorite_rounded,
                      size: 44,
                      color: style.color,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    _offer
                        ? ApplicationStrings.offerTitle
                        : ApplicationStrings.rejectedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  _offer
                      ? ApplicationStrings.offerMessage(widget.company)
                      : ApplicationStrings.rejectedMessage(widget.company),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _offer
                          ? ApplicationStrings.offerAction
                          : ApplicationStrings.rejectedAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One-shot confetti falling over the dialog. Seeded, so it looks the same
/// every time and is cheap to test.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = [
    Color(0xFF1E88E5),
    Color(0xFFFFA000),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFE53935),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final x = random.nextDouble() * size.width;
      final delay = random.nextDouble() * 0.4;
      final speed = 0.6 + random.nextDouble() * 0.5;
      final progress = ((t - delay) / (1 - delay)).clamp(0.0, 1.0) * speed;
      if (progress <= 0 || progress >= 1) continue;
      final sway = math.sin(progress * 8 + i) * 12;
      final y = -10 + progress * (size.height + 20);
      paint.color = _colors[i % _colors.length].withValues(
        alpha: 1 - progress * progress,
      );
      canvas
        ..save()
        ..translate(x + sway, y)
        ..rotate(progress * 10 + i)
        ..drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-3, -5, 6, 10),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
