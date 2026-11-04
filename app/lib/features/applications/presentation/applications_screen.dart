import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../../../domain/models/job_application.dart';
import '../../dashboard/application/chart_logic.dart';
import '../application/application_controllers.dart';
import '../application/application_providers.dart';
import '../application/filter_labels.dart';
import 'application_card.dart';
import 'filter_sheet.dart';
import 'status_change_sheet.dart';

/// Applications list tab (`/applications`).
class ApplicationsScreen extends ConsumerStatefulWidget {
  /// Creates the screen. [query] holds the route's query parameters
  /// (`status`, `from`, `to`, …); when it carries any, they replace the
  /// current filter (CHARTS.md §3).
  const ApplicationsScreen({this.query = const {}, super.key});

  final Map<String, String> query;

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  late final PendingDeleteController _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pending = ref.read(pendingDeleteProvider.notifier);
    _scroll.addListener(_maybeLoadMore);
    _search.text = ref.read(applicationFilterProvider).query;
    _applyQuery();
  }

  @override
  void didUpdateWidget(ApplicationsScreen old) {
    super.didUpdateWidget(old);
    if (!mapEquals(old.query, widget.query)) _applyQuery();
  }

  /// Replaces (never merges) the filter with the one the URL describes.
  void _applyQuery() {
    if (!hasFilterParams(widget.query)) return;
    final filter = filterFromQuery(widget.query);
    // Providers may not be modified while the tree is building.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(applicationFilterProvider.notifier).state = filter;
    });
  }

  /// Applies [filter] and mirrors it in the URL (when it differs) so the
  /// dashboard can link to the same filter again.
  void _setFilterAndUrl(ApplicationFilter filter) {
    ref.read(applicationFilterProvider.notifier).state = filter;
    _syncUrl(applicationsUriForFilter(filter));
  }

  /// Resets every criterion and drops the query parameters from the URL.
  void _clearAll() {
    _setFilter((f) => ApplicationFilter(sort: f.sort));
    _syncUrl(Uri(path: Routes.applications));
  }

  void _syncUrl(Uri target) {
    final current = GoRouterState.of(context).uri;
    if (current.queryParameters.isEmpty && target.queryParameters.isEmpty) {
      return;
    }
    if (current.toString() != target.toString()) context.go(target.toString());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ScaffoldMessenger.of(context).clearSnackBars();
      _pending.flushAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pending.flushAll();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 400) {
      ref.read(applicationListProvider.notifier).loadMore();
    }
  }

  void _setFilter(ApplicationFilter Function(ApplicationFilter) change) {
    final notifier = ref.read(applicationFilterProvider.notifier);
    notifier.state = change(notifier.state);
  }

  Future<bool> _confirmDismiss(
    BuildContext context,
    JobApplication app,
    DismissDirection direction,
  ) async {
    if (direction == DismissDirection.startToEnd) {
      await showStatusChangeSheet(context, app);
      return false;
    }
    final upcoming = app.nextInterviewAt != null;
    return showConfirmDialog(
      context,
      title: ApplicationStrings.deleteTitle,
      message:
          ApplicationStrings.deleteMessage(app.jobTitle, app.companyName) +
          (upcoming ? ApplicationStrings.deleteUpcomingWarning : ''),
      confirmLabel: ApplicationStrings.swipeDelete,
      destructive: true,
    );
  }

  void _scheduleDelete(JobApplication app) {
    final messenger = ScaffoldMessenger.of(context);
    final pending = _pending;
    pending.schedule(app);
    showUndoSnackBar(
      context,
      ApplicationStrings.deleted,
      onUndo: () => pending.undo(app.id),
      onClosedWithoutUndo: () async {
        final error = await pending.commit(app.id);
        if (error != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(failureMessage(error))));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = ref.watch(applicationFilterProvider);
    final async = ref.watch(applicationListProvider);
    final pendingIds = ref.watch(pendingDeleteProvider);

    // Keep the search box in sync when the filter is reset elsewhere.
    ref.listen(applicationFilterProvider.select((f) => f.query), (_, query) {
      if (_search.text != query) _search.text = query;
    });

    final data = async.valueOrNull;
    final total = data == null ? null : data.total - pendingIds.length;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        // Several tabs stay alive at once; shared hero tags would clash.
        heroTag: null,
        onPressed: () => context.push(Routes.newApplication),
        icon: const Icon(Icons.add_rounded),
        label: const Text(ApplicationStrings.addFab),
      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      ApplicationStrings.listTitle,
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (total != null)
                    Text(
                      listCaption(total < 0 ? 0 : total, filter),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: Spacing.md),
                  _SearchRow(
                    controller: _search,
                    filter: filter,
                    onChanged: (v) => _setFilter((f) => f.copyWith(query: v)),
                    onOpenFilters: () =>
                        showApplicationFilterSheet(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            _StatusChipsRow(
              filter: filter,
              onSelected: (statuses) =>
                  _setFilter((f) => f.copyWith(statuses: statuses)),
            ),
            _ActiveFilterRow(
              filter: filter,
              onRemove: (kind) => _setFilterAndUrl(withoutFilter(filter, kind)),
              onClearAll: _clearAll,
            ),
            // The caption is the first thing to go when text is very large:
            // the list needs the room more.
            if (MediaQuery.textScalerOf(context).scale(1) < 1.8)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.screen,
                  Spacing.sm,
                  Spacing.screen,
                  Spacing.xs,
                ),
                child: Text(
                  ApplicationStrings.sortedBy(filter.sort.label),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (async.isLoading && async.hasValue)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildBody(context, filter, async, pendingIds)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ApplicationFilter filter,
    AsyncValue<ApplicationListState> async,
    Map<int, JobApplication> pendingIds,
  ) {
    final data = async.valueOrNull;
    if (data == null) {
      if (async.isLoading) return const SkeletonList();
      return ErrorState(
        error: async.error,
        onRetry: () => ref.invalidate(applicationListProvider),
      );
    }

    final items = [
      for (final a in data.items)
        if (!pendingIds.containsKey(a.id)) a,
    ];

    if (items.isEmpty && !data.hasMore) {
      // A single stage with nothing in it, e.g. "No Offer applications yet".
      final single =
          filter.statuses.length == 1 &&
              filter.query.trim().isEmpty &&
              filter.arrangements.isEmpty &&
              filter.appliedFrom == null &&
              filter.appliedTo == null
          ? filter.statuses.first
          : null;
      if (single != null) {
        return EmptyState(
          icon: Icons.inbox_outlined,
          title: ApplicationStrings.noStatusTitle(single.label),
          message: ApplicationStrings.noStatusMessage,
          actionLabel: ApplicationStrings.clearFilter,
          onAction: _clearAll,
        );
      }
      return filter.isActive
          ? EmptyState(
              icon: Icons.search_off_rounded,
              title: ApplicationStrings.noResultsTitle,
              message: ApplicationStrings.noResultsMessage,
              actionLabel: ApplicationStrings.clearFilters,
              onAction: _clearAll,
            )
          : EmptyState(
              icon: Icons.work_outline_rounded,
              title: ApplicationStrings.emptyTitle,
              message: ApplicationStrings.emptyMessage,
              actionLabel: ApplicationStrings.emptyAction,
              onAction: () => context.push(Routes.newApplication),
            );
    }

    // A short list may not be scrollable, so scrolling can't trigger paging.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (position.hasContentDimensions && position.maxScrollExtent == 0) {
        _maybeLoadMore();
      }
    });

    final hasFooter = data.hasMore || data.loadMoreError != null;
    return RefreshIndicator(
      onRefresh: () => ref.read(applicationListProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          Spacing.sm,
          Spacing.screen,
          // Room for the FAB.
          88,
        ),
        itemCount: items.length + (hasFooter ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
        itemBuilder: (context, index) {
          if (index >= items.length) return _ListFooter(data: data);
          final app = items[index];
          return _SwipeableCard(
            key: ValueKey('application-${app.id}'),
            application: app,
            confirmDismiss: (direction) =>
                _confirmDismiss(context, app, direction),
            onDeleted: () => _scheduleDelete(app),
            onTap: () => context.push(Routes.applicationDetail(app.id)),
          );
        },
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.filter,
    required this.onChanged,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final ApplicationFilter filter;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilters;

  int get _activeCount =>
      (filter.statuses.length > 1 ? 1 : 0) +
      (filter.arrangements.isNotEmpty ? 1 : 0) +
      (filter.appliedFrom != null || filter.appliedTo != null ? 1 : 0) +
      (filter.sort != ApplicationSort.newest ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: ApplicationStrings.searchSemantics,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: ApplicationStrings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).deleteButtonTooltip,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Semantics(
          button: true,
          label: ApplicationStrings.filterButton,
          child: SizedBox(
            width: Sizes.buttonHeight,
            height: Sizes.buttonHeight,
            child: Badge(
              isLabelVisible: _activeCount > 0,
              label: Text('$_activeCount'),
              child: IconButton.outlined(
                tooltip: ApplicationStrings.filterButton,
                style: IconButton.styleFrom(
                  side: BorderSide(color: scheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.input),
                  ),
                  fixedSize: const Size.square(Sizes.buttonHeight),
                ),
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Removable chips for the criteria that narrow the list, plus "Clear all".
class _ActiveFilterRow extends StatelessWidget {
  const _ActiveFilterRow({
    required this.filter,
    required this.onRemove,
    required this.onClearAll,
  });

  final ApplicationFilter filter;
  final ValueChanged<ActiveFilterKind> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = activeFilterChips(filter);
    if (chips.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: ApplicationStrings.activeFilters,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          Spacing.sm,
          Spacing.screen,
          0,
        ),
        child: Wrap(
          spacing: Spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final chip in chips)
              InputChip(
                key: ValueKey('filter-chip-${chip.kind.name}'),
                label: Text(chip.label),
                deleteButtonTooltipMessage: ApplicationStrings.removeFilter(
                  chip.label,
                ),
                onDeleted: () => onRemove(chip.kind),
              ),
            TextButton(
              onPressed: onClearAll,
              child: const Text(ApplicationStrings.clearAll),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChipsRow extends StatelessWidget {
  const _StatusChipsRow({required this.filter, required this.onSelected});

  final ApplicationFilter filter;
  final ValueChanged<Set<ApplicationStatus>> onSelected;

  @override
  Widget build(BuildContext context) {
    final statuses = filter.statuses;
    return SizedBox(
      // Chips grow with the text size.
      height: MediaQuery.textScalerOf(context).scale(Sizes.minTouch),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screen),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text(ApplicationStrings.filterAll),
              selected: statuses.isEmpty,
              onSelected: (_) => onSelected(const {}),
            ),
            for (final status in ApplicationStatus.values) ...[
              const SizedBox(width: Spacing.sm),
              ChoiceChip(
                label: Text(status.label),
                selected: statuses.length == 1 && statuses.contains(status),
                onSelected: (_) => onSelected({status}),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeableCard extends StatelessWidget {
  const _SwipeableCard({
    required this.application,
    required this.confirmDismiss,
    required this.onDeleted,
    required this.onTap,
    super.key,
  });

  final JobApplication application;
  final Future<bool> Function(DismissDirection) confirmDismiss;
  final VoidCallback onDeleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${application.id}'),
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDeleted(),
      background: _SwipePanel(
        color: scheme.primary,
        foreground: scheme.onPrimary,
        icon: Icons.swap_horiz_rounded,
        label: ApplicationStrings.swipeStatus,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipePanel(
        color: scheme.error,
        foreground: scheme.onError,
        icon: Icons.delete_outline_rounded,
        label: ApplicationStrings.swipeDelete,
        alignment: Alignment.centerRight,
      ),
      child: ApplicationCard(application: application, onTap: onTap),
    );
  }
}

class _SwipePanel extends StatelessWidget {
  const _SwipePanel({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListFooter extends ConsumerWidget {
  const _ListFooter({required this.data});

  final ApplicationListState data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (data.loadMoreError != null) {
      return Column(
        children: [
          const Text(ApplicationStrings.loadMoreFailed),
          TextButton(
            onPressed: () =>
                ref.read(applicationListProvider.notifier).loadMore(),
            child: const Text(AppStrings.retry),
          ),
        ],
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.lg),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
