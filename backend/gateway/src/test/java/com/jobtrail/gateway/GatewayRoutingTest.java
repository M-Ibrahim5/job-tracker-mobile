package com.jobtrail.gateway;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayRoutingTest {

  private static final StubService USER = new StubService("user");
  private static final StubService TRACKER = new StubService("tracker");

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", TRACKER::url);
    registry.add("jobtrail.gateway.api-limit", () -> "100000");
    registry.add("jobtrail.gateway.auth-limit", () -> "100000");
  }

  @AfterAll
  static void stopStubs() {
    USER.stop();
    TRACKER.stop();
  }

  @Autowired WebTestClient client;

  @Test
  void accountPathsGoToTheUserService() {
    for (String path : new String[] {"/api/v1/auth/login", "/api/v1/auth/change-password", "/api/v1/me",
        "/api/v1/me/settings", "/api/v1/me/avatar", "/uploads/avatars/1-abc.png"}) {
      client.post().uri(path).contentType(MediaType.APPLICATION_JSON).bodyValue("{}")
          .exchange()
          .expectStatus().isOk()
          .expectBody().jsonPath("$.service").isEqualTo("user");
    }
  }

  @Test
  void trackerPathsGoToTheTrackerService() {
    for (String path : new String[] {"/api/v1/applications", "/api/v1/applications/5/status",
        "/api/v1/applications/5/interviews", "/api/v1/interviews/3", "/api/v1/notifications/unread-count",
        "/api/v1/reminders/upcoming", "/api/v1/dashboard", "/api/v1/calendar", "/api/v1/export", "/api/v1/data"}) {
      client.get().uri(path)
          .exchange()
          .expectStatus().isOk()
          .expectBody().jsonPath("$.service").isEqualTo("tracker");
    }
  }

  @Test
  void queryStringMethodAndHeadersAreForwarded() {
    client.patch().uri("/api/v1/applications/7?sort=status&status=offer,applied")
        .header("Authorization", "Bearer abc.def")
        .header("X-Timezone", "Asia/Kuala_Lumpur")
        .contentType(MediaType.APPLICATION_JSON)
        .bodyValue("{}")
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.method").isEqualTo("PATCH")
        .jsonPath("$.uri").isEqualTo("/api/v1/applications/7?sort=status&status=offer,applied")
        .jsonPath("$.authorization").isEqualTo("Bearer abc.def")
        .jsonPath("$.timezone").isEqualTo("Asia/Kuala_Lumpur");
  }

  @Test
  void internalEndpointsAreNeverExposed() {
    client.get().uri("/internal/users/1/settings")
        .header("X-Internal-Key", "anything")
        .exchange()
        .expectStatus().isNotFound()
        .expectBody().jsonPath("$.error.code").isEqualTo("NOT_FOUND");
  }

  @Test
  void unknownRoutesUseTheErrorShape() {
    client.get().uri("/api/v1/nothing-here")
        .exchange()
        .expectStatus().isNotFound()
        .expectBody()
        .jsonPath("$.error.code").isEqualTo("NOT_FOUND")
        .jsonPath("$.error.message").isNotEmpty();
  }

  @Test
  void healthReportsEveryServiceAndTheVersion() {
    client.get().uri("/api/v1/health")
        .exchange()
        .expectStatus().isOk()
        .expectBody()
        .jsonPath("$.status").isEqualTo("ok")
        .jsonPath("$.version").isNotEmpty()
        .jsonPath("$.services.user").isEqualTo("up")
        .jsonPath("$.services.tracker").isEqualTo("up");
  }

  @Test
  void aClientCannotPresentTheInternalKeyToAService() {
    client.get().uri("/api/v1/applications").header("X-Internal-Key", "guessed-key")
        .exchange()
        .expectStatus().isOk()
        .expectBody().jsonPath("$.internalKey").isEqualTo("");
  }
}
