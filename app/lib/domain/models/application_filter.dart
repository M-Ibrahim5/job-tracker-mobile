import '../../core/utils/api_date.dart';
import '../enums/enums.dart';

/// Search / filter / sort criteria for the application list.
class ApplicationFilter {
  /// Creates a filter; the default matches everything, newest first.
  const ApplicationFilter({
    this.query = '',
    this.statuses = const {},
    this.arrangements = const {},
    this.appliedFrom,
    this.appliedTo,
    this.sort = ApplicationSort.newest,
  });

  /// Free text matched against title, company and location.
  final String query;
  final Set<ApplicationStatus> statuses;
  final Set<WorkArrangement> arrangements;
  final DateTime? appliedFrom;
  final DateTime? appliedTo;
  final ApplicationSort sort;

  /// Whether any narrowing criterion is set (sort excluded).
  bool get isActive =>
      query.trim().isNotEmpty ||
      statuses.isNotEmpty ||
      arrangements.isNotEmpty ||
      appliedFrom != null ||
      appliedTo != null;

  /// Returns a copy with the given fields replaced.
  ApplicationFilter copyWith({
    String? query,
    Set<ApplicationStatus>? statuses,
    Set<WorkArrangement>? arrangements,
    DateTime? appliedFrom,
    DateTime? appliedTo,
    bool clearDates = false,
    ApplicationSort? sort,
  }) {
    return ApplicationFilter(
      query: query ?? this.query,
      statuses: statuses ?? this.statuses,
      arrangements: arrangements ?? this.arrangements,
      appliedFrom: clearDates ? null : (appliedFrom ?? this.appliedFrom),
      appliedTo: clearDates ? null : (appliedTo ?? this.appliedTo),
      sort: sort ?? this.sort,
    );
  }

  /// Query parameters for `GET /applications` (without paging).
  Map<String, dynamic> toQuery() {
    final q = query.trim();
    return {
      if (q.isNotEmpty) 'q': q,
      if (statuses.isNotEmpty) 'status': statuses.map((s) => s.name).join(','),
      if (arrangements.isNotEmpty)
        'arrangement': arrangements.map((a) => a.name).join(','),
      if (appliedFrom != null) 'from': ApiDate.toDateOnly(appliedFrom!),
      if (appliedTo != null) 'to': ApiDate.toDateOnly(appliedTo!),
      'sort': sort.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is ApplicationFilter &&
      other.query == query &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses) &&
      other.arrangements.length == arrangements.length &&
      other.arrangements.containsAll(arrangements) &&
      other.appliedFrom == appliedFrom &&
      other.appliedTo == appliedTo &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(arrangements),
    appliedFrom,
    appliedTo,
    sort,
  );
}
