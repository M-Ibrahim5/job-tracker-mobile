import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/app/theme/app_theme.dart';
import 'package:jobtrail/data/fake/fake_backend.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/domain/models/application_extras.dart';
import 'package:jobtrail/domain/models/application_filter.dart';
import 'package:jobtrail/domain/models/job_application.dart';
import 'package:jobtrail/domain/models/page.dart';

import '../../helpers/test_app.dart';

/// Fake repository that records calls and can be told to fail or wait.
class RecordingApplicationRepository extends FakeJobApplicationRepository {
  RecordingApplicationRepository(super.b);

  final listCalls = <({ApplicationFilter filter, int page})>[];
  final deleted = <int>[];
  final statusChanges = <({int id, ApplicationStatus status, String? note})>[];
  final created = <JobApplication>[];
  final updated = <JobApplication>[];

  /// Failures thrown (once each) by the next call of that kind.
  Object? failNextList;
  Object? failNextDelete;
  Object? failNextSave;

  /// When set, `list` waits for it (to observe the loading state).
  Completer<void>? listGate;

  @override
  Future<Page<JobApplication>> list(
    ApplicationFilter filter, {
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls.add((filter: filter, page: page));
    final gate = listGate;
    if (gate != null) await gate.future;
    final error = failNextList;
    if (error != null) {
      failNextList = null;
      throw error;
    }
    return super.list(filter, page: page, pageSize: pageSize);
  }

  @override
  Future<void> delete(int id) async {
    final error = failNextDelete;
    if (error != null) {
      failNextDelete = null;
      throw error;
    }
    deleted.add(id);
    return super.delete(id);
  }

  @override
  Future<StatusChangeResult> changeStatus(
    int id,
    ApplicationStatus status, {
    String? note,
  }) {
    statusChanges.add((id: id, status: status, note: note));
    return super.changeStatus(id, status, note: note);
  }

  @override
  Future<JobApplication> create(JobApplication application) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    created.add(application);
    return super.create(application);
  }

  @override
  Future<JobApplication> update(JobApplication application) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    updated.add(application);
    return super.update(application);
  }
}

/// Backend + recording repository wired through provider overrides.
class AppFixture {
  AppFixture() {
    repo = RecordingApplicationRepository(backend);
  }

  final backend = FakeBackend(latency: Duration.zero);
  late final RecordingApplicationRepository repo;

  List<Override> get overrides => [
    ...fakeOverrides(backend),
    jobApplicationRepositoryProvider.overrideWithValue(repo),
  ];

  /// Adds [count] extra applications so the list needs several pages.
  Future<void> addApplications(int count) async {
    for (var i = 0; i < count; i++) {
      await FakeJobApplicationRepository(backend).create(
        JobApplication(
          id: 0,
          jobTitle: 'Bulk role $i',
          companyName: 'Bulk Co $i',
          location: 'Nowhere',
          workArrangement: WorkArrangement.remote,
          appliedDate: DateTime(2020, 1, 1).add(Duration(days: i)),
          status: ApplicationStatus.applied,
          createdAt: DateTime(2020),
          updatedAt: DateTime(2020),
        ),
      );
    }
  }
}

/// Pumps [home] at `/` inside a themed router app. Extra [routes] let tests
/// push to other screens; `/applications/new` and `/applications/:id` render
/// text markers unless overridden.
Widget routedApp(
  Widget home, {
  required List<Override> overrides,
  List<GoRoute> routes = const [],
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      ...routes,
      GoRoute(
        path: '/applications/new',
        builder: (_, _) => const Scaffold(body: Text('NEW-FORM')),
      ),
      GoRoute(
        path: '/applications/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL-${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: brightness == Brightness.light
          ? AppTheme.light(useGoogleFonts: false)
          : AppTheme.dark(useGoogleFonts: false),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

/// A home screen with a button that pushes [target], so pops can be tested.
Widget pushingHome(String target) => Builder(
  builder: (context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.push(target),
        child: const Text('open'),
      ),
    ),
  ),
);
