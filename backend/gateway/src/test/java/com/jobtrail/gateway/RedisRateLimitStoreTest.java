package com.jobtrail.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

/**
 * The shared-counter tests need a Redis server: set {@code REDIS_TEST_URL}, e.g.
 * {@code redis://localhost:6379} ({@code docker run -p 6379:6379 redis:7}). They are skipped
 * otherwise; the fallback test always runs.
 */
class RedisRateLimitStoreTest {

  private static void awaitConnected(RedisRateLimitStore store) throws InterruptedException {
    Instant deadline = Instant.now().plusSeconds(10);
    while (!store.connected() && Instant.now().isBefore(deadline)) {
      Thread.sleep(50);
    }
    assertThat(store.connected()).as("connected to Redis").isTrue();
  }

  @Test
  @EnabledIfEnvironmentVariable(named = "REDIS_TEST_URL", matches = ".+")
  void twoGatewaysShareOneBudget() throws Exception {
    String url = System.getenv("REDIS_TEST_URL");
    String key = "it-" + UUID.randomUUID();
    try (RedisRateLimitStore a = new RedisRateLimitStore(url, new InMemoryRateLimitStore());
        RedisRateLimitStore b = new RedisRateLimitStore(url, new InMemoryRateLimitStore())) {
      awaitConnected(a);
      awaitConnected(b);
      assertThat(a.tryAcquire("api", key, 3).block().allowed()).isTrue();
      assertThat(b.tryAcquire("api", key, 3).block().allowed()).isTrue();
      assertThat(a.tryAcquire("api", key, 3).block().allowed()).isTrue();
      FixedWindowLimiter.Result blocked = b.tryAcquire("api", key, 3).block();
      assertThat(blocked.allowed()).as("the 4th request, on the other gateway").isFalse();
      assertThat(blocked.retryAfterSeconds()).isBetween(1L, 60L);
      // Buckets are independent.
      assertThat(a.tryAcquire("auth", key, 3).block().allowed()).isTrue();
    }
  }

  @Test
  @EnabledIfEnvironmentVariable(named = "REDIS_TEST_URL", matches = ".+")
  void countersExpireWithTheWindow() throws Exception {
    String url = System.getenv("REDIS_TEST_URL");
    String key = "ttl-" + UUID.randomUUID();
    try (RedisRateLimitStore store = new RedisRateLimitStore(url, new InMemoryRateLimitStore())) {
      awaitConnected(store);
      store.tryAcquire("api", key, 1).block();
      FixedWindowLimiter.Result blocked = store.tryAcquire("api", key, 1).block();
      assertThat(blocked.allowed()).isFalse();
      // The key carries the window as its expiry, so it can never block forever.
      assertThat(blocked.retryAfterSeconds()).isLessThanOrEqualTo(60);
    }
  }

  @Test
  void anUnreachableRedisFallsBackToCountingInMemory() {
    // Nothing listens on port 1; the gateway must keep working (and keep limiting).
    try (RedisRateLimitStore store = new RedisRateLimitStore("redis://127.0.0.1:1", new InMemoryRateLimitStore())) {
      Instant started = Instant.now();
      assertThat(store.tryAcquire("api", "ip:1", 2).block().allowed()).isTrue();
      assertThat(store.tryAcquire("api", "ip:1", 2).block().allowed()).isTrue();
      assertThat(store.tryAcquire("api", "ip:1", 2).block().allowed()).isFalse();
      assertThat(Duration.between(started, Instant.now())).isLessThan(Duration.ofSeconds(1));
    }
  }

  @Test
  void scriptResultsBecomeDecisions() {
    assertThat(RedisRateLimitStore.result(List.of(3L, 40_000L), 3).allowed()).isTrue();
    FixedWindowLimiter.Result blocked = RedisRateLimitStore.result(List.of(4L, 40_001L), 3);
    assertThat(blocked.allowed()).isFalse();
    assertThat(blocked.retryAfterSeconds()).isEqualTo(41);
  }
}
