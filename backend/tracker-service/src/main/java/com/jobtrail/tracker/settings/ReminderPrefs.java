package com.jobtrail.tracker.settings;

import java.util.List;

/** The slice of a user's settings that drives reminders, alerts and defaults. */
public record ReminderPrefs(
    boolean interviewRemindersEnabled,
    boolean followUpRemindersEnabled,
    boolean statusAlertsEnabled,
    List<Integer> defaultReminderOffsetsMinutes,
    Integer defaultFollowUpDays) {

  /** What a brand-new account gets (docs/DATABASE.md). */
  public static final ReminderPrefs DEFAULTS = new ReminderPrefs(true, true, true, List.of(1440, 60), 7);
}
