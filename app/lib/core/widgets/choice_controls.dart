import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/haptics.dart';

/// Outlined segmented control for 2–3 mutually exclusive options. The selected
/// segment gets the tonal fill, a check icon and bold text.
class SegmentedChoice<T> extends StatelessWidget {
  /// Creates a control.
  const SegmentedChoice({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        // The check icon is dropped when text is large: the segments need the
        // room, and the tonal fill + bold label still mark the selection.
        showSelectedIcon: MediaQuery.textScalerOf(context).scale(1) <= 1.3,
        segments: [
          for (final v in values)
            ButtonSegment<T>(
              value: v,
              icon: iconOf?.call(v) == null ? null : Icon(iconOf!(v)),
              label: Text(
                labelOf(v),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (s) {
          Haptics.selection();
          onChanged(s.first);
        },
      ),
    );
  }
}

/// Wrapping row of choice chips; [multiSelect] toggles membership, otherwise
/// exactly one value is selected (tapping it again keeps it selected).
class ChoiceChips<T> extends StatelessWidget {
  /// Creates the chips.
  const ChoiceChips({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.multiSelect = false,
    super.key,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelect;

  void _toggle(T value) {
    Haptics.selection();
    if (!multiSelect) {
      onChanged({value});
      return;
    }
    final next = {...selected};
    if (!next.add(value)) next.remove(value);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: selected.contains(v),
            showCheckmark: true,
            onSelected: (_) => _toggle(v),
          ),
      ],
    );
  }
}
