package com.jobtrail.gateway;

import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

/**
 * {@code GET /api/v1/health}: {@code {"status":"ok","version"}} when every service answers,
 * {@code 503 {"status":"degraded"}} (with per-service detail) when one does not.
 *
 * <p>The endpoint is public and not rate limited, so the probe result is shared: concurrent calls
 * wait for one probe, and the answer is reused for {@link #CACHE_FOR}. A flood of health checks
 * therefore costs the services at most two requests per interval.
 */
@RestController
public class HealthController {

  static final Duration CACHE_FOR = Duration.ofSeconds(3);

  private final WebClient http = WebClient.create();
  private final String version;
  private final Map<String, String> services = new LinkedHashMap<>();
  private final Mono<Map<String, Object>> cachedProbe;

  public HealthController(
      @Value("${jobtrail.version:dev}") String version,
      @Value("${jobtrail.services.user-url}") String userUrl,
      @Value("${jobtrail.services.tracker-url}") String trackerUrl) {
    this.version = version;
    services.put("user", userUrl);
    services.put("tracker", trackerUrl);
    this.cachedProbe = probeAll().cache(value -> CACHE_FOR, error -> Duration.ZERO, () -> Duration.ZERO);
  }

  @GetMapping("/api/v1/health")
  Mono<ResponseEntity<Map<String, Object>>> health() {
    return cachedProbe.map(body -> ResponseEntity
        .status("ok".equals(body.get("status")) ? HttpStatus.OK : HttpStatus.SERVICE_UNAVAILABLE)
        .body(body));
  }

  private Mono<Map<String, Object>> probeAll() {
    return Mono.zip(probe("user"), probe("tracker")).map(both -> {
      boolean ok = both.getT1() && both.getT2();
      Map<String, Object> body = new LinkedHashMap<>();
      body.put("status", ok ? "ok" : "degraded");
      body.put("version", version);
      Map<String, String> detail = new LinkedHashMap<>();
      detail.put("user", both.getT1() ? "up" : "down");
      detail.put("tracker", both.getT2() ? "up" : "down");
      body.put("services", detail);
      return body;
    });
  }

  private Mono<Boolean> probe(String name) {
    return http.get()
        .uri(services.get(name) + "/api/v1/health")
        .retrieve()
        .toBodilessEntity()
        .map(response -> response.getStatusCode().is2xxSuccessful())
        .timeout(Duration.ofSeconds(2))
        .onErrorReturn(false);
  }
}
