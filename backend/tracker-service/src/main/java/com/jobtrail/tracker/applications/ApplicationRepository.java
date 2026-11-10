package com.jobtrail.tracker.applications;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.db.UpdateBuilder;
import com.jobtrail.common.model.ApplicationStatus;
import com.jobtrail.common.model.EmploymentType;
import com.jobtrail.common.model.JobSource;
import com.jobtrail.common.model.WorkArrangement;
import java.time.Instant;
import java.time.LocalDate;
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
public class ApplicationRepository {

  public enum Sort {
    newest,
    oldest,
    companyAZ,
    status
  }

  public record Filter(String q, List<ApplicationStatus> status, List<WorkArrangement> arrangement,
      LocalDate from, LocalDate to, Sort sort) {}

  /** API field to column, for fields a client may set (status has its own endpoint). */
  private static final Map<String, String> COLUMNS = Map.ofEntries(
      Map.entry("jobTitle", "job_title"),
      Map.entry("companyName", "company_name"),
      Map.entry("location", "location"),
      Map.entry("workArrangement", "work_arrangement"),
      Map.entry("jobDescription", "job_description"),
      Map.entry("applicationLink", "application_link"),
      Map.entry("employmentType", "employment_type"),
      Map.entry("salaryRange", "salary_range"),
      Map.entry("source", "source"),
      Map.entry("appliedDate", "applied_date"),
      Map.entry("notes", "notes"),
      Map.entry("contactName", "contact_name"),
      Map.entry("contactEmail", "contact_email"),
      Map.entry("followUpAt", "follow_up_at"));

  private static final String NEXT_INTERVIEW = """
      (SELECT MIN(i.scheduled_at) FROM interviews i
        WHERE i.application_id = a.id AND i.outcome = 'pending' AND i.scheduled_at > :now) AS next_interview_at""";

  private static final String COLUMN_LIST = """
      a.id, a.job_title, a.company_name, a.location, a.work_arrangement, %s AS job_description,
      a.application_link, a.employment_type, a.salary_range, a.source, a.applied_date, a.status, a.notes,
      a.contact_name, a.contact_email, a.follow_up_at, a.created_at, a.updated_at, """ + NEXT_INTERVIEW;

  /** Lists skip the (potentially large) job description. */
  private static final String LIGHT = "SELECT " + COLUMN_LIST.formatted("NULL") + " FROM job_applications a";
  private static final String FULL = "SELECT " + COLUMN_LIST.formatted("a.job_description") + " FROM job_applications a";

  private static final RowMapper<ApplicationRow> MAPPER = (rs, n) -> new ApplicationRow(
      rs.getLong("id"),
      rs.getString("job_title"),
      rs.getString("company_name"),
      rs.getString("location"),
      WorkArrangement.valueOf(rs.getString("work_arrangement")),
      rs.getString("job_description"),
      rs.getString("application_link"),
      enumOrNull(EmploymentType.class, rs.getString("employment_type")),
      rs.getString("salary_range"),
      enumOrNull(JobSource.class, rs.getString("source")),
      Db.date(rs, "applied_date"),
      ApplicationStatus.valueOf(rs.getString("status")),
      rs.getString("notes"),
      rs.getString("contact_name"),
      rs.getString("contact_email"),
      Db.instant(rs, "follow_up_at"),
      Db.instant(rs, "next_interview_at"),
      Db.instant(rs, "created_at"),
      Db.instant(rs, "updated_at"));

  private static <E extends Enum<E>> E enumOrNull(Class<E> type, String value) {
    return value == null ? null : Enum.valueOf(type, value);
  }

  /** Most applications returned by one calendar or reminder range query. */
  public static final int MAX_PER_RANGE = 1000;

  private final JdbcClient jdbc;

  public ApplicationRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public Optional<ApplicationRow> find(long userId, long id, Instant now) {
    return jdbc.sql(FULL + " WHERE a.id = :id AND a.user_id = :user")
        .param("id", id)
        .param("user", userId)
        .param("now", Db.ts(now))
        .query(MAPPER)
        .optional();
  }

  /** {@code %}, {@code _} and the escape character itself are matched literally. */
  private static String likePattern(String q) {
    return "%" + q.replace("|", "||").replace("%", "|%").replace("_", "|_") + "%";
  }

  private static String where(long userId, Filter f, Map<String, Object> params) {
    StringBuilder sql = new StringBuilder("a.user_id = :user");
    params.put("user", userId);
    if (f.q() != null) {
      sql.append(" AND (a.job_title LIKE :q ESCAPE '|' OR a.company_name LIKE :q ESCAPE '|'"
          + " OR a.location LIKE :q ESCAPE '|')");
      params.put("q", likePattern(f.q()));
    }
    if (!f.status().isEmpty()) {
      sql.append(" AND a.status IN (:status)");
      params.put("status", f.status().stream().map(Enum::name).toList());
    }
    if (!f.arrangement().isEmpty()) {
      sql.append(" AND a.work_arrangement IN (:arrangement)");
      params.put("arrangement", f.arrangement().stream().map(Enum::name).toList());
    }
    if (f.from() != null) {
      sql.append(" AND a.applied_date >= :from");
      params.put("from", f.from());
    }
    if (f.to() != null) {
      sql.append(" AND a.applied_date <= :to");
      params.put("to", f.to());
    }
    return sql.toString();
  }

  private static String orderBy(Sort sort) {
    return switch (sort) {
      case oldest -> "a.applied_date ASC, a.id ASC";
      case companyAZ -> "a.company_name ASC, a.id ASC";
      // MySQL ENUM columns sort by declaration order, which is the pipeline order.
      case status -> "a.status ASC, a.applied_date DESC, a.id DESC";
      case newest -> "a.applied_date DESC, a.id DESC";
    };
  }

  public List<ApplicationRow> list(long userId, Filter f, int limit, int offset, Instant now) {
    Map<String, Object> params = new LinkedHashMap<>();
    String where = where(userId, f, params);
    params.put("now", Db.ts(now));
    params.put("limit", limit);
    params.put("offset", offset);
    return jdbc.sql(LIGHT + " WHERE " + where + " ORDER BY " + orderBy(f.sort()) + " LIMIT :limit OFFSET :offset")
        .params(params)
        .query(MAPPER)
        .list();
  }

  public long count(long userId, Filter f) {
    Map<String, Object> params = new LinkedHashMap<>();
    String where = where(userId, f, params);
    return jdbc.sql("SELECT COUNT(*) FROM job_applications a WHERE " + where)
        .params(params)
        .query(Long.class)
        .single();
  }

  /** Full rows with {@code id > afterId}, ascending: the export walks the table in keyset pages. */
  public List<ApplicationRow> pageAfter(long userId, long afterId, int limit, Instant now) {
    return jdbc.sql(FULL + " WHERE a.user_id = :user AND a.id > :after ORDER BY a.id ASC LIMIT :limit")
        .param("user", userId)
        .param("after", afterId)
        .param("limit", limit)
        .param("now", Db.ts(now))
        .query(MAPPER)
        .list();
  }

  public List<ApplicationRow> appliedBetween(long userId, LocalDate from, LocalDate to) {
    return jdbc.sql(LIGHT + " WHERE a.user_id = :user AND a.applied_date >= :from AND a.applied_date <= :to"
            + " ORDER BY a.applied_date ASC, a.id ASC LIMIT :limit")
        .param("limit", MAX_PER_RANGE)
        .param("user", userId)
        .param("from", from)
        .param("to", to)
        .param("now", Db.ts(Instant.now()))
        .query(MAPPER)
        .list();
  }

  /** Applications whose follow-up falls in {@code lo <= follow_up_at < hi}. */
  public List<ApplicationRow> followUpsBetween(long userId, Instant lo, Instant hi) {
    return jdbc.sql(LIGHT + " WHERE a.user_id = :user AND a.follow_up_at >= :lo AND a.follow_up_at < :hi"
            + " ORDER BY a.follow_up_at ASC, a.id ASC LIMIT :limit")
        .param("limit", MAX_PER_RANGE)
        .param("user", userId)
        .param("lo", Db.ts(lo))
        .param("hi", Db.ts(hi))
        .param("now", Db.ts(Instant.now()))
        .query(MAPPER)
        .list();
  }

  /** Applications with {@code after < follow_up_at <= upTo}. */
  public List<ApplicationRow> followUpsAfter(long userId, Instant after, Instant upTo) {
    return jdbc.sql(LIGHT + " WHERE a.user_id = :user AND a.follow_up_at > :after AND a.follow_up_at <= :upTo"
            + " ORDER BY a.follow_up_at ASC, a.id ASC LIMIT :limit")
        .param("limit", MAX_PER_RANGE)
        .param("user", userId)
        .param("after", Db.ts(after))
        .param("upTo", Db.ts(upTo))
        .param("now", Db.ts(Instant.now()))
        .query(MAPPER)
        .list();
  }

  public Map<ApplicationStatus, Long> countByStatus(long userId) {
    Map<ApplicationStatus, Long> counts = new LinkedHashMap<>();
    jdbc.sql("SELECT status, COUNT(*) AS c FROM job_applications WHERE user_id = :user GROUP BY status")
        .param("user", userId)
        .query((rs, n) -> {
          counts.put(ApplicationStatus.valueOf(rs.getString("status")), rs.getLong("c"));
          return null;
        })
        .list();
    return counts;
  }

  /** Applications per Monday-start week since {@code firstWeek}, aggregated in SQL. */
  public Map<LocalDate, Long> countByWeek(long userId, LocalDate firstWeek) {
    Map<LocalDate, Long> counts = new LinkedHashMap<>();
    jdbc.sql("""
            SELECT DATE_SUB(applied_date, INTERVAL WEEKDAY(applied_date) DAY) AS week_start, COUNT(*) AS c
            FROM job_applications
            WHERE user_id = :user AND applied_date >= :first
            GROUP BY week_start""")
        .param("user", userId)
        .param("first", firstWeek)
        .query((rs, n) -> {
          counts.put(Db.date(rs, "week_start"), rs.getLong("c"));
          return null;
        })
        .list();
    return counts;
  }

  public long insert(long userId, Map<String, Object> v, ApplicationStatus status, Instant followUpAt) {
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("""
            INSERT INTO job_applications
              (user_id, job_title, company_name, location, work_arrangement, job_description, application_link,
               employment_type, salary_range, source, applied_date, status, notes, contact_name, contact_email,
               follow_up_at)
            VALUES
              (:user, :jobTitle, :companyName, :location, :workArrangement, :jobDescription, :applicationLink,
               :employmentType, :salaryRange, :source, :appliedDate, :status, :notes, :contactName, :contactEmail,
               :followUpAt)""")
        .param("user", userId)
        .param("jobTitle", v.get("jobTitle"))
        .param("companyName", v.get("companyName"))
        .param("location", v.get("location"))
        .param("workArrangement", Db.param(v.get("workArrangement")))
        .param("jobDescription", v.get("jobDescription"))
        .param("applicationLink", v.get("applicationLink"))
        .param("employmentType", Db.param(v.get("employmentType")))
        .param("salaryRange", v.get("salaryRange"))
        .param("source", Db.param(v.get("source")))
        .param("appliedDate", v.get("appliedDate"))
        .param("status", status.name())
        .param("notes", v.get("notes"))
        .param("contactName", v.get("contactName"))
        .param("contactEmail", v.get("contactEmail"))
        .param("followUpAt", Db.ts(followUpAt))
        .update(keys);
    return keys.getKey().longValue();
  }

  public void update(long id, Map<String, Object> v) {
    UpdateBuilder update = UpdateBuilder.table("job_applications");
    COLUMNS.forEach((field, column) -> {
      if (v.containsKey(field)) {
        update.set(column, v.get(field));
      }
    });
    update.execute(jdbc, "id = :id", Map.of("id", id));
  }

  public void updateStatus(long id, ApplicationStatus status) {
    jdbc.sql("UPDATE job_applications SET status = :status WHERE id = :id")
        .param("status", status.name())
        .param("id", id)
        .update();
  }

  public int delete(long userId, long id) {
    return jdbc.sql("DELETE FROM job_applications WHERE id = :id AND user_id = :user")
        .param("id", id)
        .param("user", userId)
        .update();
  }

  /** Cascades to history, interviews and their notifications. */
  public int deleteAll(long userId) {
    return jdbc.sql("DELETE FROM job_applications WHERE user_id = :user").param("user", userId).update();
  }
}
