import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/data/api/api_calendar_repository.dart';
import 'package:jobtrail/data/api/api_dashboard_repository.dart';
import 'package:jobtrail/domain/enums/enums.dart';

import '../helpers/test_app.dart';

({Dio dio, ScriptedAdapter adapter}) _dio(String body) {
  final adapter = ScriptedAdapter((_) async => jsonBody(body, 200));
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  test('dashboard sends the device timezone and parses the aggregates', () async {
    final t = _dio(
      '{"total":15,"active":11,"responseRatePercent":67,'
      '"statusCounts":{"applied":5,"screening":3,"interview":3,"offer":1,"rejected":3},'
      '"weekly":[{"weekStart":"2026-08-31","count":1},{"weekStart":"2026-09-07","count":4}],'
      '"upcomingInterviews":[],'
      '"recentActivity":[{"applicationId":12,"companyName":"Northwind Labs",'
      '"toStatus":"interview","changedAt":"2026-10-24T03:05:00.000Z"}]}',
    );
    final data = await ApiDashboardRepository(
      t.dio,
    ).load(timezone: 'Asia/Kuala_Lumpur');

    final req = t.adapter.requests.single;
    expect(req.path, '/dashboard');
    expect(req.queryParameters, {'tz': 'Asia/Kuala_Lumpur'});
    expect(data.total, 15);
    expect(data.active, 11);
    expect(data.responseRatePercent, 67);
    expect(data.statusCounts[ApplicationStatus.screening], 3);
    expect(data.weekly.last.count, 4);
    expect(data.weekly.first.weekStart, DateTime(2026, 8, 31));
    expect(data.recentActivity.single.toStatus, ApplicationStatus.interview);
  });

  test('calendar sends the range and timezone and parses every event type', () async {
    final t = _dio(
      '{"events":['
      '{"date":"2026-10-22","type":"applied","applicationId":12,"companyName":"A","title":"T"},'
      '{"date":"2026-10-24","type":"statusChange","applicationId":12,"companyName":"A","title":"T",'
      '"status":"interview","at":"2026-10-24T03:05:00.000Z"},'
      '{"date":"2026-10-27","type":"interview","interviewId":3,"applicationId":12,"companyName":"A",'
      '"title":"Round 2","interviewType":"video","at":"2026-10-27T02:00:00.000Z"},'
      '{"date":"2026-10-25","type":"followUp","applicationId":14,"companyName":"B","title":"T2",'
      '"at":"2026-10-25T01:00:00.000Z"}]}',
    );
    final events = await ApiCalendarRepository(t.dio).events(
      from: DateTime(2026, 9, 21, 15),
      to: DateTime(2026, 11, 8),
      timezone: 'UTC',
    );

    final req = t.adapter.requests.single;
    expect(req.path, '/calendar');
    expect(req.queryParameters, {
      'from': '2026-09-21',
      'to': '2026-11-08',
      'tz': 'UTC',
    });
    expect(events.map((e) => e.type), [
      CalendarEventType.applied,
      CalendarEventType.statusChange,
      CalendarEventType.interview,
      CalendarEventType.followUp,
    ]);
    expect(events[1].status, ApplicationStatus.interview);
    expect(events[2].interviewId, 3);
    expect(events[2].interviewType, InterviewType.video);
    expect(events[0].date, DateTime(2026, 10, 22));
  });
}
