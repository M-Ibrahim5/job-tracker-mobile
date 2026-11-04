import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/app/app.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/app/router.dart';
import 'package:jobtrail/core/errors/failures.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/domain/models/page.dart';
import 'package:jobtrail/domain/models/status_history_entry.dart';
import 'package:jobtrail/features/applications/application/application_providers.dart';
import 'package:jobtrail/features/applications/presentation/application_card.dart';

import '../helpers/test_app.dart';

JobApplication _app(int i, {String? title}) => JobApplication(
  id: 0,
  jobTitle: title ?? 'Role number $i',
  companyName: 'Company $i',
  location: 'Somewhere',
  workArrangement: WorkArrangement.values[i % 3],
  appliedDate: DateTime(2025, 1, 1).add(Duration(days: i % 400)),
  status: ApplicationStatus.applied,
  createdAt: DateTime(2025),
  updatedAt: DateTime(2025),
);

Future<void> _seed(FakeBackend b, int count, {String? longTitle}) async {
  final repo = FakeJobApplicationRepository(b);
  for (var i = 0; i < count; i++) {
    await repo.create(_app(i, title: i == 0 ? longTitle : null));
  }
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  Size size = const Size(390, 844),
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend.currentUser = backend.usersByEmail[kFakeEmail];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...fakeOverrides(backend), ...extra],
      child: const JobTrailApp(useGoogleFonts: false),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(JobTrailApp)));
}

void main() {
  group('500+ applications', () {
    testWidgets('the list pages through all of them while scrolling', (
      tester,
    ) async {
      final backend = FakeBackend(latency: Duration.zero)..clearData();
      await _seed(backend, 620);
      final container = await _pumpApp(tester, backend);
      container.read(routerProvider).go('/applications');
      await tester.pumpAndSettle();

      final watch = Stopwatch()..start();
      expect(find.text('620 total'), findsOneWidget);
      for (var i = 0; i < 60; i++) {
        await tester.fling(
          find.byType(ListView).first,
          const Offset(0, -3000),
          8000,
        );
        await tester.pumpAndSettle();
        final state = container.read(applicationListProvider).requireValue;
        if (!state.hasMore) break;
      }
      final state = container.read(applicationListProvider).requireValue;
      expect(state.items.length, 620, reason: 'every page was fetched');
      expect(state.items.map((a) => a.id).toSet().length, 620);
      expect(watch.elapsed, lessThan(const Duration(seconds: 60)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtering and searching stay responsive', (tester) async {
      final backend = FakeBackend(latency: Duration.zero)..clearData();
      await _seed(backend, 600);
      final container = await _pumpApp(tester, backend);

      final repo = container.read(jobApplicationRepositoryProvider);
      final watch = Stopwatch()..start();
      final page = await repo.list(
        const ApplicationFilter(
          query: 'Company 59',
          sort: ApplicationSort.companyAZ,
        ),
      );
      watch.stop();
      expect(page.total, 11); // Company 59 and Company 590..599
      expect(page.items.length, 11);
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    testWidgets('the dashboard counts them all', (tester) async {
      final backend = FakeBackend(latency: Duration.zero)..clearData();
      await _seed(backend, 550);
      final container = await _pumpApp(tester, backend);
      container.read(routerProvider).go('/');
      await tester.pumpAndSettle();
      expect(find.text('550'), findsWidgets);
    });
  });

  group('very long text', () {
    final longTitle = 'Principal Staff Distinguished ${'Engineer ' * 40}';

    testWidgets('list card, detail and form do not overflow', (tester) async {
      final backend = FakeBackend(latency: Duration.zero)..clearData();
      await _seed(backend, 3, longTitle: longTitle);
      final container = await _pumpApp(
        tester,
        backend,
        size: const Size(320, 568),
      );
      final router = container.read(routerProvider);

      router.go('/applications');
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationCard), findsWidgets);
      expect(tester.takeException(), isNull);

      final id = backend.applications.values.first.id;
      router.go('/applications/$id');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      router.go('/applications/$id/edit');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long job description collapses behind Read more', (
      tester,
    ) async {
      final backend = FakeBackend(latency: Duration.zero)..clearData();
      await _seed(backend, 1);
      final id = backend.applications.values.first.id;
      backend.applications[id] = backend.applications[id]!.copyWith(
        jobDescription: List.filled(
          400,
          'Responsibilities include things.',
        ).join(' '),
      );
      final container = await _pumpApp(tester, backend);
      container.read(routerProvider).go('/applications/$id');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Read more'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Read more'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('offline', () {
    testWidgets('every data tab degrades to a retry state, never a crash', (
      tester,
    ) async {
      final backend = FakeBackend(latency: Duration.zero);
      // Everything the server would answer is down.
      final container = await _pumpApp(
        tester,
        backend,
        extra: [jobApplicationRepositoryProvider.overrideWithValue(_Offline())],
      );
      final router = container.read(routerProvider);
      for (final route in ['/applications', '/applications/1']) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(find.text('Retry'), findsWidgets, reason: route);
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  });
}

/// Application repository whose reads fail like a dropped connection.
class _Offline extends FakeJobApplicationRepository {
  _Offline() : super(FakeBackend(latency: Duration.zero));

  @override
  Future<Page<JobApplication>> list(
    ApplicationFilter filter, {
    int page = 1,
    int pageSize = 20,
  }) => Future.error(const NetworkFailure());

  @override
  Future<JobApplication> getById(int id) =>
      Future.error(const NetworkFailure());

  @override
  Future<List<StatusHistoryEntry>> history(int id) =>
      Future.error(const NetworkFailure());
}
