import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/account_strings.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/snackbar.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/fake/fake_backend.dart';
import '../application/biometric_controller.dart';
import '../application/login_controller.dart';
import 'auth_widgets.dart';
import 'forgot_password_dialog.dart';

/// Email + password sign-in (`DESIGN.md §4.1`). With the fake backend the demo
/// account is pre-filled.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final bool _demo = ref.read(useFakeBackendProvider);
  late final _email = TextEditingController(text: _demo ? kFakeEmail : '');
  late final _password = TextEditingController(
    text: _demo ? kFakePassword : '',
  );

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  Future<void> _biometricSignIn() async {
    FocusScope.of(context).unfocus();
    try {
      await ref.read(biometricActionsProvider).signIn();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        e is UnauthorizedFailure
            ? AccountStrings.biometricExpired
            : failureMessage(e),
      );
    }
  }

  Future<void> _forgot() {
    return showDialog<void>(
      context: context,
      builder: (_) => ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginControllerProvider, (_, next) {
      if (next.error is NetworkFailure) {
        showAppSnackBar(context, failureMessage(next.error!));
      }
    });
    final state = ref.watch(loginControllerProvider);
    final error = state.error;
    final banner = error != null && error is! NetworkFailure
        ? failureMessage(error)
        : null;
    final theme = Theme.of(context);
    final canUseBiometric =
        ref.watch(biometricStatusProvider).valueOrNull?.canSignIn ?? false;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.screen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthLogo(),
                    const SizedBox(height: Spacing.xl),
                    Text(
                      AccountStrings.loginTitle,
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      AccountStrings.loginSubtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),
                    AppTextField(
                      label: AccountStrings.email,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: Validators.requiredEmail,
                    ),
                    const SizedBox(height: Spacing.lg),
                    AppTextField(
                      label: AccountStrings.password,
                      controller: _password,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (v) => (v ?? '').isEmpty
                          ? AccountStrings.errPasswordRequired
                          : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgot,
                        child: const Text(AccountStrings.forgotPassword),
                      ),
                    ),
                    if (banner != null) ...[
                      const SizedBox(height: Spacing.sm),
                      NoticeBanner(
                        message: banner,
                        icon: Icons.error_outline_rounded,
                      ),
                    ],
                    const SizedBox(height: Spacing.lg),
                    PrimaryButton(
                      label: AccountStrings.signIn,
                      loading: state.isLoading,
                      onPressed: _submit,
                    ),
                    if (canUseBiometric) ...[
                      const SizedBox(height: Spacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: Sizes.minTouch,
                        child: OutlinedButton.icon(
                          onPressed: state.isLoading ? null : _biometricSignIn,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: const Text(AccountStrings.biometricSignIn),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.lg),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(AccountStrings.newToApp),
                          TextButton(
                            onPressed: () => context.go(Routes.register),
                            child: const Text(AccountStrings.createAccountLink),
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
