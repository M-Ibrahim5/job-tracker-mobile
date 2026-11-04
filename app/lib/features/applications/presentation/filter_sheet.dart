import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/application_filter.dart';
import '../application/application_providers.dart';

/// Opens the filter / sort sheet and applies the result to
/// [applicationFilterProvider].
Future<void> showApplicationFilterSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final result = await showModalBottomSheet<ApplicationFilter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        ApplicationFilterSheet(initial: ref.read(applicationFilterProvider)),
  );
  if (result != null) {
    ref.read(applicationFilterProvider.notifier).state = result;
  }
}

/// Bottom sheet editing status, arrangement, date range and sort order. The
/// search text is carried through unchanged.
class ApplicationFilterSheet extends StatefulWidget {
  /// Creates the sheet starting from [initial].
  const ApplicationFilterSheet({required this.initial, super.key});

  final ApplicationFilter initial;

  @override
  State<ApplicationFilterSheet> createState() => _ApplicationFilterSheetState();
}

class _ApplicationFilterSheetState extends State<ApplicationFilterSheet> {
  late ApplicationFilter _draft = widget.initial;

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final current = from ? _draft.appliedFrom : _draft.appliedTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _draft = from
          ? _draft.copyWith(appliedFrom: picked)
          : _draft.copyWith(appliedTo: picked);
    });
  }

  void _reset() =>
      setState(() => _draft = ApplicationFilter(query: widget.initial.query));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
            ApplicationStrings.filterTitle,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.lg),
          const Eyebrow(ApplicationStrings.filterStatus),
          const SizedBox(height: Spacing.sm),
          ChoiceChips<ApplicationStatus>(
            multiSelect: true,
            values: ApplicationStatus.values,
            selected: _draft.statuses,
            labelOf: (s) => s.label,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(statuses: v)),
          ),
          const SizedBox(height: Spacing.section),
          const Eyebrow(ApplicationStrings.filterArrangement),
          const SizedBox(height: Spacing.sm),
          ChoiceChips<WorkArrangement>(
            multiSelect: true,
            values: WorkArrangement.values,
            selected: _draft.arrangements,
            labelOf: (a) => a.label,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(arrangements: v)),
          ),
          const SizedBox(height: Spacing.section),
          const Eyebrow(ApplicationStrings.filterDates),
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Expanded(
                child: _DateButton(
                  label: ApplicationStrings.filterFrom,
                  date: _draft.appliedFrom,
                  onTap: () => _pickDate(from: true),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _DateButton(
                  label: ApplicationStrings.filterTo,
                  date: _draft.appliedTo,
                  onTap: () => _pickDate(from: false),
                ),
              ),
            ],
          ),
          if (_draft.appliedFrom != null || _draft.appliedTo != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => _draft = _draft.copyWith(clearDates: true)),
                child: const Text(ApplicationStrings.filterClearDates),
              ),
            ),
          const SizedBox(height: Spacing.section),
          const Eyebrow(ApplicationStrings.filterSort),
          RadioGroup<ApplicationSort>(
            groupValue: _draft.sort,
            onChanged: (v) {
              if (v != null) setState(() => _draft = _draft.copyWith(sort: v));
            },
            child: Column(
              children: [
                for (final sort in ApplicationSort.values)
                  RadioListTile<ApplicationSort>(
                    value: sort,
                    contentPadding: EdgeInsets.zero,
                    title: Text(sort.label),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: ApplicationStrings.filterReset,
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: PrimaryButton(
                  label: ApplicationStrings.filterApply,
                  onPressed: () => Navigator.of(context).pop(_draft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = date == null
        ? ApplicationStrings.filterAnyDate
        : DateHelpers.formatDate(date!);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.event_rounded, size: 18),
      label: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
