import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../errors/failures.dart';
import '../utils/failure_message.dart';
import 'app_buttons.dart';

/// Centered icon + title + message + optional action, used for empty and
/// error states.
class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.iconColor,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: iconColor),
            ),
            const SizedBox(height: Spacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Spacing.xl),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: PrimaryButton(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Nothing here" view with an optional call to action.
class EmptyState extends StatelessWidget {
  /// Creates an empty state.
  const EmptyState({
    this.icon = Icons.inbox_rounded,
    this.title = AppStrings.emptyDefaultTitle,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StateView(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.primary,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Error view with a Retry button. Pass the caught [error] to show a friendly
/// message from [failureMessage], or an explicit [message].
class ErrorState extends StatelessWidget {
  /// Creates an error state.
  const ErrorState({
    this.error,
    this.message,
    this.title = AppStrings.errorDefaultTitle,
    this.onRetry,
    super.key,
  });

  final Object? error;
  final String? message;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is NetworkFailure;
    return _StateView(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message ?? (error == null ? null : failureMessage(error!)),
      actionLabel: onRetry == null ? null : AppStrings.retry,
      onAction: onRetry,
    );
  }
}
