import '../../../core/constants/app_constants.dart';
import '../../../core/constants/application_strings.dart';
import '../../../domain/enums/enums.dart';

/// How a status option relates to an application's current status.
enum StatusOptionKind {
  /// The status the application is already in (not selectable).
  current,

  /// The next step in the normal flow (dashed outline).
  next,

  /// Any other status; every status can be set at any time.
  other,
}

/// Classifies [option] relative to [current].
StatusOptionKind statusOptionKind(
  ApplicationStatus option,
  ApplicationStatus current,
) {
  if (option == current) return StatusOptionKind.current;
  if (current.nextInFlow == option) return StatusOptionKind.next;
  return StatusOptionKind.other;
}

/// Validation message for the optional status note, or null when it is fine.
String? statusNoteError(String note) => note.trim().length > Limits.note
    ? AppStrings.errMaxLength(Limits.note)
    : null;

/// Whether Confirm is enabled in the status sheet.
bool canConfirmStatusChange({
  required ApplicationStatus current,
  required ApplicationStatus? selected,
  required String note,
}) => selected != null && selected != current && statusNoteError(note) == null;

/// Normalised note to send: trimmed, null when empty.
String? normalizedNote(String note) {
  final v = note.trim();
  return v.isEmpty ? null : v;
}

/// Label text for the kind chip beside an option, or null for [other].
String? statusKindLabel(StatusOptionKind kind) => switch (kind) {
  StatusOptionKind.current => ApplicationStrings.statusCurrent,
  StatusOptionKind.next => ApplicationStrings.statusNext,
  StatusOptionKind.other => null,
};
