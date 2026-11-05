import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../../../domain/models/job_application.dart';
import '../../../domain/models/page.dart';
import '../../applications/application/application_providers.dart';

/// Most applications a chart pop-up lists; the rest are one tap away in the
/// Applications tab (CHARTS.md §1.5 / §2.4).
const int kDrillDownLimit = 50;

/// Applications in [status], newest first (pipeline pop-up).
ApplicationFilter statusDrillFilter(ApplicationStatus status) =>
    ApplicationFilter(statuses: {status});

/// Applications sent in the Monday–Sunday week starting on [monday], oldest
/// first (weekly pop-up). Calendar dates only, so DST never shifts it.
ApplicationFilter weekDrillFilter(DateTime monday) {
  final start = DateHelpers.dayOnly(monday);
  return ApplicationFilter(
    appliedFrom: start,
    appliedTo: DateTime(start.year, start.month, start.day + 6),
    sort: ApplicationSort.oldest,
  );
}

/// One day of the weekly pop-up's timeline.
class AppliedDay {
  /// Creates a day.
  const AppliedDay(this.day, this.applications);

  /// Local midnight of the applied date.
  final DateTime day;
  final List<JobApplication> applications;
}

/// [applications] grouped by applied date, earliest day first; within a day
/// the order is stable (by id). Days without applications are left out.
List<AppliedDay> groupByAppliedDay(Iterable<JobApplication> applications) {
  final byDay = <DateTime, List<JobApplication>>{};
  for (final a in applications) {
    byDay.putIfAbsent(DateHelpers.dayOnly(a.appliedDate), () => []).add(a);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final d in days)
      AppliedDay(d, byDay[d]!..sort((a, b) => a.id.compareTo(b.id))),
  ];
}

/// How many of [applications] are in each status now, in pipeline order,
/// statuses with none left out ("where did that week's applications end up").
List<(ApplicationStatus, int)> statusBreakdown(
  Iterable<JobApplication> applications,
) {
  final counts = <ApplicationStatus, int>{};
  for (final a in applications) {
    counts[a.status] = (counts[a.status] ?? 0) + 1;
  }
  return [
    for (final s in ApplicationStatus.values)
      if ((counts[s] ?? 0) > 0) (s, counts[s]!),
  ];
}

/// The applications a chart pop-up shows, reloaded when data changes.
final chartDrillDownProvider = FutureProvider.autoDispose
    .family<Page<JobApplication>, ApplicationFilter>((ref, filter) {
      ref.watch(dataRevisionProvider);
      ref.watch(applicationsRevisionProvider);
      return ref
          .watch(jobApplicationRepositoryProvider)
          .list(filter, pageSize: kDrillDownLimit);
    });
