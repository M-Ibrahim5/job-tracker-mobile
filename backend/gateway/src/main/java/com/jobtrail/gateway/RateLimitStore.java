package com.jobtrail.gateway;

import reactor.core.publisher.Mono;

/**
 * Counts requests per key in fixed one-minute windows. {@link InMemoryRateLimitStore} counts in this
 * gateway process only; {@link RedisRateLimitStore} shares the counts between every gateway
 * instance (enabled by {@code REDIS_URL}).
 */
public interface RateLimitStore {

  long WINDOW_MILLIS = 60_000;

  /** Counts one request for [key] in [bucket] (e.g. "api", "auth") against [limit] per window. */
  Mono<FixedWindowLimiter.Result> tryAcquire(String bucket, String key, int limit);
}
