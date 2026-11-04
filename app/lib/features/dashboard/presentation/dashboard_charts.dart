import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../application/chart_logic.dart';
import '../application/dashboard_view_model.dart';
import 'chart_touch.dart';

/// Colors of the two dashboard charts (CHARTS.md §1, §2, §4).
class ChartColors {
  const ChartColors._({
    required this.surface,
    required this.border,
    required this.secondary,
    required this.skeleton,
    required this.barPast,
    required this.barPeak,
    required this.barCurrent,
    required this.barSelected,
    required this.barOutline,
    required this.dot,
    required this.grid,
    required this.tooltipBackground,
    required this.tooltipText,
    required this.currentLabel,
  });

  static const _light = ChartColors._(
    surface: Colors.white,
    border: Color(0xFFE6E8F0),
    secondary: Color(0xFF4A4F66),
    skeleton: Color(0xFFEEF0F6),
    barPast: Color(0xFFC5CBEF),
    barPeak: [Color(0xFF9FA8E6), Color(0xFFC5CBEF)],
    barCurrent: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
    barSelected: [Color(0xFF8E9AE0), Color(0xFF5C6BC0)],
    barOutline: Color(0xFF283593),
    dot: Color(0xFFD5D9EE),
    grid: Color(0xFFECEEF7),
    tooltipBackground: Color(0xFF1B1E2B),
    tooltipText: Colors.white,
    currentLabel: Color(0xFF3F51B5),
  );

  static const _dark = ChartColors._(
    surface: Color(0xFF1C1B22),
    border: Color(0xFF3A3A44),
    secondary: Color(0xFFB8B3BD),
    skeleton: Color(0xFF2A2A33),
    barPast: Color(0xFF3A4075),
    barPeak: [Color(0xFF6E78C8), Color(0xFF4A5199)],
    barCurrent: [Color(0xFF7986E0), Color(0xFF5C6BC0)],
    barSelected: [Color(0xFF9AA5E8), Color(0xFF7986E0)],
    barOutline: Color(0xFFC5CBEF),
    dot: Color(0xFF3A3A44),
    grid: Color(0xFF2A2A33),
    tooltipBackground: Color(0xFFE6E1E5),
    tooltipText: Color(0xFF1B1E2B),
    currentLabel: Color(0xFFAAB4F0),
  );

  /// Colors for the theme's brightness.
  static ChartColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  final Color surface;
  final Color border;
  final Color secondary;
  final Color skeleton;
  final Color barPast;
  final List<Color> barPeak;
  final List<Color> barCurrent;
  final List<Color> barSelected;
  final Color barOutline;
  final Color dot;
  final Color grid;
  final Color tooltipBackground;
  final Color tooltipText;
  final Color currentLabel;
}

/// Rounded, bordered surface shared by both charts.
class ChartCard extends StatelessWidget {
  /// Creates the card.
  const ChartCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Pipeline: segmented ring
// ---------------------------------------------------------------------------

const double _ringSize = 200;
const double _ringHole = 64;
const double _ringThickness = 24;
const double _ringThicknessSelected = 33;

Color _selectedText(StatusStyle style, Brightness brightness) =>
    brightness == Brightness.light
    ? style.chipText
    : Color.lerp(style.color, Colors.white, 0.2)!;

Color _selectedBackground(StatusStyle style, Brightness brightness) =>
    brightness == Brightness.light
    ? style.chipBackground
    : style.color.withValues(alpha: 0.18);

/// Segmented ring of the pipeline with a live center and a legend; tapping a
/// segment or a legend row opens the filtered list.
class PipelineCard extends StatefulWidget {
  /// Creates the card.
  const PipelineCard({
    required this.vm,
    required this.onOpenStatus,
    this.onAdd,
    super.key,
  });

  final DashboardViewModel vm;
  final ValueChanged<ApplicationStatus> onOpenStatus;

  /// Shown as "Add your first application" when there is nothing to chart.
  final VoidCallback? onAdd;

  @override
  State<PipelineCard> createState() => _PipelineCardState();
}

class _PipelineCardState extends State<PipelineCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  bool _introStarted = false;
  ApplicationStatus? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  ApplicationStatus? _statusAt(Offset? point) {
    if (point == null) return null;
    final slices = widget.vm.slices;
    final index = ringSegmentAt(point, const Size.square(_ringSize), [
      for (final s in slices) s.count,
    ], holeRadius: _ringHole);
    return index == null ? null : slices[index].status;
  }

  void _preview(Offset? point) {
    final next = _statusAt(point);
    if (next == _selected) return;
    if (next != null) Haptics.selection();
    setState(() => _selected = next);
  }

  void _open(ApplicationStatus status) {
    Haptics.success();
    widget.onOpenStatus(status);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final colors = ChartColors.of(context);
    return ChartCard(
      child: Semantics(
        container: true,
        label: vm.pipelineSummary,
        child: Column(
          children: [
            if (vm.total == 0)
              _EmptyRing(onAdd: widget.onAdd)
            else ...[
              _buildRing(context, colors),
              const SizedBox(height: 16),
              for (final t in vm.tiles)
                _LegendRow(
                  status: t.status,
                  count: t.count,
                  percent: vm.percents[t.status] ?? 0,
                  selected: _selected == t.status,
                  onTap: () => _open(t.status),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRing(BuildContext context, ChartColors colors) {
    final vm = widget.vm;
    final brightness = Theme.of(context).brightness;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final pie = PieChart(
      PieChartData(
        startDegreeOffset: -90,
        sectionsSpace: vm.slices.length > 1 ? 3 : 0,
        centerSpaceRadius: _ringHole,
        pieTouchData: PieTouchData(enabled: false),
        sections: [
          for (final s in vm.slices)
            PieChartSectionData(
              value: s.count.toDouble(),
              color: StatusStyle.of(s.status, brightness).color,
              radius: _selected == s.status
                  ? _ringThicknessSelected
                  : _ringThickness,
              showTitle: false,
            ),
        ],
      ),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
    );

    return ExcludeSemantics(
      child: SizedBox(
        width: _ringSize,
        height: _ringSize,
        child: ChartTouchRegion(
          onPreview: _preview,
          onTap: (point) {
            final status = _statusAt(point);
            if (status != null) _open(status);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _intro,
                child: pie,
                // Reveals the ring clockwise from 12 o'clock.
                builder: (_, child) {
                  final p = Curves.easeOutCubic.transform(_intro.value);
                  return ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => SweepGradient(
                      transform: const GradientRotation(-math.pi / 2),
                      colors: const [
                        Colors.white,
                        Colors.white,
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: [0, p, p, 1],
                    ).createShader(rect),
                    child: child,
                  );
                },
              ),
              IgnorePointer(
                child: SizedBox(
                  width: 112,
                  height: 92,
                  child: AnimatedSwitcher(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    child: _selected == null
                        ? _defaultCenter(colors)
                        : _selectedCenter(_selected!, brightness, colors),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultCenter(ChartColors colors) {
    return FittedBox(
      key: const ValueKey('ring-center-total'),
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _intro,
            builder: (_, _) {
              final p = Curves.easeOutCubic.transform(_intro.value);
              return Text(
                '${(widget.vm.total * p).round()}',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              );
            },
          ),
          const Text(
            DashboardStrings.statApplications,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _selectedCenter(
    ApplicationStatus status,
    Brightness brightness,
    ChartColors colors,
  ) {
    final vm = widget.vm;
    final color = _selectedText(StatusStyle.of(status, brightness), brightness);
    final count = vm.tiles.firstWhere((t) => t.status == status).count;
    return FittedBox(
      key: ValueKey('ring-center-${status.name}'),
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: color,
            ),
          ),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            DashboardStrings.shareOfTotal(vm.percents[status] ?? 0, vm.total),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.status,
    required this.count,
    required this.percent,
    required this.selected,
    required this.onTap,
  });

  final ApplicationStatus status;
  final int count;
  final int percent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = ChartColors.of(context);
    final style = StatusStyle.of(status, brightness);
    final base = Theme.of(context).colorScheme.onSurface;
    final text = selected ? _selectedText(style, brightness) : base;
    final weight = selected ? FontWeight.w800 : FontWeight.w600;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: DashboardStrings.legendSemantics(status.label, count, percent),
      onTap: onTap,
      child: Material(
        color: selected
            ? _selectedBackground(style, brightness)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Opacity(
              opacity: count == 0 ? 0.45 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 7,
                  horizontal: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: style.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        status.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: weight,
                          color: text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '$percent%',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: weight,
                          color: selected ? text : colors.secondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed circle with "0" for an account without applications.
class _EmptyRing extends StatelessWidget {
  const _EmptyRing({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    return Column(
      children: [
        SizedBox(
          width: _ringSize,
          height: _ringSize,
          child: CustomPaint(
            painter: _DashedCirclePainter(
              color: colors.border,
              inset: _ringThickness / 2 + 8,
            ),
            child: Center(
              child: SizedBox(
                width: 112,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        DashboardStrings.pipelineEmptyCenter,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (onAdd != null) ...[
          const SizedBox(height: 16),
          SecondaryButton(
            label: DashboardStrings.emptyAction,
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color, required this.inset});

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashes = 36;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.color != color || old.inset != inset;
}

/// Loading placeholder: gray ring and five legend rows.
class PipelineSkeleton extends StatelessWidget {
  /// Creates the placeholder.
  const PipelineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    return ChartCard(
      child: Column(
        children: [
          SizedBox(
            width: _ringSize,
            height: _ringSize,
            child: CustomPaint(
              painter: _RingSkeletonPainter(colors.skeleton),
              child: const SkeletonBox(
                width: _ringSize,
                height: _ringSize,
                radius: _ringSize / 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < ApplicationStatus.values.length; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              child: SkeletonBox(height: 34, radius: 12),
            ),
        ],
      ),
    );
  }
}

class _RingSkeletonPainter extends CustomPainter {
  const _RingSkeletonPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      _ringHole + _ringThickness / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringThickness,
    );
  }

  @override
  bool shouldRepaint(_RingSkeletonPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Applications per week: rounded bars
// ---------------------------------------------------------------------------

const double _plotBodyHeight = 156;
const double _weeklyMaxBarWidth = 28;
const double _barTopRadius = 8;

/// Eight bars of applications per week with a tooltip; tapping a bar opens
/// the list filtered to that week.
class WeeklyBarsCard extends StatefulWidget {
  /// Creates the card.
  const WeeklyBarsCard({
    required this.vm,
    required this.onOpenWeek,
    this.onAdd,
    super.key,
  });

  final DashboardViewModel vm;

  /// Called with the Monday of the tapped week.
  final ValueChanged<DateTime> onOpenWeek;
  final VoidCallback? onAdd;

  @override
  State<WeeklyBarsCard> createState() => _WeeklyBarsCardState();
}

class _WeeklyBarsCardState extends State<WeeklyBarsCard>
    with SingleTickerProviderStateMixin {
  static const _barMs = 500;
  static const _staggerMs = 40;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _barMs + 7 * _staggerMs),
  );
  bool _introStarted = false;
  int? _pressed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  int _columnAt(double dx, double width) {
    final count = widget.vm.bars.length;
    return (dx / (width / count)).floor().clamp(0, count - 1);
  }

  void _preview(Offset? point, double width) {
    final next = point == null ? null : _columnAt(point.dx, width);
    if (next == _pressed) return;
    if (next != null) Haptics.selection();
    setState(() => _pressed = next);
  }

  void _open(int index) {
    final bar = widget.vm.bars[index];
    if (bar.count == 0) return;
    Haptics.success();
    widget.onOpenWeek(bar.weekStart);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ChartColors.of(context);
    final vm = widget.vm;
    final allZero = vm.bars.every((b) => b.count == 0);
    final scaler = MediaQuery.textScalerOf(context);
    // Room above the tallest bar for the tooltip bubble, its arrow and gap.
    final reserve = math.max(40.0, scaler.scale(12) * 1.25 + 12 + 5 + 8 + 2);

    return ChartCard(
      child: Semantics(
        container: true,
        label: vm.barsSummary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      DashboardStrings.sectionWeekly,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    DashboardStrings.weeklyCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, box) => _chart(
                context,
                colors,
                box.maxWidth,
                reserve,
                scaler,
                allZero,
              ),
            ),
            const SizedBox(height: 8),
            _axisLabels(colors),
          ],
        ),
      ),
    );
  }

  Widget _chart(
    BuildContext context,
    ChartColors colors,
    double width,
    double reserve,
    TextScaler scaler,
    bool allZero,
  ) {
    final vm = widget.vm;
    final height = reserve + _plotBodyHeight;
    final columnWidth = width / vm.bars.length;
    final painter = _WeeklyPainter(
      bars: vm.bars,
      colors: colors,
      pressed: _pressed,
      reserve: reserve,
      textScaler: scaler,
      repaint: _intro,
      progress: _intro,
    );

    final chart = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: painter)),
          Row(
            children: [
              for (var i = 0; i < vm.bars.length; i++)
                SizedBox(
                  width: columnWidth,
                  height: height,
                  child: Semantics(
                    container: true,
                    button: vm.bars[i].count > 0,
                    excludeSemantics: true,
                    label: DashboardStrings.weekSemantics(
                      DateFormat('d MMM').format(vm.bars[i].weekStart),
                      vm.bars[i].count,
                    ),
                    onTap: vm.bars[i].count > 0 ? () => _open(i) : null,
                    child: const SizedBox.expand(),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (allZero) {
      return Stack(
        alignment: Alignment.center,
        children: [
          chart,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DashboardStrings.noWeeklyData,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.secondary,
                ),
              ),
              if (widget.onAdd != null)
                TextButton(
                  onPressed: widget.onAdd,
                  child: const Text(DashboardStrings.addApplicationShort),
                ),
            ],
          ),
        ],
      );
    }

    return ChartTouchRegion(
      onPreview: (p) => _preview(p, width),
      onTap: (p) => _open(_columnAt(p.dx, width)),
      child: chart,
    );
  }

  Widget _axisLabels(ChartColors colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.vm.axisStart,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.secondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              DashboardStrings.thisWeek,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: colors.currentLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyPainter extends CustomPainter {
  _WeeklyPainter({
    required this.bars,
    required this.colors,
    required this.pressed,
    required this.reserve,
    required this.textScaler,
    required this.progress,
    super.repaint,
  });

  final List<BarVm> bars;
  final ChartColors colors;
  final int? pressed;
  final double reserve;
  final TextScaler textScaler;
  final Animation<double> progress;

  /// 0 … 1 growth of bar [i] (staggered, ease-out).
  double _grow(int i) {
    const total =
        _WeeklyBarsCardState._barMs + 7 * _WeeklyBarsCardState._staggerMs;
    const start = _WeeklyBarsCardState._staggerMs;
    final ms = progress.value * total - i * start;
    return Curves.easeOutCubic.transform(
      (ms / _WeeklyBarsCardState._barMs).clamp(0.0, 1.0),
    );
  }

  Paint _gradient(List<Color> stops, Rect rect) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: stops,
    ).createShader(rect);

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height - 1;
    final plotHeight = baseline - reserve;

    final gridPaint = Paint()
      ..color = colors.grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = reserve + plotHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final columnWidth = size.width / bars.length;
    final barWidth = math.min(_weeklyMaxBarWidth, columnWidth * 0.72);
    final tops = List<double>.filled(bars.length, baseline);

    for (var i = 0; i < bars.length; i++) {
      final bar = bars[i];
      final cx = columnWidth * (i + 0.5);
      final grow = _grow(i);
      if (bar.count == 0) {
        const radius = 3.5;
        final cy = baseline - 4 - radius;
        tops[i] = cy - radius;
        canvas.drawCircle(
          Offset(cx, cy),
          radius,
          Paint()..color = colors.dot.withValues(alpha: grow),
        );
        continue;
      }
      final full = math.max(_barTopRadius, plotHeight * bar.fraction);
      final h = full * grow;
      tops[i] = baseline - full;
      if (h <= 0) continue;
      final rect = Rect.fromLTWH(cx - barWidth / 2, baseline - h, barWidth, h);
      const corner = Radius.circular(_barTopRadius);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: corner,
        topRight: corner,
      );
      final isPressed = pressed == i;
      final List<Color> fill;
      if (bar.isCurrent) {
        fill = colors.barCurrent;
      } else if (isPressed) {
        fill = colors.barSelected;
      } else if (bar.isPeak) {
        fill = colors.barPeak;
      } else {
        fill = [colors.barPast, colors.barPast];
      }
      canvas.drawRRect(rrect, _gradient(fill, rect));
      if (bar.isCurrent && isPressed) {
        canvas.drawRRect(
          rrect.deflate(1.5),
          Paint()
            ..color = colors.barOutline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }

    final tooltipIndex = pressed ?? _peak();
    if (tooltipIndex != null) {
      _paintTooltip(
        canvas,
        size,
        bars[tooltipIndex].tooltip,
        columnWidth * (tooltipIndex + 0.5),
        tops[tooltipIndex],
      );
    }
  }

  int? _peak() {
    for (var i = 0; i < bars.length; i++) {
      if (bars[i].isPeak) return i;
    }
    return null;
  }

  void _paintTooltip(
    Canvas canvas,
    Size size,
    String text,
    double cx,
    double barTop,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: colors.tooltipText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    const arrow = 5.0;
    final w = math.min(tp.width + 20, size.width);
    final h = tp.height + 12;
    final left = (cx - w / 2)
        .clamp(0.0, math.max(0.0, size.width - w))
        .toDouble();
    final bottom = barTop - 8 - arrow;
    final rect = Rect.fromLTWH(left, bottom - h, w, h);
    final paint = Paint()..color = colors.tooltipBackground;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(9)),
      paint,
    );

    final ax = cx
        .clamp(rect.left + 12, math.max(rect.left + 12, rect.right - 12))
        .toDouble();
    canvas.drawPath(
      Path()
        ..moveTo(ax - arrow, rect.bottom - 0.5)
        ..lineTo(ax + arrow, rect.bottom - 0.5)
        ..lineTo(ax, rect.bottom + arrow)
        ..close(),
      paint,
    );
    tp.paint(canvas, Offset(rect.left + (w - tp.width) / 2, rect.top + 6));
  }

  @override
  bool shouldRepaint(_WeeklyPainter old) =>
      old.bars != bars ||
      old.colors != colors ||
      old.pressed != pressed ||
      old.reserve != reserve ||
      old.textScaler != textScaler;
}

/// Loading placeholder: eight bars of varied height.
class WeeklySkeleton extends StatelessWidget {
  /// Creates the placeholder.
  const WeeklySkeleton({super.key});

  static const _heights = [60.0, 90.0, 40.0, 120.0, 70.0, 100.0, 50.0, 80.0];

  @override
  Widget build(BuildContext context) {
    return ChartCard(
      child: SizedBox(
        height: 196,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in _heights)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SkeletonBox(height: h, radius: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
