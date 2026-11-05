import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/job_application.dart';
import '../application/application_controllers.dart';
import '../application/status_flow.dart';
import 'status_celebration_dialog.dart';

/// Opens the status sheet for [application]; resolves to true when the status
/// was changed. [initial] pre-selects an option (detail screen selector).
Future<bool> showStatusChangeSheet(
  BuildContext context,
  JobApplication application, {
  ApplicationStatus? initial,
}) async {
  final changed = await showModalBottomSheet<ApplicationStatus>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        StatusChangeSheet(application: application, initial: initial),
  );
  if (changed == null) return false;
  if (context.mounted && hasStatusMessage(changed)) {
    await showStatusCelebration(
      context,
      status: changed,
      company: application.companyName,
    );
  }
  return true;
}

/// Bottom sheet to pick a new status and add an optional note.
class StatusChangeSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const StatusChangeSheet({required this.application, this.initial, super.key});

  final JobApplication application;
  final ApplicationStatus? initial;

  @override
  ConsumerState<StatusChangeSheet> createState() => _StatusChangeSheetState();
}

class _StatusChangeSheetState extends ConsumerState<StatusChangeSheet> {
  final _note = TextEditingController();
  ApplicationStatus? _selected;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null && initial != widget.application.status) {
      _selected = initial;
    }
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _error = null);
    final result = await ref
        .read(statusChangeControllerProvider.notifier)
        .change(widget.application.id, selected, note: _note.text);
    if (!mounted) return;
    if (result == null) {
      setState(() => _error = ref.read(statusChangeControllerProvider).error);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ApplicationStrings.statusChanged(selected.label)),
        ),
      );
    navigator.pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saving = ref.watch(statusChangeControllerProvider).isLoading;
    final current = widget.application.status;
    final canConfirm =
        !saving &&
        canConfirmStatusChange(
          current: current,
          selected: _selected,
          note: _note.text,
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          0,
          Spacing.screen,
          Spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ApplicationStrings.statusSheetTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '${widget.application.jobTitle} · ${widget.application.companyName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            for (final option in ApplicationStatus.values) ...[
              _StatusOption(
                status: option,
                kind: statusOptionKind(option, current),
                selected: _selected == option,
                onTap: saving ? null : () => setState(() => _selected = option),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            const SizedBox(height: Spacing.sm),
            AppTextField(
              label: ApplicationStrings.statusNoteLabel,
              controller: _note,
              hint: ApplicationStrings.statusNoteHint,
              minLines: 2,
              maxLines: 4,
              maxLength: Limits.note,
              showCounter: true,
              enabled: !saving,
              validator: (v) => statusNoteError(v ?? ''),
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.md),
              NoticeBanner(
                message: failureMessage(_error!),
                icon: Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: Spacing.lg),
            PrimaryButton(
              label: ApplicationStrings.statusConfirm,
              loading: saving,
              onPressed: canConfirm ? _confirm : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ApplicationStatus status;
  final StatusOptionKind kind;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StatusStyle.of(status, theme.brightness);
    final isCurrent = kind == StatusOptionKind.current;
    final kindLabel = statusKindLabel(kind);

    final content = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: selected || isCurrent
            ? style.chipBackground
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Radii.input),
        border: kind == StatusOptionKind.next && !selected
            ? null
            : Border.all(
                color: selected
                    ? style.color
                    : isCurrent
                    ? Colors.transparent
                    : theme.colorScheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.chipText),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              status.label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: isCurrent || selected ? style.chipText : null,
              ),
            ),
          ),
          if (kindLabel != null)
            Text(
              kindLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isCurrent
                    ? style.chipText
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (selected) ...[
            const SizedBox(width: Spacing.sm),
            Icon(Icons.check_circle_rounded, color: style.chipText),
          ],
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      enabled: !isCurrent && onTap != null,
      label: [status.label, ?kindLabel].join(', '),
      excludeSemantics: true,
      child: Opacity(
        opacity: isCurrent ? 0.85 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.input),
          onTap: isCurrent ? null : onTap,
          child: kind == StatusOptionKind.next && !selected
              ? DashedBorder(
                  color: style.color,
                  radius: Radii.input,
                  child: content,
                )
              : content,
        ),
      ),
    );
  }
}
