package com.jobtrail.tracker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jobtrail.common.db.Db;
import com.jobtrail.tracker.notifications.NotificationRetention;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/** Protections added after the load and security review (docs/SECURITY-AND-LOAD-REPORT.md). */
class HardeningTest extends TrackerTest {

  private static Map<String, Object> application() {
    return Map.of("jobTitle", "Engineer", "companyName", "Acme", "location", "Remote",
        "workArrangement", "remote", "appliedDate", today().toString());
  }

  @Autowired NotificationRetention retention;

  private void notification(long user, Instant visibleAt, boolean read) {
    jdbc.update("INSERT INTO notifications (user_id, type, title, body, visible_at, is_read) VALUES (?, 'system', 't', 'b', ?, ?)",
        user, Db.ts(visibleAt), read);
  }

  @Test
  void retentionDeletesOnlyOldReadNotifications() {
    long user = createUser("retention@example.com");
    Instant now = Instant.now();
    notification(user, now.minus(Duration.ofDays(400)), true);   // old and read: deleted
    notification(user, now.minus(Duration.ofDays(400)), false);  // old but unread: kept
    notification(user, now.minus(Duration.ofDays(10)), true);    // recent: kept
    notification(user, now.plus(Duration.ofDays(3)), false);     // reminder not fired yet: kept

    assertThat(retention.purge(now)).isEqualTo(1);
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM notifications", Integer.class)).isEqualTo(3);
  }

  @Test
  void writesWithTheTokenOfADeletedAccountAreUnauthorizedNotServerErrors() throws Exception {
    long user = createUser("gone@example.com");
    String token = token(user);
    jdbc.update("DELETE FROM users WHERE id = ?", user);

    post("/api/v1/applications", token, application())
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
  }

  @Test
  void pageNumbersAreCappedInsteadOfOverflowing() throws Exception {
    String token = newToken("pages@example.com");
    get("/api/v1/applications?page=2147483647&pageSize=100", token)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.page").exists());
    get("/api/v1/applications?page=10000&pageSize=100", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items").isEmpty());
  }

  @Test
  void oversizedJsonBodiesAreRefusedBeforeParsing() throws Exception {
    String token = newToken("big@example.com");
    String big = "{\"jobTitle\":\"x\",\"notes\":\"" + "a".repeat(2 * 1024 * 1024) + "\"}";
    mvc.perform(MockMvcRequestBuilders.post("/api/v1/applications")
            .header("Authorization", "Bearer " + token)
            .contentType("application/json")
            .content(big))
        .andExpect(status().isPayloadTooLarge())
        .andExpect(jsonPath("$.error.code").value("PAYLOAD_TOO_LARGE"));
  }
}
