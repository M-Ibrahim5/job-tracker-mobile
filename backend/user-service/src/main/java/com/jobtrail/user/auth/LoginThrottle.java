package com.jobtrail.user.auth;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.error.AppException;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Per-account backoff for password checks ({@code login_throttle}). After {@link #FREE_FAILURES}
 * wrong passwords within {@link #WINDOW}, the account is locked for one minute, doubling with each
 * further failure up to {@link #MAX_LOCK}. A correct password clears the record.
 *
 * <p>This complements the gateway's per-IP limit, which an attacker with many IP addresses can
 * spread out. Locks are short so an attacker cannot keep someone out of their account for long,
 * and a locked account is rejected before any hashing, so an attack costs almost no CPU.
 */
@Component
public class LoginThrottle {

  static final int FREE_FAILURES = 5;
  static final Duration WINDOW = Duration.ofMinutes(15);
  static final Duration FIRST_LOCK = Duration.ofMinutes(1);
  static final Duration MAX_LOCK = Duration.ofMinutes(15);

  private record State(int failures, Instant windowStartedAt, Instant lockedUntil) {}

  private final JdbcClient jdbc;
  private final TransactionTemplate tx;

  public LoginThrottle(JdbcClient jdbc, TransactionTemplate tx) {
    this.jdbc = jdbc;
    this.tx = tx;
  }

  private static String key(String email) {
    return email.trim().toLowerCase(Locale.ROOT);
  }

  /**
   * Counts a password attempt for [email] <em>before</em> its password is hashed, and throws 429
   * {@code RATE_LIMITED} while the account is locked. Counting first, under a row lock, means a
   * burst of parallel guesses cannot all pass the check before the first failure is recorded:
   * the fifth attempt in a window sets the lock, and every later one sees it. A correct password
   * deletes the record ({@link #succeeded}); a busy server hands the attempt back ({@link #refund}).
   */
  public void reserve(String email, Instant now) {
    String key = key(email);
    Duration[] remaining = new Duration[1];
    // Created in its own statement (autocommit), so the row exists before the locking read below.
    // Doing both in one transaction made concurrent first attempts deadlock on the missing key.
    jdbc.sql("INSERT IGNORE INTO login_throttle (email, failures, window_started_at) VALUES (:email, 0, :now)")
        .param("email", key)
        .param("now", Db.ts(now))
        .update();
    tx.executeWithoutResult(status -> {
      State row = jdbc.sql("""
              SELECT failures, window_started_at, locked_until FROM login_throttle
              WHERE email = :email FOR UPDATE""")
          .param("email", key)
          .query((rs, i) -> new State(rs.getInt("failures"), Db.instant(rs, "window_started_at"),
              Db.instant(rs, "locked_until")))
          .single();
      if (row.lockedUntil() != null && row.lockedUntil().isAfter(now)) {
        remaining[0] = Duration.between(now, row.lockedUntil());
        return;
      }
      boolean newWindow = row.windowStartedAt().isBefore(now.minus(WINDOW));
      int failures = newWindow ? 1 : row.failures() + 1;
      Instant lockedUntil = failures >= FREE_FAILURES ? now.plus(lockFor(failures)) : null;
      jdbc.sql("""
              UPDATE login_throttle
              SET failures = :failures, window_started_at = :windowStart, locked_until = :lockedUntil
              WHERE email = :email""")
          .param("failures", failures)
          .param("windowStart", Db.ts(newWindow ? now : row.windowStartedAt()))
          .param("lockedUntil", lockedUntil == null ? null : Db.ts(lockedUntil))
          .param("email", key)
          .update();
    });
    if (remaining[0] != null) {
      long minutes = Math.max(1, (remaining[0].toSeconds() + 59) / 60);
      throw new AppException("RATE_LIMITED", HttpStatus.TOO_MANY_REQUESTS,
          "Too many failed attempts. Try again in " + minutes + (minutes == 1 ? " minute" : " minutes"));
    }
  }

  /** Hands back an attempt that was never evaluated (the server was too busy to hash). */
  public void refund(String email) {
    jdbc.sql("UPDATE login_throttle SET failures = GREATEST(failures - 1, 0) WHERE email = :email")
        .param("email", key(email))
        .update();
  }

  /** Clears the record after a correct password. */
  public void succeeded(String email) {
    jdbc.sql("DELETE FROM login_throttle WHERE email = :email").param("email", key(email)).update();
  }

  /** 1 min at the 5th failure, then 2, 4, 8, capped at 15 min. */
  static Duration lockFor(int failures) {
    int doublings = Math.min(failures - FREE_FAILURES, 4);
    Duration lock = FIRST_LOCK.multipliedBy(1L << Math.max(0, doublings));
    return lock.compareTo(MAX_LOCK) > 0 ? MAX_LOCK : lock;
  }

  /** Drops records whose window ended and whose lock expired before [before]. */
  public int purge(Instant before) {
    return jdbc.sql("""
            DELETE FROM login_throttle
            WHERE window_started_at < :before AND (locked_until IS NULL OR locked_until < :before)""")
        .param("before", Db.ts(before))
        .update();
  }
}
