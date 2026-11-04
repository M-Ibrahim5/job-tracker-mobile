package com.jobtrail.tracker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.time.Iso;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class InterviewsTest extends TrackerTest {

  private static final String KL = "Asia/Kuala_Lumpur";

  private long applicationId(String token) throws Exception {
    // No default follow-up so only interview reminders are in play.
    Map<String, Object> noFollowUp = new LinkedHashMap<>();
    noFollowUp.put("followUpAt", null);
    return createApplication(token, noFollowUp).get("id").asLong();
  }

  private static String at(Instant instant) {
    return Iso.format(instant);
  }

  /** Tomorrow-ish at 02:00 UTC, i.e. 10:00 AM in Kuala Lumpur, far enough away for both reminders. */
  private static Instant tenAmKl() {
    return Instant.now().plus(5, ChronoUnit.DAYS).truncatedTo(ChronoUnit.DAYS).plus(2, ChronoUnit.HOURS);
  }

  @Test
  void createReturnsTheInterviewWithApplicationDetails() throws Exception {
    String token = newToken("int1@example.com");
    long appId = applicationId(token);
    createInterview(token, appId, Map.of("durationMinutes", 45, "locationOrLink", "https://meet.example.com/x",
        "interviewerName", "Daniel Lim", "notes", "Bring laptop"))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.applicationId").value(appId))
        .andExpect(jsonPath("$.applicationTitle").value("Flutter Developer"))
        .andExpect(jsonPath("$.companyName").value("Northwind Labs"))
        .andExpect(jsonPath("$.type").value("video"))
        .andExpect(jsonPath("$.durationMinutes").value(45))
        .andExpect(jsonPath("$.interviewerName").value("Daniel Lim"))
        .andExpect(jsonPath("$.outcome").value("pending"))
        .andExpect(jsonPath("$.reminderOffsetsMinutes[0]").value(1440))
        .andExpect(jsonPath("$.reminderOffsetsMinutes[1]").value(60));
    createInterview(token, appId, Map.of("scheduledAt", inDays(8)))
        .andExpect(jsonPath("$.durationMinutes").value(60));
  }

  @Test
  void createValidatesItsBody() throws Exception {
    String token = newToken("int2@example.com");
    long appId = applicationId(token);
    post("/api/v1/applications/" + appId + "/interviews", token, Map.of())
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.title").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.type").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.scheduledAt").value("This field is required"));
    createInterview(token, appId, Map.of("type", "zoom", "scheduledAt", "tomorrow", "durationMinutes", 0))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.type").exists())
        .andExpect(jsonPath("$.error.fields.scheduledAt").exists())
        .andExpect(jsonPath("$.error.fields.durationMinutes").exists());
    createInterview(token, appId, Map.of("reminderOffsetsMinutes", List.of(1, 2, 3, 4, 5, 6)))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.reminderOffsetsMinutes").value("At most 5 reminders"));
    createInterview(token, 999_999, Map.of()).andExpect(status().isNotFound());
  }

  @Test
  void createsOneHiddenReminderPerOffsetWithFormattedText() throws Exception {
    String token = newToken("int3@example.com");
    long appId = applicationId(token);
    JsonNode interview = body(createInterview(token, appId, Map.of("scheduledAt", at(tenAmKl())), KL)
        .andExpect(status().isCreated()));
    long id = interview.get("id").asLong();

    List<Map<String, Object>> rows = jdbc.queryForList(
        "SELECT title, body, visible_at FROM notifications WHERE related_interview_id = ? ORDER BY visible_at", id);
    assertThat(rows).hasSize(2);
    assertThat(rows.get(0).get("title")).isEqualTo("Interview in 1 day");
    assertThat(rows.get(1).get("title")).isEqualTo("Interview in 1 hour");
    assertThat(rows.get(0).get("body")).isEqualTo("Northwind Labs · 10:00 AM · Video");

    // Reminders appear only once their time has come.
    get("/api/v1/notifications", token).andExpect(jsonPath("$.total").value(0));
    get("/api/v1/notifications/unread-count", token).andExpect(jsonPath("$.count").value(0));
  }

  @Test
  void reminderBodiesDefaultToUtc() throws Exception {
    String token = newToken("int4@example.com");
    long appId = applicationId(token);
    createInterview(token, appId, Map.of("scheduledAt", at(tenAmKl()))).andExpect(status().isCreated());
    long id = latestInterviewId();
    String body = jdbc.queryForObject(
        "SELECT body FROM notifications WHERE related_interview_id = ? LIMIT 1", String.class, id);
    assertThat(body).isEqualTo("Northwind Labs · 2:00 AM · Video");
  }

  private long latestInterviewId() {
    return jdbc.queryForObject("SELECT MAX(id) FROM interviews", Long.class);
  }

  @Test
  void pastInterviewsAndDisabledRemindersCreateNoRows() throws Exception {
    long userId = createUser("int5@example.com");
    String token = token(userId);
    long appId = applicationId(token);
    createInterview(token, appId, Map.of("scheduledAt", inDays(-2))).andExpect(status().isCreated());
    assertThat(count("SELECT COUNT(*) FROM notifications")).isZero();

    // Only the offsets that are still in the future are scheduled.
    createInterview(token, appId, Map.of("scheduledAt", at(Instant.now().plus(3, ChronoUnit.HOURS))))
        .andExpect(status().isCreated());
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE title = 'Interview in 1 hour'")).isEqualTo(1);
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE title = 'Interview in 1 day'")).isZero();

    jdbc.update("UPDATE user_settings SET interview_reminders_enabled = 0 WHERE user_id = ?", userId);
    jdbc.update("DELETE FROM notifications");
    createInterview(token, appId, Map.of("scheduledAt", inDays(6))).andExpect(status().isCreated());
    assertThat(count("SELECT COUNT(*) FROM notifications")).isZero();
  }

  @Test
  void customOffsetsOverrideTheDefaultsAndAreDeduplicated() throws Exception {
    String token = newToken("int6@example.com");
    long appId = applicationId(token);
    createInterview(token, appId, Map.of("reminderOffsetsMinutes", List.of(30, 30, 10080)))
        .andExpect(jsonPath("$.reminderOffsetsMinutes.length()").value(2));
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE title = 'Interview in 30 minutes'")).isEqualTo(1);
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE title = 'Interview in 7 days'")).isEqualTo(0);

    createInterview(token, appId, Map.of("scheduledAt", inDays(20), "reminderOffsetsMinutes", List.of()))
        .andExpect(jsonPath("$.reminderOffsetsMinutes.length()").value(0));
  }

  @Test
  void twoInterviewsAtTheSameInstantConflict() throws Exception {
    String token = newToken("int7@example.com");
    long appId = applicationId(token);
    String when = inDays(4);
    createInterview(token, appId, Map.of("scheduledAt", when)).andExpect(status().isCreated());
    createInterview(token, appId, Map.of("scheduledAt", when, "title", "Duplicate"))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.error.code").value("INTERVIEW_CONFLICT"))
        .andExpect(jsonPath("$.error.fields.scheduledAt").exists());
    assertThat(count("SELECT COUNT(*) FROM interviews")).isEqualTo(1);

    // The same time on another application is fine.
    long other = applicationId(token);
    createInterview(token, other, Map.of("scheduledAt", when)).andExpect(status().isCreated());
  }

  @Test
  void patchReschedulesTheRemindersAndDetectsConflicts() throws Exception {
    String token = newToken("int8@example.com");
    long appId = applicationId(token);
    JsonNode first = body(createInterview(token, appId, Map.of("scheduledAt", inDays(4))));
    JsonNode second = body(createInterview(token, appId, Map.of("scheduledAt", inDays(7))));
    long id = first.get("id").asLong();

    String moved = at(Instant.now().plus(10, ChronoUnit.DAYS));
    patch("/api/v1/interviews/" + id, token, Map.of("scheduledAt", moved, "title", "Moved"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.title").value("Moved"))
        .andExpect(jsonPath("$.scheduledAt").value(moved));
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isEqualTo(2);
    Instant firstReminder = jdbc.queryForObject(
        "SELECT MIN(visible_at) FROM notifications WHERE related_interview_id = ?", java.time.LocalDateTime.class, id)
        .toInstant(java.time.ZoneOffset.UTC);
    assertThat(firstReminder).isEqualTo(Instant.parse(moved).minus(1, ChronoUnit.DAYS));

    patch("/api/v1/interviews/" + id, token, Map.of("scheduledAt", second.get("scheduledAt").asText()))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.error.code").value("INTERVIEW_CONFLICT"));

    patch("/api/v1/interviews/" + id, token, Map.of("durationMinutes", 0)).andExpect(status().isBadRequest());
    patch("/api/v1/interviews/" + id, token, Map.of("title", "")).andExpect(status().isBadRequest());
  }

  @Test
  void cancellingRemovesUnfiredRemindersAndDeletingRemovesTheRow() throws Exception {
    String token = newToken("int9@example.com");
    long appId = applicationId(token);
    long id = body(createInterview(token, appId, Map.of())).get("id").asLong();
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isEqualTo(2);

    patch("/api/v1/interviews/" + id, token, Map.of("outcome", "cancelled"))
        .andExpect(jsonPath("$.outcome").value("cancelled"));
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isZero();

    patch("/api/v1/interviews/" + id, token, Map.of("outcome", "pending"));
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isEqualTo(2);

    delete("/api/v1/interviews/" + id, token).andExpect(status().isNoContent());
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isZero();
    get("/api/v1/interviews/" + id, token).andExpect(status().isNotFound());
    delete("/api/v1/interviews/" + id, token).andExpect(status().isNotFound());
  }

  @Test
  void firedRemindersSurviveRescheduling() throws Exception {
    String token = newToken("int10@example.com");
    long appId = applicationId(token);
    long id = body(createInterview(token, appId, Map.of("scheduledAt", inDays(4)))).get("id").asLong();
    // Pretend the day-before reminder already fired.
    jdbc.update("UPDATE notifications SET visible_at = '2020-01-01 00:00:00' WHERE related_interview_id = ? "
        + "AND title = 'Interview in 1 day'", id);
    patch("/api/v1/interviews/" + id, token, Map.of("scheduledAt", inDays(9))).andExpect(status().isOk());
    // The fired row stays, the unfired one is replaced: 1 old + 2 new.
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_interview_id = ?", id)).isEqualTo(3);
    get("/api/v1/notifications", token).andExpect(jsonPath("$.total").value(1));
  }

  @Test
  void interviewsAreScopedToTheirOwner() throws Exception {
    String alice = newToken("alice-i@example.com");
    String bob = newToken("bob-i@example.com");
    long id = body(createInterview(alice, applicationId(alice), Map.of())).get("id").asLong();
    get("/api/v1/interviews/" + id, bob).andExpect(status().isNotFound());
    patch("/api/v1/interviews/" + id, bob, Map.of("title", "x")).andExpect(status().isNotFound());
    delete("/api/v1/interviews/" + id, bob).andExpect(status().isNotFound());
    get("/api/v1/interviews", bob).andExpect(jsonPath("$.total").value(0));
    get("/api/v1/interviews", alice).andExpect(jsonPath("$.total").value(1));
  }

  @Test
  void listFiltersByScopeApplicationAndRange() throws Exception {
    String token = newToken("int11@example.com");
    long appA = applicationId(token);
    long appB = applicationId(token);
    createInterview(token, appA, Map.of("title", "Past 1", "scheduledAt", inDays(-5)));
    createInterview(token, appA, Map.of("title", "Past 2", "scheduledAt", inDays(-2)));
    createInterview(token, appA, Map.of("title", "Soon", "scheduledAt", inDays(2)));
    createInterview(token, appB, Map.of("title", "Later", "scheduledAt", inDays(6)));

    assertThat(titles(token, "?scope=upcoming")).containsExactly("Soon", "Later");
    assertThat(titles(token, "?scope=past")).containsExactly("Past 2", "Past 1");
    assertThat(titles(token, "")).containsExactly("Past 1", "Past 2", "Soon", "Later");
    assertThat(titles(token, "?applicationId=" + appB)).containsExactly("Later");
    assertThat(titles(token, "?from=" + daysFromToday(1) + "&to=" + daysFromToday(3))).containsExactly("Soon");
    // A date-only upper bound includes that whole day.
    assertThat(titles(token, "?from=" + daysFromToday(6) + "&to=" + daysFromToday(6))).containsExactly("Later");

    get("/api/v1/interviews?scope=upcoming&pageSize=1", token)
        .andExpect(jsonPath("$.total").value(2))
        .andExpect(jsonPath("$.items.length()").value(1))
        .andExpect(jsonPath("$.items[0].applicationTitle").value("Flutter Developer"))
        .andExpect(jsonPath("$.items[0].companyName").value("Northwind Labs"));
    get("/api/v1/interviews?scope=sometime", token).andExpect(status().isBadRequest());
    get("/api/v1/interviews?applicationId=abc", token).andExpect(status().isBadRequest());
  }

  private List<String> titles(String token, String query) throws Exception {
    JsonNode page = body(get("/api/v1/interviews" + query, token).andExpect(status().isOk()));
    List<String> out = new java.util.ArrayList<>();
    page.get("items").forEach(n -> out.add(n.get("title").asText()));
    return out;
  }

  // ----- notifications ------------------------------------------------------------------------

  @Test
  void notificationsListNewestFirstAndCanBeReadAndDeleted() throws Exception {
    long userId = createUser("notif@example.com");
    String token = token(userId);
    long a = insertNotification(userId, "First", -3, false);
    long b = insertNotification(userId, "Second", -2, false);
    long c = insertNotification(userId, "Third", -1, true);
    insertNotification(userId, "Future", 2, false);

    get("/api/v1/notifications", token)
        .andExpect(jsonPath("$.total").value(3))
        .andExpect(jsonPath("$.items[0].title").value("Third"))
        .andExpect(jsonPath("$.items[2].title").value("First"))
        .andExpect(jsonPath("$.items[0].isRead").value(true));
    get("/api/v1/notifications/unread-count", token).andExpect(jsonPath("$.count").value(2));

    post("/api/v1/notifications/" + a + "/read", token, null).andExpect(status().isNoContent());
    get("/api/v1/notifications/unread-count", token).andExpect(jsonPath("$.count").value(1));
    // Reading again is fine.
    post("/api/v1/notifications/" + a + "/read", token, null).andExpect(status().isNoContent());

    post("/api/v1/notifications/read-all", token, null).andExpect(status().isNoContent());
    get("/api/v1/notifications/unread-count", token).andExpect(jsonPath("$.count").value(0));

    delete("/api/v1/notifications/" + b, token).andExpect(status().isNoContent());
    delete("/api/v1/notifications/" + b, token).andExpect(status().isNotFound());
    get("/api/v1/notifications?pageSize=1&page=2", token).andExpect(jsonPath("$.items.length()").value(1));

    delete("/api/v1/notifications", token).andExpect(status().isNoContent());
    get("/api/v1/notifications", token).andExpect(jsonPath("$.total").value(0));
    // Clearing only removes what the user could see; the future reminder is still scheduled.
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE title = 'Future'")).isEqualTo(1);
    assertThat(c).isPositive();
  }

  @Test
  void notificationsBelongToTheirOwner() throws Exception {
    long alice = createUser("alice-n@example.com");
    String bob = newToken("bob-n@example.com");
    long id = insertNotification(alice, "Private", -1, false);
    post("/api/v1/notifications/" + id + "/read", bob, null).andExpect(status().isNotFound());
    delete("/api/v1/notifications/" + id, bob).andExpect(status().isNotFound());
    get("/api/v1/notifications", bob).andExpect(jsonPath("$.total").value(0));
    delete("/api/v1/notifications", bob).andExpect(status().isNoContent());
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE id = ?", id)).isEqualTo(1);
    // Future notifications cannot be read or deleted before they fire.
    long future = insertNotification(alice, "Soon", 3, false);
    post("/api/v1/notifications/" + future + "/read", token(alice), null).andExpect(status().isNotFound());
  }

  private long insertNotification(long userId, String title, int daysFromNow, boolean read) {
    jdbc.update("INSERT INTO notifications (user_id, type, title, body, visible_at, is_read) "
            + "VALUES (?, 'system', ?, 'body', DATE_ADD(UTC_TIMESTAMP(3), INTERVAL ? DAY), ?)",
        userId, title, daysFromNow, read);
    return jdbc.queryForObject("SELECT MAX(id) FROM notifications", Long.class);
  }

  // ----- /reminders/upcoming ------------------------------------------------------------------

  @Test
  void upcomingRemindersListFutureItemsWithStableKeys() throws Exception {
    long userId = createUser("rem@example.com");
    String token = token(userId);
    Map<String, Object> noFollowUp = new LinkedHashMap<>();
    noFollowUp.put("followUpAt", null);
    long appId = createApplication(token, noFollowUp).get("id").asLong();
    long withFollowUp = createApplication(token, Map.of("followUpAt", inDays(3))).get("id").asLong();
    Instant when = tenAmKl();
    long interviewId = body(createInterview(token, appId, Map.of("scheduledAt", at(when)))).get("id").asLong();
    // Not reminders: beyond the 60 day horizon, in the past, cancelled.
    createInterview(token, appId, Map.of("scheduledAt", inDays(90)));
    createInterview(token, appId, Map.of("scheduledAt", inDays(-1)));
    createInterview(token, appId, Map.of("scheduledAt", inDays(12), "outcome", "cancelled"));

    JsonNode items = body(get("/api/v1/reminders/upcoming", token, KL).andExpect(status().isOk())).get("items");
    List<String> keys = new java.util.ArrayList<>();
    items.forEach(n -> keys.add(n.get("key").asText()));
    assertThat(keys).containsExactly(
        "followUp:" + withFollowUp,
        "interview:" + interviewId + ":1440",
        "interview:" + interviewId + ":60");

    JsonNode followUp = items.get(0);
    assertThat(followUp.get("kind").asText()).isEqualTo("followUpReminder");
    assertThat(followUp.get("title").asText()).isEqualTo("Follow up with Northwind Labs");
    assertThat(followUp.get("interviewId").isNull()).isTrue();
    JsonNode dayBefore = items.get(1);
    assertThat(dayBefore.get("kind").asText()).isEqualTo("interviewReminder");
    assertThat(dayBefore.get("title").asText()).isEqualTo("Interview in 1 day");
    assertThat(dayBefore.get("body").asText()).isEqualTo("Northwind Labs · 10:00 AM · Video");
    assertThat(dayBefore.get("fireAt").asText()).isEqualTo(at(when.minus(1, ChronoUnit.DAYS)));
    assertThat(dayBefore.get("applicationId").asLong()).isEqualTo(appId);
    assertThat(dayBefore.get("interviewId").asLong()).isEqualTo(interviewId);

    // Only enabled types are returned.
    jdbc.update("UPDATE user_settings SET followup_reminders_enabled = 0 WHERE user_id = ?", userId);
    assertThat(body(get("/api/v1/reminders/upcoming", token)).get("items")).hasSize(2);
    jdbc.update("UPDATE user_settings SET interview_reminders_enabled = 0 WHERE user_id = ?", userId);
    assertThat(body(get("/api/v1/reminders/upcoming", token)).get("items")).isEmpty();
  }
}
