package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.error.AppException;
import com.jobtrail.user.auth.BoundedPasswordEncoder;
import com.jobtrail.user.auth.TokenCleanup;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Protections added after the load and security review (docs/SECURITY-AND-LOAD-REPORT.md). */
class HardeningTest extends IntegrationTest {

  @Autowired TokenCleanup cleanup;

  private void failLogin(String email) throws Exception {
    post("/api/v1/auth/login", null, Map.of("email", email, "password", "wrong"))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void repeatedWrongPasswordsLockTheAccountBriefly() throws Exception {
    register("target@example.com");
    for (int i = 0; i < 5; i++) {
      failLogin("target@example.com");
    }
    // Locked: even the right password is refused until the lock ends.
    post("/api/v1/auth/login", null, Map.of("email", "TARGET@example.com", "password", PASSWORD))
        .andExpect(status().isTooManyRequests())
        .andExpect(jsonPath("$.error.code").value("RATE_LIMITED"))
        .andExpect(jsonPath("$.error.message").value("Too many failed attempts. Try again in 1 minute"));

    // Once the lock has passed, the right password works and clears the record.
    jdbc.update("UPDATE login_throttle SET locked_until = ?", Db.ts(Instant.now().minusSeconds(1)));
    post("/api/v1/auth/login", null, Map.of("email", "target@example.com", "password", PASSWORD))
        .andExpect(status().isOk());
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM login_throttle", Integer.class)).isZero();
  }

  @Test
  void unknownEmailsAreThrottledTheSameWay() throws Exception {
    for (int i = 0; i < 5; i++) {
      failLogin("nobody@example.com");
    }
    post("/api/v1/auth/login", null, Map.of("email", "nobody@example.com", "password", "x"))
        .andExpect(status().isTooManyRequests());
  }

  @Test
  void passwordChecksBehindATokenShareTheThrottle() throws Exception {
    String token = register("stolen@example.com").get("accessToken").asText();
    for (int i = 0; i < 5; i++) {
      delete("/api/v1/me", token, Map.of("password", "guess" + i)).andExpect(status().isUnauthorized());
    }
    delete("/api/v1/me", token, Map.of("password", PASSWORD)).andExpect(status().isTooManyRequests());
  }

  @Test
  void oversizedJsonBodiesAreRefused() throws Exception {
    String big = "{\"email\":\"" + "a".repeat(2 * 1024 * 1024) + "\"}";
    mvc.perform(MockMvcRequestBuilders.post("/api/v1/auth/login").contentType("application/json").content(big))
        .andExpect(status().isPayloadTooLarge())
        .andExpect(jsonPath("$.error.code").value("PAYLOAD_TOO_LARGE"));
  }

  @Test
  void responsesCarryNosniff() throws Exception {
    get("/api/v1/health", null).andExpect(header().string("X-Content-Type-Options", "nosniff"));
  }

  @Test
  void cleanupKeepsLiveAndRevokedButUnexpiredTokens() throws Exception {
    register("cleanup@example.com");
    long user = jdbc.queryForObject("SELECT id FROM users", Long.class);
    Instant now = Instant.now();
    jdbc.update("INSERT INTO refresh_tokens (user_id, token_hash, expires_at, revoked_at) VALUES (?, ?, ?, ?)",
        user, "a".repeat(64), Db.ts(now.minus(Duration.ofDays(1))), null);
    jdbc.update("INSERT INTO refresh_tokens (user_id, token_hash, expires_at, revoked_at) VALUES (?, ?, ?, ?)",
        user, "b".repeat(64), Db.ts(now.plus(Duration.ofDays(5))), Db.ts(now.minus(Duration.ofDays(2))));
    jdbc.update("INSERT INTO device_tokens (user_id, token_hash, expires_at, revoked_at) VALUES (?, ?, ?, ?)",
        user, "c".repeat(64), Db.ts(now.plus(Duration.ofDays(5))), Db.ts(now.minus(Duration.ofDays(40))));
    jdbc.update("INSERT INTO login_throttle (email, failures, window_started_at) VALUES (?, 1, ?)",
        "old@example.com", Db.ts(now.minus(Duration.ofDays(3))));

    assertThat(cleanup.purge(now)).isEqualTo(3);
    // Left: the token from register, and the revoked one that has not expired (reuse detection).
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens", Integer.class)).isEqualTo(2);
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens", Integer.class)).isZero();
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM login_throttle", Integer.class)).isZero();
  }

  @Test
  void hashingIsCappedAndExcessCallersAreToldTheServerIsBusy() throws Exception {
    CountDownLatch inside = new CountDownLatch(1);
    CountDownLatch release = new CountDownLatch(1);
    PasswordEncoder slow = new PasswordEncoder() {
      @Override
      public String encode(CharSequence raw) {
        return raw.toString();
      }

      @Override
      public boolean matches(CharSequence raw, String encoded) {
        inside.countDown();
        try {
          release.await(5, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
        }
        return true;
      }
    };
    BoundedPasswordEncoder bounded = new BoundedPasswordEncoder(slow, 1, 50);
    Thread holder = new Thread(() -> bounded.matches("a", "a"));
    holder.start();
    assertThat(inside.await(5, TimeUnit.SECONDS)).isTrue();
    assertThatThrownBy(() -> bounded.matches("b", "b"))
        .isInstanceOf(AppException.class)
        .hasMessageContaining("busy");
    release.countDown();
    holder.join();
    assertThat(bounded.matches("c", "c")).isTrue();
  }
}
