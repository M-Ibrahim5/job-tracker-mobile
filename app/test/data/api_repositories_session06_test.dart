import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/data/api/api_interview_repository.dart';
import 'package:jobtrail/data/api/api_notification_repository.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/interview.dart';

import '../helpers/test_app.dart';

const _interview =
    '{"id":3,"applicationId":12,"applicationTitle":"Dev","companyName":"Acme",'
    '"title":"Round 2","type":"finalRound","scheduledAt":"2026-10-27T02:00:00.000Z",'
    '"durationMinutes":45,"locationOrLink":null,"interviewerName":null,"notes":null,'
    '"reminderOffsetsMinutes":[1440,60],"outcome":"pending",'
    '"createdAt":"2026-10-24T00:00:00.000Z","updatedAt":"2026-10-24T00:00:00.000Z"}';

({Dio dio, ScriptedAdapter adapter}) _dio(
  Future<ResponseBody> Function(RequestOptions) handler,
) {
  final adapter = ScriptedAdapter(handler);
  final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
    ..httpClientAdapter = adapter;
  return (dio: dio, adapter: adapter);
}

void main() {
  group('ApiInterviewRepository', () {
    test('list sends scope, application and paging', () async {
      final t = _dio(
        (_) async => jsonBody(
          '{"items":[$_interview],"page":1,"pageSize":20,"total":1}',
          200,
        ),
      );
      final page = await ApiInterviewRepository(
        t.dio,
      ).list(scope: InterviewScope.past, applicationId: 12);

      final req = t.adapter.requests.single;
      expect(req.path, '/interviews');
      expect(req.queryParameters, {
        'scope': 'past',
        'applicationId': 12,
        'page': 1,
        'pageSize': 20,
      });
      final i = page.items.single;
      expect(i.type, InterviewType.finalRound);
      expect(i.reminderOffsets, [
        const Duration(days: 1),
        const Duration(hours: 1),
      ]);
      expect(i.companyName, 'Acme');
    });

    test('create posts under the application; update patches by id', () async {
      final t = _dio((_) async => jsonBody(_interview, 200));
      final repo = ApiInterviewRepository(t.dio);
      final draft = Interview(
        id: 0,
        applicationId: 12,
        title: 'Round 2',
        type: InterviewType.finalRound,
        scheduledAt: DateTime.utc(2026, 10, 27, 2),
        reminderOffsets: const [Duration(hours: 1)],
      );

      await repo.create(12, draft);
      await repo.update(draft.copyWith(id: 3));
      await repo.delete(3);

      final post = t.adapter.requests[0];
      expect(post.method, 'POST');
      expect(post.path, '/applications/12/interviews');
      expect((post.data as Map)['type'], 'finalRound');
      expect((post.data as Map)['scheduledAt'], '2026-10-27T02:00:00.000Z');
      expect((post.data as Map)['reminderOffsetsMinutes'], [60]);

      expect(t.adapter.requests[1].method, 'PATCH');
      expect(t.adapter.requests[1].path, '/interviews/3');
      expect(t.adapter.requests[2].method, 'DELETE');
      expect(t.adapter.requests[2].path, '/interviews/3');
    });

    test('a 409 becomes INTERVIEW_CONFLICT', () async {
      final t = _dio(
        (_) async => jsonBody(
          '{"error":{"code":"INTERVIEW_CONFLICT","message":"Clash"}}',
          409,
        ),
      );
      await expectLater(
        ApiInterviewRepository(t.dio).getById(3),
        throwsA(
          isA<ApiFailure>().having((e) => e.code, 'code', 'INTERVIEW_CONFLICT'),
        ),
      );
    });
  });

  group('ApiNotificationRepository', () {
    test('talks to every notification endpoint', () async {
      final t = _dio((o) async {
        if (o.path == '/notifications/unread-count') {
          return jsonBody('{"count":3}', 200);
        }
        if (o.method == 'GET') {
          return jsonBody(
            '{"items":[{"id":9,"type":"statusChange","title":"Moved",'
            '"body":"b","relatedApplicationId":12,"relatedInterviewId":null,'
            '"createdAt":"2026-10-24T03:05:00.000Z","isRead":false}],'
            '"page":1,"pageSize":20,"total":1}',
            200,
          );
        }
        return ResponseBody.fromString('', 204);
      });
      final repo = ApiNotificationRepository(t.dio);

      final page = await repo.list();
      expect(page.items.single.relatedApplicationId, 12);
      expect(await repo.unreadCount(), 3);
      await repo.markRead(9);
      await repo.markAllRead();
      await repo.delete(9);
      await repo.clear();

      expect(t.adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'GET /notifications',
        'GET /notifications/unread-count',
        'POST /notifications/9/read',
        'POST /notifications/read-all',
        'DELETE /notifications/9',
        'DELETE /notifications',
      ]);
    });
  });

  group('ApiReminderRepository', () {
    test('parses upcoming reminders', () async {
      final t = _dio(
        (_) async => jsonBody(
          '{"items":[{"key":"interview:3:1440","kind":"interviewReminder",'
          '"fireAt":"2026-10-26T02:00:00.000Z","title":"Interview tomorrow",'
          '"body":"Acme","applicationId":12,"interviewId":3}]}',
          200,
        ),
      );
      final items = await ApiReminderRepository(t.dio).upcoming();

      expect(t.adapter.requests.single.path, '/reminders/upcoming');
      expect(items.single.key, 'interview:3:1440');
      expect(items.single.kind, ReminderKind.interviewReminder);
      expect(items.single.fireAt.toUtc(), DateTime.utc(2026, 10, 26, 2));
      expect(items.single.interviewId, 3);
    });
  });
}
