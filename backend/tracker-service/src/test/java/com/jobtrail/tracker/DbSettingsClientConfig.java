package com.jobtrail.tracker;

import com.jobtrail.common.json.IntList;
import com.jobtrail.tracker.settings.ReminderPrefs;
import com.jobtrail.tracker.settings.UserSettingsClient;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;

/** Replaces the HTTP call to the user service with a read of the {@code user_settings} test rows. */
@TestConfiguration
class DbSettingsClientConfig {

  @Bean
  @Primary
  UserSettingsClient dbSettingsClient(JdbcTemplate jdbc) {
    return userId -> jdbc.query("SELECT * FROM user_settings WHERE user_id = ?", rs -> {
      if (!rs.next()) {
        return ReminderPrefs.DEFAULTS;
      }
      Object days = rs.getObject("default_followup_days");
      return new ReminderPrefs(
          rs.getBoolean("interview_reminders_enabled"),
          rs.getBoolean("followup_reminders_enabled"),
          rs.getBoolean("status_alerts_enabled"),
          IntList.fromJson(rs.getString("default_reminder_offsets")),
          days == null ? null : ((Number) days).intValue());
    }, userId);
  }
}
