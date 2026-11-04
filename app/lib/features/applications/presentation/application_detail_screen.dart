import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/models/job_application.dart';
import '../application/application_controllers.dart';
import '../application/application_providers.dart';
import 'detail_sections.dart';
import 'status_change_sheet.dart';

/// Application detail (`/applications/:id`).
class ApplicationDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for application [id]. With [focusInterviewId] the
  /// page scrolls to that interview and highlights it briefly.
  const ApplicationDetailScreen({
    required this.id,
    this.focusInterviewId,
    super.key,
  });

  final int id;
  final int? focusInterviewId;

  @override
  ConsumerState<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState
    extends ConsumerState<ApplicationDetailScreen> {
  bool _deleting = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUri(Uri? uri, String failureText) async {
    var ok = false;
    if (uri != null) {
      try {
        ok = await ref.read(urlLauncherProvider)(uri);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) _snack(failureText);
  }

  Future<void> _confirmDelete(JobApplication app) async {
    final upcoming = app.nextInterviewAt != null;
    final confirmed = await showConfirmDialog(
      context,
      title: ApplicationStrings.deleteTitle,
      message:
          ApplicationStrings.deleteMessage(app.jobTitle, app.companyName) +
          (upcoming ? ApplicationStrings.deleteUpcomingWarning : ''),
      confirmLabel: ApplicationStrings.detailDelete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(deleteApplicationProvider)(app);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(failureMessage(e));
      return;
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.applications);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(ApplicationStrings.deleted)));
  }

  Future<void> _followUp(JobApplication app) async {
    final current = app.followUpAt;
    if (current != null) {
      final choice = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text(ApplicationStrings.followUpChange),
                subtitle: Text(DateHelpers.formatDate(current)),
                onTap: () => Navigator.of(context).pop(true),
              ),
              ListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: const Text(ApplicationStrings.followUpClear),
                onTap: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;
      if (!choice) {
        await _saveFollowUp(app, null);
        return;
      }
    }
    if (!mounted) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: DateHelpers.dayOnly(now),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (picked == null || !mounted) return;
    await _saveFollowUp(
      app,
      DateTime(picked.year, picked.month, picked.day, 9),
    );
  }

  Future<void> _saveFollowUp(JobApplication app, DateTime? date) async {
    final saved = await ref
        .read(applicationFormControllerProvider.notifier)
        .setFollowUp(app, date);
    if (!mounted) return;
    if (saved == null) {
      _snack(
        failureMessage(
          ref.read(applicationFormControllerProvider).error ??
              ApplicationStrings.updateFailed,
        ),
      );
      return;
    }
    _snack(
      date == null
          ? ApplicationStrings.followUpCleared
          : ApplicationStrings.followUpSaved,
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(applicationDetailProvider(widget.id));
    // Keeps the auto-dispose form controller alive while follow-ups save.
    final saving = ref.watch(applicationFormControllerProvider).isLoading;
    final app = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.screenApplicationDetail),
        actions: [
          IconButton(
            tooltip: ApplicationStrings.detailEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: app == null || _deleting
                ? null
                : () => context.push(Routes.editApplication(widget.id)),
          ),
          IconButton(
            tooltip: ApplicationStrings.detailDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: app == null || _deleting
                  ? null
                  : Theme.of(context).colorScheme.error,
            ),
            onPressed: app == null || _deleting
                ? null
                : () => _confirmDelete(app),
          ),
        ],
      ),
      body: SafeArea(
        child: app != null
            ? _Body(
                application: app,
                focusInterviewId: widget.focusInterviewId,
                busy: saving || _deleting,
                onOpenLink: _openLink,
                onOpenMail: (email) => _openUri(
                  Uri(scheme: 'mailto', path: email),
                  ApplicationStrings.mailOpenFailed,
                ),
                onFollowUp: () => _followUp(app),
              )
            : async.isLoading
            ? const _DetailSkeleton()
            : ErrorState(
                error: async.error,
                onRetry: () =>
                    ref.invalidate(applicationDetailProvider(widget.id)),
              ),
      ),
    );
  }

  void _openLink(JobApplication app) {
    final link = app.applicationLink?.trim();
    if (link == null || link.isEmpty) {
      _snack(ApplicationStrings.noLinkSaved);
      return;
    }
    _openUri(Uri.tryParse(link), ApplicationStrings.linkOpenFailed);
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.application,
    required this.focusInterviewId,
    required this.busy,
    required this.onOpenLink,
    required this.onOpenMail,
    required this.onFollowUp,
  });

  final JobApplication application;
  final int? focusInterviewId;
  final bool busy;
  final void Function(JobApplication) onOpenLink;
  final ValueChanged<String> onOpenMail;
  final VoidCallback onFollowUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = application;
    final history = ref.watch(statusHistoryProvider(a.id));
    final description = a.jobDescription?.trim() ?? '';
    final notes = a.notes?.trim() ?? '';
    final email = a.contactEmail?.trim() ?? '';
    final contactName = a.contactName?.trim() ?? '';

    const gap = SizedBox(height: Spacing.section);
    return ListView(
      // A focused interview may be far down; build everything so it can be
      // scrolled to.
      scrollCacheExtent: focusInterviewId == null
          ? null
          : const ScrollCacheExtent.pixels(6000),
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.sm,
        Spacing.screen,
        Spacing.xl,
      ),
      children: [
        DetailHeader(application: a),
        const SizedBox(height: Spacing.lg),
        QuickActions(
          busy: busy,
          followUpSet: a.followUpAt != null,
          onOpenLink: () => onOpenLink(a),
          onAddInterview: () => context.push(Routes.newInterviewFor(a.id)),
          onFollowUp: onFollowUp,
        ),
        gap,
        const SectionTitle(ApplicationStrings.sectionStatus),
        const SizedBox(height: Spacing.md),
        StatusSelector(
          current: a.status,
          onSelected: (status) =>
              showStatusChangeSheet(context, a, initial: status),
        ),
        gap,
        const SectionTitle(ApplicationStrings.sectionTimeline),
        const SizedBox(height: Spacing.md),
        history.when(
          loading: () => const SkeletonBox(height: 96, radius: Radii.card),
          error: (e, _) => ErrorBox(
            error: e,
            onRetry: () => ref.invalidate(statusHistoryProvider(a.id)),
          ),
          data: (entries) => StatusTimeline(history: entries, source: a.source),
        ),
        gap,
        InterviewsSection(
          applicationId: a.id,
          focusInterviewId: focusInterviewId,
          onAdd: () => context.push(Routes.newInterviewFor(a.id)),
          onOpen: (i) => context.push(Routes.interviewDetail(i.id)),
        ),
        if (description.isNotEmpty) ...[
          gap,
          const SectionTitle(ApplicationStrings.sectionDescription),
          const SizedBox(height: Spacing.md),
          SectionCard(child: ExpandableText(text: description)),
        ],
        gap,
        const SectionTitle(ApplicationStrings.sectionDetails),
        const SizedBox(height: Spacing.md),
        SectionCard(
          child: Column(
            children: [
              DetailRow(
                label: ApplicationStrings.detailAppliedOn,
                value: DateHelpers.formatDate(a.appliedDate),
              ),
              DetailRow(
                label: ApplicationStrings.detailSource,
                value: a.source?.label ?? ApplicationStrings.notSet,
              ),
              DetailRow(
                label: ApplicationStrings.detailContact,
                value: contactName.isEmpty && email.isEmpty
                    ? ApplicationStrings.notSet
                    : contactName.isEmpty
                    ? email
                    : email.isEmpty
                    ? contactName
                    : '$contactName · $email',
                onTap: email.isEmpty ? null : () => onOpenMail(email),
              ),
              DetailRow(
                label: ApplicationStrings.detailFollowUp,
                value: a.followUpAt == null
                    ? ApplicationStrings.notSet
                    : DateHelpers.formatDate(a.followUpAt!),
              ),
            ],
          ),
        ),
        if (notes.isNotEmpty) ...[
          gap,
          const SectionTitle(ApplicationStrings.sectionNotes),
          const SizedBox(height: Spacing.md),
          SectionCard(
            child: Text(notes, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(Spacing.screen),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 90, height: 24, radius: 12),
          SizedBox(height: Spacing.md),
          SkeletonBox(height: 32),
          SizedBox(height: Spacing.sm),
          SkeletonBox(width: 160, height: 18),
          SizedBox(height: Spacing.xl),
          SkeletonBox(height: 72, radius: Radii.input),
          SizedBox(height: Spacing.xl),
          SkeletonBox(height: 120, radius: Radii.card),
        ],
      ),
    );
  }
}
