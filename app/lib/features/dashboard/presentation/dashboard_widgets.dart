import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../application/dashboard_view_model.dart';

/// Section heading with an optional trailing action.
class DashSectionTitle extends StatelessWidget {
  /// Creates a heading.
  const DashSectionTitle(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Primary-filled card with total, active and response rate.
class SummaryCard extends StatelessWidget {
  /// Creates the card.
  const SummaryCard({required this.vm, super.key});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(Radii.summary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Stat(
                  value: '${vm.total}',
                  label: DashboardStrings.statApplications,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${vm.active}',
                  label: DashboardStrings.statActive,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${vm.responsePercent}%',
                  label: DashboardStrings.statResponse,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Semantics(
            label: DashboardStrings.responseSemantics(vm.responsePercent),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: vm.responseFraction,
                  minHeight: 8,
                  backgroundColor: onPrimary.withValues(alpha: 0.25),
                  valueColor: AlwaysStoppedAnimation(onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: onPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: onPrimary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Five equal tiles, one per status; tapping filters the applications list.
class StatusTiles extends StatelessWidget {
  /// Creates the tiles.
  const StatusTiles({required this.tiles, required this.onTap, super.key});

  final List<StatusTileVm> tiles;
  final ValueChanged<StatusTileVm> onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Tile(
              vm: tiles[i],
              style: StatusStyle.of(tiles[i].status, brightness),
              onTap: () => onTap(tiles[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.vm, required this.style, required this.onTap});

  final StatusTileVm vm;
  final StatusStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: DashboardStrings.tileSemantics(vm.status.label, vm.count),
      excludeSemantics: true,
      child: Material(
        color: style.chipBackground,
        borderRadius: BorderRadius.circular(Radii.input),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              children: [
                Icon(style.icon, size: 20, color: style.chipText),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${vm.count}',
                    style: TextStyle(
                      color: style.chipText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    vm.status.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: style.chipText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One recent status change.
class ActivityRow extends StatelessWidget {
  /// Creates a row.
  const ActivityRow({required this.vm, required this.onTap, super.key});

  final ActivityVm vm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(vm.status, theme.brightness);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Sizes.minTouch),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: style.chipBackground,
                  borderRadius: BorderRadius.circular(Radii.chip),
                ),
                child: Icon(style.icon, color: style.chipText, size: 22),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: DashboardStrings.movedPrefix),
                          TextSpan(
                            text: vm.company,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text:
                                '${DashboardStrings.movedMiddle}${vm.status.label}',
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      vm.relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration + call to action when there are no applications.
class DashboardEmpty extends StatelessWidget {
  /// Creates the empty state.
  const DashboardEmpty({required this.onAdd, super.key});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xl),
      child: Column(
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 160,
              height: 130,
              child: CustomPaint(
                painter: _EmptyPainter(
                  primary: theme.colorScheme.primary,
                  container: theme.colorScheme.primaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            DashboardStrings.emptyTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            DashboardStrings.emptyMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.xl),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: PrimaryButton(
              label: DashboardStrings.emptyAction,
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPainter extends CustomPainter {
  const _EmptyPainter({required this.primary, required this.container});

  final Color primary;
  final Color container;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bg = Paint()..color = container;
    canvas.drawCircle(Offset(w / 2, h / 2), h / 2, bg);

    // Briefcase body, handle and clasp.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.58),
        width: w * 0.5,
        height: h * 0.42,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(body, Paint()..color = primary);
    final handle = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.34),
          width: w * 0.2,
          height: h * 0.18,
        ),
        const Radius.circular(6),
      ),
      handle,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.58),
        width: w * 0.5,
        height: 3,
      ),
      Paint()..color = container,
    );
    canvas.drawCircle(Offset(w / 2, h * 0.58), 6, Paint()..color = container);

    // A couple of sparkles.
    final spark = Paint()..color = primary.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(w * 0.14, h * 0.22), 4, spark);
    canvas.drawCircle(Offset(w * 0.88, h * 0.3), 5, spark);
    canvas.drawCircle(Offset(w * 0.8, h * 0.85), 3, spark);
  }

  @override
  bool shouldRepaint(_EmptyPainter old) =>
      old.primary != primary || old.container != container;
}
