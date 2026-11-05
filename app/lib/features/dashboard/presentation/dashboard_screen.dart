import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/dashboard_strings.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../interviews/presentation/interview_tile.dart';
import '../application/chart_logic.dart';
import '../application/dashboard_providers.dart';
import '../application/dashboard_view_model.dart';
import 'chart_sheets.dart';
import 'dashboard_charts.dart';
import 'dashboard_widgets.dart';

/// Opens the pipeline pop-up for [status], then whatever was chosen in it:
/// an application (pushed, so Back returns here) or the filtered list.
Future<void> openStatusSheet(
  BuildContext context,
  ApplicationStatus status,
) async {
  final action = await showStatusApplicationsSheet(context, status);
  if (!context.mounted) return;
  _follow(context, action, applicationsUriForStatus(status));
}

/// Opens the weekly pop-up for the week starting [monday].
Future<void> openWeekSheet(
  BuildContext context,
  DateTime monday, {
  required bool isCurrent,
}) async {
  final action = await showWeekApplicationsSheet(
    context,
    monday: monday,
    isCurrent: isCurrent,
  );
  if (!context.mounted) return;
  _follow(context, action, applicationsUriForWeek(monday));
}

void _follow(BuildContext context, DrillAction? action, Uri fullList) {
  switch (action) {
    case OpenApplicationAction(:final id):
      context.push(Routes.applicationDetail(id));
    case OpenFullListAction():
      context.go(fullList.toString());
    case null:
      break;
  }
}

/// Home tab (`/`).
class DashboardScreen extends ConsumerWidget {
  /// Creates the screen.
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(dashboardClockProvider)();
    final firstName = firstNameOf(ref.watch(currentUserProvider)?.fullName);
    final async = ref.watch(dashboardProvider);
    final data = async.valueOrNull;

    final body = data != null
        ? _Content(
            vm: DashboardViewModel.from(data, now: now, firstName: firstName),
          )
        : async.isLoading
        ? const _Skeleton()
        : Padding(
            padding: const EdgeInsets.only(top: 80),
            child: ErrorState(
              error: async.error,
              onRetry: () => ref.invalidate(dashboardProvider),
            ),
          );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            final reloaded = ref.refresh(dashboardProvider.future);
            try {
              await reloaded;
            } catch (_) {
              // Shown through the provider state.
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              Spacing.lg,
              Spacing.screen,
              Spacing.xl,
            ),
            children: [
              _Header(
                dateLine: dateLineFor(now),
                greeting: greetingFor(now, firstName),
                onAdd: () => context.push(Routes.newApplication),
                theme: theme,
              ),
              const SizedBox(height: Spacing.lg),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.dateLine,
    required this.greeting,
    required this.onAdd,
    required this.theme,
  });

  final String dateLine;
  final String greeting;
  final VoidCallback onAdd;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLine,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Semantics(
                header: true,
                child: Text(greeting, style: theme.textTheme.headlineSmall),
              ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.md),
        Semantics(
          button: true,
          label: DashboardStrings.addApplication,
          child: IconButton.filled(
            tooltip: DashboardStrings.addApplication,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.input),
              ),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppStrings.loading,
      child: const Column(
        children: [
          SkeletonBox(height: 130, radius: Radii.summary),
          SizedBox(height: Spacing.section),
          SkeletonBox(height: 90, radius: Radii.input),
          SizedBox(height: Spacing.section),
          PipelineSkeleton(),
          SizedBox(height: Spacing.section),
          WeeklySkeleton(),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isEmpty) {
      return DashboardEmpty(onAdd: () => context.push(Routes.newApplication));
    }
    const gap = SizedBox(height: Spacing.section);
    const small = SizedBox(height: Spacing.md);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryCard(vm: vm),
        gap,
        const DashSectionTitle(DashboardStrings.sectionByStatus),
        small,
        StatusTiles(
          tiles: vm.tiles,
          onTap: (t) =>
              context.go(applicationsUriForStatus(t.status).toString()),
        ),
        gap,
        const DashSectionTitle(DashboardStrings.sectionPipeline),
        small,
        PipelineCard(
          vm: vm,
          onAdd: () => context.push(Routes.newApplication),
          onOpenStatus: (s) => openStatusSheet(context, s),
        ),
        gap,
        WeeklyBarsCard(
          vm: vm,
          onAdd: () => context.push(Routes.newApplication),
          onOpenWeek: (monday) => openWeekSheet(
            context,
            monday,
            isCurrent: vm.bars.any((b) => b.isCurrent && b.weekStart == monday),
          ),
        ),
        gap,
        DashSectionTitle(
          DashboardStrings.sectionUpcoming,
          trailing: TextButton(
            onPressed: () => context.push(Routes.interviews),
            child: const Text(DashboardStrings.seeAll),
          ),
        ),
        small,
        if (vm.upcoming.isEmpty)
          Text(
            DashboardStrings.noUpcoming,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final i in vm.upcoming) ...[
            InterviewTile(
              interview: i,
              onTap: () => context.push(Routes.interviewDetail(i.id)),
            ),
            const SizedBox(height: Spacing.sm),
          ],
        gap,
        const DashSectionTitle(DashboardStrings.sectionActivity),
        small,
        if (vm.activity.isEmpty)
          Text(
            DashboardStrings.noActivity,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final a in vm.activity)
            ActivityRow(
              vm: a,
              onTap: () =>
                  context.push(Routes.applicationDetail(a.applicationId)),
            ),
      ],
    );
  }
}
