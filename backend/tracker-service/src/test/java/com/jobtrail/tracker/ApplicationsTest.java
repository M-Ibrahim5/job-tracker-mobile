package com.jobtrail.tracker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ApplicationsTest extends TrackerTest {

  @Test
  void authIsRequired() throws Exception {
    get("/api/v1/applications", null)
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    get("/api/v1/applications", "garbage").andExpect(status().isUnauthorized());
  }

  @Test
  void createReturnsTheApplicationWithAnInitialHistoryEntry() throws Exception {
    String token = newToken("a@example.com");
    JsonNode created = createApplication(token, Map.of("jobDescription", "Build apps", "notes", "  hello  "));
    assertThat(created.get("id").isNumber()).isTrue();
    assertThat(created.get("status").asText()).isEqualTo("applied");
    assertThat(created.get("jobDescription").asText()).isEqualTo("Build apps");
    assertThat(created.get("notes").asText()).isEqualTo("hello");
    assertThat(created.get("appliedDate").asText()).isEqualTo(daysFromToday(0));
    assertThat(created.get("nextInterviewAt").isNull()).isTrue();
    assertThat(created.get("createdAt").asText()).matches("\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z");

    get("/api/v1/applications/" + created.get("id").asLong() + "/history", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.length()").value(1))
        .andExpect(jsonPath("$[0].fromStatus").value((Object) null))
        .andExpect(jsonPath("$[0].toStatus").value("applied"))
        .andExpect(jsonPath("$[0].applicationId").value(created.get("id").asLong()));
  }

  @Test
  void createWithAnExplicitStatusStartsThere() throws Exception {
    String token = newToken("b@example.com");
    JsonNode created = createApplication(token, Map.of("status", "screening"));
    assertThat(created.get("status").asText()).isEqualTo("screening");
    get("/api/v1/applications/" + created.get("id").asLong() + "/history", token)
        .andExpect(jsonPath("$[0].toStatus").value("screening"));
  }

  @Test
  void defaultFollowUpIsAppliedUnlessOptedOut() throws Exception {
    String token = newToken("followup@example.com");
    String applied = daysFromToday(0);
    JsonNode withDefault = createApplication(token, Map.of("appliedDate", applied));
    assertThat(withDefault.get("followUpAt").asText())
        .isEqualTo(LocalDate.parse(applied).plusDays(7) + "T09:00:00.000Z");

    java.util.Map<String, Object> optOut = new java.util.LinkedHashMap<>();
    optOut.put("followUpAt", null);
    JsonNode none = createApplication(token, optOut);
    assertThat(none.get("followUpAt").isNull()).isTrue();

    // Only the defaulted application got a reminder row, and it is hidden until it fires.
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'followUpReminder'")).isEqualTo(1);
    get("/api/v1/notifications", token).andExpect(jsonPath("$.total").value(0));
  }

  @Test
  void settingFollowUpOffInSettingsSkipsTheDefault() throws Exception {
    long userId = createUser("nofollow@example.com");
    jdbc.update("UPDATE user_settings SET default_followup_days = NULL WHERE user_id = ?", userId);
    JsonNode created = createApplication(token(userId));
    assertThat(created.get("followUpAt").isNull()).isTrue();
  }

  @Test
  void validationErrorsListEveryField() throws Exception {
    String token = newToken("validation@example.com");
    post("/api/v1/applications", token, Map.of())
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.fields.jobTitle").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.companyName").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.location").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.workArrangement").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.appliedDate").value("This field is required"));

    post("/api/v1/applications", token, Map.of(
            "jobTitle", "x".repeat(101), "companyName", "C", "location", "L", "workArrangement", "moon",
            "appliedDate", daysFromToday(5), "applicationLink", "ftp://example.com",
            "contactEmail", "not-an-email", "jobDescription", "d".repeat(10_001)))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.jobTitle").value("Must be at most 100 characters"))
        .andExpect(jsonPath("$.error.fields.workArrangement").exists())
        .andExpect(jsonPath("$.error.fields.appliedDate").value("Date cannot be in the future"))
        .andExpect(jsonPath("$.error.fields.applicationLink").value("Enter a valid http(s) URL"))
        .andExpect(jsonPath("$.error.fields.contactEmail").value("Enter a valid email address"))
        .andExpect(jsonPath("$.error.fields.jobDescription").exists());
  }

  @Test
  void tomorrowIsAllowedForTimezoneSlack() throws Exception {
    String token = newToken("tomorrow@example.com");
    post("/api/v1/applications", token, Map.of("jobTitle", "T", "companyName", "C", "location", "L",
        "workArrangement", "remote", "appliedDate", daysFromToday(1))).andExpect(status().isCreated());
  }

  @Test
  void usersCannotSeeOrTouchEachOthersApplications() throws Exception {
    String alice = newToken("alice@example.com");
    String bob = newToken("bob@example.com");
    long id = createApplication(alice).get("id").asLong();
    String path = "/api/v1/applications/" + id;

    get(path, bob).andExpect(status().isNotFound()).andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    patch(path, bob, Map.of("notes", "hacked")).andExpect(status().isNotFound());
    delete(path, bob).andExpect(status().isNotFound());
    post(path + "/status", bob, Map.of("status", "offer")).andExpect(status().isNotFound());
    get(path + "/history", bob).andExpect(status().isNotFound());
    get(path + "/timeline", bob).andExpect(status().isNotFound());
    createInterview(bob, id, Map.of()).andExpect(status().isNotFound());
    get("/api/v1/applications", bob).andExpect(jsonPath("$.total").value(0));

    get(path, alice).andExpect(status().isOk());
    assertThat(count("SELECT COUNT(*) FROM job_applications")).isEqualTo(1);
  }

  @Test
  void malformedIdsAreNotFound() throws Exception {
    String token = newToken("ids@example.com");
    get("/api/v1/applications/abc", token).andExpect(status().isNotFound());
    get("/api/v1/applications/0", token).andExpect(status().isNotFound());
    get("/api/v1/applications/-3", token).andExpect(status().isNotFound());
  }

  @Test
  void patchUpdatesFieldsButIgnoresStatus() throws Exception {
    String token = newToken("patch@example.com");
    long id = createApplication(token).get("id").asLong();
    patch("/api/v1/applications/" + id, token, Map.of(
            "jobTitle", "Staff Engineer", "salaryRange", "RM 10,000", "status", "offer", "contactEmail", ""))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.jobTitle").value("Staff Engineer"))
        .andExpect(jsonPath("$.salaryRange").value("RM 10,000"))
        .andExpect(jsonPath("$.contactEmail").value((Object) null))
        .andExpect(jsonPath("$.status").value("applied"))
        .andExpect(jsonPath("$.companyName").value("Northwind Labs"));
    get("/api/v1/applications/" + id + "/history", token).andExpect(jsonPath("$.length()").value(1));

    patch("/api/v1/applications/" + id, token, Map.of("jobTitle", ""))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.jobTitle").exists());
  }

  @Test
  void changingTheFollowUpReplacesItsUnfiredReminder() throws Exception {
    String token = newToken("replace@example.com");
    long id = createApplication(token).get("id").asLong();
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_application_id = ?", id)).isEqualTo(1);

    String later = inDays(20);
    patch("/api/v1/applications/" + id, token, Map.of("followUpAt", later))
        .andExpect(jsonPath("$.followUpAt").value(later));
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_application_id = ?", id)).isEqualTo(1);

    java.util.Map<String, Object> clear = new java.util.LinkedHashMap<>();
    clear.put("followUpAt", null);
    patch("/api/v1/applications/" + id, token, clear).andExpect(status().isOk());
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE related_application_id = ?", id)).isZero();
  }

  @Test
  void statusChangeRecordsHistoryNoteAndAnAlert() throws Exception {
    String token = newToken("status@example.com");
    long id = createApplication(token).get("id").asLong();

    var result = post("/api/v1/applications/" + id + "/status", token,
            Map.of("status", "interview", "note", "Recruiter called"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.application.status").value("interview"))
        .andExpect(jsonPath("$.history.fromStatus").value("applied"))
        .andExpect(jsonPath("$.history.toStatus").value("interview"))
        .andExpect(jsonPath("$.history.note").value("Recruiter called"));
    assertThat(body(result).get("history").get("changedAt").asText()).endsWith("Z");

    get("/api/v1/applications/" + id + "/history", token)
        .andExpect(jsonPath("$.length()").value(2))
        .andExpect(jsonPath("$[1].toStatus").value("interview"));

    get("/api/v1/notifications", token)
        .andExpect(jsonPath("$.total").value(1))
        .andExpect(jsonPath("$.items[0].type").value("statusChange"))
        .andExpect(jsonPath("$.items[0].title").value("Moved to Interview"))
        .andExpect(jsonPath("$.items[0].body").value("Northwind Labs · Flutter Developer"))
        .andExpect(jsonPath("$.items[0].relatedApplicationId").value(id))
        .andExpect(jsonPath("$.items[0].isRead").value(false));
  }

  @Test
  void sameStatusIsANoOp() throws Exception {
    String token = newToken("noop@example.com");
    long id = createApplication(token).get("id").asLong();
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "applied"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.application.status").value("applied"))
        .andExpect(jsonPath("$.history.toStatus").value("applied"));
    assertThat(count("SELECT COUNT(*) FROM status_history WHERE application_id = ?", id)).isEqualTo(1);
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'statusChange'")).isZero();
  }

  @Test
  void statusAlertsCanBeSwitchedOff() throws Exception {
    long userId = createUser("quiet@example.com");
    jdbc.update("UPDATE user_settings SET status_alerts_enabled = 0 WHERE user_id = ?", userId);
    String token = token(userId);
    long id = createApplication(token).get("id").asLong();
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "offer")).andExpect(status().isOk());
    assertThat(count("SELECT COUNT(*) FROM status_history WHERE application_id = ?", id)).isEqualTo(2);
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE type = 'statusChange'")).isZero();
  }

  @Test
  void statusChangeValidatesItsBody() throws Exception {
    String token = newToken("badstatus@example.com");
    long id = createApplication(token).get("id").asLong();
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "hired"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.status").exists());
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "offer", "note", "n".repeat(501)))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.note").exists());
  }

  @Test
  void listFiltersByTextStatusArrangementAndDates() throws Exception {
    String token = newToken("filters@example.com");
    createApplication(token, Map.of("jobTitle", "Flutter Dev", "companyName", "Orbit", "location", "KL",
        "workArrangement", "remote", "appliedDate", daysFromToday(-10)));
    JsonNode b = createApplication(token, Map.of("jobTitle", "Backend 100% Engineer", "companyName", "Tidal",
        "location", "Penang", "workArrangement", "onsite", "appliedDate", daysFromToday(-5)));
    createApplication(token, Map.of("jobTitle", "Designer", "companyName", "Lumen", "location", "KL",
        "workArrangement", "hybrid", "appliedDate", daysFromToday(-1), "status", "offer"));
    post("/api/v1/applications/" + b.get("id").asLong() + "/status", token, Map.of("status", "screening"));

    get("/api/v1/applications?q=flutter", token).andExpect(jsonPath("$.total").value(1));
    get("/api/v1/applications?q=TIDAL", token).andExpect(jsonPath("$.total").value(1));
    get("/api/v1/applications?q=kl", token).andExpect(jsonPath("$.total").value(2));
    // % and _ are literal characters, not wildcards.
    get("/api/v1/applications?q=100%", token).andExpect(jsonPath("$.total").value(1));
    get("/api/v1/applications?q=%", token).andExpect(jsonPath("$.total").value(1));
    get("/api/v1/applications?q=_", token).andExpect(jsonPath("$.total").value(0));

    get("/api/v1/applications?status=offer", token).andExpect(jsonPath("$.total").value(1));
    get("/api/v1/applications?status=offer,screening", token).andExpect(jsonPath("$.total").value(2));
    get("/api/v1/applications?status=offer&status=applied", token).andExpect(jsonPath("$.total").value(2));
    get("/api/v1/applications?arrangement=remote,onsite", token).andExpect(jsonPath("$.total").value(2));
    get("/api/v1/applications?from=" + daysFromToday(-6) + "&to=" + daysFromToday(-2), token)
        .andExpect(jsonPath("$.total").value(1))
        .andExpect(jsonPath("$.items[0].companyName").value("Tidal"));
    get("/api/v1/applications?status=hired", token)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.status").exists());
    get("/api/v1/applications?from=yesterday", token).andExpect(status().isBadRequest());
  }

  @Test
  void listSortsByDateCompanyAndPipelineStatus() throws Exception {
    String token = newToken("sort@example.com");
    createApplication(token, Map.of("companyName", "Charlie", "appliedDate", daysFromToday(-3), "status", "rejected"));
    createApplication(token, Map.of("companyName", "Alpha", "appliedDate", daysFromToday(-2), "status", "applied"));
    createApplication(token, Map.of("companyName", "Bravo", "appliedDate", daysFromToday(-1), "status", "interview"));
    createApplication(token, Map.of("companyName", "Delta", "appliedDate", daysFromToday(-4), "status", "offer"));

    assertThat(companies(token, "")).containsExactly("Bravo", "Alpha", "Charlie", "Delta");
    assertThat(companies(token, "?sort=newest")).containsExactly("Bravo", "Alpha", "Charlie", "Delta");
    assertThat(companies(token, "?sort=oldest")).containsExactly("Delta", "Charlie", "Alpha", "Bravo");
    assertThat(companies(token, "?sort=companyAZ")).containsExactly("Alpha", "Bravo", "Charlie", "Delta");
    // Pipeline order, not alphabetical: applied < interview < offer < rejected.
    assertThat(companies(token, "?sort=status")).containsExactly("Alpha", "Bravo", "Delta", "Charlie");
    get("/api/v1/applications?sort=random", token).andExpect(status().isBadRequest());
  }

  private List<String> companies(String token, String query) throws Exception {
    JsonNode page = body(get("/api/v1/applications" + query, token));
    List<String> names = new ArrayList<>();
    page.get("items").forEach(n -> names.add(n.get("companyName").asText()));
    return names;
  }

  @Test
  void listPaginatesAndOmitsTheDescription() throws Exception {
    String token = newToken("paging@example.com");
    for (int i = 0; i < 5; i++) {
      createApplication(token, Map.of("companyName", "Company " + i, "jobDescription", "Long text " + i,
          "appliedDate", daysFromToday(-i)));
    }
    JsonNode first = body(get("/api/v1/applications?page=1&pageSize=2", token)
        .andExpect(jsonPath("$.page").value(1))
        .andExpect(jsonPath("$.pageSize").value(2))
        .andExpect(jsonPath("$.total").value(5))
        .andExpect(jsonPath("$.items.length()").value(2)));
    assertThat(first.get("items").get(0).get("jobDescription").isNull()).isTrue();
    long id = first.get("items").get(0).get("id").asLong();
    get("/api/v1/applications/" + id, token).andExpect(jsonPath("$.jobDescription").value("Long text 0"));

    get("/api/v1/applications?page=3&pageSize=2", token).andExpect(jsonPath("$.items.length()").value(1));
    get("/api/v1/applications?page=9&pageSize=2", token).andExpect(jsonPath("$.items.length()").value(0));
    get("/api/v1/applications?pageSize=101", token).andExpect(status().isBadRequest());
    get("/api/v1/applications?page=0", token).andExpect(status().isBadRequest());
  }

  @Test
  void deletingAnApplicationRemovesItsDependants() throws Exception {
    String token = newToken("cascade@example.com");
    long id = createApplication(token).get("id").asLong();
    createInterview(token, id, Map.of()).andExpect(status().isCreated());
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "interview"));
    assertThat(count("SELECT COUNT(*) FROM interviews")).isEqualTo(1);
    assertThat(count("SELECT COUNT(*) FROM notifications")).isGreaterThan(0);

    delete("/api/v1/applications/" + id, token).andExpect(status().isNoContent());
    assertThat(count("SELECT COUNT(*) FROM interviews")).isZero();
    assertThat(count("SELECT COUNT(*) FROM status_history")).isZero();
    assertThat(count("SELECT COUNT(*) FROM notifications")).isZero();
    get("/api/v1/applications/" + id, token).andExpect(status().isNotFound());
    delete("/api/v1/applications/" + id, token).andExpect(status().isNotFound());
  }

  @Test
  void timelineCombinesHistoryAndInterviews() throws Exception {
    String token = newToken("timeline@example.com");
    long id = createApplication(token).get("id").asLong();
    post("/api/v1/applications/" + id + "/status", token, Map.of("status", "screening"));
    createInterview(token, id, Map.of("title", "Phone screen", "type", "phone"));
    get("/api/v1/applications/" + id + "/timeline", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.history.length()").value(2))
        .andExpect(jsonPath("$.interviews.length()").value(1))
        .andExpect(jsonPath("$.interviews[0].title").value("Phone screen"))
        .andExpect(jsonPath("$.interviews[0].applicationTitle").value("Flutter Developer"));
  }

  @Test
  void nextInterviewAtIsTheEarliestFuturePendingInterview() throws Exception {
    String token = newToken("next@example.com");
    long id = createApplication(token).get("id").asLong();
    String soon = inDays(2);
    createInterview(token, id, Map.of("scheduledAt", inDays(5), "title", "Later"));
    createInterview(token, id, Map.of("scheduledAt", soon, "title", "Sooner"));
    createInterview(token, id, Map.of("scheduledAt", inDays(-3), "title", "Past"));
    createInterview(token, id, Map.of("scheduledAt", inDays(1), "title", "Cancelled", "outcome", "cancelled"));

    JsonNode app = body(get("/api/v1/applications/" + id, token));
    assertThat(Instant.parse(app.get("nextInterviewAt").asText())).isEqualTo(Instant.parse(soon));
    JsonNode listed = body(get("/api/v1/applications", token));
    assertThat(Instant.parse(listed.get("items").get(0).get("nextInterviewAt").asText())).isEqualTo(Instant.parse(soon));
  }

  @Test
  void listingAThousandApplicationsIsFastAndUsesAnIndex() throws Exception {
    long userId = createUser("perf@example.com");
    String token = token(userId);
    jdbc.update("""
        INSERT INTO job_applications
          (user_id, job_title, company_name, location, work_arrangement, applied_date, status)
        WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 1000)
        SELECT ?, CONCAT('Title ', i), CONCAT('Company ', i), 'KL', 'remote',
               DATE_SUB(CURDATE(), INTERVAL i % 365 DAY),
               ELT(i % 5 + 1, 'applied', 'screening', 'interview', 'offer', 'rejected')
        FROM n""", userId);
    assertThat(count("SELECT COUNT(*) FROM job_applications WHERE user_id = ?", userId)).isEqualTo(1000);

    get("/api/v1/applications?pageSize=50", token).andExpect(status().isOk()); // warm up pool and plan cache
    long started = System.nanoTime();
    get("/api/v1/applications?pageSize=50&status=applied,screening&sort=status", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.items.length()").value(50))
        .andExpect(jsonPath("$.total").value(400));
    long millis = (System.nanoTime() - started) / 1_000_000;
    assertThat(millis).as("list latency in ms").isLessThan(200);

    // EXPLAIN: the user_id + status/applied_date filters must not fall back to a full table scan.
    String key = jdbc.queryForMap("EXPLAIN SELECT id FROM job_applications "
        + "WHERE user_id = ? AND status IN ('applied') ORDER BY applied_date DESC LIMIT 50", userId)
        .get("key").toString();
    assertThat(key).startsWith("idx_app_user");
  }

  @Test
  void unknownRoutesUseTheErrorShape() throws Exception {
    String token = newToken("route@example.com");
    get("/api/v1/nope", token)
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
  }

  @Test
  void healthIsPublic() throws Exception {
    get("/api/v1/health", null).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("ok"));
  }
}
