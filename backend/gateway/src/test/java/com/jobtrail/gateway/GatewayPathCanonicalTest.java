package com.jobtrail.gateway;

import java.net.URI;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

/**
 * The rate limits test the raw path with plain string prefixes, while routing and the services
 * match decoded segments. Paths that differ between the two views must never be forwarded.
 */
@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayPathCanonicalTest {

  private static final StubService USER = new StubService("user");
  private static final StubService TRACKER = new StubService("tracker");

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", TRACKER::url);
    registry.add("jobtrail.gateway.api-limit", () -> "6");
    registry.add("jobtrail.gateway.auth-limit", () -> "3");
  }

  @AfterAll
  static void stopStubs() {
    USER.stop();
    TRACKER.stop();
  }

  @Autowired WebTestClient client;

  @LocalServerPort int port;

  private WebTestClient.ResponseSpec post(String rawPath) {
    // An absolute URI keeps the path exactly as written; uri(String) would encode '%' into '%25'.
    return client.post().uri(URI.create("http://127.0.0.1:" + port + rawPath)).exchange();
  }

  @Test
  void encodedOrParameterisedVariantsOfApiPathsAreRejected() {
    for (String path : new String[] {
        "/%61pi/v1/auth/login",
        "/api/v1;x/auth/login",
        "/api/v1/%61uth/login",
        "/api/v1/auth;x/login",
        "/api/v1//auth/login",
        "/api/v1/auth/./login",
        "/api/v1/me/../auth/login",
        "/api/v1/me/../../internal/users/1/settings"}) {
      post(path).expectStatus().isNotFound()
          .expectBody().jsonPath("$.error.code").isEqualTo("NOT_FOUND");
    }
  }

  @Test
  void rejectedPathsDoNotCountAsRoutedRequests() {
    // Five rejected variants, then the canonical path still has its whole auth budget.
    for (int i = 0; i < 5; i++) {
      post("/api/v1/%61uth/login").expectStatus().isNotFound();
    }
    for (int i = 0; i < 3; i++) {
      post("/api/v1/auth/login").expectStatus().isOk();
    }
    post("/api/v1/auth/login").expectStatus().isEqualTo(429);
  }

  @Test
  void canonicalPathsStillRoute() {
    client.get().uri("/api/v1/applications").exchange().expectStatus().isOk();
    client.get().uri("/uploads/avatars/1-0123456789abcdef01234567.png").exchange().expectStatus().isOk();
  }
}
