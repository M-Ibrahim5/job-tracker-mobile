import '../../core/errors/failures.dart';
import '../../core/utils/date_helpers.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/interview.dart';
import '../../domain/models/job_application.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/status_history_entry.dart';
import '../../domain/models/user.dart';

/// Credentials of the seeded demo account.
const kFakeEmail = 'demo@jobtrail.app';
const kFakePassword = 'Password1!';

/// Mutable in-memory state shared by every fake repository, seeded with the
/// sample data from `DESIGN.md`. Dates are relative to [now] so the data
/// always looks current.
class FakeBackend {
  /// Creates a seeded backend. Use [latency] `Duration.zero` in tests.
  FakeBackend({
    this.latency = const Duration(milliseconds: 250),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _seed();
  }

  /// Simulated network delay applied by [run].
  final Duration latency;
  final DateTime Function() _clock;

  /// Current time as seen by the fake server.
  DateTime get now => _clock();

  final Map<String, String> passwords = {};

  /// Fingerprint-login tokens: token → account e-mail.
  final Map<String, String> deviceTokens = {};
  int _deviceTokenSeq = 0;

  /// A fresh fake device token.
  String newDeviceToken() => 'device-token-${++_deviceTokenSeq}';
  final Map<String, User> usersByEmail = {};
  User? currentUser;

  Settings settings = const Settings();
  final Map<int, JobApplication> applications = {};
  final List<StatusHistoryEntry> history = [];
  final Map<int, Interview> interviews = {};
  final List<AppNotification> notifications = [];

  int _nextApplicationId = 1;
  int _nextHistoryId = 1;
  int _nextInterviewId = 1;
  int _nextNotificationId = 1;
  int _nextUserId = 2;

  /// Runs [body] after the simulated latency.
  Future<T> run<T>(T Function() body) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return body();
  }

  /// Error for a missing record.
  ApiFailure notFound() => const ApiFailure(
    code: ApiCodes.notFound,
    message: 'Not found',
    statusCode: 404,
  );

  int newApplicationId() => _nextApplicationId++;
  int newHistoryId() => _nextHistoryId++;
  int newInterviewId() => _nextInterviewId++;
  int newNotificationId() => _nextNotificationId++;
  int newUserId() => _nextUserId++;

  /// Application with `nextInterviewAt` computed from its interviews.
  JobApplication withNextInterview(JobApplication a) {
    final next = interviews.values
        .where((i) => i.applicationId == a.id && i.scheduledAt.isAfter(now))
        .map((i) => i.scheduledAt)
        .fold<DateTime?>(
          null,
          (min, t) => min == null || t.isBefore(min) ? t : min,
        );
    return a.copyWith(
      nextInterviewAt: next,
      clearNextInterviewAt: next == null,
    );
  }

  /// Copy of [a] without the job description, as list responses omit it.
  JobApplication withoutDescription(JobApplication a) => JobApplication(
    id: a.id,
    jobTitle: a.jobTitle,
    companyName: a.companyName,
    location: a.location,
    workArrangement: a.workArrangement,
    applicationLink: a.applicationLink,
    employmentType: a.employmentType,
    salaryRange: a.salaryRange,
    source: a.source,
    appliedDate: a.appliedDate,
    status: a.status,
    notes: a.notes,
    contactName: a.contactName,
    contactEmail: a.contactEmail,
    followUpAt: a.followUpAt,
    nextInterviewAt: a.nextInterviewAt,
    createdAt: a.createdAt,
    updatedAt: a.updatedAt,
  );

  /// Interview with application title / company filled in.
  Interview enrich(Interview i) {
    final app = applications[i.applicationId];
    return i.copyWith(
      applicationTitle: app?.jobTitle,
      companyName: app?.companyName,
    );
  }

  /// Adds a notification row visible immediately.
  void notify(
    NotificationType type,
    String title,
    String body, {
    int? applicationId,
    int? interviewId,
    DateTime? at,
    bool isRead = false,
  }) {
    notifications.add(
      AppNotification(
        id: newNotificationId(),
        type: type,
        title: title,
        body: body,
        createdAt: at ?? now,
        relatedApplicationId: applicationId,
        relatedInterviewId: interviewId,
        isRead: isRead,
      ),
    );
  }

  /// Removes all applications, interviews, history and notifications.
  void clearData() {
    applications.clear();
    history.clear();
    interviews.clear();
    notifications.clear();
  }

  // ---------------------------------------------------------------- seeding

  void _seed() {
    const demo = User(
      id: 1,
      email: kFakeEmail,
      fullName: 'Muhammad Ibrahim',
      currentRole: 'Software Engineer',
      location: 'Kuala Lumpur, Malaysia',
      emailVerified: true,
    );
    usersByEmail[kFakeEmail] = demo;
    passwords[kFakeEmail] = kFakePassword;

    final today = DateHelpers.dayOnly(now);
    // (title, company, location, arrangement, status, daysAgo, followUpDays)
    final rows =
        <
          (
            String,
            String,
            String,
            WorkArrangement,
            ApplicationStatus,
            int,
            int?,
          )
        >[
          (
            'Senior Flutter Developer',
            'Northwind Labs',
            'Kuala Lumpur',
            WorkArrangement.hybrid,
            ApplicationStatus.interview,
            2,
            null,
          ),
          (
            'Flutter Developer',
            'Orbit Health',
            'Petaling Jaya',
            WorkArrangement.remote,
            ApplicationStatus.screening,
            6,
            1,
          ),
          (
            'Mobile Engineer',
            'Lumen Pay',
            'Singapore',
            WorkArrangement.hybrid,
            ApplicationStatus.applied,
            1,
            null,
          ),
          (
            'Cross-platform Developer',
            'Atlas Cloud',
            'Kuala Lumpur',
            WorkArrangement.onsite,
            ApplicationStatus.applied,
            3,
            4,
          ),
          (
            'Android Developer',
            'Brightside',
            'Penang',
            WorkArrangement.onsite,
            ApplicationStatus.rejected,
            20,
            null,
          ),
          (
            'Flutter Engineer',
            'Kite Studio',
            'Remote',
            WorkArrangement.remote,
            ApplicationStatus.offer,
            30,
            null,
          ),
          (
            'Software Engineer',
            'Helio Systems',
            'Cyberjaya',
            WorkArrangement.hybrid,
            ApplicationStatus.interview,
            12,
            null,
          ),
          (
            'Frontend Developer',
            'Fernwood',
            'Kuala Lumpur',
            WorkArrangement.hybrid,
            ApplicationStatus.screening,
            9,
            null,
          ),
          (
            'App Developer',
            'Quanta Retail',
            'Johor Bahru',
            WorkArrangement.onsite,
            ApplicationStatus.applied,
            5,
            null,
          ),
          (
            'Flutter Lead',
            'Meridian Bank',
            'Kuala Lumpur',
            WorkArrangement.hybrid,
            ApplicationStatus.interview,
            15,
            null,
          ),
          (
            'Mobile Developer',
            'Cobalt Games',
            'Remote',
            WorkArrangement.remote,
            ApplicationStatus.rejected,
            25,
            null,
          ),
          (
            'Flutter Developer',
            'Sunrise Logistics',
            'Shah Alam',
            WorkArrangement.onsite,
            ApplicationStatus.screening,
            11,
            null,
          ),
          (
            'UI Engineer',
            'Pixelforge',
            'Remote',
            WorkArrangement.remote,
            ApplicationStatus.applied,
            8,
            null,
          ),
          (
            'Software Developer',
            'Tidal Analytics',
            'Kuala Lumpur',
            WorkArrangement.hybrid,
            ApplicationStatus.rejected,
            40,
            null,
          ),
          (
            'Mobile Tech Lead',
            'Granite Insurance',
            'Petaling Jaya',
            WorkArrangement.hybrid,
            ApplicationStatus.applied,
            0,
            null,
          ),
        ];

    for (final r in rows) {
      final applied = today.subtract(Duration(days: r.$6));
      final id = newApplicationId();
      final app = JobApplication(
        id: id,
        jobTitle: r.$1,
        companyName: r.$2,
        location: r.$3,
        workArrangement: r.$4,
        jobDescription:
            'Build and ship features for a cross-platform mobile app.\n\n'
            'You will work with product and design, write tests and review code.',
        applicationLink:
            'https://careers.example.com/${r.$2.toLowerCase().replaceAll(' ', '-')}',
        employmentType: EmploymentType.fullTime,
        salaryRange: 'RM 9,000 – 12,000',
        source: ApplicationSource.values[id % ApplicationSource.values.length],
        appliedDate: applied,
        status: r.$5,
        notes: 'Recruiter was friendly.',
        contactName: 'Aisha Rahman',
        contactEmail: 'aisha@${r.$2.toLowerCase().replaceAll(' ', '')}.example',
        followUpAt: r.$7 == null
            ? null
            : today.add(Duration(days: r.$7!, hours: 9)),
        createdAt: applied.add(const Duration(hours: 9)),
        updatedAt: applied.add(const Duration(hours: 9)),
      );
      applications[id] = app;

      // Initial entry plus one entry per step towards the current status.
      history.add(
        StatusHistoryEntry(
          id: newHistoryId(),
          applicationId: id,
          toStatus: ApplicationStatus.applied,
          changedAt: app.createdAt,
        ),
      );
      var from = ApplicationStatus.applied;
      final path = switch (r.$5) {
        ApplicationStatus.applied => <ApplicationStatus>[],
        ApplicationStatus.screening => [ApplicationStatus.screening],
        ApplicationStatus.interview => [
          ApplicationStatus.screening,
          ApplicationStatus.interview,
        ],
        ApplicationStatus.offer => [
          ApplicationStatus.screening,
          ApplicationStatus.interview,
          ApplicationStatus.offer,
        ],
        ApplicationStatus.rejected => [
          ApplicationStatus.screening,
          ApplicationStatus.rejected,
        ],
      };
      for (var i = 0; i < path.length; i++) {
        history.add(
          StatusHistoryEntry(
            id: newHistoryId(),
            applicationId: id,
            fromStatus: from,
            toStatus: path[i],
            changedAt: app.createdAt.add(Duration(days: i + 1, hours: 2)),
            note: i == 0 ? 'Recruiter called' : null,
          ),
        );
        from = path[i];
      }
    }

    void interview(
      int appId,
      String title,
      InterviewType type,
      Duration from, {
      int minutes = 60,
    }) {
      final id = newInterviewId();
      interviews[id] = Interview(
        id: id,
        applicationId: appId,
        title: title,
        type: type,
        scheduledAt: DateTime(today.year, today.month, today.day, 10).add(from),
        durationMinutes: minutes,
        locationOrLink: type == InterviewType.video
            ? 'https://meet.example.com/abc'
            : 'Level 12, KL Sentral',
        interviewerName: 'Daniel Lim',
        notes: 'Review system design basics.',
        createdAt: now,
        updatedAt: now,
      );
    }

    interview(
      1,
      'Technical interview · Round 2',
      InterviewType.video,
      const Duration(days: 3),
    );
    interview(
      7,
      'HR chat',
      InterviewType.phone,
      const Duration(days: 5, hours: 4),
      minutes: 30,
    );
    interview(
      10,
      'Final round',
      InterviewType.finalRound,
      const Duration(days: 9),
      minutes: 90,
    );
    interview(
      1,
      'Screening call',
      InterviewType.phone,
      const Duration(days: -4),
      minutes: 30,
    );

    notify(
      NotificationType.statusChange,
      'Moved to Interview',
      'Northwind Labs · Senior Flutter Developer',
      applicationId: 1,
      at: now.subtract(const Duration(hours: 2)),
    );
    notify(
      NotificationType.interviewReminder,
      'Interview tomorrow',
      'Helio Systems · 10:00 AM · Phone',
      applicationId: 7,
      interviewId: 2,
      at: now.subtract(const Duration(hours: 5)),
    );
    notify(
      NotificationType.followUpReminder,
      'Time to follow up',
      'Orbit Health · Flutter Developer',
      applicationId: 2,
      at: now.subtract(const Duration(days: 1)),
      isRead: true,
    );
    notify(
      NotificationType.system,
      'Welcome to JobTrail',
      'Add your first application to get started.',
      at: now.subtract(const Duration(days: 3)),
      isRead: true,
    );
  }
}
