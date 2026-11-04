import 'dart:math' as math;
import 'dart:ui';

import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/utils/api_date.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';

/// `/applications?status=<status>` (CHARTS.md §3).
Uri applicationsUriForStatus(ApplicationStatus s) =>
    Uri(path: Routes.applications, queryParameters: {'status': s.name});

/// `/applications?from=<Monday>&to=<Sunday>` for the week starting on
/// [weekStartMonday]. Works on calendar dates only, so DST never shifts it.
Uri applicationsUriForWeek(DateTime weekStartMonday) {
  final monday = DateTime(
    weekStartMonday.year,
    weekStartMonday.month,
    weekStartMonday.day,
  );
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  return Uri(
    path: Routes.applications,
    queryParameters: {
      'from': ApiDate.toDateOnly(monday),
      'to': ApiDate.toDateOnly(sunday),
    },
  );
}

/// The query parameters that `/applications` understands.
const Set<String> kApplicationQueryKeys = {
  'status',
  'arrangement',
  'from',
  'to',
  'q',
  'sort',
};

/// Whether [query] sets at least one filter parameter.
bool hasFilterParams(Map<String, String> query) =>
    query.keys.any(kApplicationQueryKeys.contains);

/// Builds the filter described by [query]; unknown keys and invalid values
/// are ignored.
ApplicationFilter filterFromQuery(Map<String, String> query) {
  final statuses = <ApplicationStatus>{};
  for (final part in (query['status'] ?? '').split(',')) {
    final name = part.trim();
    for (final s in ApplicationStatus.values) {
      if (s.name == name) statuses.add(s);
    }
  }
  final arrangements = <WorkArrangement>{};
  for (final part in (query['arrangement'] ?? '').split(',')) {
    final name = part.trim();
    for (final a in WorkArrangement.values) {
      if (a.name == name) arrangements.add(a);
    }
  }
  var from = _parseDay(query['from']);
  var to = _parseDay(query['to']);
  if (from != null && to != null && from.isAfter(to)) {
    from = null;
    to = null;
  }
  var sort = ApplicationSort.newest;
  for (final s in ApplicationSort.values) {
    if (s.name == query['sort']) sort = s;
  }
  return ApplicationFilter(
    query: (query['q'] ?? '').trim(),
    statuses: statuses,
    arrangements: arrangements,
    appliedFrom: from,
    appliedTo: to,
    sort: sort,
  );
}

/// The `/applications` URI that reproduces [filter] (no params when it is
/// unfiltered).
Uri applicationsUriForFilter(ApplicationFilter filter) {
  final q = filter.query.trim();
  final params = <String, String>{
    if (filter.statuses.isNotEmpty)
      'status': ApplicationStatus.values
          .where(filter.statuses.contains)
          .map((s) => s.name)
          .join(','),
    if (filter.arrangements.isNotEmpty)
      'arrangement': WorkArrangement.values
          .where(filter.arrangements.contains)
          .map((a) => a.name)
          .join(','),
    if (filter.appliedFrom != null)
      'from': ApiDate.toDateOnly(filter.appliedFrom!),
    if (filter.appliedTo != null) 'to': ApiDate.toDateOnly(filter.appliedTo!),
    if (q.isNotEmpty) 'q': q,
    if (filter.sort != ApplicationSort.newest) 'sort': filter.sort.name,
  };
  return Uri(
    path: Routes.applications,
    queryParameters: params.isEmpty ? null : params,
  );
}

DateTime? _parseDay(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final day = ApiDate.parseDate(value);
  // Rejects dates such as 2026-02-31 that DateTime would roll over.
  return ApiDate.toDateOnly(day) == value ? day : null;
}

/// Whole-number percentage per status that sums to exactly 100 (largest
/// remainder rounding). All zero when there are no applications.
Map<ApplicationStatus, int> percentages(Map<ApplicationStatus, int> counts) {
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return {for (final s in counts.keys) s: 0};
  final floors = <ApplicationStatus, int>{};
  final remainders = <ApplicationStatus, int>{};
  for (final e in counts.entries) {
    floors[e.key] = e.value * 100 ~/ total;
    remainders[e.key] = e.value * 100 % total;
  }
  var left = 100 - floors.values.fold<int>(0, (a, b) => a + b);
  // Biggest remainder first; the earlier pipeline stage wins ties.
  final order = counts.keys.toList()
    ..sort((a, b) {
      final c = remainders[b]!.compareTo(remainders[a]!);
      return c != 0 ? c : a.index.compareTo(b.index);
    });
  for (final s in order) {
    if (left <= 0) break;
    if ((counts[s] ?? 0) == 0) continue;
    floors[s] = floors[s]! + 1;
    left--;
  }
  return floors;
}

/// Top of the weekly chart's y scale: at least 4 so one application does not
/// fill the chart.
int axisMax(List<int> counts) => counts.fold<int>(4, (m, c) => c > m ? c : m);

/// Index of the busiest week (the earliest on a tie), or null when every week
/// is empty.
int? peakIndex(List<int> counts) {
  int? best;
  for (var i = 0; i < counts.length; i++) {
    if (counts[i] > 0 && (best == null || counts[i] > counts[best])) best = i;
  }
  return best;
}

/// Tooltip text of one weekly bar: "4 · wk of 12 Oct" or "2 · this week".
String weekTooltip({
  required int count,
  required DateTime weekStart,
  required bool isCurrent,
}) => isCurrent
    ? '$count · this week'
    : '$count · wk of ${DateFormat('d MMM').format(weekStart)}';

/// Which ring segment lies under [point] in a ring of [size], or null.
///
/// [counts] are the drawn segments in order, clockwise from 12 o'clock. The
/// hit area spans the hole's edge to the box edge so thin rings stay easy to
/// hit.
int? ringSegmentAt(
  Offset point,
  Size size,
  List<int> counts, {
  required double holeRadius,
}) {
  final total = counts.fold<int>(0, (a, b) => a + b);
  if (total == 0) return null;
  final d = point - size.center(Offset.zero);
  final distance = d.distance;
  if (distance < holeRadius || distance > size.shortestSide / 2) return null;
  // 0 at 12 o'clock, growing clockwise.
  var turns = (math.atan2(d.dy, d.dx) + math.pi / 2) / (2 * math.pi);
  turns = turns - turns.floorToDouble();
  var edge = 0.0;
  for (var i = 0; i < counts.length; i++) {
    edge += counts[i] / total;
    if (turns < edge) return i;
  }
  return counts.length - 1;
}
