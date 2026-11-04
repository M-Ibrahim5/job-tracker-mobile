import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/job_application.dart';
import '../application/application_controllers.dart';
import '../application/application_providers.dart';

/// Add / edit application form (`/applications/new`, `/applications/:id/edit`).
class ApplicationFormScreen extends ConsumerWidget {
  /// Creates the screen; a null [id] means a new application, which starts
  /// with [initialAppliedDate] (default today) as its applied date.
  const ApplicationFormScreen({this.id, this.initialAppliedDate, super.key});

  final int? id;
  final DateTime? initialAppliedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = this.id;
    if (id == null) {
      return ApplicationForm(initialAppliedDate: initialAppliedDate);
    }

    final async = ref.watch(applicationDetailProvider(id));
    final app = async.valueOrNull;
    if (app != null) {
      return ApplicationForm(key: ValueKey(app.id), initial: app);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(ApplicationStrings.editTitle)),
      body: async.isLoading
          ? const Padding(
              padding: EdgeInsets.all(Spacing.screen),
              child: SkeletonBox(height: 240, radius: Radii.card),
            )
          : ErrorState(
              error: async.error,
              onRetry: () => ref.invalidate(applicationDetailProvider(id)),
            ),
    );
  }
}

/// The form itself; [initial] is the application being edited, if any.
class ApplicationForm extends ConsumerStatefulWidget {
  /// Creates the form.
  const ApplicationForm({this.initial, this.initialAppliedDate, super.key});

  final JobApplication? initial;

  /// Applied date of a new application; today when null or in the future.
  final DateTime? initialAppliedDate;

  @override
  ConsumerState<ApplicationForm> createState() => _ApplicationFormState();
}

class _ApplicationFormState extends ConsumerState<ApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  final _salary = TextEditingController();
  final _link = TextEditingController();
  final _description = TextEditingController();
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _notes = TextEditingController();
  final _appliedText = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _title,
    _company,
    _location,
    _salary,
    _link,
    _description,
    _contactName,
    _contactEmail,
    _notes,
  ];

  WorkArrangement _arrangement = WorkArrangement.onsite;
  EmploymentType? _employment;
  late DateTime _appliedDate;
  ApplicationSource? _source;
  DateTime? _followUpAt;
  bool _followUpTouched = false;

  late List<Object?> _baseline;
  Map<String, String> _serverErrors = {};
  bool _allowPop = false;
  bool _started = false;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    final today = DateHelpers.dayOnly(DateTime.now());
    final requested = widget.initialAppliedDate;
    _appliedDate = DateHelpers.dayOnly(
      a?.appliedDate ??
          (requested != null && !DateHelpers.dayOnly(requested).isAfter(today)
              ? requested
              : today),
    );
    if (a != null) {
      _title.text = a.jobTitle;
      _company.text = a.companyName;
      _location.text = a.location;
      _salary.text = a.salaryRange ?? '';
      _link.text = a.applicationLink ?? '';
      _description.text = a.jobDescription ?? '';
      _contactName.text = a.contactName ?? '';
      _contactEmail.text = a.contactEmail ?? '';
      _notes.text = a.notes ?? '';
      _arrangement = a.workArrangement;
      _employment = a.employmentType;
      _source = a.source;
      _followUpAt = a.followUpAt;
    }
    _appliedText.text = DateHelpers.formatDate(_appliedDate);
    _baseline = _snapshot();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
    // New applications start with the default follow-up from settings.
    ref.listenManual(followUpDefaultDaysProvider, (_, next) {
      final days = next.valueOrNull;
      if (_isEdit || _followUpTouched || days == null || !mounted) return;
      void apply() {
        _followUpAt = _defaultFollowUp(days);
        _baseline = _snapshot();
      }

      // The immediate call runs inside initState, where setState is illegal.
      _started ? setState(apply) : apply();
    }, fireImmediately: true);
    _started = true;
  }

  @override
  void dispose() {
    for (final c in [..._controllers, _appliedText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  DateTime _defaultFollowUp(int days) {
    final today = DateHelpers.dayOnly(DateTime.now());
    final day = today.add(Duration(days: days));
    return DateTime(day.year, day.month, day.day, 9);
  }

  List<Object?> _snapshot() => [
    for (final c in _controllers) c.text.trim(),
    _arrangement,
    _employment,
    _appliedDate,
    _source,
    _followUpAt,
  ];

  bool get _dirty => !listEquals(_snapshot(), _baseline);

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  String? _optional(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickAppliedDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _appliedDate.isAfter(now) ? now : _appliedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateHelpers.dayOnly(now).add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      _appliedDate = picked;
      _appliedText.text = DateHelpers.formatDate(picked);
    });
    _clearServerError('appliedDate');
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final current = _followUpAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && current.isAfter(now) ? current : now,
      firstDate: DateHelpers.dayOnly(now),
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _followUpTouched = true;
      _followUpAt = DateTime(picked.year, picked.month, picked.day, 9);
    });
  }

  JobApplication _buildDraft() {
    final initial = widget.initial;
    final now = DateTime.now();
    return JobApplication(
      id: initial?.id ?? 0,
      jobTitle: _title.text.trim(),
      companyName: _company.text.trim(),
      location: _location.text.trim(),
      workArrangement: _arrangement,
      jobDescription: _optional(_description),
      applicationLink: _optional(_link),
      employmentType: _employment,
      salaryRange: _optional(_salary),
      source: _source,
      appliedDate: _appliedDate,
      status: initial?.status ?? ApplicationStatus.applied,
      notes: _optional(_notes),
      contactName: _optional(_contactName),
      contactEmail: _optional(_contactEmail),
      followUpAt: _followUpAt,
      nextInterviewAt: initial?.nextInterviewAt,
      createdAt: initial?.createdAt ?? now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    setState(() => _serverErrors = {});
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _snack(ApplicationStrings.formHasErrors);
      return;
    }
    final saved = await ref
        .read(applicationFormControllerProvider.notifier)
        .save(_buildDraft(), isEdit: _isEdit);
    if (!mounted) return;
    if (saved == null) {
      _handleFailure(ref.read(applicationFormControllerProvider).error);
      return;
    }
    setState(() => _allowPop = true);
    if (_isEdit) {
      context.pop();
    } else {
      context.pushReplacement(Routes.applicationDetail(saved.id));
    }
  }

  void _handleFailure(Object? error) {
    if (error is ApiFailure && error.fields.isNotEmpty) {
      setState(() => _serverErrors = error.fields);
      // Re-run validation so the server messages show under their inputs.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
      _snack(ApplicationStrings.formHasErrors);
      return;
    }
    _snack(
      error == null ? ApplicationStrings.saveFailed : failureMessage(error),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onPopBlocked() async {
    final discard = await showConfirmDialog(
      context,
      title: ApplicationStrings.discardTitle,
      message: ApplicationStrings.discardMessage,
      confirmLabel: ApplicationStrings.discardConfirm,
      destructive: true,
    );
    if (discard && mounted) {
      setState(() => _allowPop = true);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(applicationFormControllerProvider).isLoading;
    final days = ref.watch(followUpDefaultDaysProvider).valueOrNull;
    final canToggleFollowUp =
        days != null || widget.initial?.followUpAt != null;

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: ApplicationStrings.closeForm,
            icon: const Icon(Icons.close_rounded),
            onPressed: saving ? null : () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            _isEdit
                ? ApplicationStrings.editTitle
                : ApplicationStrings.newTitle,
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : _save,
              child: const Text(AppStrings.save),
            ),
          ],
        ),
        bottomNavigationBar: FormFooter(
          saving: saving,
          onCancel: () => Navigator.of(context).maybePop(),
          onSave: _save,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                Spacing.screen,
                Spacing.lg,
                Spacing.screen,
                Spacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    label: ApplicationStrings.fieldJobTitle,
                    controller: _title,
                    isRequired: true,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['jobTitle'],
                    validator: Validators.requiredText,
                    onChanged: (_) => _clearServerError('jobTitle'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldCompany,
                    controller: _company,
                    isRequired: true,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['companyName'],
                    validator: Validators.requiredText,
                    onChanged: (_) => _clearServerError('companyName'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldLocation,
                    controller: _location,
                    isRequired: true,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['location'],
                    validator: Validators.requiredText,
                    onChanged: (_) => _clearServerError('location'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const _FieldLabel(
                    ApplicationStrings.fieldArrangement,
                    isRequired: true,
                  ),
                  const SizedBox(height: 6),
                  SegmentedChoice<WorkArrangement>(
                    values: WorkArrangement.values,
                    selected: _arrangement,
                    labelOf: (a) => a.label,
                    onChanged: (v) => setState(() => _arrangement = v),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const _FieldLabel(ApplicationStrings.fieldEmploymentType),
                  const SizedBox(height: 6),
                  ChoiceChips<EmploymentType>(
                    values: EmploymentType.values,
                    selected: {?_employment},
                    labelOf: (t) => t.label,
                    // Tapping the selected chip clears it (the field is optional).
                    onChanged: (v) => setState(
                      () =>
                          _employment = v.first == _employment ? null : v.first,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  _Pair(
                    first: AppTextField(
                      label: ApplicationStrings.fieldAppliedDate,
                      controller: _appliedText,
                      isRequired: true,
                      readOnly: true,
                      enabled: !saving,
                      onTap: _pickAppliedDate,
                      suffix: const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                      ),
                      errorText: _serverErrors['appliedDate'],
                      validator: (_) => Validators.appliedDate(_appliedDate),
                    ),
                    second: _SourceDropdown(
                      value: _source,
                      enabled: !saving,
                      onChanged: (v) => setState(() => _source = v),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldSalary,
                    controller: _salary,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['salaryRange'],
                    validator: (v) =>
                        Validators.optionalText(v, max: Limits.shortText),
                    onChanged: (_) => _clearServerError('salaryRange'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldLink,
                    controller: _link,
                    enabled: !saving,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['applicationLink'],
                    validator: Validators.applicationLink,
                    onChanged: (_) => _clearServerError('applicationLink'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldDescription,
                    controller: _description,
                    enabled: !saving,
                    minLines: 6,
                    maxLines: 12,
                    maxLength: Limits.jobDescription,
                    showCounter: true,
                    keyboardType: TextInputType.multiline,
                    errorText: _serverErrors['jobDescription'],
                    validator: Validators.jobDescription,
                    onChanged: (_) => _clearServerError('jobDescription'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  _Pair(
                    first: AppTextField(
                      label: ApplicationStrings.fieldContactName,
                      controller: _contactName,
                      enabled: !saving,
                      textInputAction: TextInputAction.next,
                      errorText: _serverErrors['contactName'],
                      validator: (v) =>
                          Validators.optionalText(v, max: Limits.shortText),
                      onChanged: (_) => _clearServerError('contactName'),
                    ),
                    second: AppTextField(
                      label: ApplicationStrings.fieldContactEmail,
                      controller: _contactEmail,
                      enabled: !saving,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      errorText: _serverErrors['contactEmail'],
                      validator: Validators.optionalEmail,
                      onChanged: (_) => _clearServerError('contactEmail'),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: ApplicationStrings.fieldNotes,
                    controller: _notes,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    errorText: _serverErrors['notes'],
                    onChanged: (_) => _clearServerError('notes'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.lg,
                        vertical: Spacing.sm,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              ApplicationStrings.followUpSwitchTitle,
                            ),
                            subtitle: Text(
                              _followUpAt != null
                                  ? ApplicationStrings.followUpSwitchSubtitle(
                                      DateHelpers.formatDate(_followUpAt!),
                                    )
                                  : canToggleFollowUp
                                  ? ''
                                  : ApplicationStrings.followUpOffHint,
                            ),
                            value: _followUpAt != null,
                            onChanged: saving || !canToggleFollowUp
                                ? null
                                : (on) => setState(() {
                                    _followUpTouched = true;
                                    _followUpAt = on
                                        ? _defaultFollowUp(days ?? 7)
                                        : null;
                                  }),
                          ),
                          if (_followUpAt != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: saving ? null : _pickFollowUpDate,
                                icon: const Icon(Icons.event_rounded),
                                label: const Text(
                                  ApplicationStrings.followUpChange,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (isRequired)
            TextSpan(
              text: ' *',
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
      style: theme.textTheme.labelMedium?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Two fields side by side, stacked on narrow widths or large text.
class _Pair extends StatelessWidget {
  const _Pair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 || scale > 1.2) {
          return Column(
            children: [
              first,
              const SizedBox(height: Spacing.lg),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: Spacing.md),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _SourceDropdown extends StatelessWidget {
  const _SourceDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final ApplicationSource? value;
  final bool enabled;
  final ValueChanged<ApplicationSource?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(ApplicationStrings.fieldSource),
        const SizedBox(height: 6),
        DropdownButtonFormField<ApplicationSource?>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          items: [
            const DropdownMenuItem<ApplicationSource?>(
              child: Text(ApplicationStrings.sourceNone),
            ),
            for (final s in ApplicationSource.values)
              DropdownMenuItem<ApplicationSource?>(
                value: s,
                child: Text(s.label, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
      ],
    );
  }
}
