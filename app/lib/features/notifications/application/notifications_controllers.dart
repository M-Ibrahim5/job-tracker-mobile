import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/models/app_notification.dart';
import '../../../core/services/reminder_scheduler.dart';

/// Page size of the Alerts list.
const int kNotificationPageSize = 20;

/// Number of unread notifications, for the Alerts tab badge. Zero when signed
/// out; keeps the last known value if a refresh fails.
class UnreadCountController extends AsyncNotifier<int> {
  int _last = 0;

  @override
  Future<int> build() async {
    ref.watch(dataRevisionProvider);
    if (ref.watch(currentUserProvider) == null) return _last = 0;
    try {
      return _last = await ref
          .read(notificationRepositoryProvider)
          .unreadCount();
    } on Failure catch (e) {
      ref.read(loggerProvider).w('Could not load unread count: $e');
      return _last;
    }
  }

  /// Re-reads the count from the server (poll, resume, after actions).
  Future<void> refresh() async {
    if (ref.read(currentUserProvider) == null) return;
    try {
      final count = await ref
          .read(notificationRepositoryProvider)
          .unreadCount();
      state = AsyncData(_last = count);
    } on Failure catch (e) {
      ref.read(loggerProvider).w('Could not refresh unread count: $e');
    }
  }

  /// Sets the count locally after an action whose result is known.
  void setLocal(int count) => state = AsyncData(_last = count < 0 ? 0 : count);
}

/// Provider for [UnreadCountController].
final unreadCountControllerProvider =
    AsyncNotifierProvider<UnreadCountController, int>(
      UnreadCountController.new,
    );

/// Whether the OS lets the app show notifications (re-read on resume).
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(reminderSchedulerProvider).notificationsEnabled(),
);

/// One loaded slice of the Alerts list.
class NotificationsState {
  /// Creates a state.
  const NotificationsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? loadMoreError;

  /// Returns a copy with the given fields replaced.
  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Object? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return NotificationsState(
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

/// Paged Alerts list with optimistic read / delete actions.
class NotificationsNotifier extends AsyncNotifier<NotificationsState> {
  int _generation = 0;

  @override
  Future<NotificationsState> build() async {
    ref.watch(dataRevisionProvider);
    final generation = ++_generation;
    final page = await ref
        .read(notificationRepositoryProvider)
        .list(pageSize: kNotificationPageSize);
    if (generation != _generation) return const NotificationsState();
    return NotificationsState(
      items: page.items,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// Reloads from page 1 and refreshes the badge.
  Future<void> refresh() async {
    final reloaded = ref.refresh(notificationsProvider.future);
    try {
      await reloaded;
    } catch (_) {
      // Exposed through the provider state.
    }
    await ref.read(unreadCountControllerProvider.notifier).refresh();
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
          .read(notificationRepositoryProvider)
          .list(page: current.page + 1, pageSize: kNotificationPageSize);
      if (generation != _generation) return;
      final known = {for (final n in current.items) n.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...next.items.where((n) => !known.contains(n.id)),
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

  void _setItems(List<AppNotification> items) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(items: items));
  }

  int get _unread =>
      state.valueOrNull?.items.where((n) => !n.isRead).length ?? 0;

  /// Marks one notification read (optimistic; rolls back on failure).
  Future<void> markRead(AppNotification n) async {
    final current = state.valueOrNull;
    if (current == null || n.isRead) return;
    final previous = current.items;
    final badge = ref.read(unreadCountControllerProvider.notifier);
    final before = ref.read(unreadCountProvider);
    _setItems([
      for (final x in previous) x.id == n.id ? x.copyWith(isRead: true) : x,
    ]);
    badge.setLocal(before - 1);
    try {
      await ref.read(notificationRepositoryProvider).markRead(n.id);
    } catch (_) {
      _setItems(previous);
      badge.setLocal(before);
    }
  }

  /// Marks everything read. Throws on failure after rolling back.
  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null || _unread == 0) return;
    final previous = current.items;
    final badge = ref.read(unreadCountControllerProvider.notifier);
    final before = ref.read(unreadCountProvider);
    _setItems([for (final x in previous) x.copyWith(isRead: true)]);
    badge.setLocal(0);
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {
      _setItems(previous);
      badge.setLocal(before);
      rethrow;
    }
  }

  /// Deletes one notification. Throws on failure after rolling back.
  Future<void> delete(AppNotification n) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = current.items;
    final badge = ref.read(unreadCountControllerProvider.notifier);
    final before = ref.read(unreadCountProvider);
    _setItems(previous.where((x) => x.id != n.id).toList());
    if (!n.isRead) badge.setLocal(before - 1);
    try {
      await ref.read(notificationRepositoryProvider).delete(n.id);
    } catch (_) {
      // A swiped row must leave the tree in the frame it was dismissed in;
      // only then may the rollback put it back.
      await SchedulerBinding.instance.endOfFrame;
      _setItems(previous);
      badge.setLocal(before);
      rethrow;
    }
  }

  /// Deletes all notifications. Throws on failure after rolling back.
  Future<void> clearAll() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final previous = current;
    final badge = ref.read(unreadCountControllerProvider.notifier);
    final before = ref.read(unreadCountProvider);
    state = const AsyncData(NotificationsState());
    badge.setLocal(0);
    try {
      await ref.read(notificationRepositoryProvider).clear();
    } catch (_) {
      state = AsyncData(previous);
      badge.setLocal(before);
      rethrow;
    }
  }
}

/// The paged Alerts list.
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, NotificationsState>(
      NotificationsNotifier.new,
    );
