package com.jobtrail.user.auth;

import com.jobtrail.common.db.Db;
import java.time.Duration;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Nightly purge of rows nothing needs any more. Every refresh inserts a token row, so without it
 * {@code refresh_tokens} grows by about 100 rows per active user per day.
 *
 * <ul>
 *   <li>Refresh tokens are kept until they expire, even when revoked: a revoked token that comes
 *       back is how reuse (theft) is detected.
 *   <li>Device tokens go once expired, or {@link #KEEP_REVOKED} after revocation.
 *   <li>Login throttle records go a day after their window closed and any lock ended.
 * </ul>
 *
 * Deletes run in batches so no single statement holds locks for long. Running on several instances
 * at once is harmless: the deletes are idempotent.
 */
@Component
public class TokenCleanup {

  private static final Logger log = LoggerFactory.getLogger(TokenCleanup.class);

  static final Duration KEEP_REVOKED = Duration.ofDays(30);
  private static final int BATCH = 5_000;

  private final JdbcClient jdbc;
  private final LoginThrottle throttle;

  public TokenCleanup(JdbcClient jdbc, LoginThrottle throttle) {
    this.jdbc = jdbc;
    this.throttle = throttle;
  }

  @Scheduled(cron = "${jobtrail.cleanup-cron:0 30 3 * * *}", zone = "UTC")
  public void nightly() {
    purge(Instant.now());
  }

  /** Runs one purge as of [now]; returns the number of rows deleted. */
  public int purge(Instant now) {
    int refresh = inBatches("DELETE FROM refresh_tokens WHERE expires_at < :now LIMIT " + BATCH, now);
    int device = inBatches("""
        DELETE FROM device_tokens
        WHERE expires_at < :now OR revoked_at < :revokedBefore LIMIT\s""" + BATCH, now);
    int throttled = throttle.purge(now.minus(Duration.ofDays(1)));
    int total = refresh + device + throttled;
    if (total > 0) {
      log.info("Cleanup removed {} refresh tokens, {} device tokens, {} login throttle records",
          refresh, device, throttled);
    }
    return total;
  }

  private int inBatches(String sql, Instant now) {
    int total = 0;
    int deleted;
    do {
      var statement = jdbc.sql(sql).param("now", Db.ts(now));
      if (sql.contains(":revokedBefore")) {
        statement = statement.param("revokedBefore", Db.ts(now.minus(KEEP_REVOKED)));
      }
      deleted = statement.update();
      total += deleted;
    } while (deleted == BATCH);
    return total;
  }
}
