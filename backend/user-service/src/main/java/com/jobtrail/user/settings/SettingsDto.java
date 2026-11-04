package com.jobtrail.user.settings;

import java.util.List;

/** The {@code Settings} object of docs/API.md. Also served to other services on /internal. */
public record SettingsDto(
    String theme,
    boolean interviewRemindersEnabled,
    boolean followUpRemindersEnabled,
    boolean statusAlertsEnabled,
    List<Integer> defaultReminderOffsetsMinutes,
    Integer defaultFollowUpDays) {}
