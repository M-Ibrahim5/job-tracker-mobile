import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/enums/enums.dart';

/// Pill showing a status with its color, icon and text label.
class StatusChip extends StatelessWidget {
  /// Creates a chip for [status].
  const StatusChip({required this.status, super.key});

  final ApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status, Theme.of(context).brightness);
    return Semantics(
      label: 'Status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: style.chipBackground,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 14, color: style.chipText),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.chipText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
