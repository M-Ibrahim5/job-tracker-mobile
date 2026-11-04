package com.jobtrail.user.auth;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.error.AppException;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Optional;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

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

  private record State(int failures, Instant lockedUntil) {}

  private final JdbcClient jdbc;

  public LoginThrottle(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  private static String key(String email) {
    return email.trim().toLowerCase(Locale.ROOT);
  }

  private Optional<State> state(String email) {
    return jdbc.sql("SELECT failures, locked_until FROM login_throttle WHERE email = :email")
        .param("email", key(email))
        .query((rs, i) -> new State(rs.getInt("failures"), Db.instant(rs, "locked_until")))
        .optional();
  }

  /** Throws 429 {@code RATE_LIMITED} while [email] is locked. */
  public void check(String email, Instant now) {
    state(email).map(State::lockedUntil).filter(until -> until.isAfter(now)).ifPresent(until -> {
      long minutes = Math.max(1, (Duration.between(now, until).toSeconds() + 59) / 60);
      throw new AppException("RATE_LIMITED", HttpStatus.TOO_MANY_REQUESTS,
          "Too many failed attempts. Try again in " + minutes + (minutes == 1 ? " minute" : " minutes"));
    });
  }

  /** Records a wrong password and locks the account once the free attempts are used up. */
  public void failed(String email, Instant now) {
    String key = key(email);
    // Assignments run left to right: `failures` still sees the old window start.
    jdbc.sql("""
            INSERT INTO login_throttle (email, failures, window_started_at) VALUES (:email, 1, :now)
            ON DUPLICATE KEY UPDATE
              failures = IF(window_started_at < :windowStart, 1, failures + 1),
              window_started_at = IF(window_started_at < :windowStart, :now, window_started_at)""")
        .param("email", key)
        .param("now", Db.ts(now))
        .param("windowStart", Db.ts(now.minus(WINDOW)))
        .update();
    int failures = state(email).map(State::failures).orElse(0);
    if (failures >= FREE_FAILURES) {
      jdbc.sql("UPDATE login_throttle SET locked_until = :until WHERE email = :email")
          .param("until", Db.ts(now.plus(lockFor(failures))))
          .param("email", key)
          .update();
    }
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
