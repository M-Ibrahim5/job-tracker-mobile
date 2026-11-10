import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../../../domain/models/job_application.dart';
import '../../../domain/models/status_history_entry.dart';
import '../../settings/application/settings_controller.dart';

/// Page size of the application list (`DESIGN.md §4.4`).
const int kApplicationPageSize = 20;

/// Search / filter / sort criteria currently applied to the list.
final applicationFilterProvider = StateProvider<ApplicationFilter>((ref) {
  ref.watch(currentUserIdProvider);
  return const ApplicationFilter();
});

/// How long the list waits after the search text changes before querying.
final searchDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 300),
);

/// Counter bumped after every successful create / update / delete / status
/// change. Screens that show aggregates (dashboard, calendar) watch it to
/// reload; the application list patches itself instead.
final applicationsRevisionProvider = StateProvider<int>((ref) => 0);

/// Opens a [Uri] in an external app; returns false when it can't. Replace in
/// tests.
final urlLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Default follow-up days from settings (null = Off) once settings load.
final followUpDefaultDaysProvider = Provider<AsyncValue<int?>>(
  (ref) => ref.watch(settingsProvider).whenData((s) => s.defaultFollowUpDays),
);

/// One loaded slice of the list plus paging state.
class ApplicationListState {
  /// Creates a list state.
  const ApplicationListState({
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<JobApplication> items;

  /// Total matches on the server for the current filter.
  final int total;

  /// Last page loaded (1-based; 0 before the first load).
  final int page;
  final bool hasMore;
  final bool loadingMore;

  /// Set when fetching the next page failed; the loaded items stay usable.
  final Object? loadMoreError;

  /// Returns a copy with the given fields replaced.
  ApplicationListState copyWith({
    List<JobApplication>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return ApplicationListState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : (loadMoreError ?? this.loadMoreError),
    );
  }
}

/// Paged application list. Rebuilds (back to page 1) when the filter changes;
/// a changed search text waits for [searchDebounceProvider] first.
class ApplicationListNotifier extends AsyncNotifier<ApplicationListState> {
  String? _lastQuery;
  int _generation = 0;

  @override
  Future<ApplicationListState> build() async {
    ref.watch(currentUserIdProvider);
    ref.watch(dataRevisionProvider);
    final filter = ref.watch(applicationFilterProvider);
    final generation = ++_generation;

    final queryChanged = _lastQuery != null && _lastQuery != filter.query;
    _lastQuery = filter.query;
    if (queryChanged) {
      await Future<void>.delayed(ref.read(searchDebounceProvider));
      // A newer keystroke rebuilt the provider meanwhile; this result is
      // discarded by Riverpod, so skip the request.
      if (generation != _generation) return const ApplicationListState();
    }

    final page = await ref
        .read(jobApplicationRepositoryProvider)
        .list(filter, pageSize: kApplicationPageSize);
    return ApplicationListState(
      items: page.items,
      total: page.total,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Reloads from page 1, keeping the old list visible meanwhile.
  Future<void> refresh() async {
    final reloaded = ref.refresh(applicationListProvider.future);
    try {
      await reloaded;
    } catch (_) {
      // The error is exposed through the provider state.
    }
  }

  /// Appends the next page; no-op while loading or when everything is loaded.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null ||
        state.isLoading ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    final generation = _generation;
    final filter = ref.read(applicationFilterProvider);
    state = AsyncData(
      current.copyWith(loadingMore: true, clearLoadMoreError: true),
    );
    try {
      final next = await ref
          .read(jobApplicationRepositoryProvider)
          .list(filter, page: current.page + 1, pageSize: kApplicationPageSize);
      if (generation != _generation) return;
      final known = {for (final a in current.items) a.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...next.items.where((a) => !known.contains(a.id)),
          ],
          total: next.total,
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

  /// Replaces [updated] in place; drops it when the status filter no longer
  /// matches its new status.
  void applyUpdated(JobApplication updated) {
    final current = state.valueOrNull;
    if (current == null || !current.items.any((a) => a.id == updated.id)) {
      return;
    }
    final statuses = ref.read(applicationFilterProvider).statuses;
    final stays = statuses.isEmpty || statuses.contains(updated.status);
    state = AsyncData(
      current.copyWith(
        items: [
          for (final a in current.items)
            if (a.id != updated.id) a else if (stays) updated,
        ],
        total: stays ? current.total : current.total - 1,
      ),
    );
  }

  /// Removes the application with [id] after it was deleted on the server.
  void removeById(int id) {
    final current = state.valueOrNull;
    if (current == null || !current.items.any((a) => a.id == id)) return;
    state = AsyncData(
      current.copyWith(
        items: current.items.where((a) => a.id != id).toList(),
        total: current.total - 1,
      ),
    );
  }
}

/// The paged, filtered application list.
final applicationListProvider =
    AsyncNotifierProvider<ApplicationListNotifier, ApplicationListState>(
      ApplicationListNotifier.new,
    );

/// A single application with its job description.
final applicationDetailProvider = FutureProvider.autoDispose
    .family<JobApplication, int>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(jobApplicationRepositoryProvider).getById(id);
    });

/// Status history of one application, oldest first.
final statusHistoryProvider = FutureProvider.autoDispose
    .family<List<StatusHistoryEntry>, int>((ref, id) {
      ref.watch(dataRevisionProvider);
      return ref.watch(jobApplicationRepositoryProvider).history(id);
    });

/// Maps a `status` query parameter to a status, or null when unknown.
ApplicationStatus? statusFromQuery(String? value) {
  if (value == null) return null;
  for (final s in ApplicationStatus.values) {
    if (s.name == value) return s;
  }
  return null;
}
