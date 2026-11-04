package com.jobtrail.tracker.notifications;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.model.NotificationType;
import java.time.Instant;
import java.util.List;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class NotificationRepository {

  private static final String INSERT = """
      INSERT INTO notifications
        (user_id, type, title, body, related_application_id, related_interview_id, visible_at)
      VALUES (:user, :type, :title, :body, :app, :interview, :visible)""";

  private static final RowMapper<NotificationRow> MAPPER = (rs, i) -> new NotificationRow(
      rs.getLong("id"),
      NotificationType.valueOf(rs.getString("type")),
      rs.getString("title"),
      rs.getString("body"),
      Db.nullableLong(rs, "related_application_id"),
      Db.nullableLong(rs, "related_interview_id"),
      Db.instant(rs, "visible_at"),
      rs.getBoolean("is_read"));

  private final JdbcClient jdbc;

  public NotificationRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void insert(NewNotification n) {
    jdbc.sql(INSERT)
        .param("user", n.userId())
        .param("type", n.type().name())
        .param("title", n.title())
        .param("body", n.body())
        .param("app", n.relatedApplicationId())
        .param("interview", n.relatedInterviewId())
        .param("visible", Db.ts(n.visibleAt()))
        .update();
  }

  public void insertAll(List<NewNotification> rows) {
    rows.forEach(this::insert);
  }

  /** Visible rows only (visible_at &lt;= now), newest first. */
  public List<NotificationRow> listVisible(long userId, Instant now, int limit, int offset) {
    return jdbc.sql("""
            SELECT * FROM notifications WHERE user_id = :user AND visible_at <= :now
            ORDER BY visible_at DESC, id DESC LIMIT :limit OFFSET :offset""")
        .param("user", userId)
        .param("now", Db.ts(now))
        .param("limit", limit)
        .param("offset", offset)
        .query(MAPPER)
        .list();
  }

  public long countVisible(long userId, Instant now) {
    return jdbc.sql("SELECT COUNT(*) FROM notifications WHERE user_id = :user AND visible_at <= :now")
        .param("user", userId)
        .param("now", Db.ts(now))
        .query(Long.class)
        .single();
  }

  public long countUnread(long userId, Instant now) {
    return jdbc.sql("""
            SELECT COUNT(*) FROM notifications
            WHERE user_id = :user AND visible_at <= :now AND is_read = 0""")
        .param("user", userId)
        .param("now", Db.ts(now))
        .query(Long.class)
        .single();
  }

  public int markRead(long userId, long id, Instant now) {
    return jdbc.sql("""
            UPDATE notifications SET is_read = 1
            WHERE id = :id AND user_id = :user AND visible_at <= :now""")
        .param("id", id)
        .param("user", userId)
        .param("now", Db.ts(now))
        .update();
  }

  public int markAllRead(long userId, Instant now) {
    return jdbc.sql("""
            UPDATE notifications SET is_read = 1
            WHERE user_id = :user AND visible_at <= :now AND is_read = 0""")
        .param("user", userId)
        .param("now", Db.ts(now))
        .update();
  }

  public int delete(long userId, long id, Instant now) {
    return jdbc.sql("DELETE FROM notifications WHERE id = :id AND user_id = :user AND visible_at <= :now")
        .param("id", id)
        .param("user", userId)
        .param("now", Db.ts(now))
        .update();
  }

  /** "Clear all" removes what the user can see; reminders that have not fired yet stay. */
  public int deleteVisible(long userId, Instant now) {
    return jdbc.sql("DELETE FROM notifications WHERE user_id = :user AND visible_at <= :now")
        .param("user", userId)
        .param("now", Db.ts(now))
        .update();
  }

  public int deleteAll(long userId) {
    return jdbc.sql("DELETE FROM notifications WHERE user_id = :user").param("user", userId).update();
  }

  public int deleteUnfiredInterviewReminders(long userId, long interviewId, Instant now) {
    return jdbc.sql("""
            DELETE FROM notifications
            WHERE user_id = :user AND related_interview_id = :interview
              AND type = 'interviewReminder' AND visible_at > :now""")
        .param("user", userId)
        .param("interview", interviewId)
        .param("now", Db.ts(now))
        .update();
  }

  public int deleteUnfiredFollowUpReminders(long userId, long applicationId, Instant now) {
    return jdbc.sql("""
            DELETE FROM notifications
            WHERE user_id = :user AND related_application_id = :app
              AND type = 'followUpReminder' AND visible_at > :now""")
        .param("user", userId)
        .param("app", applicationId)
        .param("now", Db.ts(now))
        .update();
  }
}
