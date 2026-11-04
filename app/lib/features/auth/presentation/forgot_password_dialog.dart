import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';

/// Asks for an email and requests a reset link. The confirmation text is the
/// same whether or not the account exists.
class ForgotPasswordDialog extends ConsumerStatefulWidget {
  /// Creates the dialog; [initialEmail] pre-fills the field.
  const ForgotPasswordDialog({this.initialEmail = '', super.key});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = failureMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(AccountStrings.forgotTitle),
      content: _sent
          ? const Text(AccountStrings.forgotSent)
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AccountStrings.forgotBody),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: AccountStrings.email,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.requiredEmail,
                    onFieldSubmitted: (_) => _send(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Spacing.md),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_sent ? AppStrings.ok : AppStrings.cancel),
        ),
        if (!_sent)
          TextButton(
            onPressed: _busy ? null : _send,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AccountStrings.forgotSend),
          ),
      ],
    );
  }
}
