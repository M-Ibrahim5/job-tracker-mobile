package com.jobtrail.gateway;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayRateLimitTest {

  private static final String SECRET = "gateway-test-secret-0123456789abcdefghijkl";
  private static final StubService USER = new StubService("user");
  private static final StubService TRACKER = new StubService("tracker");

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", TRACKER::url);
    registry.add("jobtrail.gateway.api-limit", () -> "6");
    registry.add("jobtrail.gateway.auth-limit", () -> "3");
    registry.add("jobtrail.gateway.token-limit", () -> "5");
    registry.add("jobtrail.jwt.secret", () -> SECRET);
    registry.add("jobtrail.gateway.trust-forwarded-for", () -> "true");
  }

  @AfterAll
  static void stopStubs() {
    USER.stop();
    TRACKER.stop();
  }

  @Autowired WebTestClient client;

  private WebTestClient.ResponseSpec call(String ip, String path) {
    return client.get().uri(path).header("X-Forwarded-For", ip).exchange();
  }

  private WebTestClient.ResponseSpec callAs(String ip, String token, String path) {
    return client.get().uri(path).header("X-Forwarded-For", ip).header("Authorization", "Bearer " + token)
        .exchange();
  }

  private static String token(long userId, String secret) {
    return io.jsonwebtoken.Jwts.builder()
        .subject(Long.toString(userId))
        .expiration(java.util.Date.from(java.time.Instant.now().plusSeconds(600)))
        .signWith(io.jsonwebtoken.security.Keys.hmacShaKeyFor(
            secret.getBytes(java.nio.charset.StandardCharsets.UTF_8)))
        .compact();
  }

  @Test
  void signedInUsersBehindOneIpHaveTheirOwnBudget() {
    String alice = token(1, SECRET);
    String bob = token(2, SECRET);
    for (int i = 0; i < 6; i++) {
      callAs("10.0.2.1", alice, "/api/v1/applications").expectStatus().isOk();
    }
    callAs("10.0.2.1", alice, "/api/v1/applications").expectStatus().isEqualTo(429);
    // Same IP, different user: not affected.
    callAs("10.0.2.1", bob, "/api/v1/applications").expectStatus().isOk();
    // Anonymous traffic from that IP is counted per IP, separately from the users.
    call("10.0.2.1", "/api/v1/applications").expectStatus().isOk();
  }

  @Test
  void forgedOrInvalidTokensFallBackToTheIpBudget() {
    String forged = token(99, "some-other-secret-0123456789abcdefghijklmn");
    for (int i = 0; i < 6; i++) {
      callAs("10.0.3.1", forged + (i == 0 ? "" : "x"), "/api/v1/applications").expectStatus().isOk();
    }
    callAs("10.0.3.1", token(98, "yet-another-secret-0123456789abcdefghijkl"), "/api/v1/applications")
        .expectStatus().isEqualTo(429);
  }

  @Test
  void refreshHasItsOwnHigherBudgetThanLogin() {
    for (int i = 0; i < 3; i++) {
      call("10.0.4.1", "/api/v1/auth/login").expectStatus().isOk();
    }
    call("10.0.4.1", "/api/v1/auth/login").expectStatus().isEqualTo(429);
    // Logins used up their budget, but refreshing and device login still work.
    call("10.0.4.1", "/api/v1/auth/refresh").expectStatus().isOk();
    call("10.0.4.1", "/api/v1/auth/device-login").expectStatus().isOk();
  }

  @Test
  void authEndpointsAreLimitedPerClient() {
    for (int i = 0; i < 3; i++) {
      call("10.0.0.1", "/api/v1/auth/login").expectStatus().isOk();
    }
    call("10.0.0.1", "/api/v1/auth/login")
        .expectStatus().isEqualTo(429)
        .expectHeader().exists("Retry-After")
        .expectBody().jsonPath("$.error.code").isEqualTo("RATE_LIMITED");
    // Another client has its own budget, and non-auth routes are not affected by the auth limit.
    call("10.0.0.2", "/api/v1/auth/login").expectStatus().isOk();
    call("10.0.0.1", "/api/v1/applications").expectStatus().isOk();
  }

  @Test
  void everythingUnderTheApiHasACoarserLimitButHealthIsExempt() {
    for (int i = 0; i < 6; i++) {
      call("10.0.1.1", "/api/v1/applications").expectStatus().isOk();
    }
    call("10.0.1.1", "/api/v1/dashboard")
        .expectStatus().isEqualTo(429)
        .expectBody().jsonPath("$.error.code").isEqualTo("RATE_LIMITED");
    call("10.0.1.1", "/api/v1/health").expectStatus().isOk();
    // Static avatar files are not part of the API budget.
    call("10.0.1.1", "/uploads/avatars/1-abc.png").expectStatus().isOk();
  }

  @Test
  void aClientCannotChooseItsAddressByWritingTheLeftOfForwardedFor() {
    // A proxy appends the address it saw (10.0.0.9); everything to the left is client-written.
    for (int i = 1; i <= 3; i++) {
      call("203.0.113." + i + ", 10.0.0.9", "/api/v1/auth/login").expectStatus().isOk();
    }
    // All four requests came from the same real client, so the auth budget (3) is used up.
    call("203.0.113.4, 10.0.0.9", "/api/v1/auth/login").expectStatus().isEqualTo(429);
    // A different client behind the same proxy has its own budget.
    call("203.0.113.1, 10.0.0.10", "/api/v1/auth/login").expectStatus().isOk();
  }

  @Test
  void trustedProxyAddressesAtTheRightAreSkipped() {
    // Another trusted hop (127.0.0.1 is in the default trusted list) sits right of the client.
    for (int i = 0; i < 3; i++) {
      call("10.0.5.1, 127.0.0.1", "/api/v1/auth/login").expectStatus().isOk();
    }
    call("10.0.5.1, 127.0.0.1", "/api/v1/auth/login").expectStatus().isEqualTo(429);
    call("10.0.5.2, 127.0.0.1", "/api/v1/auth/login").expectStatus().isOk();
  }
}
