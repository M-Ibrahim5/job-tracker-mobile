package com.jobtrail.tracker.notifications;

import com.jobtrail.common.db.Db;
import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Nightly retention for notifications: read ones are deleted {@code jobtrail.notification-retention-days}
 * (default 365) after they became visible. Unread notifications and reminders that have not fired
 * yet are never touched. Deletes run in batches; running on several instances is harmless.
 */
@Component
public class NotificationRetention {

  private static final Logger log = LoggerFactory.getLogger(NotificationRetention.class);
  private static final int BATCH = 5_000;

  private final JdbcClient jdbc;
  private final Duration keep;

  public NotificationRetention(JdbcClient jdbc,
      @Value("${jobtrail.notification-retention-days:365}") int retentionDays) {
    this.jdbc = jdbc;
    this.keep = Duration.ofDays(Math.max(1, retentionDays));
  }

  @Scheduled(cron = "${jobtrail.cleanup-cron:0 30 3 * * *}", zone = "UTC")
  public void nightly() {
    purge(Instant.now());
  }

  /** Deletes read notifications that became visible before [now] minus the retention period. */
  public int purge(Instant now) {
    int total = 0;
    int deleted;
    do {
      deleted = jdbc.sql("DELETE FROM notifications WHERE is_read = TRUE AND visible_at < :before LIMIT " + BATCH)
          .param("before", Db.ts(now.minus(keep)))
          .update();
      total += deleted;
    } while (deleted == BATCH);
    if (total > 0) {
      log.info("Retention removed {} read notifications older than {} days", total, keep.toDays());
    }
    return total;
  }
}
