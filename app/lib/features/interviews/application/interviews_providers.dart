import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../../../domain/models/interview.dart';
import '../../../domain/models/job_application.dart';

/// Page size of the interviews lists.
const int kInterviewPageSize = 20;

/// Bumped after every successful interview create / update / delete so the
/// reminders are re-planned and dependent screens reload.
final interviewsRevisionProvider = StateProvider<int>((ref) => 0);

/// Interviews of one application, earliest first (detail screen section).
final interviewsForApplicationProvider = FutureProvider.autoDispose
    .family<List<Interview>, int>((ref, applicationId) async {
      ref.watch(dataRevisionProvider);
      ref.watch(interviewsRevisionProvider);
      final page = await ref
          .watch(interviewRepositoryProvider)
          .list(applicationId: applicationId, pageSize: 100);
      return [...page.items]
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    });

/// A single interview.
final interviewDetailProvider = FutureProvider.autoDispose
    .family<Interview, int>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(interviewRepositoryProvider).getById(id);
    });

/// Applications the user can attach an interview to (company A–Z).
final applicationOptionsProvider =
    FutureProvider.autoDispose<List<JobApplication>>((ref) async {
      ref.watch(dataRevisionProvider);
      final page = await ref
          .watch(jobApplicationRepositoryProvider)
          .list(
            const ApplicationFilter(sort: ApplicationSort.companyAZ),
            pageSize: 100,
          );
      return page.items;
    });

/// One loaded slice of an interviews tab.
class InterviewListState {
  /// Creates a state.
  const InterviewListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Interview> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;

  /// Returns a copy with the given fields replaced.
  InterviewListState copyWith({
    List<Interview>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return InterviewListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Paged upcoming / past interviews.
class InterviewListNotifier
    extends FamilyAsyncNotifier<InterviewListState, InterviewScope> {
  int _generation = 0;

  @override
  Future<InterviewListState> build(InterviewScope arg) async {
    ref.watch(currentUserIdProvider);
    ref.watch(dataRevisionProvider);
    ref.watch(interviewsRevisionProvider);
    final generation = ++_generation;
    final page = await ref
        .read(interviewRepositoryProvider)
        .list(scope: arg, pageSize: kInterviewPageSize);
    if (generation != _generation) return const InterviewListState();
    return InterviewListState(
      items: page.items,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Reloads from page 1.
  Future<void> refresh() async {
    final reloaded = ref.refresh(interviewListProvider(arg).future);
    try {
      await reloaded;
    } catch (_) {
      // Exposed through the provider state.
    }
  }

  /// Appends the next page.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        state.isLoading ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, clearLoadMoreError: true),
    );
    try {
      final next = await ref
          .read(interviewRepositoryProvider)
          .list(
            scope: arg,
            page: current.page + 1,
            pageSize: kInterviewPageSize,
          );
      if (generation != _generation) return;
      final known = {for (final i in current.items) i.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...next.items.where((i) => !known.contains(i.id)),
          ],
          page: next.page,
          hasMore: next.hasMore,
          loadingMore: false,
          clearLoadMoreError: true,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreError: e));
    }
  }
}

/// Upcoming / past interview lists, one per [InterviewScope].
final interviewListProvider =
    AsyncNotifierProvider.family<
      InterviewListNotifier,
      InterviewListState,
      InterviewScope
    >(InterviewListNotifier.new);
