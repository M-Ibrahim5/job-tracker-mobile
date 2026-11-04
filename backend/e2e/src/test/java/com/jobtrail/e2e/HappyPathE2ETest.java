package com.jobtrail.e2e;

import static org.assertj.core.api.Assertions.assertThat;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;

/**
 * Walks the whole API through the gateway of a RUNNING stack (user-service, tracker-service,
 * gateway, MySQL). It registers throw-away accounts and deletes them again.
 *
 * <pre>mvn -pl e2e test -De2e=true [-Dbase.url=http://localhost:3000/api/v1]</pre>
 */
@EnabledIfSystemProperty(named = "e2e", matches = "true")
class HappyPathE2ETest {

  private static final String BASE = System.getProperty("base.url", "http://localhost:3000/api/v1");
  private static final String PASSWORD = "Passw0rd!";

  private final HttpClient http = HttpClient.newHttpClient();
  private final ObjectMapper json = new ObjectMapper();

  /** Response status and parsed body (null for 204 / non-JSON). */
  private record Reply(int status, JsonNode body, String raw) {}

  private Reply call(String method, String path, String token, Object body) throws Exception {
    HttpRequest.Builder request = HttpRequest.newBuilder(URI.create(BASE + path))
        .header("Content-Type", "application/json");
    if (token != null) {
      request.header("Authorization", "Bearer " + token);
    }
    request.method(method, body == null
        ? HttpRequest.BodyPublishers.noBody()
        : HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body)));
    HttpResponse<String> response = http.send(request.build(), HttpResponse.BodyHandlers.ofString());
    JsonNode parsed = null;
    String raw = response.body();
    if (!raw.isBlank() && (raw.startsWith("{") || raw.startsWith("["))) {
      try {
        parsed = json.readTree(raw);
      } catch (IOException ignored) {
        // CSV and other non-JSON payloads stay available as raw text
      }
    }
    return new Reply(response.statusCode(), parsed, raw);
  }

  private static Map<String, Object> map(Object... pairs) {
    Map<String, Object> m = new LinkedHashMap<>();
    for (int i = 0; i < pairs.length; i += 2) {
      m.put((String) pairs[i], pairs[i + 1]);
    }
    return m;
  }

  private JsonNode register(String email) throws Exception {
    Reply r = call("POST", "/auth/register", null, map("fullName", "E2E User", "email", email, "password", PASSWORD));
    assertThat(r.status()).as("register %s", r.raw()).isEqualTo(201);
    return r.body();
  }

  @Test
  void fullHappyPath() throws Exception {
    // 1. health
    Reply health = call("GET", "/health", null, null);
    assertThat(health.status()).isEqualTo(200);
    assertThat(health.body().get("status").asText()).isEqualTo("ok");

    // 2. register + login + me
    String email = "e2e-" + UUID.randomUUID() + "@jobtrail.test";
    JsonNode auth = register(email);
    String token = auth.get("accessToken").asText();
    assertThat(call("POST", "/auth/register", null,
        map("fullName", "Dup", "email", email, "password", PASSWORD)).status()).isEqualTo(409);
    JsonNode login = call("POST", "/auth/login", null, map("email", email, "password", PASSWORD)).body();
    assertThat(login.get("user").get("email").asText()).isEqualTo(email);
    assertThat(call("GET", "/me", token, null).body().get("email").asText()).isEqualTo(email);
    assertThat(call("GET", "/me", null, null).status()).isEqualTo(401);

    // 3. application + initial history
    String today = LocalDate.now(ZoneOffset.UTC).toString();
    Reply created = call("POST", "/applications", token, map("jobTitle", "Flutter Developer",
        "companyName", "E2E Corp", "location", "Kuala Lumpur", "workArrangement", "hybrid", "appliedDate", today));
    assertThat(created.status()).as(created.raw()).isEqualTo(201);
    long appId = created.body().get("id").asLong();
    assertThat(call("GET", "/applications/" + appId + "/history", token, null).body()).hasSize(1);

    // 4. another user cannot see it
    String otherEmail = "other-" + UUID.randomUUID() + "@jobtrail.test";
    JsonNode other = register(otherEmail);
    String otherToken = other.get("accessToken").asText();
    assertThat(call("GET", "/applications/" + appId, otherToken, null).status()).isEqualTo(404);
    assertThat(call("GET", "/applications", otherToken, null).body().get("total").asInt()).isZero();

    // 5. status change -> history + alert
    Reply status = call("POST", "/applications/" + appId + "/status", token,
        map("status", "interview", "note", "Recruiter called"));
    assertThat(status.status()).isEqualTo(200);
    assertThat(status.body().get("application").get("status").asText()).isEqualTo("interview");
    assertThat(call("GET", "/applications/" + appId + "/history", token, null).body()).hasSize(2);
    assertThat(call("GET", "/notifications/unread-count", token, null).body().get("count").asInt()).isEqualTo(1);

    // 6. interview, conflict, reminders
    String when = Instant.now().plus(3, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS).toString();
    Reply interview = call("POST", "/applications/" + appId + "/interviews", token,
        map("title", "Technical interview", "type", "video", "scheduledAt", when));
    assertThat(interview.status()).as(interview.raw()).isEqualTo(201);
    assertThat(call("POST", "/applications/" + appId + "/interviews", token,
        map("title", "Again", "type", "phone", "scheduledAt", when)).status()).isEqualTo(409);
    JsonNode reminders = call("GET", "/reminders/upcoming", token, null).body().get("items");
    assertThat(reminders.size()).isGreaterThanOrEqualTo(2);

    // 7. dashboard + calendar
    JsonNode dashboard = call("GET", "/dashboard?tz=Asia/Kuala_Lumpur", token, null).body();
    assertThat(dashboard.get("total").asInt()).isEqualTo(1);
    assertThat(dashboard.get("weekly")).hasSize(8);
    assertThat(dashboard.get("upcomingInterviews")).hasSize(1);
    LocalDate now = LocalDate.now(ZoneOffset.UTC);
    JsonNode calendar = call("GET", "/calendar?from=" + now.minusDays(1) + "&to=" + now.plusDays(10)
        + "&tz=Asia/Kuala_Lumpur", token, null).body();
    assertThat(calendar.get("events").size()).isGreaterThanOrEqualTo(3);

    // 8. export
    Reply exportJson = call("GET", "/export?format=json", token, null);
    assertThat(exportJson.body().get("applications")).hasSize(1);
    Reply exportCsv = call("GET", "/export?format=csv", token, null);
    assertThat(exportCsv.raw()).startsWith("id,jobTitle,companyName").contains("E2E Corp");

    // 9. refresh rotation and reuse detection
    String refresh = login.get("refreshToken").asText();
    JsonNode rotated = call("POST", "/auth/refresh", null, map("refreshToken", refresh)).body();
    assertThat(rotated.get("refreshToken").asText()).isNotEqualTo(refresh);
    assertThat(call("POST", "/auth/refresh", null, map("refreshToken", refresh)).status()).isEqualTo(401);
    assertThat(call("POST", "/auth/refresh", null, map("refreshToken", rotated.get("refreshToken").asText()))
        .status()).isEqualTo(401);

    // 10. delete all data, then the accounts
    assertThat(call("DELETE", "/data", token, map("confirm", "nope")).status()).isEqualTo(400);
    assertThat(call("DELETE", "/data", token, map("confirm", "DELETE")).status()).isEqualTo(204);
    assertThat(call("GET", "/applications", token, null).body().get("total").asInt()).isZero();
    assertThat(call("DELETE", "/me", token, map("password", PASSWORD)).status()).isEqualTo(204);
    assertThat(call("DELETE", "/me", otherToken, map("password", PASSWORD)).status()).isEqualTo(204);
    assertThat(call("POST", "/auth/login", null, map("email", email, "password", PASSWORD)).status())
        .isEqualTo(401);
  }
}
