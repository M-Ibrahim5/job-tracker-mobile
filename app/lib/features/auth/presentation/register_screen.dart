import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../application/register_controller.dart';

/// Account creation (`DESIGN.md §4.2`).
class RegisterScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _agreed = false;

  /// Field errors from the last server response, keyed by JSON field name.
  Map<String, String> _server = {};

  @override
  void initState() {
    super.initState();
    // Rebuild the strength meter as the user types.
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _server = {};
    if (!_agreed || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(registerControllerProvider.notifier)
        .submit(
          fullName: _name.text,
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(registerControllerProvider, (_, next) {
      final e = next.error;
      if (e == null) return;
      if (e is ApiFailure &&
          (e.fields.isNotEmpty || e.code == ApiCodes.emailTaken)) {
        _server = {
          ...e.fields,
          if (e.code == ApiCodes.emailTaken) 'email': failureMessage(e),
        };
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _formKey.currentState?.validate(),
        );
      } else {
        showAppSnackBar(context, failureMessage(e));
      }
    });
    final state = ref.watch(registerControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: AccountStrings.back,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.screen,
              0,
              Spacing.screen,
              Spacing.screen,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AccountStrings.registerTitle,
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: Spacing.xl),
                    AppTextField(
                      label: AccountStrings.fullName,
                      controller: _name,
                      isRequired: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (v) =>
                          _server['fullName'] ?? Validators.requiredText(v),
                    ),
                    const SizedBox(height: Spacing.lg),
                    AppTextField(
                      label: AccountStrings.email,
                      controller: _email,
                      isRequired: true,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: (v) =>
                          _server['email'] ?? Validators.requiredEmail(v),
                    ),
                    const SizedBox(height: Spacing.lg),
                    AppTextField(
                      label: AccountStrings.password,
                      controller: _password,
                      isRequired: true,
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      helperText: AccountStrings.passwordHint,
                      validator: (v) =>
                          _server['password'] ?? Validators.newPassword(v),
                    ),
                    const SizedBox(height: Spacing.sm),
                    PasswordStrengthMeter(password: _password.text),
                    const SizedBox(height: Spacing.lg),
                    AppTextField(
                      label: AccountStrings.confirmPassword,
                      controller: _confirm,
                      isRequired: true,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) => Validators.matches(v, _password.text),
                    ),
                    const SizedBox(height: Spacing.md),
                    CheckboxListTile(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(AccountStrings.terms),
                    ),
                    const SizedBox(height: Spacing.md),
                    PrimaryButton(
                      label: AccountStrings.createAccount,
                      loading: state.isLoading,
                      onPressed: _agreed ? _submit : null,
                    ),
                    const SizedBox(height: Spacing.lg),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(AccountStrings.haveAccount),
                          TextButton(
                            onPressed: () => context.go(Routes.login),
                            child: const Text(AccountStrings.signIn),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
