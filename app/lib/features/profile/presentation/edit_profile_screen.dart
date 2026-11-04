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
import '../../../domain/models/user.dart';
import '../application/profile_controller.dart';
import 'user_avatar.dart';

/// Edit profile (`DESIGN.md §4.11`).
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final User _initial = ref.read(currentUserProvider)!;
  late final _name = TextEditingController(text: _initial.fullName);
  late final _phone = TextEditingController(text: _initial.phone ?? '');
  late final _role = TextEditingController(text: _initial.currentRole ?? '');
  late final _lookingFor = TextEditingController(
    text: _initial.lookingFor ?? '',
  );
  late final _location = TextEditingController(text: _initial.location ?? '');
  bool _allowPop = false;

  /// Photo picked in this session. Only previewed until Save is pressed;
  /// Cancel/back drops it and the saved photo stays untouched.
  String? _pendingAvatar;
  Map<String, String> _server = {};

  List<TextEditingController> get _controllers => [
    _name,
    _phone,
    _role,
    _lookingFor,
    _location,
  ];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String? _changed(TextEditingController c, String? original) {
    final value = c.text.trim();
    return value == (original ?? '') ? null : value;
  }

  bool get _dirty =>
      _pendingAvatar != null ||
      _changed(_name, _initial.fullName) != null ||
      _changed(_phone, _initial.phone) != null ||
      _changed(_role, _initial.currentRole) != null ||
      _changed(_lookingFor, _initial.lookingFor) != null ||
      _changed(_location, _initial.location) != null;

  Future<void> _close() async {
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    context.canPop() ? context.pop() : context.go(Routes.settings);
  }

  Future<void> _confirmClose() async {
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: AccountStrings.discardTitle,
        message: AccountStrings.discardBody,
        confirmLabel: AccountStrings.discard,
        cancelLabel: AccountStrings.keepEditing,
        destructive: true,
      );
      if (!discard || !mounted) return;
    }
    await _close();
  }

  Future<void> _save() async {
    _server = {};
    if (!_formKey.currentState!.validate()) return;
    if (!_dirty) {
      await _close();
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(profileControllerProvider.notifier)
        .save(
          avatarPath: _pendingAvatar,
          fullName: _changed(_name, _initial.fullName),
          phone: _changed(_phone, _initial.phone),
          currentRole: _changed(_role, _initial.currentRole),
          lookingFor: _changed(_lookingFor, _initial.lookingFor),
          location: _changed(_location, _initial.location),
        );
    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    if (state.hasError) {
      final e = state.error!;
      if (e is ApiFailure && e.fields.isNotEmpty) {
        _server = e.fields;
        _formKey.currentState?.validate();
      } else {
        showAppSnackBar(context, failureMessage(e));
      }
      return;
    }
    showAppSnackBar(context, AccountStrings.profileSaved);
    await _close();
  }

  Future<void> _changePhoto() async {
    final path = await ref.read(avatarPickerProvider).pick();
    if (path == null || !mounted) return;
    setState(() => _pendingAvatar = path);
  }

  Future<void> _deleteAccount() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordPromptDialog(),
    );
    if (password == null || !mounted) return;
    await ref.read(profileControllerProvider.notifier).deleteAccount(password);
    if (!mounted) return;
    final state = ref.read(profileControllerProvider);
    if (state.hasError) {
      showAppSnackBar(context, failureMessage(state.error!));
    }
    // On success the user is signed out and the router redirects to /login.
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider) ?? _initial;
    final state = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: AccountStrings.semBack,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _confirmClose,
          ),
          title: const Text(AccountStrings.editProfile),
          actions: [
            TextButton(
              onPressed: state.isLoading ? null : _save,
              child: const Text(AppStrings.save),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.screen),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  UserAvatar(
                                    user: user,
                                    size: 96,
                                    previewPath: _pendingAvatar,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Material(
                                      color: theme.colorScheme.primary,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        tooltip: AccountStrings.semChangePhoto,
                                        icon: Icon(
                                          Icons.photo_camera_rounded,
                                          color: theme.colorScheme.onPrimary,
                                        ),
                                        onPressed: _changePhoto,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _changePhoto,
                                child: const Text(AccountStrings.changePhoto),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: AccountStrings.fullName,
                          controller: _name,
                          isRequired: true,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              _server['fullName'] ?? Validators.requiredText(v),
                        ),
                        const SizedBox(height: Spacing.lg),
                        _EmailField(user: user),
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: AccountStrings.phone,
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          validator: (_) => _server['phone'],
                        ),
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: AccountStrings.currentRole,
                          controller: _role,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              _server['currentRole'] ??
                              Validators.optionalText(v, max: Limits.shortText),
                        ),
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: AccountStrings.lookingFor,
                          controller: _lookingFor,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              _server['lookingFor'] ??
                              Validators.optionalText(v, max: Limits.shortText),
                        ),
                        const SizedBox(height: Spacing.lg),
                        AppTextField(
                          label: AccountStrings.location,
                          controller: _location,
                          textInputAction: TextInputAction.done,
                          validator: (v) =>
                              _server['location'] ??
                              Validators.optionalText(v, max: Limits.shortText),
                        ),
                        const SizedBox(height: Spacing.xl),
                        Center(
                          child: TextButton(
                            onPressed: _deleteAccount,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.error,
                            ),
                            child: const Text(AccountStrings.deleteAccount),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FormFooter(
                onCancel: _confirmClose,
                onSave: _save,
                saving: state.isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppTextField(
      label: AccountStrings.email,
      initialValue: user.email,
      readOnly: true,
      helperText: AccountStrings.emailReadOnlyHint,
      suffix: user.emailVerified
          ? Padding(
              padding: const EdgeInsets.only(right: Spacing.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: Color(0xFF43A047),
                  ),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    AccountStrings.verified,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

class _PasswordPromptDialog extends StatefulWidget {
  const _PasswordPromptDialog();

  @override
  State<_PasswordPromptDialog> createState() => _PasswordPromptDialogState();
}

class _PasswordPromptDialogState extends State<_PasswordPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text(AccountStrings.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AccountStrings.deleteAccountBody),
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
          style: TextButton.styleFrom(foregroundColor: error),
          child: const Text(AccountStrings.deleteAccount),
        ),
      ],
    );
  }
}
