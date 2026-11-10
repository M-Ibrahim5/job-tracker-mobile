package com.jobtrail.tracker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jobtrail.common.db.Db;
import com.jobtrail.tracker.interviews.InterviewRepository;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Reads that are not paginated must not load every row a user owns: a user can create many
 * interviews far in the future, and each call would otherwise pull all of them into the heap.
 */
class BoundedReadsTest extends TrackerTest {

  @Autowired InterviewRepository interviews;

  private long application(String token) throws Exception {
    return body(post("/api/v1/applications", token, Map.of("jobTitle", "Engineer", "companyName", "Acme",
        "location", "Remote", "workArrangement", "remote", "appliedDate", today().toString())))
        .get("id").asLong();
  }

  private void seed(long user, long application, Instant firstAt, int count, int stepHours) {
    List<Object[]> rows = new ArrayList<>();
    for (int i = 0; i < count; i++) {
      rows.add(new Object[] {user, application, "Round " + i, Db.ts(firstAt.plus(Duration.ofHours((long) i * stepHours))),
          "x".repeat(2000)});
    }
    jdbc.batchUpdate("""
        INSERT INTO interviews (user_id, application_id, title, type, scheduled_at, notes, reminder_offsets)
        VALUES (?, ?, ?, 'video', ?, ?, '[60]')""", rows);
  }

  @Test
  void reminderQueryLoadsOnlyInterviewsThatCanStillProduceAReminder() throws Exception {
    long user = createUser("bounded@example.com");
    String token = token(user);
    long app = application(token);
    Instant now = Instant.now();
    seed(user, app, now.plus(Duration.ofDays(2)), 3, 24);
    // Far beyond the 60-day horizon plus the longest reminder offset (30 days): can never fire.
    seed(user, app, now.plus(Duration.ofDays(400)), 600, 1);

    get("/api/v1/reminders/upcoming", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items[?(@.kind == 'interviewReminder')]", hasSize(3)));

    Instant upTo = now.plus(Duration.ofDays(60 + 30));
    assertThat(interviews.pendingBetween(user, now, upTo, 500)).hasSize(3);
  }

  @Test
  void anApplicationTimelineIsCapped() throws Exception {
    long user = createUser("timeline@example.com");
    String token = token(user);
    long app = application(token);
    seed(user, app, Instant.now().plus(Duration.ofDays(5)), 250, 1);

    get("/api/v1/applications/" + app + "/timeline", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.interviews.length()").value(200));
  }
}
