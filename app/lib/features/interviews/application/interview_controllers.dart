import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/interview.dart';
import '../../applications/application/application_providers.dart';
import 'interviews_providers.dart';

/// Refreshes everything that shows interviews or an application's next
/// interview after a change.
void refreshAfterInterviewChange(Ref ref, int applicationId) {
  ref.read(interviewsRevisionProvider.notifier).state++;
  ref.invalidate(interviewsForApplicationProvider(applicationId));
  ref.invalidate(applicationDetailProvider(applicationId));
  ref.invalidate(applicationListProvider);
  ref.read(applicationsRevisionProvider.notifier).state++;
}

/// Creates, updates and changes the outcome of interviews.
///
/// `state` is `AsyncLoading` while saving and `AsyncError` with the
/// repository's failure (e.g. `INTERVIEW_CONFLICT`) when it fails.
class InterviewController extends AutoDisposeAsyncNotifier<Interview?> {
  /// True when the last save created the interview but moving the application
  /// to Interview failed.
  bool statusMoveFailed = false;

  @override
  Interview? build() => null;

  /// How many interviews [applicationId] already has.
  Future<int> countFor(int applicationId) async {
    final page = await ref
        .read(interviewRepositoryProvider)
        .list(applicationId: applicationId, pageSize: 1);
    return page.total;
  }

  /// Saves [draft] for [applicationId]; with [moveStatus] the application is
  /// moved to Interview right after a successful create. Returns the saved
  /// interview or null when it failed.
  Future<Interview?> save({
    required int applicationId,
    required Interview draft,
    required bool isEdit,
    bool moveStatus = false,
  }) async {
    state = const AsyncLoading();
    statusMoveFailed = false;
    final repo = ref.read(interviewRepositoryProvider);
    try {
      final saved = isEdit
          ? await repo.update(draft)
          : await repo.create(applicationId, draft);
      if (moveStatus && !isEdit) {
        try {
          final result = await ref
              .read(jobApplicationRepositoryProvider)
              .changeStatus(applicationId, ApplicationStatus.interview);
          ref
              .read(applicationListProvider.notifier)
              .applyUpdated(result.application);
          ref.invalidate(statusHistoryProvider(applicationId));
        } catch (e) {
          statusMoveFailed = true;
          ref.read(loggerProvider).w('Could not move to Interview: $e');
        }
      }
      refreshAfterInterviewChange(ref, applicationId);
      ref.invalidate(interviewDetailProvider(saved.id));
      unawaited(Haptics.success());
      state = AsyncData(saved);
      return saved;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Sets the outcome of [interview].
  Future<Interview?> setOutcome(
    Interview interview,
    InterviewOutcome outcome,
  ) async {
    state = const AsyncLoading();
    try {
      final saved = await ref
          .read(interviewRepositoryProvider)
          .update(interview.copyWith(outcome: outcome));
      refreshAfterInterviewChange(ref, interview.applicationId);
      ref.invalidate(interviewDetailProvider(interview.id));
      unawaited(Haptics.success());
      state = AsyncData(saved);
      return saved;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

/// Provider for [InterviewController].
final interviewControllerProvider =
    AutoDisposeAsyncNotifierProvider<InterviewController, Interview?>(
      InterviewController.new,
    );

/// Deletes an interview and refreshes the caches that show it.
final deleteInterviewProvider = Provider<Future<void> Function(Interview)>((
  ref,
) {
  return (interview) async {
    await ref.read(interviewRepositoryProvider).delete(interview.id);
    refreshAfterInterviewChange(ref, interview.applicationId);
  };
});
