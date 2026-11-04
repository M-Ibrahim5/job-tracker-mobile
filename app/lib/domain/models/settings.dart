import 'package:flutter/foundation.dart';

import '../enums/enums.dart';

/// Per-user preferences (`Settings` in `API.md`).
class Settings {
  /// Creates immutable settings.
  const Settings({
    this.theme = ThemeSetting.system,
    this.interviewRemindersEnabled = true,
    this.followUpRemindersEnabled = true,
    this.statusAlertsEnabled = true,
    this.defaultReminderOffsets = const [Duration(days: 1), Duration(hours: 1)],
    this.defaultFollowUpDays = 7,
  });

  /// Parses API settings.
  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    theme: enumByName(ThemeSetting.values, json['theme'] as String),
    interviewRemindersEnabled: json['interviewRemindersEnabled'] as bool,
    followUpRemindersEnabled: json['followUpRemindersEnabled'] as bool,
    statusAlertsEnabled: json['statusAlertsEnabled'] as bool,
    defaultReminderOffsets: (json['defaultReminderOffsetsMinutes'] as List)
        .map((m) => Duration(minutes: m as int))
        .toList(),
    defaultFollowUpDays: json['defaultFollowUpDays'] as int?,
  );

  final ThemeSetting theme;
  final bool interviewRemindersEnabled;
  final bool followUpRemindersEnabled;
  final bool statusAlertsEnabled;
  final List<Duration> defaultReminderOffsets;

  /// Null means follow-up reminders default to off; otherwise 3/5/7/14.
  final int? defaultFollowUpDays;

  /// Returns a copy with the given fields replaced. [clearFollowUpDays] sets
  /// [defaultFollowUpDays] to null.
  Settings copyWith({
    ThemeSetting? theme,
    bool? interviewRemindersEnabled,
    bool? followUpRemindersEnabled,
    bool? statusAlertsEnabled,
    List<Duration>? defaultReminderOffsets,
    int? defaultFollowUpDays,
    bool clearFollowUpDays = false,
  }) {
    return Settings(
      theme: theme ?? this.theme,
      interviewRemindersEnabled:
          interviewRemindersEnabled ?? this.interviewRemindersEnabled,
      followUpRemindersEnabled:
          followUpRemindersEnabled ?? this.followUpRemindersEnabled,
      statusAlertsEnabled: statusAlertsEnabled ?? this.statusAlertsEnabled,
      defaultReminderOffsets:
          defaultReminderOffsets ?? this.defaultReminderOffsets,
      defaultFollowUpDays: clearFollowUpDays
          ? null
          : (defaultFollowUpDays ?? this.defaultFollowUpDays),
    );
  }

  /// JSON mirror of the API representation.
  Map<String, dynamic> toJson() => {
    'theme': theme.name,
    'interviewRemindersEnabled': interviewRemindersEnabled,
    'followUpRemindersEnabled': followUpRemindersEnabled,
    'statusAlertsEnabled': statusAlertsEnabled,
    'defaultReminderOffsetsMinutes': defaultReminderOffsets
        .map((d) => d.inMinutes)
        .toList(),
    'defaultFollowUpDays': defaultFollowUpDays,
  };

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.theme == theme &&
      other.interviewRemindersEnabled == interviewRemindersEnabled &&
      other.followUpRemindersEnabled == followUpRemindersEnabled &&
      other.statusAlertsEnabled == statusAlertsEnabled &&
      other.defaultFollowUpDays == defaultFollowUpDays &&
      listEquals(other.defaultReminderOffsets, defaultReminderOffsets);

  @override
  int get hashCode => Object.hash(
    theme,
    interviewRemindersEnabled,
    followUpRemindersEnabled,
    statusAlertsEnabled,
    defaultFollowUpDays,
    Object.hashAll(defaultReminderOffsets),
  );
}
