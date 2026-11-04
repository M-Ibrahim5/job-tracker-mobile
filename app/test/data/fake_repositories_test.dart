import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';

void main() {
  late FakeBackend backend;

  setUp(() => backend = FakeBackend(latency: Duration.zero));

  group('auth', () {
    test('signs in the seeded account and rejects a wrong password', () async {
      final auth = FakeAuthRepository(backend);
      expect(await auth.restoreSession(), isNull);

      await expectLater(
        auth.signIn(email: kFakeEmail, password: 'nope'),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.code,
            'code',
            ApiCodes.invalidCredentials,
          ),
        ),
      );

      final user = await auth.signIn(
        email: kFakeEmail,
        password: kFakePassword,
      );
      expect(user.fullName, 'Muhammad Ibrahim');
      expect(await auth.restoreSession(), user);

      await auth.signOut();
      expect(await auth.restoreSession(), isNull);
    });

    test('rejects a duplicate email on register', () async {
      final auth = FakeAuthRepository(backend);
      await expectLater(
        auth.signUp(
          fullName: 'Someone',
          email: kFakeEmail,
          password: 'Abcdef1!',
        ),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', ApiCodes.emailTaken),
        ),
      );
    });
  });

  group('applications', () {
    late FakeJobApplicationRepository repo;

    setUp(() => repo = FakeJobApplicationRepository(backend));

    test('lists newest first, paginates and omits the description', () async {
      final first = await repo.list(const ApplicationFilter(), pageSize: 10);
      expect(first.total, 15);
      expect(first.items, hasLength(10));
      expect(first.hasMore, isTrue);
      expect(first.items.every((a) => a.jobDescription == null), isTrue);
      final dates = first.items.map((a) => a.appliedDate).toList();
      expect([...dates]..sort((a, b) => b.compareTo(a)), dates);

      final second = await repo.list(
        const ApplicationFilter(),
        page: 2,
        pageSize: 10,
      );
      expect(second.items, hasLength(5));
      expect(second.hasMore, isFalse);
    });

    test('filters by status, text and sorts by company', () async {
      final applied = await repo.list(
        const ApplicationFilter(statuses: {ApplicationStatus.applied}),
      );
      expect(applied.total, 5);

      final search = await repo.list(
        const ApplicationFilter(query: 'northwind'),
      );
      expect(search.items.single.companyName, 'Northwind Labs');

      final sorted = await repo.list(
        const ApplicationFilter(sort: ApplicationSort.companyAZ),
      );
      final names = sorted.items
          .map((a) => a.companyName.toLowerCase())
          .toList();
      expect([...names]..sort(), names);
    });

    test('detail has the description and computed next interview', () async {
      final app = await repo.getById(1);
      expect(app.jobDescription, isNotEmpty);
      expect(app.nextInterviewAt, isNotNull);
    });

    test('create starts as applied with an initial history entry', () async {
      final draft = (await repo.getById(
        1,
      )).copyWith(jobTitle: 'New role', status: ApplicationStatus.offer);
      final created = await repo.create(draft);
      expect(created.id, greaterThan(15));
      expect(created.status, ApplicationStatus.applied);
      final history = await repo.history(created.id);
      expect(history.single.fromStatus, isNull);
      expect(history.single.toStatus, ApplicationStatus.applied);
    });

    test(
      'changeStatus records history, notifies and is a no-op when unchanged',
      () async {
        final result = await repo.changeStatus(
          3,
          ApplicationStatus.screening,
          note: 'Recruiter called',
        );
        expect(result.application.status, ApplicationStatus.screening);
        expect(result.history!.fromStatus, ApplicationStatus.applied);
        expect(result.history!.note, 'Recruiter called');
        expect(backend.notifications.last.title, 'Moved to Screening');

        final again = await repo.changeStatus(3, ApplicationStatus.screening);
        expect(again.history, isNull);
        expect((await repo.history(3)).length, 2);
      },
    );

    test('delete cascades and unknown ids are NOT_FOUND', () async {
      await repo.delete(1);
      expect(
        backend.interviews.values.where((i) => i.applicationId == 1),
        isEmpty,
      );
      await expectLater(
        repo.getById(1),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', ApiCodes.notFound),
        ),
      );
    });
  });

  group('interviews', () {
    late FakeInterviewRepository repo;

    setUp(() => repo = FakeInterviewRepository(backend));

    test('upcoming is ascending and past is descending', () async {
      final upcoming = await repo.list(scope: InterviewScope.upcoming);
      final times = upcoming.items.map((i) => i.scheduledAt).toList();
      expect([...times]..sort(), times);
      expect(upcoming.items.first.companyName, isNotNull);

      final past = await repo.list(scope: InterviewScope.past);
      expect(past.items, isNotEmpty);
      expect(
        past.items.every((i) => i.scheduledAt.isBefore(backend.now)),
        isTrue,
      );
    });

    test(
      'rejects a second interview at the same time for an application',
      () async {
        final existing = (await repo.getById(1));
        await expectLater(
          repo.create(2, existing.copyWith(applicationId: 2)),
          completes,
        );
        await expectLater(
          repo.create(2, existing.copyWith(applicationId: 2)),
          throwsA(
            isA<ApiFailure>().having(
              (f) => f.code,
              'code',
              ApiCodes.interviewConflict,
            ),
          ),
        );
      },
    );
  });

  test('notifications: unread count, mark read, clear', () async {
    final repo = FakeNotificationRepository(backend);
    expect(await repo.unreadCount(), 2);
    final page = await repo.list();
    await repo.markRead(page.items.first.id);
    expect(await repo.unreadCount(), 1);
    await repo.markAllRead();
    expect(await repo.unreadCount(), 0);
    await repo.clear();
    expect((await repo.list()).total, 0);
  });

  test('dashboard matches the sample numbers from DESIGN.md', () async {
    final data = await FakeDashboardRepository(backend).load(timezone: 'UTC');
    expect(data.total, 15);
    expect(data.active, 11);
    expect(data.responseRatePercent, 67);
    expect(data.statusCounts, {
      ApplicationStatus.applied: 5,
      ApplicationStatus.screening: 3,
      ApplicationStatus.interview: 3,
      ApplicationStatus.offer: 1,
      ApplicationStatus.rejected: 3,
    });
    expect(data.weekly, hasLength(8));
    expect(data.upcomingInterviews, hasLength(3));
    expect(data.recentActivity.length, lessThanOrEqualTo(5));
  });

  test('reminders include only future fire times for enabled types', () async {
    final repo = FakeReminderRepository(backend);
    final items = await repo.upcoming();
    expect(items, isNotEmpty);
    expect(items.every((r) => r.fireAt.isAfter(backend.now)), isTrue);
    expect(items.any((r) => r.kind == ReminderKind.followUpReminder), isTrue);

    backend.settings = backend.settings.copyWith(
      interviewRemindersEnabled: false,
      followUpRemindersEnabled: false,
    );
    expect(await repo.upcoming(), isEmpty);
  });

  test(
    'export produces JSON and CSV; deleteAllData keeps the account',
    () async {
      final data = FakeDataRepository(backend);
      final json = String.fromCharCodes(await data.export(ExportFormat.json));
      expect(json, contains('"applications"'));
      final csv = String.fromCharCodes(await data.export(ExportFormat.csv));
      expect(csv.split('\n'), hasLength(16));

      await data.deleteAllData();
      expect(backend.applications, isEmpty);
      expect(backend.usersByEmail, isNotEmpty);
    },
  );
}
