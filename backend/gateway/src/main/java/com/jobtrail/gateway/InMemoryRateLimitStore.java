package com.jobtrail.gateway;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;
import reactor.core.publisher.Mono;

/** Per-process counters; fine for a single gateway, and the fallback when Redis is unreachable. */
public final class InMemoryRateLimitStore implements RateLimitStore {

  private final Map<String, FixedWindowLimiter> limiters = new ConcurrentHashMap<>();
  private final LongSupplier clock;

  public InMemoryRateLimitStore() {
    this(System::currentTimeMillis);
  }

  InMemoryRateLimitStore(LongSupplier clock) {
    this.clock = clock;
  }

  /** Same as {@link #tryAcquire} without the reactive wrapper. */
  FixedWindowLimiter.Result acquire(String bucket, String key, int limit) {
    return limiters
        .computeIfAbsent(bucket + "|" + limit, b -> new FixedWindowLimiter(limit, WINDOW_MILLIS, clock))
        .tryAcquire(key);
  }

  @Override
  public Mono<FixedWindowLimiter.Result> tryAcquire(String bucket, String key, int limit) {
    return Mono.fromSupplier(() -> acquire(bucket, key, limit));
  }
}
