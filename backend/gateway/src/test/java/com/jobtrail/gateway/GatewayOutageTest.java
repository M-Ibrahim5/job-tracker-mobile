package com.jobtrail.gateway;

import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

/** The tracker service is down (nothing listens on its port); the user service is fine. */
@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayOutageTest {

  private static final StubService USER = new StubService("user");
  /** A port that was just free, so connecting is refused. */
  private static final int DEAD_PORT = closedPort();

  private static int closedPort() {
    try (java.net.ServerSocket socket = new java.net.ServerSocket(0)) {
      return socket.getLocalPort();
    } catch (java.io.IOException e) {
      throw new IllegalStateException(e);
    }
  }

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", () -> "http://127.0.0.1:" + DEAD_PORT);
    registry.add("jobtrail.gateway.api-limit", () -> "100000");
  }

  @AfterAll
  static void stopStub() {
    USER.stop();
  }

  @Autowired WebTestClient client;

  @Test
  void requestsToTheDeadServiceFailWithTheErrorShapeWhileTheRestKeepsWorking() {
    client.get().uri("/api/v1/applications")
        .exchange()
        .expectStatus().isEqualTo(503)
        .expectBody().jsonPath("$.error.code").isEqualTo("INTERNAL");
    client.get().uri("/api/v1/me").exchange().expectStatus().isOk();
  }

  @Test
  void healthShowsWhichServiceIsDown() {
    client.get().uri("/api/v1/health")
        .exchange()
        .expectStatus().isEqualTo(503)
        .expectBody()
        .jsonPath("$.status").isEqualTo("degraded")
        .jsonPath("$.services.user").isEqualTo("up")
        .jsonPath("$.services.tracker").isEqualTo("down");
  }
}
