import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import 'app_buttons.dart';

/// Pinned bottom bar with Cancel (outlined) and Save (filled).
class FormFooter extends StatelessWidget {
  /// Creates the footer.
  const FormFooter({
    required this.onCancel,
    required this.onSave,
    this.saving = false,
    this.cancelLabel = AppStrings.cancel,
    this.saveLabel = AppStrings.save,
    super.key,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  /// Shows a spinner on Save and disables both buttons.
  final bool saving;
  final String cancelLabel;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.screen,
            Spacing.md,
            Spacing.screen,
            Spacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: cancelLabel,
                  onPressed: saving ? null : onCancel,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: PrimaryButton(
                  label: saveLabel,
                  onPressed: onSave,
                  loading: saving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
