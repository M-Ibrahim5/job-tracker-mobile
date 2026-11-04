/// Domain enums for JobTrail. Persisted by [Enum.name], so do not rename
/// values without a database migration.
library;

/// Hiring pipeline stage of a job application, in normal forward order.
enum ApplicationStatus {
  applied('Applied'),
  screening('Screening'),
  interview('Interview'),
  offer('Offer'),
  rejected('Rejected');

  const ApplicationStatus(this.label);

  /// Human readable name.
  final String label;

  /// Whether the application is still in play (not Offer / Rejected).
  bool get isActive => this != offer && this != rejected;

  /// The next status in the normal forward flow, or null when none.
  ApplicationStatus? get nextInFlow => switch (this) {
    applied => screening,
    screening => interview,
    interview => offer,
    offer || rejected => null,
  };
}

/// Where the work is performed.
enum WorkArrangement {
  onsite('On-site'),
  hybrid('Hybrid'),
  remote('Remote');

  const WorkArrangement(this.label);

  /// Human readable name.
  final String label;
}

/// Contract type of a position.
enum EmploymentType {
  fullTime('Full-time'),
  partTime('Part-time'),
  contract('Contract'),
  internship('Internship');

  const EmploymentType(this.label);

  /// Human readable name.
  final String label;
}

/// Where the user found the job.
enum ApplicationSource {
  linkedIn('LinkedIn'),
  jobStreet('JobStreet'),
  indeed('Indeed'),
  companySite('Company site'),
  referral('Referral'),
  other('Other');

  const ApplicationSource(this.label);

  /// Human readable name.
  final String label;
}

/// Kind of interview round.
enum InterviewType {
  phone('Phone'),
  video('Video'),
  onsite('On-site'),
  technical('Technical'),
  hr('HR'),
  finalRound('Final'),
  other('Other');

  const InterviewType(this.label);

  /// Human readable name.
  final String label;
}

/// Result of an interview.
enum InterviewOutcome {
  pending('Pending'),
  passed('Passed'),
  failed('Failed'),
  cancelled('Cancelled');

  const InterviewOutcome(this.label);

  /// Human readable name.
  final String label;
}

/// Category of an in-app notification entry.
enum NotificationType {
  interviewReminder('Interview reminder'),
  followUpReminder('Follow-up reminder'),
  statusChange('Status change'),
  system('System');

  const NotificationType(this.label);

  /// Human readable name.
  final String label;
}

/// Sort order for the application list.
enum ApplicationSort {
  newest('Newest first'),
  oldest('Oldest first'),
  companyAZ('Company A–Z'),
  status('Status');

  const ApplicationSort(this.label);

  /// Human readable name.
  final String label;
}

/// Theme preference stored in the user's settings.
enum ThemeSetting {
  system('System'),
  light('Light'),
  dark('Dark');

  const ThemeSetting(this.label);

  /// Human readable name.
  final String label;
}

/// Kind of entry returned by `GET /calendar`.
enum CalendarEventType { applied, statusChange, interview, followUp }

/// Kind of device reminder returned by `GET /reminders/upcoming`.
enum ReminderKind { interviewReminder, followUpReminder }

/// Which interviews `GET /interviews` returns.
enum InterviewScope { upcoming, past }

/// Export formats of `GET /export`.
enum ExportFormat {
  json('JSON'),
  csv('CSV');

  const ExportFormat(this.label);

  /// Human readable name.
  final String label;
}

/// Looks up an enum value by its camelCase [name] (the API representation).
T enumByName<T extends Enum>(List<T> values, String name) =>
    values.byName(name);

/// Nullable variant of [enumByName].
T? enumByNameOrNull<T extends Enum>(List<T> values, String? name) =>
    name == null ? null : values.byName(name);
