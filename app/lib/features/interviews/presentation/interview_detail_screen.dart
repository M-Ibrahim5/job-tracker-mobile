import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/interview_strings.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/interview.dart';
import '../../applications/application/application_providers.dart';
import '../application/interview_controllers.dart';
import '../application/interview_flow.dart';
import '../application/interviews_providers.dart';
import 'interview_tile.dart';

/// Interview detail (`/interviews/:id`).
class InterviewDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for interview [id].
  const InterviewDetailScreen({required this.id, super.key});

  final int id;

  @override
  ConsumerState<InterviewDetailScreen> createState() =>
      _InterviewDetailScreenState();
}

class _InterviewDetailScreenState extends ConsumerState<InterviewDetailScreen> {
  bool _deleting = false;

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.tryParse(link);
    var ok = false;
    if (uri != null) {
      try {
        ok = await ref.read(urlLauncherProvider)(uri);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && mounted) _snack(InterviewStrings.linkOpenFailed);
  }

  Future<void> _setOutcome(Interview i, InterviewOutcome outcome) async {
    if (outcome == i.outcome) return;
    final saved = await ref
        .read(interviewControllerProvider.notifier)
        .setOutcome(i, outcome);
    if (!mounted) return;
    _snack(
      saved == null
          ? failureMessage(ref.read(interviewControllerProvider).error!)
          : InterviewStrings.outcomeSaved,
    );
  }

  Future<void> _delete(Interview i) async {
    final ok = await showConfirmDialog(
      context,
      title: InterviewStrings.deleteTitle,
      message: InterviewStrings.deleteMessage(i.title),
      confirmLabel: InterviewStrings.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _deleting = true);
    try {
      await ref.read(deleteInterviewProvider)(i);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      _snack(failureMessage(e));
      return;
    }
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.interviews);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(InterviewStrings.deleted)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(interviewDetailProvider(widget.id));
    // Keeps the auto-dispose controller alive while an outcome saves.
    final saving = ref.watch(interviewControllerProvider).isLoading;
    final interview = async.valueOrNull;
    final scheme = Theme.of(context).colorScheme;
    final busy = interview == null || _deleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text(InterviewStrings.detailTitle),
        actions: [
          IconButton(
            tooltip: InterviewStrings.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: busy
                ? null
                : () => context.push(Routes.editInterview(widget.id)),
          ),
          IconButton(
            tooltip: InterviewStrings.delete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: busy ? null : scheme.error,
            ),
            onPressed: busy ? null : () => _delete(interview),
          ),
        ],
      ),
      body: SafeArea(
        child: interview != null
            ? _Body(
                interview: interview,
                saving: saving,
                onOutcome: (o) => _setOutcome(interview, o),
                onOpenLink: _openLink,
              )
            : async.isLoading
            ? const Padding(
                padding: EdgeInsets.all(Spacing.screen),
                child: SkeletonBox(height: 200, radius: Radii.card),
              )
            : ErrorState(
                error: async.error,
                onRetry: () =>
                    ref.invalidate(interviewDetailProvider(widget.id)),
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.interview,
    required this.saving,
    required this.onOutcome,
    required this.onOpenLink,
  });

  final Interview interview;
  final bool saving;
  final ValueChanged<InterviewOutcome> onOutcome;
  final ValueChanged<String> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i = interview;
    final end = i.scheduledAt.add(Duration(minutes: i.durationMinutes));
    final when =
        '${DateFormat.yMMMEd().format(i.scheduledAt)} · '
        '${DateFormat.jm().format(i.scheduledAt)} – ${DateFormat.jm().format(end)}';
    final location = i.locationOrLink?.trim() ?? '';
    final isLink =
        location.startsWith('http://') || location.startsWith('https://');
    final interviewer = i.interviewerName?.trim() ?? '';
    final notes = i.notes?.trim() ?? '';
    final offsets = [...i.reminderOffsets]..sort((a, b) => b.compareTo(a));

    final lines = <Widget>[
      DetailLine(
        label: InterviewStrings.application,
        value: [?i.companyName, ?i.applicationTitle].join(' · '),
        onTap: () => context.push(Routes.applicationDetail(i.applicationId)),
      ),
      DetailLine(label: InterviewStrings.when, value: when),
      DetailLine(label: InterviewStrings.type, value: i.type.label),
      DetailLine(
        label: InterviewStrings.duration,
        value: InterviewStrings.minutes(i.durationMinutes),
      ),
      if (location.isNotEmpty)
        DetailLine(label: InterviewStrings.location, value: location),
      if (interviewer.isNotEmpty)
        DetailLine(label: InterviewStrings.interviewer, value: interviewer),
      DetailLine(
        label: InterviewStrings.reminders,
        value: offsets.isEmpty
            ? InterviewStrings.noReminders
            : offsets.map(reminderOffsetLabel).join(', '),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.screen,
        Spacing.sm,
        Spacing.screen,
        Spacing.xl,
      ),
      children: [
        Row(
          children: [
            DateBlock(date: i.scheduledAt),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  OutcomePill(outcome: i.outcome),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        if (isLink)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => onOpenLink(location),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text(InterviewStrings.openLink),
            ),
          ),
        if (isLink) const SizedBox(height: Spacing.lg),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                for (var n = 0; n < lines.length; n++) ...[
                  if (n > 0) const Divider(height: 1),
                  lines[n],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.section),
        Semantics(
          header: true,
          child: Text(
            InterviewStrings.outcome,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: Spacing.md),
        IgnorePointer(
          ignoring: saving,
          child: ChoiceChips<InterviewOutcome>(
            values: InterviewOutcome.values,
            selected: {i.outcome},
            labelOf: (o) => o.label,
            onChanged: (v) => onOutcome(v.first),
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          Semantics(
            header: true,
            child: Text(
              InterviewStrings.prepNotes,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Text(notes, style: theme.textTheme.bodyMedium),
            ),
          ),
        ],
      ],
    );
  }
}

/// Label / value row; a non-null [onTap] makes the value a link. Labels share
/// one fixed-width column and values start at the same x, so rows line up.
class DetailLine extends StatelessWidget {
  /// Creates a row.
  const DetailLine({
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  /// Width of the label column.
  static const labelWidth = 104.0;

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      value,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: onTap == null ? null : theme.colorScheme.primary,
        decoration: onTap == null ? null : TextDecoration.underline,
      ),
    );
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(child: text),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Sizes.minTouch),
      child: onTap == null ? row : InkWell(onTap: onTap, child: row),
    );
  }
}
