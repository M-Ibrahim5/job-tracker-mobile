package com.jobtrail.gateway;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

/** X-Forwarded-For is ignored when the TCP peer is not one of the configured trusted proxies. */
@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayUntrustedProxyTest {

  private static final StubService USER = new StubService("user");
  private static final StubService TRACKER = new StubService("tracker");

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", TRACKER::url);
    registry.add("jobtrail.gateway.auth-limit", () -> "3");
    registry.add("jobtrail.gateway.trust-forwarded-for", () -> "true");
    // The test client connects from loopback, which is deliberately not in this list.
    registry.add("jobtrail.gateway.trusted-proxies", () -> "192.0.2.1");
  }

  @AfterAll
  static void stopStubs() {
    USER.stop();
    TRACKER.stop();
  }

  @Autowired WebTestClient client;

  @Test
  void headerFromAnUntrustedPeerCannotPickTheClientAddress() {
    for (int i = 1; i <= 3; i++) {
      client.get().uri("/api/v1/auth/login").header("X-Forwarded-For", "198.51.100." + i)
          .exchange().expectStatus().isOk();
    }
    client.get().uri("/api/v1/auth/login").header("X-Forwarded-For", "198.51.100.4")
        .exchange().expectStatus().isEqualTo(429);
  }
}
