import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/account_actions.dart';

/// Opens the change-password bottom sheet.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ChangePasswordSheet(),
  );
}

/// Current / new / confirm password form (`DESIGN.md §4.10`).
class ChangePasswordSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ChangePasswordSheet({super.key});

  @override
  ConsumerState<ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;

  @override
  void initState() {
    super.initState();
    _new.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _currentError = null;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: _current.text, newPassword: _new.text);
    if (!mounted) return;
    final state = ref.read(changePasswordControllerProvider);
    if (state.hasError) {
      final e = state.error;
      if (e is ApiFailure && e.code == ApiCodes.invalidCredentials) {
        _currentError = AccountStrings.errCurrentPasswordWrong;
        _formKey.currentState?.validate();
      } else {
        showAppSnackBar(context, failureMessage(e!));
      }
      return;
    }
    navigator.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AccountStrings.passwordChanged)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.screen,
          0,
          Spacing.screen,
          Spacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AccountStrings.changePassword,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.lg),
              AppTextField(
                label: AccountStrings.currentPassword,
                controller: _current,
                isPassword: true,
                isRequired: true,
                validator: (v) => _currentError ?? Validators.requiredText(v),
              ),
              const SizedBox(height: Spacing.lg),
              AppTextField(
                label: AccountStrings.newPassword,
                controller: _new,
                isPassword: true,
                isRequired: true,
                helperText: AccountStrings.passwordHint,
                validator: Validators.newPassword,
              ),
              const SizedBox(height: Spacing.sm),
              PasswordStrengthMeter(password: _new.text),
              const SizedBox(height: Spacing.lg),
              AppTextField(
                label: AccountStrings.confirmNewPassword,
                controller: _confirm,
                isPassword: true,
                isRequired: true,
                validator: (v) => Validators.matches(v, _new.text),
              ),
              const SizedBox(height: Spacing.xl),
              PrimaryButton(
                label: AccountStrings.changePassword,
                loading: state.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
