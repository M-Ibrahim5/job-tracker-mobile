import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/utils/api_date.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/domain/models/dashboard_data.dart';
import 'package:jobtrail/domain/models/interview.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/domain/models/page.dart';
import 'package:jobtrail/domain/models/reminder_item.dart';
import 'package:jobtrail/domain/models/settings.dart';
import 'package:jobtrail/domain/models/user.dart';

void main() {
  test('ApiDate converts between UTC strings and local time', () {
    final utc = DateTime.utc(2026, 10, 27, 2);
    expect(ApiDate.toUtcIso(utc), '2026-10-27T02:00:00.000Z');
    expect(ApiDate.parseUtc('2026-10-27T02:00:00.000Z'), utc.toLocal());
    expect(ApiDate.parseDate('2026-10-22'), DateTime(2026, 10, 22));
    expect(ApiDate.toDateOnly(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('User parses, derives names and round-trips', () {
    final json = {
      'id': 1,
      'email': 'a@b.com',
      'fullName': 'Muhammad Ibrahim',
      'phone': null,
      'currentRole': 'Software Engineer',
      'lookingFor': null,
      'location': 'Kuala Lumpur, Malaysia',
      'avatarUrl': null,
      'emailVerified': true,
    };
    final user = User.fromJson(json);
    expect(user.firstName, 'Muhammad');
    expect(user.initials, 'MI');
    expect(user.toJson(), json);
  });

  test('Settings parses minutes into durations and handles null follow-up', () {
    final settings = Settings.fromJson({
      'theme': 'dark',
      'interviewRemindersEnabled': true,
      'followUpRemindersEnabled': false,
      'statusAlertsEnabled': true,
      'defaultReminderOffsetsMinutes': [1440, 60],
      'defaultFollowUpDays': null,
    });
    expect(settings.theme, ThemeSetting.dark);
    expect(settings.defaultReminderOffsets, const [
      Duration(days: 1),
      Duration(hours: 1),
    ]);
    expect(settings.defaultFollowUpDays, isNull);
    expect(Settings.fromJson(settings.toJson()), settings);
    expect(settings.copyWith(defaultFollowUpDays: 5).defaultFollowUpDays, 5);
    expect(
      const Settings().copyWith(clearFollowUpDays: true).defaultFollowUpDays,
      isNull,
    );
  });

  test(
    'JobApplication parses the API shape and serializes editable fields',
    () {
      final app = JobApplication.fromJson({
        'id': 12,
        'jobTitle': 'Senior Flutter Developer',
        'companyName': 'Northwind Labs',
        'location': 'Kuala Lumpur',
        'workArrangement': 'hybrid',
        'jobDescription': null,
        'applicationLink': 'https://example.com',
        'employmentType': 'fullTime',
        'salaryRange': null,
        'source': 'linkedIn',
        'appliedDate': '2026-10-22',
        'status': 'interview',
        'notes': null,
        'contactName': null,
        'contactEmail': null,
        'followUpAt': null,
        'nextInterviewAt': '2026-10-27T02:00:00.000Z',
        'createdAt': '2026-10-22T01:00:00.000Z',
        'updatedAt': '2026-10-22T01:00:00.000Z',
      });
      expect(app.workArrangement, WorkArrangement.hybrid);
      expect(app.employmentType, EmploymentType.fullTime);
      expect(app.source, ApplicationSource.linkedIn);
      expect(app.appliedDate, DateTime(2026, 10, 22));
      expect(app.nextInterviewAt, DateTime.utc(2026, 10, 27, 2).toLocal());

      final json = app.toJson();
      expect(json['appliedDate'], '2026-10-22');
      expect(json['source'], 'linkedIn');
      expect(json.containsKey('status'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(app.copyWith(clearNextInterviewAt: true).nextInterviewAt, isNull);
    },
  );

  test('Interview maps final round, reminder minutes and write payload', () {
    final interview = Interview.fromJson({
      'id': 3,
      'applicationId': 12,
      'applicationTitle': 'Senior Flutter Developer',
      'companyName': 'Northwind Labs',
      'title': 'Technical interview · Round 2',
      'type': 'finalRound',
      'scheduledAt': '2026-10-27T02:00:00.000Z',
      'durationMinutes': 60,
      'locationOrLink': null,
      'interviewerName': null,
      'notes': null,
      'reminderOffsetsMinutes': [1440, 60],
      'outcome': 'pending',
      'createdAt': '2026-10-24T00:00:00.000Z',
      'updatedAt': '2026-10-24T00:00:00.000Z',
    });
    expect(interview.type, InterviewType.finalRound);
    expect(interview.companyName, 'Northwind Labs');
    expect(interview.reminderOffsets, kDefaultReminderOffsets);
    final body = interview.toJson();
    expect(body['type'], 'finalRound');
    expect(body['reminderOffsetsMinutes'], [1440, 60]);
    expect(body['scheduledAt'], '2026-10-27T02:00:00.000Z');
  });

  test('Page reports whether more items follow', () {
    final page = Page<int>.fromJson({
      'items': [
        {'v': 1},
        {'v': 2},
      ],
      'page': 1,
      'pageSize': 2,
      'total': 3,
    }, (m) => m['v'] as int);
    expect(page.items, [1, 2]);
    expect(page.hasMore, isTrue);
    expect(
      const Page<int>(items: [], page: 2, pageSize: 2, total: 4).hasMore,
      isFalse,
    );
    expect(
      const Page<int>(items: [], page: 1, pageSize: 2, total: 4).hasMore,
      isTrue,
    );
  });

  test('DashboardData fills missing status counts with zero', () {
    final data = DashboardData.fromJson({
      'total': 2,
      'active': 2,
      'responseRatePercent': 50,
      'statusCounts': {'applied': 1, 'screening': 1},
      'weekly': [
        {'weekStart': '2026-10-19', 'count': 2},
      ],
      'upcomingInterviews': <dynamic>[],
      'recentActivity': [
        {
          'applicationId': 1,
          'companyName': 'X',
          'toStatus': 'interview',
          'changedAt': '2026-10-24T03:05:00.000Z',
        },
      ],
    });
    expect(data.statusCounts[ApplicationStatus.offer], 0);
    expect(data.weekly.single.weekStart, DateTime(2026, 10, 19));
    expect(data.recentActivity.single.toStatus, ApplicationStatus.interview);
  });

  group('ApplicationFilter.toQuery', () {
    test('defaults to sorting only', () {
      expect(const ApplicationFilter().toQuery(), {'sort': 'newest'});
    });

    test('serializes every criterion with API names', () {
      final query = ApplicationFilter(
        query: '  flutter ',
        statuses: {ApplicationStatus.applied, ApplicationStatus.offer},
        arrangements: {WorkArrangement.onsite},
        appliedFrom: DateTime(2026, 10, 1),
        appliedTo: DateTime(2026, 10, 31),
        sort: ApplicationSort.companyAZ,
      ).toQuery();
      expect(query, {
        'q': 'flutter',
        'status': 'applied,offer',
        'arrangement': 'onsite',
        'from': '2026-10-01',
        'to': '2026-10-31',
        'sort': 'companyAZ',
      });
    });

    test('equal filters compare equal regardless of set order', () {
      expect(
        const ApplicationFilter(
          statuses: {ApplicationStatus.applied, ApplicationStatus.offer},
        ),
        const ApplicationFilter(
          statuses: {ApplicationStatus.offer, ApplicationStatus.applied},
        ),
      );
    });
  });

  test(
    'ReminderItem derives a stable positive notification id from its key',
    () {
      final item = ReminderItem(
        key: 'interview:3:1440',
        kind: ReminderKind.interviewReminder,
        fireAt: _fireAt,
        title: 't',
        body: 'b',
      );
      expect(item.notificationId, item.notificationId);
      expect(item.notificationId, inInclusiveRange(0, 0x7fffffff));
      // Pinned so a change of algorithm (which would orphan scheduled
      // notifications after an app update) is noticed.
      expect(item.notificationId, 1240989698);
      expect(
        ReminderItem(
          key: 'interview:3:60',
          kind: ReminderKind.interviewReminder,
          fireAt: _fireAt,
          title: 't',
          body: 'b',
        ).notificationId,
        isNot(item.notificationId),
      );
    },
  );
}

final _fireAt = DateTime.utc(2026, 10, 26, 2);
