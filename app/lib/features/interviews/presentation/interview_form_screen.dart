import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/interview_strings.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/enums/enums.dart';
import '../../../domain/models/interview.dart';
import '../../../domain/models/job_application.dart';
import '../../applications/application/application_providers.dart';
import '../../notifications/presentation/notification_permission.dart';
import '../../settings/application/settings_controller.dart';
import '../application/interview_controllers.dart';
import '../application/interview_flow.dart';
import '../application/interviews_providers.dart';

/// Add / edit interview form. Routes: `/applications/:id/interviews/new`
/// ([applicationId]), `/interviews/new?date=` ([initialDate]) and
/// `/interviews/:id/edit` ([interviewId]).
class InterviewFormScreen extends ConsumerWidget {
  /// Creates the screen.
  const InterviewFormScreen({
    this.applicationId,
    this.interviewId,
    this.initialDate,
    super.key,
  });

  final int? applicationId;
  final int? interviewId;
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = interviewId;
    if (id == null) {
      return InterviewForm(
        applicationId: applicationId,
        initialDate: initialDate,
      );
    }
    final async = ref.watch(interviewDetailProvider(id));
    final interview = async.valueOrNull;
    if (interview != null) {
      return InterviewForm(key: ValueKey(interview.id), initial: interview);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(InterviewStrings.editTitle)),
      body: async.isLoading
          ? const Padding(
              padding: EdgeInsets.all(Spacing.screen),
              child: SkeletonBox(height: 240, radius: Radii.card),
            )
          : ErrorState(
              error: async.error,
              onRetry: () => ref.invalidate(interviewDetailProvider(id)),
            ),
    );
  }
}

/// The form itself.
class InterviewForm extends ConsumerStatefulWidget {
  /// Creates the form; [initial] is the interview being edited.
  const InterviewForm({
    this.initial,
    this.applicationId,
    this.initialDate,
    super.key,
  });

  final Interview? initial;
  final int? applicationId;
  final DateTime? initialDate;

  @override
  ConsumerState<InterviewForm> createState() => _InterviewFormState();
}

class _InterviewFormState extends ConsumerState<InterviewForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _interviewer = TextEditingController();
  final _notes = TextEditingController();
  final _dateText = TextEditingController();
  final _timeText = TextEditingController();

  late final List<TextEditingController> _controllers = [
    _title,
    _location,
    _interviewer,
    _notes,
  ];

  int? _applicationId;
  InterviewType _type = InterviewType.video;
  late DateTime _date;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 60;
  Set<Duration> _offsets = {};
  bool _offsetsTouched = false;

  late List<Object?> _baseline;
  Map<String, String> _serverErrors = {};
  String? _timeError;
  bool _allowPop = false;
  bool _started = false;

  bool get _isEdit => widget.initial != null;

  /// Application id when it can't be changed (opened from an application, or
  /// editing).
  int? get _lockedApplicationId =>
      widget.initial?.applicationId ?? widget.applicationId;

  DateTime get _scheduled =>
      combineDateAndTime(_date, _time.hour, _time.minute);

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _applicationId = _lockedApplicationId;
    if (i != null) {
      _title.text = i.title;
      _location.text = i.locationOrLink ?? '';
      _interviewer.text = i.interviewerName ?? '';
      _notes.text = i.notes ?? '';
      _type = i.type;
      _date = DateHelpers.dayOnly(i.scheduledAt);
      _time = TimeOfDay(hour: i.scheduledAt.hour, minute: i.scheduledAt.minute);
      _duration = i.durationMinutes;
      _offsets = {...i.reminderOffsets};
    } else {
      final today = DateHelpers.dayOnly(DateTime.now());
      _date = widget.initialDate != null
          ? DateHelpers.dayOnly(widget.initialDate!)
          : today.add(const Duration(days: 1));
    }
    _baseline = _snapshot();
    for (final c in _controllers) {
      c.addListener(_onChanged);
    }
    // New interviews start with the default reminders from settings.
    ref.listenManual(settingsProvider, (_, next) {
      final settings = next.valueOrNull;
      if (_isEdit || _offsetsTouched || settings == null || !mounted) return;
      void apply() {
        _offsets = {...settings.defaultReminderOffsets};
        _baseline = _snapshot();
      }

      // The immediate call runs inside initState, where setState is illegal.
      _started ? setState(apply) : apply();
    }, fireImmediately: true);
    _started = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dateText.text = DateHelpers.formatDate(_date);
    _timeText.text = MaterialLocalizations.of(context).formatTimeOfDay(_time);
  }

  @override
  void dispose() {
    for (final c in [..._controllers, _dateText, _timeText]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() => setState(() {});

  List<Object?> _snapshot() => [
    for (final c in _controllers) c.text.trim(),
    _applicationId,
    _type,
    _date,
    _time,
    _duration,
    (_offsets.map((d) => d.inMinutes).toList()..sort()).join(','),
  ];

  bool get _dirty => !listEquals(_snapshot(), _baseline);

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearServerError(String field) {
    if (_serverErrors.containsKey(field)) {
      setState(() => _serverErrors = {..._serverErrors}..remove(field));
    }
  }

  String? _optional(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateText.text = DateHelpers.formatDate(picked);
      _timeError = null;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() {
      _time = picked;
      _timeText.text = MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(picked);
      _timeError = null;
    });
  }

  Future<void> _addCustomReminder() async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (_) => const _CustomReminderDialog(),
    );
    if (minutes == null || !mounted) return;
    _setOffsets({..._offsets, Duration(minutes: minutes)});
  }

  void _setOffsets(Set<Duration> next) {
    if (next.length > kMaxReminderOffsets) {
      _snack(InterviewStrings.tooManyReminders);
      return;
    }
    setState(() {
      _offsetsTouched = true;
      _offsets = next;
    });
  }

  Interview _buildDraft(int applicationId) {
    final initial = widget.initial;
    return Interview(
      id: initial?.id ?? 0,
      applicationId: applicationId,
      title: _title.text.trim(),
      type: _type,
      scheduledAt: _scheduled,
      durationMinutes: _duration,
      locationOrLink: _optional(_location),
      interviewerName: _optional(_interviewer),
      notes: _optional(_notes),
      reminderOffsets: (_offsets.toList()..sort((a, b) => b.compareTo(a))),
      outcome: initial?.outcome ?? InterviewOutcome.pending,
    );
  }

  Future<JobApplication?> _applicationFor(int id) async {
    try {
      return await ref.read(applicationDetailProvider(id).future);
    } catch (_) {
      return null;
    }
  }

  /// Asks whether to move the application to Interview; true only on Yes.
  Future<bool> _askStatusMove(int applicationId) async {
    final controller = ref.read(interviewControllerProvider.notifier);
    final app = await _applicationFor(applicationId);
    if (app == null || !mounted) return false;
    final int count;
    try {
      count = await controller.countFor(applicationId);
    } catch (_) {
      return false;
    }
    if (!shouldSuggestInterviewStatus(
      status: app.status,
      existingInterviews: count,
    )) {
      return false;
    }
    if (!mounted) return false;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(InterviewStrings.suggestTitle),
        content: Text(
          InterviewStrings.suggestMessage(app.companyName, app.status.label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(InterviewStrings.suggestNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(InterviewStrings.suggestYes),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _save() async {
    setState(() {
      _serverErrors = {};
      _timeError = null;
    });
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _snack(InterviewStrings.formHasErrors);
      return;
    }
    final applicationId = _applicationId!;
    final moveStatus = _isEdit ? false : await _askStatusMove(applicationId);
    if (!mounted) return;

    final controller = ref.read(interviewControllerProvider.notifier);
    final saved = await controller.save(
      applicationId: applicationId,
      draft: _buildDraft(applicationId),
      isEdit: _isEdit,
      moveStatus: moveStatus,
    );
    if (!mounted) return;
    if (saved == null) {
      _handleFailure(ref.read(interviewControllerProvider).error);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final ask =
        _offsets.isNotEmpty && !isPastSchedule(_scheduled, DateTime.now());
    final moveFailed = controller.statusMoveFailed;
    setState(() => _allowPop = true);
    if (ask) await maybeAskNotificationPermission(context, ref);
    if (router.canPop()) router.pop();
    if (moveFailed) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(InterviewStrings.statusMoveFailed)),
        );
    }
  }

  void _handleFailure(Object? error) {
    if (error is ApiFailure) {
      if (error.code == ApiCodes.interviewConflict) {
        setState(() => _timeError = failureMessage(error));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _formKey.currentState?.validate();
        });
        return;
      }
      if (error.fields.isNotEmpty) {
        final fields = {...error.fields};
        final time = fields.remove('scheduledAt');
        setState(() {
          _serverErrors = fields;
          _timeError = time;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _formKey.currentState?.validate();
        });
        _snack(InterviewStrings.formHasErrors);
        return;
      }
    }
    _snack(error == null ? InterviewStrings.saveFailed : failureMessage(error));
  }

  Future<void> _onPopBlocked() async {
    final discard = await showConfirmDialog(
      context,
      title: InterviewStrings.discardTitle,
      message: InterviewStrings.discardMessage,
      confirmLabel: InterviewStrings.discardConfirm,
      destructive: true,
    );
    if (discard && mounted) {
      setState(() => _allowPop = true);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(interviewControllerProvider).isLoading;
    final past = isPastSchedule(_scheduled, DateTime.now());
    final presetSet = kPresetReminderOffsets.toSet();
    final customOffsets = _offsets.where((d) => !presetSet.contains(d)).toList()
      ..sort((a, b) => b.compareTo(a));

    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: AppStrings.cancel,
            icon: const Icon(Icons.close_rounded),
            onPressed: saving ? null : () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            _isEdit ? InterviewStrings.editTitle : InterviewStrings.newTitle,
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
                  _ApplicationField(
                    lockedId: _lockedApplicationId,
                    selectedId: _applicationId,
                    enabled: !saving,
                    onChanged: (id) => setState(() => _applicationId = id),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: InterviewStrings.fieldTitle,
                    controller: _title,
                    isRequired: true,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['title'],
                    validator: (v) => Validators.requiredText(v, max: 150),
                    onChanged: (_) => _clearServerError('title'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const _Label(InterviewStrings.fieldType, isRequired: true),
                  const SizedBox(height: 6),
                  ChoiceChips<InterviewType>(
                    values: InterviewType.values,
                    selected: {_type},
                    labelOf: (t) => t.label,
                    onChanged: (v) => setState(() => _type = v.first),
                  ),
                  const SizedBox(height: Spacing.lg),
                  _Pair(
                    first: AppTextField(
                      label: InterviewStrings.fieldDate,
                      controller: _dateText,
                      isRequired: true,
                      readOnly: true,
                      enabled: !saving,
                      onTap: _pickDate,
                      suffix: const Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                      ),
                    ),
                    second: AppTextField(
                      label: InterviewStrings.fieldTime,
                      controller: _timeText,
                      isRequired: true,
                      readOnly: true,
                      enabled: !saving,
                      onTap: _pickTime,
                      suffix: const Icon(Icons.schedule_rounded, size: 20),
                      errorText: _timeError,
                    ),
                  ),
                  if (past) ...[
                    const SizedBox(height: Spacing.md),
                    const NoticeBanner(
                      message: InterviewStrings.pastWarning,
                      icon: Icons.history_rounded,
                    ),
                  ],
                  const SizedBox(height: Spacing.lg),
                  const _Label(InterviewStrings.fieldDuration),
                  const SizedBox(height: 6),
                  ChoiceChips<int>(
                    values: {...kDurationChoices, _duration}.toList()..sort(),
                    selected: {_duration},
                    labelOf: InterviewStrings.minutes,
                    onChanged: (v) => setState(() => _duration = v.first),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: InterviewStrings.fieldLocation,
                    controller: _location,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['locationOrLink'],
                    validator: (v) =>
                        Validators.optionalText(v, max: Limits.linkLength),
                    onChanged: (_) => _clearServerError('locationOrLink'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: InterviewStrings.fieldInterviewer,
                    controller: _interviewer,
                    enabled: !saving,
                    textInputAction: TextInputAction.next,
                    errorText: _serverErrors['interviewerName'],
                    validator: (v) =>
                        Validators.optionalText(v, max: Limits.shortText),
                    onChanged: (_) => _clearServerError('interviewerName'),
                  ),
                  const SizedBox(height: Spacing.lg),
                  const _Label(InterviewStrings.fieldRemind),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    children: [
                      for (final d in [
                        ...kPresetReminderOffsets,
                        ...customOffsets,
                      ])
                        FilterChip(
                          label: Text(reminderOffsetLabel(d)),
                          selected: _offsets.contains(d),
                          showCheckmark: true,
                          onSelected: (on) {
                            HapticFeedback.selectionClick();
                            _setOffsets(
                              on
                                  ? {..._offsets, d}
                                  : ({..._offsets}..remove(d)),
                            );
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(InterviewStrings.customReminder),
                        onPressed: saving ? null : _addCustomReminder,
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.lg),
                  AppTextField(
                    label: InterviewStrings.fieldNotes,
                    controller: _notes,
                    enabled: !saving,
                    minLines: 3,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    errorText: _serverErrors['notes'],
                    validator: (v) => Validators.optionalText(v, max: 10000),
                    onChanged: (_) => _clearServerError('notes'),
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

class _Label extends StatelessWidget {
  const _Label(this.text, {this.isRequired = false});

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

/// Application picker; read-only text when the application is fixed.
class _ApplicationField extends ConsumerWidget {
  const _ApplicationField({
    required this.lockedId,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final int? lockedId;
  final int? selectedId;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = lockedId;
    if (locked != null) {
      final app = ref.watch(applicationDetailProvider(locked)).valueOrNull;
      return AppTextField(
        key: ValueKey('locked-$locked-${app?.id}'),
        label: InterviewStrings.fieldApplication,
        isRequired: true,
        readOnly: true,
        initialValue: app == null
            ? '…'
            : '${app.companyName} · ${app.jobTitle}',
        suffix: const Icon(Icons.lock_outline_rounded, size: 20),
      );
    }

    final options = ref.watch(applicationOptionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(InterviewStrings.fieldApplication, isRequired: true),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: selectedId,
          isExpanded: true,
          hint: Text(
            options.isLoading
                ? AppStrings.loading
                : InterviewStrings.pickApplication,
          ),
          onChanged: enabled ? onChanged : null,
          validator: (v) => v == null ? InterviewStrings.pickApplication : null,
          items: [
            for (final a in options.valueOrNull ?? const <JobApplication>[])
              DropdownMenuItem<int>(
                value: a.id,
                child: Text(
                  '${a.companyName} · ${a.jobTitle}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog();

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final minutes = int.tryParse(_controller.text.trim());
    final error = validateReminderMinutes(minutes);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(InterviewStrings.customReminderTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: InterviewStrings.customReminderMinutes,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(InterviewStrings.customReminderAdd),
        ),
      ],
    );
  }
}
