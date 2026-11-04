import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class _ButtonChild extends StatelessWidget {
  const _ButtonChild({
    required this.label,
    required this.loading,
    required this.color,
    this.icon,
  });

  final String label;
  final bool loading;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Semantics(
        label: AppStrings.loading,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// Filled primary button (52–56 high, radius 16) with a loading state.
class PrimaryButton extends StatelessWidget {
  /// Creates the button. A null [onPressed] or [loading] disables it.
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: _ButtonChild(
        label: label,
        loading: loading,
        icon: icon,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }
}

/// Outlined secondary button with a loading state.
class SecondaryButton extends StatelessWidget {
  /// Creates the button. A null [onPressed] or [loading] disables it.
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      child: _ButtonChild(
        label: label,
        loading: loading,
        icon: icon,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Outlined button in the error color (2px) for destructive actions.
class DestructiveButton extends StatelessWidget {
  /// Creates the button. A null [onPressed] or [loading] disables it.
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: error, width: 2),
      ),
      child: _ButtonChild(
        label: label,
        loading: loading,
        icon: icon,
        color: error,
      ),
    );
  }
}
