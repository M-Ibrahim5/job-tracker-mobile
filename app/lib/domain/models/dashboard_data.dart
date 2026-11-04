import '../../core/utils/api_date.dart';
import '../enums/enums.dart';
import 'interview.dart';

/// Applications created in one week (`weekly` in `GET /dashboard`).
class WeeklyCount {
  /// Creates a weekly bucket.
  const WeeklyCount({required this.weekStart, required this.count});

  /// Parses an API bucket.
  factory WeeklyCount.fromJson(Map<String, dynamic> json) => WeeklyCount(
    weekStart: ApiDate.parseDate(json['weekStart'] as String),
    count: json['count'] as int,
  );

  final DateTime weekStart;
  final int count;
}

/// A recent status change (`recentActivity` in `GET /dashboard`).
class RecentActivity {
  /// Creates an activity entry.
  const RecentActivity({
    required this.applicationId,
    required this.companyName,
    required this.toStatus,
    required this.changedAt,
  });

  /// Parses an API entry.
  factory RecentActivity.fromJson(Map<String, dynamic> json) => RecentActivity(
    applicationId: json['applicationId'] as int,
    companyName: json['companyName'] as String,
    toStatus: enumByName(ApplicationStatus.values, json['toStatus'] as String),
    changedAt: ApiDate.parseUtc(json['changedAt'] as String),
  );

  final int applicationId;
  final String companyName;
  final ApplicationStatus toStatus;
  final DateTime changedAt;
}

/// Aggregates for the dashboard screen.
class DashboardData {
  /// Creates dashboard data.
  const DashboardData({
    required this.total,
    required this.active,
    required this.responseRatePercent,
    required this.statusCounts,
    required this.weekly,
    required this.upcomingInterviews,
    required this.recentActivity,
  });

  /// Parses the `GET /dashboard` response.
  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final counts = json['statusCounts'] as Map<String, dynamic>;
    return DashboardData(
      total: json['total'] as int,
      active: json['active'] as int,
      responseRatePercent: json['responseRatePercent'] as int,
      statusCounts: {
        for (final s in ApplicationStatus.values)
          s: counts[s.name] as int? ?? 0,
      },
      weekly: (json['weekly'] as List)
          .map((e) => WeeklyCount.fromJson(e as Map<String, dynamic>))
          .toList(),
      upcomingInterviews: (json['upcomingInterviews'] as List)
          .map((e) => Interview.fromJson(e as Map<String, dynamic>))
          .toList(),
      recentActivity: (json['recentActivity'] as List)
          .map((e) => RecentActivity.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int total;
  final int active;
  final int responseRatePercent;
  final Map<ApplicationStatus, int> statusCounts;

  /// Eight buckets, oldest first; the last is the current week.
  final List<WeeklyCount> weekly;
  final List<Interview> upcomingInterviews;
  final List<RecentActivity> recentActivity;
}
