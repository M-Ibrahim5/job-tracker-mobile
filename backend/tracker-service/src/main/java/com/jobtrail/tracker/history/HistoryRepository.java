package com.jobtrail.tracker.history;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.model.ApplicationStatus;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

@Repository
public class HistoryRepository {

  /** A history row together with the application it belongs to (calendar, dashboard). */
  public record WithApplication(HistoryRow history, String companyName, String jobTitle) {}

  private static final RowMapper<HistoryRow> MAPPER = (rs, i) -> new HistoryRow(
      rs.getLong("id"),
      rs.getLong("application_id"),
      status(rs.getString("from_status")),
      ApplicationStatus.valueOf(rs.getString("to_status")),
      Db.instant(rs, "changed_at"),
      rs.getString("note"));

  private static final RowMapper<WithApplication> JOINED = (rs, i) ->
      new WithApplication(MAPPER.mapRow(rs, i), rs.getString("company_name"), rs.getString("job_title"));

  private static ApplicationStatus status(String value) {
    return value == null ? null : ApplicationStatus.valueOf(value);
  }

  /** Most status changes returned for one application. */
  public static final int MAX_PER_APPLICATION = 200;
  /** Most status changes returned for one calendar range. */
  public static final int MAX_PER_RANGE = 1000;

  private final JdbcClient jdbc;

  public HistoryRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public long insert(long userId, long applicationId, ApplicationStatus from, ApplicationStatus to,
      Instant changedAt, String note) {
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO status_history (user_id, application_id, from_status, to_status, changed_at, note)
            VALUES (:user, :app, :from, :to, :at, :note)""")
        .param("user", userId)
        .param("app", applicationId)
        .param("from", from == null ? null : from.name())
        .param("to", to.name())
        .param("at", Db.ts(changedAt))
        .param("note", note)
        .update(keys);
    return keys.getKey().longValue();
  }

  public HistoryRow get(long userId, long id) {
    return jdbc.sql("SELECT * FROM status_history WHERE id = :id AND user_id = :user")
        .param("id", id)
        .param("user", userId)
        .query(MAPPER)
        .single();
  }

  /** Oldest first. */
  public List<HistoryRow> forApplication(long userId, long applicationId) {
    return jdbc.sql("""
            SELECT * FROM status_history WHERE user_id = :user AND application_id = :app
            ORDER BY changed_at ASC, id ASC LIMIT :limit""")
        .param("user", userId)
        .param("app", applicationId)
        .param("limit", MAX_PER_APPLICATION)
        .query(MAPPER)
        .list();
  }

  public Optional<HistoryRow> latest(long userId, long applicationId) {
    return jdbc.sql("""
            SELECT * FROM status_history WHERE user_id = :user AND application_id = :app
            ORDER BY changed_at DESC, id DESC LIMIT 1""")
        .param("user", userId)
        .param("app", applicationId)
        .query(MAPPER)
        .optional();
  }

  /** Latest status changes (initial entries excluded), newest first. */
  public List<WithApplication> recentChanges(long userId, int limit) {
    return jdbc.sql("""
            SELECT h.*, a.company_name, a.job_title FROM status_history h
            JOIN job_applications a ON a.id = h.application_id
            WHERE h.user_id = :user AND h.from_status IS NOT NULL
            ORDER BY h.changed_at DESC, h.id DESC LIMIT :limit""")
        .param("user", userId)
        .param("limit", limit)
        .query(JOINED)
        .list();
  }

  /** Status changes (initial entries excluded) with {@code lo <= changed_at < hi}. */
  public List<WithApplication> changesBetween(long userId, Instant lo, Instant hi) {
    return jdbc.sql("""
            SELECT h.*, a.company_name, a.job_title FROM status_history h
            JOIN job_applications a ON a.id = h.application_id
            WHERE h.user_id = :user AND h.from_status IS NOT NULL
              AND h.changed_at >= :lo AND h.changed_at < :hi
            ORDER BY h.changed_at ASC, h.id ASC LIMIT :limit""")
        .param("user", userId)
        .param("lo", Db.ts(lo))
        .param("hi", Db.ts(hi))
        .param("limit", MAX_PER_RANGE)
        .query(JOINED)
        .list();
  }

  public Map<Long, List<HistoryRow>> forApplications(long userId, List<Long> applicationIds) {
    Map<Long, List<HistoryRow>> byApplication = new LinkedHashMap<>();
    if (applicationIds.isEmpty()) {
      return byApplication;
    }
    List<HistoryRow> rows = jdbc.sql("""
            SELECT * FROM status_history WHERE user_id = :user AND application_id IN (:ids)
            ORDER BY changed_at ASC, id ASC""")
        .param("user", userId)
        .param("ids", applicationIds)
        .query(MAPPER)
        .list();
    for (HistoryRow row : rows) {
      byApplication.computeIfAbsent(row.applicationId(), k -> new ArrayList<>()).add(row);
    }
    return byApplication;
  }
}
