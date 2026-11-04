import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jobtrail/app/providers.dart';
import 'package:jobtrail/data/fake/fake_repositories.dart';
import 'package:jobtrail/domain/models/interview.dart';
import 'package:jobtrail/domain/models/page.dart';
import 'package:jobtrail/domain/enums/enums.dart';
import 'package:jobtrail/features/interviews/presentation/interview_detail_screen.dart';
import 'package:jobtrail/features/interviews/presentation/interview_form_screen.dart';

import '../applications/harness.dart';

/// Interview repository that records calls and can fail on demand.
class RecordingInterviewRepository extends FakeInterviewRepository {
  RecordingInterviewRepository(super.b);

  final created = <({int applicationId, Interview interview})>[];
  final updated = <Interview>[];
  final deleted = <int>[];
  Object? failNextSave;
  Object? failNextList;

  @override
  Future<Page<Interview>> list({
    InterviewScope? scope,
    int? applicationId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async {
    final error = failNextList;
    if (error != null) {
      failNextList = null;
      throw error;
    }
    return super.list(
      scope: scope,
      applicationId: applicationId,
      from: from,
      to: to,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Interview> create(int applicationId, Interview interview) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    created.add((applicationId: applicationId, interview: interview));
    return super.create(applicationId, interview);
  }

  @override
  Future<Interview> update(Interview interview) async {
    final error = failNextSave;
    if (error != null) {
      failNextSave = null;
      throw error;
    }
    updated.add(interview);
    return super.update(interview);
  }

  @override
  Future<void> delete(int id) {
    deleted.add(id);
    return super.delete(id);
  }
}

/// [AppFixture] plus a recording interview repository.
class InterviewFixture extends AppFixture {
  InterviewFixture() {
    interviews = RecordingInterviewRepository(backend);
  }

  late final RecordingInterviewRepository interviews;

  @override
  List<Override> get overrides => [
    ...super.overrides,
    interviewRepositoryProvider.overrideWithValue(interviews),
  ];
}

/// Routes that render the real interview screens.
List<GoRoute> interviewRoutes() => [
  GoRoute(
    path: '/interviews/new',
    builder: (_, s) => InterviewFormScreen(
      initialDate: s.uri.queryParameters['date'] == null
          ? null
          : DateTime.parse(s.uri.queryParameters['date']!),
    ),
  ),
  GoRoute(
    path: '/interviews/:id',
    builder: (_, s) =>
        InterviewDetailScreen(id: int.parse(s.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/interviews/:id/edit',
    builder: (_, s) =>
        InterviewFormScreen(interviewId: int.parse(s.pathParameters['id']!)),
  ),
  GoRoute(
    path: '/applications/:id/interviews/new',
    builder: (_, s) =>
        InterviewFormScreen(applicationId: int.parse(s.pathParameters['id']!)),
  ),
];
