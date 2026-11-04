import 'package:flutter/material.dart';

import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/widgets.dart';

/// Asks for the account password before fingerprint login is turned on.
/// Resolves to the entered password, or null when cancelled.
Future<String?> showBiometricPasswordDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _BiometricPasswordDialog(),
  );
}

class _BiometricPasswordDialog extends StatefulWidget {
  const _BiometricPasswordDialog();

  @override
  State<_BiometricPasswordDialog> createState() =>
      _BiometricPasswordDialogState();
}

class _BiometricPasswordDialogState extends State<_BiometricPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AccountStrings.biometricPasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AccountStrings.biometricPasswordBody),
          const SizedBox(height: Spacing.lg),
          AppTextField(
            label: AccountStrings.password,
            controller: _controller,
            isPassword: true,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        TextButton(
          onPressed: _controller.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_controller.text),
          child: const Text(AccountStrings.biometricPasswordAction),
        ),
      ],
    );
  }
}
