package com.jobtrail.user.settings;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.db.UpdateBuilder;
import com.jobtrail.common.json.IntList;
import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class SettingsRepository {

  static final List<Integer> DEFAULT_OFFSETS = List.of(1440, 60);
  static final int DEFAULT_FOLLOW_UP_DAYS = 7;

  private static final RowMapper<SettingsDto> MAPPER = (rs, i) -> new SettingsDto(
      rs.getString("theme"),
      rs.getBoolean("interview_reminders_enabled"),
      rs.getBoolean("followup_reminders_enabled"),
      rs.getBoolean("status_alerts_enabled"),
      IntList.fromJson(rs.getString("default_reminder_offsets")),
      Db.nullableInt(rs, "default_followup_days"));

  private final JdbcClient jdbc;

  public SettingsRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** Creates the default row for users that somehow lack one (idempotent). */
  public void ensure(long userId) {
    jdbc.sql("""
            INSERT IGNORE INTO user_settings (user_id, default_reminder_offsets, default_followup_days)
            VALUES (:user, CAST(:offsets AS JSON), :days)""")
        .param("user", userId)
        .param("offsets", IntList.toJson(DEFAULT_OFFSETS))
        .param("days", DEFAULT_FOLLOW_UP_DAYS)
        .update();
  }

  public SettingsDto find(long userId) {
    return jdbc.sql("SELECT * FROM user_settings WHERE user_id = :user")
        .param("user", userId)
        .query(MAPPER)
        .single();
  }

  public void update(long userId, UpdateBuilder update) {
    update.execute(jdbc, "user_id = :user", Map.of("user", userId));
  }
}
