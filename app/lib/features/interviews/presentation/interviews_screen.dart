import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/interview_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../application/interviews_providers.dart';
import 'interview_tile.dart';

/// Upcoming / past interviews (`/interviews`).
class InterviewsScreen extends StatelessWidget {
  /// Creates the screen.
  const InterviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(InterviewStrings.listTitle),
          bottom: const TabBar(
            tabs: [
              Tab(text: InterviewStrings.tabUpcoming),
              Tab(text: InterviewStrings.tabPast),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          // Several tabs stay alive at once; shared hero tags would clash.
          heroTag: null,
          onPressed: () => context.push(Routes.newInterview),
          icon: const Icon(Icons.add_rounded),
          label: const Text(InterviewStrings.fab),
        ),
        body: const TabBarView(
          children: [
            _InterviewsTab(scope: InterviewScope.upcoming),
            _InterviewsTab(scope: InterviewScope.past),
          ],
        ),
      ),
    );
  }
}

class _InterviewsTab extends ConsumerStatefulWidget {
  const _InterviewsTab({required this.scope});

  final InterviewScope scope;

  @override
  ConsumerState<_InterviewsTab> createState() => _InterviewsTabState();
}

class _InterviewsTabState extends ConsumerState<_InterviewsTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 400) {
        ref.read(interviewListProvider(widget.scope).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = interviewListProvider(widget.scope);
    final async = ref.watch(provider);
    final data = async.valueOrNull;
    final upcoming = widget.scope == InterviewScope.upcoming;

    if (data == null) {
      if (async.isLoading) return const SkeletonList(itemHeight: 76);
      return ErrorState(
        error: async.error,
        onRetry: () => ref.invalidate(provider),
      );
    }
    if (data.items.isEmpty && !data.hasMore) {
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: upcoming
            ? InterviewStrings.emptyUpcomingTitle
            : InterviewStrings.emptyPastTitle,
        message: upcoming
            ? InterviewStrings.emptyUpcomingMessage
            : InterviewStrings.emptyPastMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(provider.notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          Spacing.lg,
          Spacing.screen,
          88,
        ),
        itemCount:
            data.items.length +
            (data.hasMore || data.loadMoreError != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: Spacing.md),
        itemBuilder: (context, index) {
          if (index >= data.items.length) {
            if (data.loadMoreError != null) {
              return Column(
                children: [
                  const Text(InterviewStrings.loadMoreFailed),
                  TextButton(
                    onPressed: () => ref.read(provider.notifier).loadMore(),
                    child: const Text(AppStrings.retry),
                  ),
                ],
              );
            }
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }
          final interview = data.items[index];
          return InterviewTile(
            interview: interview,
            onTap: () => context.push(Routes.interviewDetail(interview.id)),
          );
        },
      ),
    );
  }
}
