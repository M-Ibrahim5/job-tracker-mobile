import '../enums/enums.dart';
import '../models/calendar_event.dart';
import '../models/dashboard_data.dart';
import '../models/reminder_item.dart';

/// `GET /dashboard`.
abstract interface class DashboardRepository {
  /// Loads aggregates; [timezone] is an IANA name such as `Asia/Kuala_Lumpur`.
  Future<DashboardData> load({required String timezone});
}

/// `GET /calendar`.
abstract interface class CalendarRepository {
  /// Events between [from] and [to] inclusive (range ≤ 70 days).
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime to,
    required String timezone,
  });
}

/// `GET /reminders/upcoming`.
abstract interface class ReminderRepository {
  /// Future reminders for the next 60 days, for local scheduling.
  Future<List<ReminderItem>> upcoming();
}

/// Export and bulk delete (`API.md` → Data).
abstract interface class DataRepository {
  /// `GET /export?format=`; returns the file bytes.
  Future<List<int>> export(ExportFormat format, {String timezone = 'UTC'});

  /// `DELETE /data` with `{ confirm: "DELETE" }`; keeps the account.
  Future<void> deleteAllData();
}
