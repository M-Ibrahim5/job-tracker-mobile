import 'package:intl/intl.dart';

import '../../../core/constants/dashboard_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/dashboard_data.dart';
import '../../../domain/models/interview.dart';
import 'chart_logic.dart';

/// "Good morning, Aisha" for the local hour of [now]; without a name just
/// "Good morning".
String greetingFor(DateTime now, String? firstName) {
  final base = now.hour < 12
      ? DashboardStrings.goodMorning
      : now.hour < 17
      ? DashboardStrings.goodAfternoon
      : DashboardStrings.goodEvening;
  final name = firstName?.trim() ?? '';
  return name.isEmpty ? base : '$base, $name';
}

/// "Sunday, 25 Oct".
String dateLineFor(DateTime now) => DateFormat('EEEE, d MMM').format(now);

/// First word of a full name, or null when blank.
String? firstNameOf(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+'));
  return parts.first.isEmpty ? null : parts.first;
}

/// One of the five status tiles.
class StatusTileVm {
  /// Creates a tile.
  const StatusTileVm({required this.status, required this.count});

  final ApplicationStatus status;
  final int count;
}

/// One slice of the pipeline donut.
class DonutSliceVm {
  /// Creates a slice.
  const DonutSliceVm({required this.status, required this.count});

  final ApplicationStatus status;
  final int count;
}

/// One bar of the weekly chart.
class BarVm {
  /// Creates a bar.
  const BarVm({
    required this.weekStart,
    required this.count,
    required this.fraction,
    required this.isCurrent,
    required this.isPeak,
    required this.tooltip,
  });

  final DateTime weekStart;
  final int count;

  /// Height relative to the y scale (`axisMax`), 0 … 1.
  final double fraction;

  /// Whether this is the current (last) week.
  final bool isCurrent;

  /// Whether this is the busiest week (the earliest on a tie).
  final bool isPeak;

  /// "4 · wk of 12 Oct" / "2 · this week".
  final String tooltip;
}

/// One line of the recent-activity list.
class ActivityVm {
  /// Creates an entry.
  const ActivityVm({
    required this.applicationId,
    required this.company,
    required this.status,
    required this.relativeTime,
  });

  final int applicationId;
  final String company;
  final ApplicationStatus status;

  /// "2h ago", or the date for older entries.
  final String relativeTime;
}

/// Everything the dashboard shows, already computed: the widgets only lay it
/// out (no business logic in widgets).
class DashboardViewModel {
  const DashboardViewModel._({
    required this.greeting,
    required this.dateLine,
    required this.total,
    required this.active,
    required this.responsePercent,
    required this.responseFraction,
    required this.tiles,
    required this.percents,
    required this.slices,
    required this.pipelineSummary,
    required this.bars,
    required this.barsSummary,
    required this.axisStart,
    required this.upcoming,
    required this.activity,
  });

  /// Builds the view model for [data] as of [now].
  factory DashboardViewModel.from(
    DashboardData data, {
    required DateTime now,
    String? firstName,
  }) {
    final tiles = [
      for (final s in ApplicationStatus.values)
        StatusTileVm(status: s, count: data.statusCounts[s] ?? 0),
    ];
    final slices = [
      for (final t in tiles)
        if (t.count > 0) DonutSliceVm(status: t.status, count: t.count),
    ];

    final counts = [for (final w in data.weekly) w.count];
    final scaleMax = axisMax(counts);
    final peak = peakIndex(counts);
    final bars = [
      for (var i = 0; i < data.weekly.length; i++)
        BarVm(
          weekStart: data.weekly[i].weekStart,
          count: data.weekly[i].count,
          fraction: data.weekly[i].count / scaleMax,
          isCurrent: i == data.weekly.length - 1,
          isPeak: i == peak,
          tooltip: weekTooltip(
            count: data.weekly[i].count,
            weekStart: data.weekly[i].weekStart,
            isCurrent: i == data.weekly.length - 1,
          ),
        ),
    ];
    final percents = percentages({for (final t in tiles) t.status: t.count});

    final percent = data.responseRatePercent.clamp(0, 100);
    return DashboardViewModel._(
      greeting: greetingFor(now, firstName),
      dateLine: dateLineFor(now),
      total: data.total,
      active: data.active,
      responsePercent: percent,
      responseFraction: percent / 100,
      tiles: tiles,
      percents: percents,
      slices: slices,
      pipelineSummary: DashboardStrings.pipelineSummary(data.total, [
        for (final t in tiles) '${t.count} ${t.status.label.toLowerCase()}',
      ]),
      bars: bars,
      barsSummary: DashboardStrings.barsSummary([
        for (final b in bars) '${b.count}',
      ]),
      axisStart: bars.isEmpty
          ? ''
          : DateFormat('d MMM').format(bars.first.weekStart),
      upcoming: data.upcomingInterviews.take(3).toList(),
      activity: [
        for (final a in data.recentActivity.take(5))
          ActivityVm(
            applicationId: a.applicationId,
            company: a.companyName,
            status: a.toStatus,
            relativeTime: DateHelpers.relative(a.changedAt, now: now),
          ),
      ],
    );
  }

  final String greeting;
  final String dateLine;
  final int total;
  final int active;
  final int responsePercent;
  final double responseFraction;
  final List<StatusTileVm> tiles;

  /// Whole-number share per status; sums to 100 unless the account is empty.
  final Map<ApplicationStatus, int> percents;

  /// Statuses with at least one application (the donut skips empty ones).
  final List<DonutSliceVm> slices;
  final String pipelineSummary;
  final List<BarVm> bars;
  final String barsSummary;

  /// Label under the first bar ("31 Aug").
  final String axisStart;
  final List<Interview> upcoming;
  final List<ActivityVm> activity;

  /// Whether the user has no applications at all.
  bool get isEmpty => total == 0;
}
