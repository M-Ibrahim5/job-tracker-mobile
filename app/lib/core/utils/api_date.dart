/// Conversions between API date strings and local [DateTime]s.
abstract final class ApiDate {
  /// Parses an ISO-8601 UTC timestamp into local time.
  static DateTime parseUtc(String value) => DateTime.parse(value).toLocal();

  /// Parses `YYYY-MM-DD` into local midnight of that day.
  static DateTime parseDate(String value) {
    final p = value.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// Formats [d] as a UTC ISO-8601 string with `Z`.
  static String toUtcIso(DateTime d) => d.toUtc().toIso8601String();

  /// Formats the calendar day of [d] as `YYYY-MM-DD`.
  static String toDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Nullable variants for optional JSON fields.
  static DateTime? parseUtcOrNull(String? v) => v == null ? null : parseUtc(v);
  static DateTime? parseDateOrNull(String? v) =>
      v == null ? null : parseDate(v);
}
