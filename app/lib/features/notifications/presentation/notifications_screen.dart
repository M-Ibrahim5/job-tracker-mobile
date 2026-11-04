import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/deep_links.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/constants/alerts_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/app_notification.dart';
import '../application/group_notifications.dart';
import '../application/notifications_controllers.dart';
import 'notification_permission.dart';

/// Alerts center (`/notifications`).
class NotificationsScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [now] is injectable for tests.
  const NotificationsScreen({this.now, super.key});

  final DateTime Function()? now;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        ref.read(notificationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _snack(failureMessage(e));
    }
  }

  Future<void> _clearAll() async {
    final ok = await showConfirmDialog(
      context,
      title: AlertsStrings.clearTitle,
      message: AlertsStrings.clearMessage,
      confirmLabel: AlertsStrings.clearAll,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(ref.read(notificationsProvider.notifier).clearAll);
  }

  void _open(AppNotification n) {
    _run(() => ref.read(notificationsProvider.notifier).markRead(n));
    final link = deepLinkForNotification(n);
    if (link != null) context.push(link);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);
    final enabled = ref.watch(notificationsEnabledProvider).valueOrNull ?? true;
    final data = async.valueOrNull;
    final hasItems = data != null && data.items.isNotEmpty;
    final hasUnread = data != null && data.items.any((n) => !n.isRead);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.screen,
                Spacing.lg,
                Spacing.screen,
                0,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      AlertsStrings.title,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: hasUnread
                            ? () => _run(
                                ref
                                    .read(notificationsProvider.notifier)
                                    .markAllRead,
                              )
                            : null,
                        child: const Text(AlertsStrings.markAllRead),
                      ),
                      TextButton(
                        onPressed: hasItems ? _clearAll : null,
                        child: const Text(AlertsStrings.clearAll),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.screen,
                  Spacing.sm,
                  Spacing.screen,
                  Spacing.sm,
                ),
                child: NoticeBanner(
                  message: AlertsStrings.bannerMessage,
                  icon: Icons.notifications_off_outlined,
                  actionLabel: AlertsStrings.bannerAction,
                  onAction: () => enableNotifications(context, ref),
                ),
              ),
            Expanded(child: _body(context, async)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AsyncValue<NotificationsState> async) {
    final data = async.valueOrNull;
    if (data == null) {
      if (async.isLoading) return const SkeletonList(itemHeight: 76);
      return ErrorState(
        error: async.error,
        onRetry: () => ref.invalidate(notificationsProvider),
      );
    }
    if (data.items.isEmpty && !data.hasMore) {
      return RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: c.maxHeight,
              child: const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: AlertsStrings.emptyTitle,
                message: AlertsStrings.emptyMessage,
              ),
            ),
          ),
        ),
      );
    }

    final groups = groupNotifications(
      data.items,
      (widget.now ?? DateTime.now)(),
    );
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          Spacing.sm,
          Spacing.screen,
          Spacing.xl,
        ),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: Spacing.md,
                bottom: Spacing.sm,
              ),
              child: Eyebrow(group.kind.label),
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _Row(
                      key: ValueKey('notification-${group.items[i].id}'),
                      notification: group.items[i],
                      now: (widget.now ?? DateTime.now)(),
                      onTap: () => _open(group.items[i]),
                      onDelete: () => _run(
                        () => ref
                            .read(notificationsProvider.notifier)
                            .delete(group.items[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (data.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.md),
              child: Column(
                children: [
                  const Text(AlertsStrings.loadMoreFailed),
                  TextButton(
                    onPressed: () =>
                        ref.read(notificationsProvider.notifier).loadMore(),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              ),
            )
          else if (data.hasMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Spacing.lg),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon, tile color and icon color for a notification type.
({IconData icon, Color background, Color foreground}) notificationStyle(
  AppNotification n,
  ThemeData theme,
) {
  final b = theme.brightness;
  switch (n.type) {
    case NotificationType.interviewReminder:
      final s = StatusStyle.of(ApplicationStatus.interview, b);
      return (
        icon: Icons.event_rounded,
        background: s.chipBackground,
        foreground: s.chipText,
      );
    case NotificationType.followUpReminder:
      return (
        icon: Icons.schedule_rounded,
        background: b == Brightness.dark
            ? StatusStyle.followUpColor.withValues(alpha: 0.24)
            : StatusStyle.followUpContainer,
        foreground: b == Brightness.dark
            ? StatusStyle.followUpColor
            : StatusStyle.followUpText,
      );
    case NotificationType.statusChange:
      final status = ApplicationStatus.values
          .where((s) => n.title.endsWith(s.label))
          .firstOrNull;
      if (status != null) {
        final s = StatusStyle.of(status, b);
        return (
          icon: s.icon,
          background: s.chipBackground,
          foreground: s.chipText,
        );
      }
      return (
        icon: Icons.swap_horiz_rounded,
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
      );
    case NotificationType.system:
      return (
        icon: Icons.info_outline_rounded,
        background: theme.colorScheme.primaryContainer,
        foreground: theme.colorScheme.onPrimaryContainer,
      );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.notification,
    required this.now,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final AppNotification notification;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _time() {
    final created = notification.createdAt.toLocal();
    return notificationGroupOf(created, now) == NotificationGroupKind.earlier
        ? DateFormat.MMMd().add_jm().format(created)
        : DateFormat.jm().format(created);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;
    final style = notificationStyle(n, theme);
    final unread = !n.isRead;
    return Dismissible(
      key: ValueKey('dismiss-${n.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onError,
        ),
      ),
      child: Semantics(
        label: unread ? AlertsStrings.semanticsUnread(n.title) : null,
        child: Material(
          color: unread
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
              : theme.colorScheme.surface,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: style.background,
                        borderRadius: BorderRadius.circular(Radii.chip),
                      ),
                      child: Icon(
                        style.icon,
                        color: style.foreground,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            n.body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_time()} · ${n.type.label}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: Spacing.sm),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          key: const ValueKey('unread-dot'),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
