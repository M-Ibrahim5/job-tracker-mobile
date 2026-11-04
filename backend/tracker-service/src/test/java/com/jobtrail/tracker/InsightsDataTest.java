package com.jobtrail.tracker;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.time.TimeUtil;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

class InsightsDataTest extends TrackerTest {

  private static final String KL = "Asia/Kuala_Lumpur";

  private JsonNode app(String token, String company, String status, LocalDate applied) throws Exception {
    Map<String, Object> overrides = new LinkedHashMap<>();
    overrides.put("companyName", company);
    overrides.put("status", status);
    overrides.put("appliedDate", applied.toString());
    overrides.put("followUpAt", null);
    return createApplication(token, overrides);
  }

  // ----- dashboard ----------------------------------------------------------------------------

  @Test
  void dashboardIsEmptyForANewUser() throws Exception {
    String token = newToken("dash0@example.com");
    JsonNode dash = body(get("/api/v1/dashboard", token).andExpect(status().isOk()));
    assertThat(dash.get("total").asInt()).isZero();
    assertThat(dash.get("active").asInt()).isZero();
    assertThat(dash.get("responseRatePercent").asInt()).isZero();
    assertThat(dash.get("statusCounts").size()).isEqualTo(5);
    assertThat(dash.get("weekly")).hasSize(8);
    assertThat(dash.get("upcomingInterviews")).isEmpty();
    assertThat(dash.get("recentActivity")).isEmpty();
  }

  @Test
  void dashboardNumbersMatchTheFixtures() throws Exception {
    String token = newToken("dash@example.com");
    LocalDate monday = TimeUtil.mondayOf(today());
    app(token, "Co1", "applied", monday);
    long co2 = app(token, "Co2", "applied", monday).get("id").asLong();
    app(token, "Co3", "screening", monday.minusDays(7));
    app(token, "Co4", "interview", monday.minusDays(8));
    app(token, "Co5", "offer", monday.minusDays(30));
    app(token, "Co6", "rejected", monday.minusDays(120));
    post("/api/v1/applications/" + co2 + "/status", token, Map.of("status", "screening"));

    JsonNode dash = body(get("/api/v1/dashboard?tz=UTC", token).andExpect(status().isOk()));
    assertThat(dash.get("total").asInt()).isEqualTo(6);
    // active = everything except offer and rejected; response rate = share that is past "applied".
    assertThat(dash.get("active").asInt()).isEqualTo(4);
    assertThat(dash.get("responseRatePercent").asInt()).isEqualTo(83);
    JsonNode counts = dash.get("statusCounts");
    assertThat(counts.get("applied").asInt()).isEqualTo(1);
    assertThat(counts.get("screening").asInt()).isEqualTo(2);
    assertThat(counts.get("interview").asInt()).isEqualTo(1);
    assertThat(counts.get("offer").asInt()).isEqualTo(1);
    assertThat(counts.get("rejected").asInt()).isEqualTo(1);

    // Eight Monday-start weeks, oldest first, the last one is the current week; zero weeks included.
    JsonNode weekly = dash.get("weekly");
    int[] expected = {0, 0, 1, 0, 0, 1, 1, 2};
    assertThat(weekly).hasSize(8);
    for (int i = 0; i < 8; i++) {
      assertThat(weekly.get(i).get("weekStart").asText()).isEqualTo(monday.minusWeeks(7 - i).toString());
      assertThat(weekly.get(i).get("count").asInt()).as("week %d", i).isEqualTo(expected[i]);
    }

    // Only real status changes count as activity, never the initial entries.
    JsonNode recent = dash.get("recentActivity");
    assertThat(recent).hasSize(1);
    assertThat(recent.get(0).get("companyName").asText()).isEqualTo("Co2");
    assertThat(recent.get(0).get("toStatus").asText()).isEqualTo("screening");
    assertThat(recent.get(0).get("applicationId").asLong()).isEqualTo(co2);
  }

  @Test
  void dashboardListsTheNextThreePendingInterviews() throws Exception {
    String token = newToken("dash2@example.com");
    long appId = app(token, "Co", "interview", today()).get("id").asLong();
    createInterview(token, appId, Map.of("title", "I-4", "scheduledAt", inDays(8)));
    createInterview(token, appId, Map.of("title", "I-1", "scheduledAt", inDays(1)));
    createInterview(token, appId, Map.of("title", "I-3", "scheduledAt", inDays(5)));
    createInterview(token, appId, Map.of("title", "I-2", "scheduledAt", inDays(3)));
    createInterview(token, appId, Map.of("title", "past", "scheduledAt", inDays(-1)));
    createInterview(token, appId, Map.of("title", "cancelled", "scheduledAt", inDays(2), "outcome", "cancelled"));

    JsonNode upcoming = body(get("/api/v1/dashboard", token)).get("upcomingInterviews");
    List<String> titles = new java.util.ArrayList<>();
    upcoming.forEach(n -> titles.add(n.get("title").asText()));
    assertThat(titles).containsExactly("I-1", "I-2", "I-3");
    assertThat(upcoming.get(0).get("companyName").asText()).isEqualTo("Co");
  }

  @Test
  void dashboardIsPerUserAndValidatesTheTimeZone() throws Exception {
    String alice = newToken("dash-a@example.com");
    String bob = newToken("dash-b@example.com");
    app(alice, "Co", "applied", today());
    assertThat(body(get("/api/v1/dashboard", bob)).get("total").asInt()).isZero();
    get("/api/v1/dashboard?tz=Mars/Base", alice)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.tz").value("Unknown time zone"));
    get("/api/v1/dashboard?tz=" + KL, alice).andExpect(status().isOk());
  }

  // ----- calendar -----------------------------------------------------------------------------

  @Test
  void calendarReturnsEveryEventTypeInDateOrder() throws Exception {
    String token = newToken("cal@example.com");
    LocalDate today = today();
    Map<String, Object> overrides = new LinkedHashMap<>();
    overrides.put("appliedDate", today.toString());
    overrides.put("followUpAt", today.plusDays(3) + "T09:00:00.000Z");
    long appId = createApplication(token, overrides).get("id").asLong();
    post("/api/v1/applications/" + appId + "/status", token, Map.of("status", "screening"));
    long interviewId = body(createInterview(token, appId,
        Map.of("title", "Round 1", "scheduledAt", today.plusDays(2) + "T04:00:00.000Z", "type", "phone")))
        .get("id").asLong();

    JsonNode events = body(get("/api/v1/calendar?from=" + today.minusDays(1) + "&to=" + today.plusDays(10)
        + "&tz=UTC", token).andExpect(status().isOk())).get("events");
    assertThat(events).hasSize(4);
    assertThat(events.get(0).get("type").asText()).isEqualTo("applied");
    assertThat(events.get(0).get("date").asText()).isEqualTo(today.toString());
    assertThat(events.get(0).get("title").asText()).isEqualTo("Flutter Developer");

    JsonNode change = events.get(1);
    assertThat(change.get("type").asText()).isEqualTo("statusChange");
    assertThat(change.get("status").asText()).isEqualTo("screening");
    assertThat(change.get("at").asText()).endsWith("Z");

    JsonNode interview = events.get(2);
    assertThat(interview.get("type").asText()).isEqualTo("interview");
    assertThat(interview.get("date").asText()).isEqualTo(today.plusDays(2).toString());
    assertThat(interview.get("interviewId").asLong()).isEqualTo(interviewId);
    assertThat(interview.get("title").asText()).isEqualTo("Round 1");
    assertThat(interview.get("interviewType").asText()).isEqualTo("phone");
    assertThat(interview.get("companyName").asText()).isEqualTo("Northwind Labs");

    JsonNode followUp = events.get(3);
    assertThat(followUp.get("type").asText()).isEqualTo("followUp");
    assertThat(followUp.get("date").asText()).isEqualTo(today.plusDays(3).toString());
  }

  @Test
  void calendarDatesFollowTheRequestedTimeZone() throws Exception {
    String token = newToken("caltz@example.com");
    LocalDate day = today().plusDays(4);
    long appId = createApplication(token, Map.of("followUpAt", day.plusDays(20) + "T09:00:00.000Z"))
        .get("id").asLong();
    // 20:00 UTC is already the next morning (04:00) in Kuala Lumpur.
    createInterview(token, appId, Map.of("scheduledAt", day + "T20:00:00.000Z"));
    String range = "from=" + day.minusDays(2) + "&to=" + day.plusDays(3);

    JsonNode utc = body(get("/api/v1/calendar?" + range + "&tz=UTC", token)).get("events");
    JsonNode kl = body(get("/api/v1/calendar?" + range + "&tz=" + KL, token)).get("events");
    assertThat(dateOf(utc, "interview")).isEqualTo(day.toString());
    assertThat(dateOf(kl, "interview")).isEqualTo(day.plusDays(1).toString());
    // Without a tz the calendar uses UTC.
    assertThat(dateOf(body(get("/api/v1/calendar?" + range, token)).get("events"), "interview"))
        .isEqualTo(day.toString());
  }

  private static String dateOf(JsonNode events, String type) {
    for (JsonNode e : events) {
      if (e.get("type").asText().equals(type)) {
        return e.get("date").asText();
      }
    }
    return null;
  }

  @Test
  void calendarRejectsBadRanges() throws Exception {
    String token = newToken("calbad@example.com");
    LocalDate today = today();
    get("/api/v1/calendar?from=" + today + "&to=" + today.plusDays(69), token).andExpect(status().isOk());
    get("/api/v1/calendar?from=" + today + "&to=" + today.plusDays(70), token)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.fields.to").exists());
    get("/api/v1/calendar?from=" + today + "&to=" + today.minusDays(1), token).andExpect(status().isBadRequest());
    get("/api/v1/calendar?to=" + today, token)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.from").value("This field is required"));
    get("/api/v1/calendar?from=2026-13-40&to=" + today, token).andExpect(status().isBadRequest());
    get("/api/v1/calendar?from=" + today + "&to=" + today + "&tz=Nowhere/Land", token)
        .andExpect(status().isBadRequest());
  }

  @Test
  void calendarOnlyShowsTheUsersOwnEvents() throws Exception {
    String alice = newToken("cal-a@example.com");
    String bob = newToken("cal-b@example.com");
    createApplication(alice);
    String range = "/api/v1/calendar?from=" + today().minusDays(1) + "&to=" + today().plusDays(1);
    assertThat(body(get(range, bob)).get("events")).isEmpty();
    assertThat(body(get(range, alice)).get("events")).hasSize(1);
  }

  // ----- export -------------------------------------------------------------------------------

  private String text(ResultActions result) throws Exception {
    return result.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
  }

  @Test
  void jsonExportIncludesHistoryAndInterviews() throws Exception {
    String alice = newToken("exp-a@example.com");
    String bob = newToken("exp-b@example.com");
    long id = createApplication(alice, Map.of("jobDescription", "Build things")).get("id").asLong();
    post("/api/v1/applications/" + id + "/status", alice, Map.of("status", "interview", "note", "Called"));
    createInterview(alice, id, Map.of("title", "Tech round"));
    createApplication(bob, Map.of("companyName", "Bob Corp"));

    ResultActions result = get("/api/v1/export?format=json", alice)
        .andExpect(status().isOk())
        .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.startsWith("attachment; filename=\"jobtrail-export-")))
        .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.endsWith(".json\"")));
    JsonNode export = json.readTree(text(result));
    assertThat(export.get("exportedAt").asText()).endsWith("Z");
    assertThat(export.get("applications")).hasSize(1);
    JsonNode application = export.get("applications").get(0);
    assertThat(application.get("jobDescription").asText()).isEqualTo("Build things");
    assertThat(application.has("nextInterviewAt")).isFalse();
    assertThat(application.get("history")).hasSize(2);
    assertThat(application.get("history").get(1).get("note").asText()).isEqualTo("Called");
    assertThat(application.get("interviews")).hasSize(1);
    assertThat(application.get("interviews").get(0).get("title").asText()).isEqualTo("Tech round");
    assertThat(text(result)).doesNotContain("Bob Corp");

    // The format defaults to JSON.
    assertThat(json.readTree(text(get("/api/v1/export", alice))).get("applications")).hasSize(1);
  }

  @Test
  void jsonExportOfNothingIsStillValid() throws Exception {
    String token = newToken("exp-empty@example.com");
    JsonNode export = json.readTree(text(get("/api/v1/export?format=json", token)));
    assertThat(export.get("applications")).isEmpty();
  }

  @Test
  void csvExportFormatsCreatedAndUpdatedInTheRequestedZone() throws Exception {
    String token = newToken("csv-stamp@example.com");
    createApplication(token, Map.of("companyName", "Stamp Co"));

    String csv = text(get("/api/v1/export?format=csv", token, "Asia/Kuala_Lumpur"));
    String utc = text(get("/api/v1/export?format=csv", token));
    assertThat(csv).isNotEqualTo(utc); // UTC+8 shifts the printed time
    // createdAt and updatedAt read dd/MM/yyyy | hh:mm AM/PM (followUpAt keeps its ISO value).
    String stamp = "\\d{2}/\\d{2}/\\d{4} \\| \\d{2}:\\d{2} (AM|PM)";
    assertThat(csv).containsPattern(stamp + "," + stamp + "\r\n");
  }

  @Test
  void csvExportEscapesSpecialCharacters() throws Exception {
    String token = newToken("csv@example.com");
    createApplication(token, Map.of("jobTitle", "Dev, Senior \"Staff\"", "companyName", "=SUM(A1)",
        "notes", "line one\nline two"));
    createApplication(token, Map.of("companyName", "Plain Co", "location", "Penang"));

    ResultActions result = get("/api/v1/export?format=csv", token)
        .andExpect(status().isOk())
        .andExpect(header().string("Content-Type", org.hamcrest.Matchers.startsWith("text/csv")))
        .andExpect(header().string("Content-Disposition", org.hamcrest.Matchers.endsWith(".csv\"")));
    String csv = text(result);
    assertThat(csv).startsWith("id,jobTitle,companyName,location,workArrangement,employmentType,salaryRange,source,"
        + "appliedDate,status,applicationLink,contactName,contactEmail,followUpAt,notes,jobDescription,createdAt,"
        + "updatedAt\r\n");
    assertThat(csv).contains("\"Dev, Senior \"\"Staff\"\"\"");
    assertThat(csv).contains("\"'=SUM(A1)\"".replace("\"", "")); // formula neutralised with a leading quote
    assertThat(csv).doesNotContain(",=SUM(A1),");
    assertThat(csv).contains("\"line one\nline two\"");
    assertThat(csv.split("\r\n")).hasSizeGreaterThanOrEqualTo(3);
    assertThat(csv).contains("Plain Co,Penang,hybrid");
  }

  @Test
  void exportRejectsUnknownFormatsAndNeedsAuth() throws Exception {
    String token = newToken("exp-bad@example.com");
    get("/api/v1/export?format=xml", token)
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.format").exists());
    get("/api/v1/export", null).andExpect(status().isUnauthorized());
  }

  @Test
  void exportWalksMoreThanOneBatch() throws Exception {
    long userId = createUser("big@example.com");
    for (int i = 0; i < 520; i++) {
      jdbc.update("INSERT INTO job_applications (user_id, job_title, company_name, location, work_arrangement, "
          + "applied_date) VALUES (?, 'T', ?, 'L', 'remote', CURDATE())", userId, "Bulk " + i);
    }
    JsonNode export = json.readTree(text(get("/api/v1/export?format=json", token(userId))));
    assertThat(export.get("applications")).hasSize(520);
    String csv = text(get("/api/v1/export?format=csv", token(userId)));
    assertThat(csv.split("\r\n")).hasSize(521);
  }

  // ----- delete all ---------------------------------------------------------------------------

  @Test
  void deleteAllRequiresTheConfirmationWord() throws Exception {
    String token = newToken("del0@example.com");
    createApplication(token);
    delete("/api/v1/data", token, Map.of()).andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.confirm").value("Type DELETE to confirm"));
    delete("/api/v1/data", token, Map.of("confirm", "delete")).andExpect(status().isBadRequest());
    delete("/api/v1/data", token).andExpect(status().isBadRequest());
    assertThat(count("SELECT COUNT(*) FROM job_applications")).isEqualTo(1);
  }

  @Test
  void deleteAllRemovesTheUsersDataButKeepsTheAccount() throws Exception {
    long aliceId = createUser("del-a@example.com");
    String alice = token(aliceId);
    String bob = newToken("del-b@example.com");
    long id = createApplication(alice).get("id").asLong();
    createInterview(alice, id, Map.of());
    post("/api/v1/applications/" + id + "/status", alice, Map.of("status", "offer"));
    createApplication(bob);

    delete("/api/v1/data", alice, Map.of("confirm", "DELETE")).andExpect(status().isNoContent());

    assertThat(count("SELECT COUNT(*) FROM job_applications WHERE user_id = ?", aliceId)).isZero();
    assertThat(count("SELECT COUNT(*) FROM interviews WHERE user_id = ?", aliceId)).isZero();
    assertThat(count("SELECT COUNT(*) FROM status_history WHERE user_id = ?", aliceId)).isZero();
    assertThat(count("SELECT COUNT(*) FROM notifications WHERE user_id = ?", aliceId)).isZero();
    assertThat(count("SELECT COUNT(*) FROM users WHERE id = ?", aliceId)).isEqualTo(1);
    assertThat(count("SELECT COUNT(*) FROM user_settings WHERE user_id = ?", aliceId)).isEqualTo(1);
    // Bob is untouched.
    assertThat(count("SELECT COUNT(*) FROM job_applications")).isEqualTo(1);
    get("/api/v1/applications", bob).andExpect(jsonPath("$.total").value(1));
  }
}
