package com.jobtrail.tracker.interviews;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.db.UpdateBuilder;
import com.jobtrail.common.json.IntList;
import com.jobtrail.common.model.InterviewOutcome;
import com.jobtrail.common.model.InterviewType;
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
public class InterviewRepository {

  /** List filter: {@code lowerInclusive <= scheduled_at < upperExclusive}; either bound may be null. */
  public record Filter(Long applicationId, Instant lowerInclusive, Instant upperExclusive, boolean descending) {}

  /** Field name in the API body to column; only these can be patched. */
  private static final Map<String, String> COLUMNS = Map.of(
      "title", "title",
      "type", "type",
      "scheduledAt", "scheduled_at",
      "durationMinutes", "duration_minutes",
      "locationOrLink", "location_or_link",
      "interviewerName", "interviewer_name",
      "notes", "notes",
      "outcome", "outcome");

  private static final String SELECT = """
      SELECT i.*, a.job_title AS application_title, a.company_name AS company_name
      FROM interviews i JOIN job_applications a ON a.id = i.application_id""";

  private static final RowMapper<InterviewRow> MAPPER = (rs, n) -> new InterviewRow(
      rs.getLong("id"),
      rs.getLong("application_id"),
      rs.getString("application_title"),
      rs.getString("company_name"),
      rs.getString("title"),
      InterviewType.valueOf(rs.getString("type")),
      Db.instant(rs, "scheduled_at"),
      rs.getInt("duration_minutes"),
      rs.getString("location_or_link"),
      rs.getString("interviewer_name"),
      rs.getString("notes"),
      IntList.fromJson(rs.getString("reminder_offsets")),
      InterviewOutcome.valueOf(rs.getString("outcome")),
      Db.instant(rs, "created_at"),
      Db.instant(rs, "updated_at"));

  private final JdbcClient jdbc;

  public InterviewRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public Optional<InterviewRow> find(long userId, long id) {
    return jdbc.sql(SELECT + " WHERE i.id = :id AND i.user_id = :user")
        .param("id", id)
        .param("user", userId)
        .query(MAPPER)
        .optional();
  }

  private static String where(Filter f, Map<String, Object> params, long userId) {
    StringBuilder sql = new StringBuilder("i.user_id = :user");
    params.put("user", userId);
    if (f.applicationId() != null) {
      sql.append(" AND i.application_id = :app");
      params.put("app", f.applicationId());
    }
    if (f.lowerInclusive() != null) {
      sql.append(" AND i.scheduled_at >= :lo");
      params.put("lo", Db.ts(f.lowerInclusive()));
    }
    if (f.upperExclusive() != null) {
      sql.append(" AND i.scheduled_at < :hi");
      params.put("hi", Db.ts(f.upperExclusive()));
    }
    return sql.toString();
  }

  public List<InterviewRow> list(long userId, Filter f, int limit, int offset) {
    Map<String, Object> params = new LinkedHashMap<>();
    String where = where(f, params, userId);
    String dir = f.descending() ? "DESC" : "ASC";
    params.put("limit", limit);
    params.put("offset", offset);
    return jdbc.sql(SELECT + " WHERE " + where + " ORDER BY i.scheduled_at " + dir + ", i.id " + dir
            + " LIMIT :limit OFFSET :offset")
        .params(params)
        .query(MAPPER)
        .list();
  }

  public long count(long userId, Filter f) {
    Map<String, Object> params = new LinkedHashMap<>();
    String where = where(f, params, userId);
    return jdbc.sql("SELECT COUNT(*) FROM interviews i WHERE " + where)
        .params(params)
        .query(Long.class)
        .single();
  }

  public List<InterviewRow> forApplication(long userId, long applicationId) {
    return jdbc.sql(SELECT + " WHERE i.user_id = :user AND i.application_id = :app ORDER BY i.scheduled_at ASC, i.id ASC")
        .param("user", userId)
        .param("app", applicationId)
        .query(MAPPER)
        .list();
  }

  public Map<Long, List<InterviewRow>> forApplications(long userId, List<Long> applicationIds) {
    Map<Long, List<InterviewRow>> byApplication = new LinkedHashMap<>();
    if (applicationIds.isEmpty()) {
      return byApplication;
    }
    List<InterviewRow> rows = jdbc.sql(SELECT
            + " WHERE i.user_id = :user AND i.application_id IN (:ids) ORDER BY i.scheduled_at ASC, i.id ASC")
        .param("user", userId)
        .param("ids", applicationIds)
        .query(MAPPER)
        .list();
    for (InterviewRow row : rows) {
      byApplication.computeIfAbsent(row.applicationId(), k -> new ArrayList<>()).add(row);
    }
    return byApplication;
  }

  /** Pending interviews at or after {@code now}, soonest first. */
  public List<InterviewRow> upcomingPending(long userId, Instant now, int limit) {
    return jdbc.sql(SELECT + " " + """
             WHERE i.user_id = :user AND i.outcome = 'pending' AND i.scheduled_at >= :now
             ORDER BY i.scheduled_at ASC, i.id ASC LIMIT :limit""")
        .param("user", userId)
        .param("now", Db.ts(now))
        .param("limit", limit)
        .query(MAPPER)
        .list();
  }

  /** Pending interviews strictly after {@code now} (the reminder candidates). */
  public List<InterviewRow> pendingAfter(long userId, Instant now) {
    return jdbc.sql(SELECT + " WHERE i.user_id = :user AND i.outcome = 'pending' AND i.scheduled_at > :now")
        .param("user", userId)
        .param("now", Db.ts(now))
        .query(MAPPER)
        .list();
  }

  /** Every interview with {@code lo <= scheduled_at < hi}. */
  public List<InterviewRow> between(long userId, Instant lo, Instant hi) {
    return jdbc.sql(SELECT + " WHERE i.user_id = :user AND i.scheduled_at >= :lo AND i.scheduled_at < :hi")
        .param("user", userId)
        .param("lo", Db.ts(lo))
        .param("hi", Db.ts(hi))
        .query(MAPPER)
        .list();
  }

  /** Inserts the row; a second interview at the same instant raises {@code DuplicateKeyException}. */
  public long insert(long userId, long applicationId, Map<String, Object> v, List<Integer> offsets) {
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO interviews
              (user_id, application_id, title, type, scheduled_at, duration_minutes, location_or_link,
               interviewer_name, notes, reminder_offsets, outcome)
            VALUES
              (:user, :app, :title, :type, :scheduledAt, :duration, :locationOrLink,
               :interviewerName, :notes, CAST(:offsets AS JSON), :outcome)""")
        .param("user", userId)
        .param("app", applicationId)
        .param("title", v.get("title"))
        .param("type", Db.param(v.get("type")))
        .param("scheduledAt", Db.param(v.get("scheduledAt")))
        .param("duration", v.get("durationMinutes"))
        .param("locationOrLink", v.get("locationOrLink"))
        .param("interviewerName", v.get("interviewerName"))
        .param("notes", v.get("notes"))
        .param("offsets", IntList.toJson(offsets))
        .param("outcome", Db.param(v.get("outcome")))
        .update(keys);
    return keys.getKey().longValue();
  }

  /** Applies the patched fields in {@code v}; a clash on (application, time) raises DuplicateKeyException. */
  public void update(long id, Map<String, Object> v, List<Integer> offsets) {
    UpdateBuilder update = UpdateBuilder.table("interviews");
    COLUMNS.forEach((field, column) -> {
      if (v.containsKey(field)) {
        update.set(column, v.get(field));
      }
    });
    if (offsets != null) {
      update.setJson("reminder_offsets", IntList.toJson(offsets));
    }
    update.execute(jdbc, "id = :id", Map.of("id", id));
  }

  public int delete(long userId, long id) {
    return jdbc.sql("DELETE FROM interviews WHERE id = :id AND user_id = :user")
        .param("id", id)
        .param("user", userId)
        .update();
  }
}
