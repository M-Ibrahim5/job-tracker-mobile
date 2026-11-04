import 'package:intl/intl.dart';

import '../../../core/constants/application_strings.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';

final _day = DateFormat('d MMM');

/// "12 Oct – 18 Oct", "From 12 Oct" or "Until 18 Oct" for the date chip.
String? dateRangeChipLabel(DateTime? from, DateTime? to) {
  if (from == null && to == null) return null;
  if (from == null) return 'Until ${_day.format(to!)}';
  if (to == null) return 'From ${_day.format(from)}';
  return '${_day.format(from)} – ${_day.format(to)}';
}

/// Compact range for the list caption: "12–18 Oct", "28 Sep – 4 Oct".
String? dateRangeCaption(DateTime? from, DateTime? to) {
  if (from == null || to == null) return dateRangeChipLabel(from, to);
  if (from.year == to.year && from.month == to.month) {
    if (from.day == to.day) return _day.format(from);
    return '${from.day}–${_day.format(to)}';
  }
  return '${_day.format(from)} – ${_day.format(to)}';
}

/// List header caption: "5 Applied applications", "4 applications · 12–18 Oct"
/// or, without a status or date filter, the plain total.
String listCaption(int count, ApplicationFilter filter) {
  final range = dateRangeCaption(filter.appliedFrom, filter.appliedTo);
  if (filter.statuses.isEmpty && range == null) {
    return ApplicationStrings.total(count);
  }
  final what = filter.statuses.length == 1
      ? '$count ${filter.statuses.first.label} applications'
      : '$count applications';
  return range == null ? what : '$what · $range';
}

/// What a removable filter chip stands for.
enum ActiveFilterKind { status, arrangement, dates }

/// One removable chip of the active-filter row.
class ActiveFilterChip {
  /// Creates a chip description.
  const ActiveFilterChip(this.kind, this.label);

  final ActiveFilterKind kind;
  final String label;
}

/// The removable chips for the criteria that narrow [filter].
List<ActiveFilterChip> activeFilterChips(ApplicationFilter filter) {
  final statuses = ApplicationStatus.values
      .where(filter.statuses.contains)
      .map((s) => s.label)
      .join(', ');
  final arrangements = WorkArrangement.values
      .where(filter.arrangements.contains)
      .map((a) => a.label)
      .join(', ');
  final range = dateRangeChipLabel(filter.appliedFrom, filter.appliedTo);
  return [
    if (statuses.isNotEmpty)
      ActiveFilterChip(
        ActiveFilterKind.status,
        ApplicationStrings.statusChip(statuses),
      ),
    if (arrangements.isNotEmpty)
      ActiveFilterChip(
        ActiveFilterKind.arrangement,
        ApplicationStrings.arrangementChip(arrangements),
      ),
    if (range != null) ActiveFilterChip(ActiveFilterKind.dates, range),
  ];
}

/// [filter] without the criterion behind [kind].
ApplicationFilter withoutFilter(
  ApplicationFilter filter,
  ActiveFilterKind kind,
) => switch (kind) {
  ActiveFilterKind.status => filter.copyWith(statuses: const {}),
  ActiveFilterKind.arrangement => filter.copyWith(arrangements: const {}),
  ActiveFilterKind.dates => filter.copyWith(clearDates: true),
};
