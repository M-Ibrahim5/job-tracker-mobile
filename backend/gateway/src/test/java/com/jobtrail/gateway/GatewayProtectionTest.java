package com.jobtrail.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.stream.IntStream;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webtestclient.autoconfigure.AutoConfigureWebTestClient;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.reactive.server.WebTestClient;

/** Oversized bodies are refused before they reach a service; health probes are shared. */
@AutoConfigureWebTestClient
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class GatewayProtectionTest {

  private static final StubService USER = new StubService("user");
  private static final StubService TRACKER = new StubService("tracker");

  @DynamicPropertySource
  static void services(DynamicPropertyRegistry registry) {
    registry.add("jobtrail.services.user-url", USER::url);
    registry.add("jobtrail.services.tracker-url", TRACKER::url);
    registry.add("jobtrail.gateway.api-limit", () -> "100000");
    registry.add("jobtrail.gateway.auth-limit", () -> "100000");
    registry.add("jobtrail.gateway.max-body-size", () -> "1KB");
    registry.add("jobtrail.gateway.max-upload-size", () -> "4KB");
  }

  @AfterAll
  static void stopStubs() {
    USER.stop();
    TRACKER.stop();
  }

  @Autowired WebTestClient client;

  private WebTestClient.ResponseSpec post(String path, int bytes) {
    return client.post().uri(path).contentType(MediaType.APPLICATION_JSON)
        .bodyValue("\"" + "a".repeat(bytes) + "\"")
        .exchange();
  }

  @Test
  void bodiesOverTheLimitAreRejectedWith413() {
    post("/api/v1/applications", 512).expectStatus().isOk();
    post("/api/v1/applications", 4096).expectStatus().isEqualTo(413);
    post("/api/v1/auth/login", 4096).expectStatus().isEqualTo(413);
  }

  @Test
  void avatarUploadsGetTheLargerLimit() {
    post("/api/v1/me/avatar", 3000).expectStatus().isOk();
    post("/api/v1/me/avatar", 8000).expectStatus().isEqualTo(413);
  }

  @Test
  void aBurstOfHealthChecksSharesOneProbe() {
    int before = TRACKER.healthCalls.get();
    IntStream.range(0, 20).forEach(i -> client.get().uri("/api/v1/health").exchange().expectStatus().isOk());
    assertThat(TRACKER.healthCalls.get() - before).isLessThanOrEqualTo(2);
  }
}
