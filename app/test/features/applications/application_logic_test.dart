import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/constants/app_constants.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/core/utils/validators.dart';
import 'package:jobtrail/data/api/api_job_application_repository.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/features/applications/application/application_controllers.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/applications/application/status_flow.dart';

import '../../helpers/test_app.dart';
import 'harness.dart';

ProviderContainer _container(AppFixture f) {
  final c = ProviderContainer(overrides: f.overrides);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('filter → query mapping', () {
    test('the default filter only sends the sort', () {
      expect(const ApplicationFilter().toQuery(), {'sort': 'newest'});
    });

    test('maps every criterion to the API parameter', () {
      final q = ApplicationFilter(
        query: '  flutter ',
        statuses: const {ApplicationStatus.interview, ApplicationStatus.offer},
        arrangements: const {WorkArrangement.remote},
        appliedFrom: DateTime(2026, 1, 5),
        appliedTo: DateTime(2026, 2, 9),
        sort: ApplicationSort.companyAZ,
      ).toQuery();
      expect(q['q'], 'flutter');
      expect((q['status'] as String).split(',').toSet(), {
        'interview',
        'offer',
      });
      expect(q['arrangement'], 'remote');
      expect(q['from'], '2026-01-05');
      expect(q['to'], '2026-02-09');
      expect(q['sort'], 'companyAZ');
    });

    test('statusFromQuery accepts only known names', () {
      expect(statusFromQuery('interview'), ApplicationStatus.interview);
      expect(statusFromQuery('nope'), isNull);
      expect(statusFromQuery(null), isNull);
    });
  });

  group('status sheet logic', () {
    test('classifies current, next-in-flow and other options', () {
      const current = ApplicationStatus.screening;
      expect(
        statusOptionKind(ApplicationStatus.screening, current),
        StatusOptionKind.current,
      );
      expect(
        statusOptionKind(ApplicationStatus.interview, current),
        StatusOptionKind.next,
      );
      expect(
        statusOptionKind(ApplicationStatus.rejected, current),
        StatusOptionKind.other,
      );
      // Rejected has no next step, so every other status is just "other".
      expect(
        statusOptionKind(ApplicationStatus.applied, ApplicationStatus.rejected),
        StatusOptionKind.other,
      );
    });

    test('Confirm needs a different status and a note within the limit', () {
      const current = ApplicationStatus.applied;
      expect(
        canConfirmStatusChange(current: current, selected: null, note: ''),
        isFalse,
      );
      expect(
        canConfirmStatusChange(
          current: current,
          selected: ApplicationStatus.applied,
          note: '',
        ),
        isFalse,
      );
      expect(
        canConfirmStatusChange(
          current: current,
          selected: ApplicationStatus.rejected,
          note: 'x' * Limits.note,
        ),
        isTrue,
      );
      expect(
        canConfirmStatusChange(
          current: current,
          selected: ApplicationStatus.rejected,
          note: 'x' * (Limits.note + 1),
        ),
        isFalse,
      );
    });

    test('blank notes are not sent', () {
      expect(normalizedNote('  '), isNull);
      expect(normalizedNote(' called '), 'called');
    });
  });

  group('validators added for applications', () {
    test('job description is capped at 10,000 characters', () {
      expect(Validators.jobDescription('x' * 10000), isNull);
      expect(Validators.jobDescription('x' * 10001), isNotNull);
      expect(Validators.jobDescription(null), isNull);
    });

    test('application link must be http(s) and at most 2048 characters', () {
      expect(Validators.applicationLink(''), isNull);
      expect(Validators.applicationLink('https://a.example/jobs'), isNull);
      expect(Validators.applicationLink('ftp://a.example'), isNotNull);
      expect(
        Validators.applicationLink('https://a.example/${'x' * 2050}'),
        isNotNull,
      );
    });
  });

  group('application list notifier', () {
    test('loads the first page of 20 and pages on loadMore', () async {
      final f = AppFixture();
      await f.addApplications(30); // 15 seeded + 30
      final c = _container(f);

      final first = await c.read(applicationListProvider.future);
      expect(first.items, hasLength(20));
      expect(first.total, 45);
      expect(first.hasMore, isTrue);

      await c.read(applicationListProvider.notifier).loadMore();
      expect(c.read(applicationListProvider).requireValue.items, hasLength(40));

      await c.read(applicationListProvider.notifier).loadMore();
      final all = c.read(applicationListProvider).requireValue;
      expect(all.items, hasLength(45));
      expect(all.hasMore, isFalse);
      expect(all.items.map((a) => a.id).toSet(), hasLength(45));

      // Nothing more to fetch: no extra request.
      final calls = f.repo.listCalls.length;
      await c.read(applicationListProvider.notifier).loadMore();
      expect(f.repo.listCalls, hasLength(calls));
    });

    test(
      'a failed page keeps the loaded items and exposes the error',
      () async {
        final f = AppFixture();
        await f.addApplications(30);
        final c = _container(f);
        await c.read(applicationListProvider.future);

        f.repo.failNextList = const NetworkFailure();
        await c.read(applicationListProvider.notifier).loadMore();
        final s = c.read(applicationListProvider).requireValue;
        expect(s.items, hasLength(20));
        expect(s.loadMoreError, isA<NetworkFailure>());
        expect(s.loadingMore, isFalse);

        await c.read(applicationListProvider.notifier).loadMore();
        expect(
          c.read(applicationListProvider).requireValue.items,
          hasLength(40),
        );
        expect(
          c.read(applicationListProvider).requireValue.loadMoreError,
          isNull,
        );
      },
    );

    test(
      'changing the filter resets to page 1 with the new criteria',
      () async {
        final f = AppFixture();
        await f.addApplications(30);
        final c = _container(f);
        await c.read(applicationListProvider.future);
        await c.read(applicationListProvider.notifier).loadMore();
        expect(c.read(applicationListProvider).requireValue.page, 2);

        c.read(applicationFilterProvider.notifier).state =
            const ApplicationFilter(statuses: {ApplicationStatus.offer});
        final reset = await c.read(applicationListProvider.future);
        expect(reset.page, 1);
        expect(
          reset.items.every((a) => a.status == ApplicationStatus.offer),
          true,
        );
        expect(f.repo.listCalls.last.page, 1);
        expect(f.repo.listCalls.last.filter.statuses, {
          ApplicationStatus.offer,
        });
      },
    );

    testWidgets(
      'search text waits 300 ms and only the last keystroke queries',
      (tester) async {
        final f = AppFixture();
        final c = _container(f);
        c.listen(applicationListProvider, (_, _) {});
        await tester.pump();
        expect(f.repo.listCalls, hasLength(1));

        final filter = c.read(applicationFilterProvider.notifier);
        filter.state = filter.state.copyWith(query: 'f');
        await tester.pump(const Duration(milliseconds: 200));
        filter.state = filter.state.copyWith(query: 'fl');
        await tester.pump(const Duration(milliseconds: 299));
        expect(f.repo.listCalls, hasLength(1), reason: 'still debouncing');

        await tester.pump(const Duration(milliseconds: 1));
        expect(f.repo.listCalls, hasLength(2));
        expect(f.repo.listCalls.last.filter.query, 'fl');
      },
    );

    testWidgets('non-search filter changes query immediately', (tester) async {
      final f = AppFixture();
      final c = _container(f);
      c.listen(applicationListProvider, (_, _) {});
      await tester.pump();

      c.read(applicationFilterProvider.notifier).state =
          const ApplicationFilter(statuses: {ApplicationStatus.applied});
      // Riverpod refreshes on a zero-length timer.
      await tester.pump(Duration.zero);
      expect(f.repo.listCalls, hasLength(2));
      expect(f.repo.listCalls.last.filter.statuses, {
        ApplicationStatus.applied,
      });
    });

    test(
      'applyUpdated drops an item that no longer matches the status filter',
      () async {
        final f = AppFixture();
        final c = _container(f);
        c.read(applicationFilterProvider.notifier).state =
            const ApplicationFilter(statuses: {ApplicationStatus.applied});
        final before = await c.read(applicationListProvider.future);
        final target = before.items.first;

        final result = await f.repo.changeStatus(
          target.id,
          ApplicationStatus.screening,
        );
        c
            .read(applicationListProvider.notifier)
            .applyUpdated(result.application);

        final after = c.read(applicationListProvider).requireValue;
        expect(after.items.any((a) => a.id == target.id), isFalse);
        expect(after.total, before.total - 1);
      },
    );
  });

  group('pending (undoable) deletes', () {
    test('nothing is deleted until commit; undo cancels it', () async {
      final f = AppFixture();
      final c = _container(f);
      final app = (await c.read(applicationListProvider.future)).items.first;
      final pending = c.read(pendingDeleteProvider.notifier);

      pending.schedule(app);
      expect(c.read(pendingDeleteProvider), contains(app.id));
      expect(f.repo.deleted, isEmpty);

      pending.undo(app.id);
      expect(c.read(pendingDeleteProvider), isEmpty);
      expect(await pending.commit(app.id), isNull);
      expect(f.repo.deleted, isEmpty);
    });

    test('commit deletes on the server and removes the row', () async {
      final f = AppFixture();
      final c = _container(f);
      final before = await c.read(applicationListProvider.future);
      final app = before.items.first;
      final pending = c.read(pendingDeleteProvider.notifier);

      pending.schedule(app);
      expect(await pending.commit(app.id), isNull);

      expect(f.repo.deleted, [app.id]);
      expect(c.read(pendingDeleteProvider), isEmpty);
      final after = c.read(applicationListProvider).requireValue;
      expect(after.items.any((a) => a.id == app.id), isFalse);
      expect(after.total, before.total - 1);
    });

    test('committing twice sends a single DELETE', () async {
      final f = AppFixture();
      final c = _container(f);
      final app = (await c.read(applicationListProvider.future)).items.first;
      final pending = c.read(pendingDeleteProvider.notifier);
      pending.schedule(app);

      await Future.wait([pending.commit(app.id), pending.commit(app.id)]);
      expect(f.repo.deleted, [app.id]);
    });

    test('a failed delete brings the row back and returns the error', () async {
      final f = AppFixture();
      final c = _container(f);
      final app = (await c.read(applicationListProvider.future)).items.first;
      final pending = c.read(pendingDeleteProvider.notifier);
      pending.schedule(app);

      f.repo.failNextDelete = const NetworkFailure();
      expect(await pending.commit(app.id), isA<NetworkFailure>());
      expect(c.read(pendingDeleteProvider), isEmpty);
      expect(
        c
            .read(applicationListProvider)
            .requireValue
            .items
            .any((a) => a.id == app.id),
        isTrue,
      );
    });

    test('flushAll commits everything that is pending', () async {
      final f = AppFixture();
      final c = _container(f);
      final items = (await c.read(applicationListProvider.future)).items;
      final pending = c.read(pendingDeleteProvider.notifier)
        ..schedule(items[0])
        ..schedule(items[1]);

      await pending.flushAll();
      expect(f.repo.deleted.toSet(), {items[0].id, items[1].id});
      expect(c.read(pendingDeleteProvider), isEmpty);
    });
  });

  group('status change controller', () {
    test('sends a trimmed note and refreshes list and detail caches', () async {
      final f = AppFixture();
      final c = _container(f);
      final list = await c.read(applicationListProvider.future);
      final target = list.items.firstWhere(
        (a) => a.status == ApplicationStatus.applied,
      );
      c.listen(statusChangeControllerProvider, (_, _) {});

      final result = await c
          .read(statusChangeControllerProvider.notifier)
          .change(target.id, ApplicationStatus.screening, note: '  called  ');

      expect(result, isNotNull);
      expect(f.repo.statusChanges.single.note, 'called');
      final updated = c
          .read(applicationListProvider)
          .requireValue
          .items
          .firstWhere((a) => a.id == target.id);
      expect(updated.status, ApplicationStatus.screening);
      expect(c.read(applicationsRevisionProvider), 1);
    });

    test('a rejected application can be reopened', () async {
      final f = AppFixture();
      final c = _container(f);
      final list = await c.read(applicationListProvider.future);
      final rejected = list.items.firstWhere(
        (a) => a.status == ApplicationStatus.rejected,
      );
      c.listen(statusChangeControllerProvider, (_, _) {});

      final result = await c
          .read(statusChangeControllerProvider.notifier)
          .change(rejected.id, ApplicationStatus.interview);
      expect(result!.application.status, ApplicationStatus.interview);
      expect(result.history!.fromStatus, ApplicationStatus.rejected);
    });
  });

  group('ApiJobApplicationRepository', () {
    const appJson =
        '{"id":12,"jobTitle":"Dev","companyName":"Acme","location":"KL",'
        '"workArrangement":"hybrid","jobDescription":null,"applicationLink":null,'
        '"employmentType":null,"salaryRange":null,"source":null,'
        '"appliedDate":"2026-10-22","status":"applied","notes":null,'
        '"contactName":null,"contactEmail":null,"followUpAt":null,'
        '"nextInterviewAt":null,"createdAt":"2026-10-22T02:00:00.000Z",'
        '"updatedAt":"2026-10-22T02:00:00.000Z"}';
    const entryJson =
        '{"id":5,"applicationId":12,"fromStatus":"applied","toStatus":"screening",'
        '"changedAt":"2026-10-24T03:05:00.000Z","note":"Called"}';

    ({ApiJobApplicationRepository repo, ScriptedAdapter adapter}) build(
      Future<ResponseBody> Function(RequestOptions) handler,
    ) {
      final adapter = ScriptedAdapter(handler);
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
        ..httpClientAdapter = adapter;
      return (repo: ApiJobApplicationRepository(dio), adapter: adapter);
    }

    test('list sends filter, sort and paging as query parameters', () async {
      final t = build(
        (_) async => jsonBody(
          '{"items":[$appJson],"page":2,"pageSize":20,"total":21}',
          200,
        ),
      );
      final page = await t.repo.list(
        const ApplicationFilter(
          query: 'dev',
          statuses: {ApplicationStatus.applied},
          sort: ApplicationSort.oldest,
        ),
        page: 2,
      );

      final req = t.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/applications');
      expect(req.queryParameters, {
        'q': 'dev',
        'status': 'applied',
        'sort': 'oldest',
        'page': 2,
        'pageSize': 20,
      });
      expect(page.items.single.jobTitle, 'Dev');
      expect(page.hasMore, isFalse);
    });

    test('create posts the editable fields; update patches by id', () async {
      final t = build((_) async => jsonBody(appJson, 200));
      final draft = (await t.repo.getById(12)).copyWith(location: 'Penang');

      await t.repo.create(draft);
      await t.repo.update(draft);

      final post = t.adapter.requests[1];
      expect(post.method, 'POST');
      expect(post.path, '/applications');
      expect((post.data as Map)['location'], 'Penang');
      expect((post.data as Map).containsKey('status'), isFalse);
      expect((post.data as Map)['appliedDate'], '2026-10-22');

      final patch = t.adapter.requests[2];
      expect(patch.method, 'PATCH');
      expect(patch.path, '/applications/12');
    });

    test(
      'changeStatus, history, timeline and delete hit the right paths',
      () async {
        final t = build((o) async {
          if (o.path.endsWith('/status')) {
            return jsonBody(
              '{"application":$appJson,"history":$entryJson}',
              200,
            );
          }
          if (o.path.endsWith('/history')) return jsonBody('[$entryJson]', 200);
          if (o.path.endsWith('/timeline')) {
            return jsonBody('{"history":[$entryJson],"interviews":[]}', 200);
          }
          return ResponseBody.fromString('', 204);
        });

        final r = await t.repo.changeStatus(
          12,
          ApplicationStatus.screening,
          note: 'Called',
        );
        expect(r.history!.note, 'Called');
        expect(t.adapter.requests.last.path, '/applications/12/status');
        expect(t.adapter.requests.last.data, {
          'status': 'screening',
          'note': 'Called',
        });

        await t.repo.changeStatus(12, ApplicationStatus.offer);
        expect(t.adapter.requests.last.data, {'status': 'offer'});

        expect(await t.repo.history(12), hasLength(1));
        expect((await t.repo.timeline(12)).history, hasLength(1));
        await t.repo.delete(12);
        expect(t.adapter.requests.last.method, 'DELETE');
        expect(t.adapter.requests.last.path, '/applications/12');
      },
    );

    test(
      'server validation errors surface as ApiFailure with fields',
      () async {
        final t = build(
          (_) async => jsonBody(
            '{"error":{"code":"VALIDATION_ERROR","message":"Bad",'
            '"fields":{"jobTitle":"This field is required"}}}',
            422,
          ),
        );
        await expectLater(
          t.repo.create(
            JobApplication.fromJson(
              jsonDecode(appJson) as Map<String, dynamic>,
            ),
          ),
          throwsA(
            isA<ApiFailure>().having(
              (e) => e.fields['jobTitle'],
              'jobTitle',
              'This field is required',
            ),
          ),
        );
      },
    );
  });
}
