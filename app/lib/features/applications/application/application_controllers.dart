import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/reminder_scheduler.dart';
import '../../../core/utils/haptics.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_extras.dart';
import '../../../domain/models/job_application.dart';
import 'application_providers.dart';
import 'status_flow.dart';

void _bumpRevision(Ref ref) =>
    ref.read(applicationsRevisionProvider.notifier).state++;

/// Rebuilds local reminders; failures are logged, never surfaced.
Future<void> _resyncReminders(Ref ref) async {
  try {
    await ref.read(reminderSchedulerProvider).resync();
  } catch (e) {
    ref.read(loggerProvider).w('Reminder resync failed: $e');
  }
}

/// Creates and updates applications and refreshes the caches that show them.
///
/// `state` is `AsyncLoading` while saving and `AsyncError` with the
/// repository's `Failure` when it fails, so forms can map server field errors.
class ApplicationFormController
    extends AutoDisposeAsyncNotifier<JobApplication?> {
  @override
  JobApplication? build() => null;

  /// Saves [draft] (create, or update when [isEdit]). Returns the saved
  /// application, or null when the request failed.
  Future<JobApplication?> save(
    JobApplication draft, {
    required bool isEdit,
  }) async {
    state = const AsyncLoading();
    final repo = ref.read(jobApplicationRepositoryProvider);
    try {
      final saved = isEdit
          ? await repo.update(draft)
          : await repo.create(draft);
      final list = ref.read(applicationListProvider.notifier);
      if (isEdit) {
        list.applyUpdated(saved);
        ref.invalidate(applicationDetailProvider(saved.id));
      } else {
        ref.invalidate(applicationListProvider);
      }
      _bumpRevision(ref);
      unawaited(_resyncReminders(ref));
      unawaited(Haptics.success());
      state = AsyncData(saved);
      return saved;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Sets or clears (null) the follow-up date of [application].
  Future<JobApplication?> setFollowUp(
    JobApplication application,
    DateTime? followUpAt,
  ) {
    return save(
      followUpAt == null
          ? application.copyWith(clearFollowUpAt: true)
          : application.copyWith(followUpAt: followUpAt),
      isEdit: true,
    );
  }
}

/// Provider for [ApplicationFormController].
final applicationFormControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      ApplicationFormController,
      JobApplication?
    >(ApplicationFormController.new);

/// Changes an application's status and refreshes list, detail and history.
class StatusChangeController extends AutoDisposeAsyncNotifier<void> {
  @override
  void build() {}

  /// Moves application [id] to [status] with an optional [note]. Returns the
  /// server result, or null when it failed (see `state`).
  Future<StatusChangeResult?> change(
    int id,
    ApplicationStatus status, {
    String? note,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(jobApplicationRepositoryProvider)
          .changeStatus(id, status, note: normalizedNote(note ?? ''));
      ref
          .read(applicationListProvider.notifier)
          .applyUpdated(result.application);
      ref.invalidate(applicationDetailProvider(id));
      ref.invalidate(statusHistoryProvider(id));
      _bumpRevision(ref);
      unawaited(Haptics.success());
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

/// Provider for [StatusChangeController].
final statusChangeControllerProvider =
    AutoDisposeAsyncNotifierProvider<StatusChangeController, void>(
      StatusChangeController.new,
    );

/// Deletions waiting for their Undo window to close.
///
/// The row is only hidden while pending; the real `DELETE` is sent by
/// [commit] once the snackbar closes without Undo (or by [flushAll] when the
/// screen goes away).
class PendingDeleteController extends Notifier<Map<int, JobApplication>> {
  final Set<int> _inFlight = {};

  @override
  Map<int, JobApplication> build() => const {};

  /// Hides [application] until it is committed or undone.
  void schedule(JobApplication application) {
    state = {...state, application.id: application};
  }

  /// Brings a pending application back.
  void undo(int id) {
    if (!state.containsKey(id)) return;
    state = {...state}..remove(id);
  }

  /// Sends the `DELETE` for a pending application. Returns the failure when it
  /// could not be deleted (the row reappears), otherwise null.
  Future<Object?> commit(int id) async {
    if (!state.containsKey(id) || !_inFlight.add(id)) return null;
    try {
      await ref.read(jobApplicationRepositoryProvider).delete(id);
      ref.read(applicationListProvider.notifier).removeById(id);
      ref.invalidate(applicationDetailProvider(id));
      _bumpRevision(ref);
      unawaited(_resyncReminders(ref));
      return null;
    } catch (e) {
      return e;
    } finally {
      _inFlight.remove(id);
      undo(id);
    }
  }

  /// Commits every pending deletion (screen disposed, app paused).
  Future<void> flushAll() async {
    await Future.wait(state.keys.toList().map(commit));
  }
}

/// Provider for [PendingDeleteController].
final pendingDeleteProvider =
    NotifierProvider<PendingDeleteController, Map<int, JobApplication>>(
      PendingDeleteController.new,
    );

/// Deletes an application immediately (detail screen, no Undo window) and
/// refreshes the caches that show it.
final deleteApplicationProvider =
    Provider<Future<void> Function(JobApplication)>((ref) {
      return (application) async {
        await ref.read(jobApplicationRepositoryProvider).delete(application.id);
        ref.read(applicationListProvider.notifier).removeById(application.id);
        _bumpRevision(ref);
        unawaited(_resyncReminders(ref));
      };
    });
