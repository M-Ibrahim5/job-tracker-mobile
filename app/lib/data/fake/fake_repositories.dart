import 'dart:convert';

import '../../core/errors/failures.dart';
import '../../core/utils/api_date.dart';
import '../../core/utils/date_helpers.dart';
import '../../domain/enums/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/application_extras.dart';
import '../../domain/models/application_filter.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/dashboard_data.dart';
import '../../domain/models/interview.dart';
import '../../domain/models/job_application.dart';
import '../../domain/models/page.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/models/settings.dart';
import '../../domain/models/status_history_entry.dart';
import '../../domain/models/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/interview_repository.dart';
import '../../domain/repositories/job_application_repository.dart';
import '../../domain/repositories/misc_repositories.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import 'fake_backend.dart';

Page<T> _paginate<T>(List<T> all, int page, int pageSize) {
  final start = ((page - 1) * pageSize).clamp(0, all.length);
  final end = (start + pageSize).clamp(0, all.length);
  return Page(
    items: all.sublist(start, end),
    page: page,
    pageSize: pageSize,
    total: all.length,
  );
}

/// In-memory [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  /// Creates the repository over [_b].
  FakeAuthRepository(this._b);

  final FakeBackend _b;

  @override
  Future<User?> restoreSession() => _b.run(() => _b.currentUser);

  @override
  Future<User> signIn({required String email, required String password}) {
    return _b.run(() {
      final key = email.trim().toLowerCase();
      final user = _b.usersByEmail[key];
      if (user == null || _b.passwords[key] != password) {
        throw const ApiFailure(
          code: ApiCodes.invalidCredentials,
          message: 'Invalid email or password',
          statusCode: 401,
        );
      }
      return _b.currentUser = user;
    });
  }

  @override
  Future<User> signUp({
    required String fullName,
    required String email,
    required String password,
  }) {
    return _b.run(() {
      final key = email.trim().toLowerCase();
      if (_b.usersByEmail.containsKey(key)) {
        throw const ApiFailure(
          code: ApiCodes.emailTaken,
          message: 'Email already registered',
          fields: {'email': 'Email already registered'},
          statusCode: 409,
        );
      }
      final user = User(
        id: _b.newUserId(),
        email: key,
        fullName: fullName.trim(),
      );
      _b.usersByEmail[key] = user;
      _b.passwords[key] = password;
      _b.clearData();
      return _b.currentUser = user;
    });
  }

  @override
  Future<String> createDeviceToken({required String password}) {
    return _b.run(() {
      final user = _b.currentUser;
      if (user == null) throw const UnauthorizedFailure();
      if (_b.passwords[user.email] != password) {
        throw const ApiFailure(
          code: ApiCodes.invalidCredentials,
          message: 'Password is incorrect',
          statusCode: 401,
        );
      }
      final token = _b.newDeviceToken();
      _b.deviceTokens[token] = user.email;
      return token;
    });
  }

  @override
  Future<User> deviceSignIn(String deviceToken) {
    return _b.run(() {
      final user = _b.usersByEmail[_b.deviceTokens[deviceToken]];
      if (user == null) throw const UnauthorizedFailure();
      return _b.currentUser = user;
    });
  }

  @override
  Future<void> revokeDeviceToken(String deviceToken) =>
      _b.run(() => _b.deviceTokens.remove(deviceToken));

  @override
  Future<void> signOut() => _b.run(() => _b.currentUser = null);

  @override
  Future<void> forgotPassword(String email) => _b.run(() {});

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _b.run(() {
      final user = _b.currentUser;
      if (user == null) throw const UnauthorizedFailure();
      if (_b.passwords[user.email] != currentPassword) {
        throw const ApiFailure(
          code: ApiCodes.invalidCredentials,
          message: 'Current password is incorrect',
          statusCode: 401,
        );
      }
      _b.passwords[user.email] = newPassword;
      _b.deviceTokens.removeWhere((_, email) => email == user.email);
    });
  }
}

/// In-memory [ProfileRepository].
class FakeProfileRepository implements ProfileRepository {
  /// Creates the repository over [_b].
  FakeProfileRepository(this._b);

  final FakeBackend _b;

  User _me() => _b.currentUser ?? (throw const UnauthorizedFailure());

  void _store(User u) {
    _b.currentUser = u;
    _b.usersByEmail[u.email] = u;
  }

  @override
  Future<User> getMe() => _b.run(_me);

  @override
  Future<User> updateMe({
    String? fullName,
    String? phone,
    String? currentRole,
    String? lookingFor,
    String? location,
  }) {
    return _b.run(() {
      final u = _me().copyWith(
        fullName: fullName,
        phone: phone,
        currentRole: currentRole,
        lookingFor: lookingFor,
        location: location,
      );
      _store(u);
      return u;
    });
  }

  /// The fake keeps the avatar URL unchanged (there is no image host).
  @override
  Future<User> uploadAvatar(String filePath) => _b.run(_me);

  @override
  Future<void> deleteAccount({required String password}) {
    return _b.run(() {
      final u = _me();
      if (_b.passwords[u.email] != password) {
        throw const ApiFailure(
          code: ApiCodes.invalidCredentials,
          message: 'Password is incorrect',
          statusCode: 401,
        );
      }
      _b.usersByEmail.remove(u.email);
      _b.passwords.remove(u.email);
      _b.clearData();
      _b.currentUser = null;
    });
  }

  @override
  Future<Settings> getSettings() => _b.run(() => _b.settings);

  @override
  Future<Settings> updateSettings(Settings settings) =>
      _b.run(() => _b.settings = settings);
}

/// In-memory [JobApplicationRepository].
class FakeJobApplicationRepository implements JobApplicationRepository {
  /// Creates the repository over [_b].
  FakeJobApplicationRepository(this._b);

  final FakeBackend _b;

  JobApplication _get(int id) {
    final a = _b.applications[id];
    if (a == null) throw _b.notFound();
    return a;
  }

  static int _statusRank(ApplicationStatus s) => s.index;

  @override
  Future<Page<JobApplication>> list(
    ApplicationFilter filter, {
    int page = 1,
    int pageSize = 20,
  }) {
    return _b.run(() {
      final q = filter.query.trim().toLowerCase();
      var items = _b.applications.values.where((a) {
        if (q.isNotEmpty &&
            !a.jobTitle.toLowerCase().contains(q) &&
            !a.companyName.toLowerCase().contains(q) &&
            !a.location.toLowerCase().contains(q)) {
          return false;
        }
        if (filter.statuses.isNotEmpty && !filter.statuses.contains(a.status)) {
          return false;
        }
        if (filter.arrangements.isNotEmpty &&
            !filter.arrangements.contains(a.workArrangement)) {
          return false;
        }
        final from = filter.appliedFrom;
        if (from != null && a.appliedDate.isBefore(DateHelpers.dayOnly(from))) {
          return false;
        }
        final to = filter.appliedTo;
        if (to != null && a.appliedDate.isAfter(DateHelpers.dayOnly(to))) {
          return false;
        }
        return true;
      }).toList();

      int byNewest(JobApplication a, JobApplication b) {
        final c = b.appliedDate.compareTo(a.appliedDate);
        return c != 0 ? c : b.id.compareTo(a.id);
      }

      items.sort(switch (filter.sort) {
        ApplicationSort.newest => byNewest,
        ApplicationSort.oldest => (a, b) => byNewest(b, a),
        ApplicationSort.companyAZ =>
          (a, b) => a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          ),
        ApplicationSort.status => (a, b) {
          final c = _statusRank(a.status).compareTo(_statusRank(b.status));
          return c != 0 ? c : byNewest(a, b);
        },
      });
      items = items
          .map((a) => _b.withoutDescription(_b.withNextInterview(a)))
          .toList();
      return _paginate(items, page, pageSize);
    });
  }

  @override
  Future<JobApplication> getById(int id) =>
      _b.run(() => _b.withNextInterview(_get(id)));

  @override
  Future<JobApplication> create(JobApplication application) {
    return _b.run(() {
      final id = _b.newApplicationId();
      final now = _b.now;
      final created = application.copyWith(
        id: id,
        status: ApplicationStatus.applied,
        createdAt: now,
        updatedAt: now,
        clearNextInterviewAt: true,
      );
      _b.applications[id] = created;
      _b.history.add(
        StatusHistoryEntry(
          id: _b.newHistoryId(),
          applicationId: id,
          toStatus: ApplicationStatus.applied,
          changedAt: now,
        ),
      );
      return created;
    });
  }

  @override
  Future<JobApplication> update(JobApplication application) {
    return _b.run(() {
      final current = _get(application.id);
      final updated = JobApplication(
        id: current.id,
        jobTitle: application.jobTitle,
        companyName: application.companyName,
        location: application.location,
        workArrangement: application.workArrangement,
        jobDescription: application.jobDescription,
        applicationLink: application.applicationLink,
        employmentType: application.employmentType,
        salaryRange: application.salaryRange,
        source: application.source,
        appliedDate: application.appliedDate,
        status: current.status,
        notes: application.notes,
        contactName: application.contactName,
        contactEmail: application.contactEmail,
        followUpAt: application.followUpAt,
        createdAt: current.createdAt,
        updatedAt: _b.now,
      );
      _b.applications[current.id] = updated;
      return _b.withNextInterview(updated);
    });
  }

  @override
  Future<void> delete(int id) {
    return _b.run(() {
      _get(id);
      _b.applications.remove(id);
      _b.history.removeWhere((h) => h.applicationId == id);
      _b.interviews.removeWhere((_, i) => i.applicationId == id);
    });
  }

  @override
  Future<StatusChangeResult> changeStatus(
    int id,
    ApplicationStatus status, {
    String? note,
  }) {
    return _b.run(() {
      final current = _get(id);
      if (current.status == status) {
        return StatusChangeResult(application: _b.withNextInterview(current));
      }
      final entry = StatusHistoryEntry(
        id: _b.newHistoryId(),
        applicationId: id,
        fromStatus: current.status,
        toStatus: status,
        changedAt: _b.now,
        note: note,
      );
      final updated = current.copyWith(status: status, updatedAt: _b.now);
      _b.applications[id] = updated;
      _b.history.add(entry);
      if (_b.settings.statusAlertsEnabled) {
        _b.notify(
          NotificationType.statusChange,
          'Moved to ${status.label}',
          '${current.companyName} · ${current.jobTitle}',
          applicationId: id,
        );
      }
      return StatusChangeResult(
        application: _b.withNextInterview(updated),
        history: entry,
      );
    });
  }

  List<StatusHistoryEntry> _history(int id) {
    _get(id);
    return _b.history.where((h) => h.applicationId == id).toList()
      ..sort((a, b) => a.changedAt.compareTo(b.changedAt));
  }

  @override
  Future<List<StatusHistoryEntry>> history(int id) =>
      _b.run(() => _history(id));

  @override
  Future<ApplicationTimeline> timeline(int id) {
    return _b.run(() {
      final interviews =
          _b.interviews.values
              .where((i) => i.applicationId == id)
              .map(_b.enrich)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return ApplicationTimeline(history: _history(id), interviews: interviews);
    });
  }
}

/// In-memory [InterviewRepository].
class FakeInterviewRepository implements InterviewRepository {
  /// Creates the repository over [_b].
  FakeInterviewRepository(this._b);

  final FakeBackend _b;

  Interview _get(int id) {
    final i = _b.interviews[id];
    if (i == null) throw _b.notFound();
    return i;
  }

  void _checkConflict(int applicationId, DateTime at, {int? excludeId}) {
    final clash = _b.interviews.values.any(
      (i) =>
          i.applicationId == applicationId &&
          i.id != excludeId &&
          i.scheduledAt.isAtSameMomentAs(at),
    );
    if (clash) {
      throw const ApiFailure(
        code: ApiCodes.interviewConflict,
        message: 'Interview already scheduled at this time',
        statusCode: 409,
      );
    }
  }

  @override
  Future<Page<Interview>> list({
    InterviewScope? scope,
    int? applicationId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) {
    return _b.run(() {
      final now = _b.now;
      final items =
          _b.interviews.values
              .where((i) {
                if (applicationId != null && i.applicationId != applicationId) {
                  return false;
                }
                if (scope == InterviewScope.upcoming &&
                    i.scheduledAt.isBefore(now)) {
                  return false;
                }
                if (scope == InterviewScope.past &&
                    !i.scheduledAt.isBefore(now)) {
                  return false;
                }
                if (from != null && i.scheduledAt.isBefore(from)) return false;
                if (to != null && i.scheduledAt.isAfter(to)) return false;
                return true;
              })
              .map(_b.enrich)
              .toList()
            ..sort(
              (a, b) => scope == InterviewScope.past
                  ? b.scheduledAt.compareTo(a.scheduledAt)
                  : a.scheduledAt.compareTo(b.scheduledAt),
            );
      return _paginate(items, page, pageSize);
    });
  }

  @override
  Future<Interview> getById(int id) => _b.run(() => _b.enrich(_get(id)));

  @override
  Future<Interview> create(int applicationId, Interview interview) {
    return _b.run(() {
      if (!_b.applications.containsKey(applicationId)) throw _b.notFound();
      _checkConflict(applicationId, interview.scheduledAt);
      final id = _b.newInterviewId();
      final created = interview.copyWith(
        id: id,
        applicationId: applicationId,
        outcome: InterviewOutcome.pending,
        createdAt: _b.now,
        updatedAt: _b.now,
      );
      _b.interviews[id] = created;
      return _b.enrich(created);
    });
  }

  @override
  Future<Interview> update(Interview interview) {
    return _b.run(() {
      final current = _get(interview.id);
      _checkConflict(
        current.applicationId,
        interview.scheduledAt,
        excludeId: current.id,
      );
      final updated = interview.copyWith(
        applicationId: current.applicationId,
        createdAt: current.createdAt,
        updatedAt: _b.now,
      );
      _b.interviews[current.id] = updated;
      return _b.enrich(updated);
    });
  }

  @override
  Future<void> delete(int id) {
    return _b.run(() {
      _get(id);
      _b.interviews.remove(id);
    });
  }
}

/// In-memory [NotificationRepository].
class FakeNotificationRepository implements NotificationRepository {
  /// Creates the repository over [_b].
  FakeNotificationRepository(this._b);

  final FakeBackend _b;

  int _index(int id) {
    final i = _b.notifications.indexWhere((n) => n.id == id);
    if (i < 0) throw _b.notFound();
    return i;
  }

  @override
  Future<Page<AppNotification>> list({int page = 1, int pageSize = 20}) {
    return _b.run(() {
      final items = [..._b.notifications]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return _paginate(items, page, pageSize);
    });
  }

  @override
  Future<int> unreadCount() =>
      _b.run(() => _b.notifications.where((n) => !n.isRead).length);

  @override
  Future<void> markRead(int id) {
    return _b.run(() {
      final i = _index(id);
      _b.notifications[i] = _b.notifications[i].copyWith(isRead: true);
    });
  }

  @override
  Future<void> markAllRead() {
    return _b.run(() {
      for (var i = 0; i < _b.notifications.length; i++) {
        _b.notifications[i] = _b.notifications[i].copyWith(isRead: true);
      }
    });
  }

  @override
  Future<void> delete(int id) =>
      _b.run(() => _b.notifications.removeAt(_index(id)));

  @override
  Future<void> clear() => _b.run(_b.notifications.clear);
}

/// In-memory [DashboardRepository].
class FakeDashboardRepository implements DashboardRepository {
  /// Creates the repository over [_b].
  FakeDashboardRepository(this._b);

  final FakeBackend _b;

  @override
  Future<DashboardData> load({required String timezone}) {
    return _b.run(() {
      final apps = _b.applications.values.toList();
      final counts = {
        for (final s in ApplicationStatus.values)
          s: apps.where((a) => a.status == s).length,
      };
      final thisWeek = DateHelpers.startOfWeek(_b.now);
      final weekly = [
        for (var w = 7; w >= 0; w--)
          () {
            final start = DateTime(
              thisWeek.year,
              thisWeek.month,
              thisWeek.day - 7 * w,
            );
            final end = DateTime(start.year, start.month, start.day + 7);
            return WeeklyCount(
              weekStart: start,
              count: apps
                  .where(
                    (a) =>
                        !a.appliedDate.isBefore(start) &&
                        a.appliedDate.isBefore(end),
                  )
                  .length,
            );
          }(),
      ];
      final upcoming =
          _b.interviews.values
              .where(
                (i) =>
                    i.scheduledAt.isAfter(_b.now) &&
                    i.outcome == InterviewOutcome.pending,
              )
              .map(_b.enrich)
              .toList()
            ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      final recent = _b.history.where((h) => h.fromStatus != null).toList()
        ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
      final responded = apps.where(
        (a) => a.status != ApplicationStatus.applied,
      );
      return DashboardData(
        total: apps.length,
        active: apps.where((a) => a.status.isActive).length,
        responseRatePercent: apps.isEmpty
            ? 0
            : (100 * responded.length / apps.length).round(),
        statusCounts: counts,
        weekly: weekly,
        upcomingInterviews: upcoming.take(3).toList(),
        recentActivity: recent
            .take(5)
            .where((h) => _b.applications.containsKey(h.applicationId))
            .map(
              (h) => RecentActivity(
                applicationId: h.applicationId,
                companyName: _b.applications[h.applicationId]!.companyName,
                toStatus: h.toStatus,
                changedAt: h.changedAt,
              ),
            )
            .toList(),
      );
    });
  }
}

/// In-memory [CalendarRepository].
class FakeCalendarRepository implements CalendarRepository {
  /// Creates the repository over [_b].
  FakeCalendarRepository(this._b);

  final FakeBackend _b;

  @override
  Future<List<CalendarEvent>> events({
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) {
    return _b.run(() {
      final start = DateHelpers.dayOnly(from);
      final end = DateHelpers.dayOnly(to);
      bool inRange(DateTime d) {
        final day = DateHelpers.dayOnly(d);
        return !day.isBefore(start) && !day.isAfter(end);
      }

      final events = <CalendarEvent>[];
      for (final a in _b.applications.values) {
        if (inRange(a.appliedDate)) {
          events.add(
            CalendarEvent(
              date: a.appliedDate,
              type: CalendarEventType.applied,
              applicationId: a.id,
              companyName: a.companyName,
              title: a.jobTitle,
            ),
          );
        }
        final followUp = a.followUpAt;
        if (followUp != null && inRange(followUp)) {
          events.add(
            CalendarEvent(
              date: DateHelpers.dayOnly(followUp),
              type: CalendarEventType.followUp,
              applicationId: a.id,
              companyName: a.companyName,
              title: a.jobTitle,
              at: followUp,
            ),
          );
        }
      }
      for (final h in _b.history.where((h) => h.fromStatus != null)) {
        final a = _b.applications[h.applicationId];
        if (a != null && inRange(h.changedAt)) {
          events.add(
            CalendarEvent(
              date: DateHelpers.dayOnly(h.changedAt),
              type: CalendarEventType.statusChange,
              applicationId: a.id,
              companyName: a.companyName,
              title: a.jobTitle,
              status: h.toStatus,
              at: h.changedAt,
            ),
          );
        }
      }
      for (final i in _b.interviews.values.map(_b.enrich)) {
        if (inRange(i.scheduledAt)) {
          events.add(
            CalendarEvent(
              date: DateHelpers.dayOnly(i.scheduledAt),
              type: CalendarEventType.interview,
              applicationId: i.applicationId,
              interviewId: i.id,
              companyName: i.companyName ?? '',
              title: i.title,
              interviewType: i.type,
              at: i.scheduledAt,
            ),
          );
        }
      }
      events.sort((a, b) => a.date.compareTo(b.date));
      return events;
    });
  }
}

/// In-memory [ReminderRepository].
class FakeReminderRepository implements ReminderRepository {
  /// Creates the repository over [_b].
  FakeReminderRepository(this._b);

  final FakeBackend _b;

  @override
  Future<List<ReminderItem>> upcoming() {
    return _b.run(() {
      final now = _b.now;
      final horizon = now.add(const Duration(days: 60));
      final items = <ReminderItem>[];
      if (_b.settings.interviewRemindersEnabled) {
        for (final i in _b.interviews.values.map(_b.enrich)) {
          if (i.outcome != InterviewOutcome.pending) continue;
          for (final offset in i.reminderOffsets) {
            final fireAt = i.scheduledAt.subtract(offset);
            if (!fireAt.isAfter(now) || fireAt.isAfter(horizon)) continue;
            items.add(
              ReminderItem(
                key: 'interview:${i.id}:${offset.inMinutes}',
                kind: ReminderKind.interviewReminder,
                fireAt: fireAt,
                title: 'Upcoming interview',
                body: '${i.companyName} · ${i.title}',
                applicationId: i.applicationId,
                interviewId: i.id,
              ),
            );
          }
        }
      }
      if (_b.settings.followUpRemindersEnabled) {
        for (final a in _b.applications.values) {
          final at = a.followUpAt;
          if (at == null || !at.isAfter(now) || at.isAfter(horizon)) continue;
          items.add(
            ReminderItem(
              key: 'followUp:${a.id}',
              kind: ReminderKind.followUpReminder,
              fireAt: at,
              title: 'Time to follow up',
              body: '${a.companyName} · ${a.jobTitle}',
              applicationId: a.id,
            ),
          );
        }
      }
      items.sort((a, b) => a.fireAt.compareTo(b.fireAt));
      return items;
    });
  }
}

/// In-memory [DataRepository].
class FakeDataRepository implements DataRepository {
  /// Creates the repository over [_b].
  FakeDataRepository(this._b);

  final FakeBackend _b;

  String _csvCell(Object? v) {
    final s = v == null ? '' : '$v';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  @override
  Future<List<int>> export(ExportFormat format, {String timezone = 'UTC'}) {
    return _b.run(() {
      final apps = _b.applications.values.toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      if (format == ExportFormat.csv) {
        const columns = [
          'jobTitle',
          'companyName',
          'location',
          'workArrangement',
          'employmentType',
          'salaryRange',
          'source',
          'appliedDate',
          'status',
          'applicationLink',
          'contactName',
          'contactEmail',
          'notes',
        ];
        final rows = [
          columns.join(','),
          for (final a in apps)
            columns
                .map(
                  (c) => _csvCell(
                    a.toJson()[c] ?? (c == 'status' ? a.status.name : null),
                  ),
                )
                .join(','),
        ];
        return utf8.encode(rows.join('\n'));
      }
      final dump = {
        'exportedAt': ApiDate.toUtcIso(_b.now),
        'applications': [
          for (final a in apps)
            {
              'id': a.id,
              ...a.toJson(),
              'status': a.status.name,
              'history': [
                for (final h in _b.history.where(
                  (h) => h.applicationId == a.id,
                ))
                  h.toJson(),
              ],
              'interviews': [
                for (final i in _b.interviews.values.where(
                  (i) => i.applicationId == a.id,
                ))
                  {'id': i.id, ...i.toJson()},
              ],
            },
        ],
      };
      return utf8.encode(const JsonEncoder.withIndent('  ').convert(dump));
    });
  }

  @override
  Future<void> deleteAllData() => _b.run(_b.clearData);
}
