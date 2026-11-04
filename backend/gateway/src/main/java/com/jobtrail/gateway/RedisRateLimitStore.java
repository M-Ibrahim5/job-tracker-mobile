package com.jobtrail.gateway;

import io.lettuce.core.ClientOptions;
import io.lettuce.core.RedisClient;
import io.lettuce.core.RedisURI;
import io.lettuce.core.SocketOptions;
import io.lettuce.core.ScriptOutputType;
import io.lettuce.core.api.StatefulRedisConnection;
import io.lettuce.core.api.reactive.RedisReactiveCommands;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

/**
 * Counters in Redis, shared by every gateway instance. One Lua script increments the counter and
 * sets its expiry atomically, so a key can never be left without one.
 *
 * <p>When Redis is unreachable (also at startup) or does not answer within {@link #TIMEOUT}, the
 * request is counted by the in-memory fallback instead: a Redis outage degrades to per-instance
 * limits, it never blocks traffic. A lost connection is retried at most every {@link #RECONNECT}.
 */
public final class RedisRateLimitStore implements RateLimitStore, AutoCloseable {

  private static final Logger log = LoggerFactory.getLogger(RedisRateLimitStore.class);

  static final Duration TIMEOUT = Duration.ofMillis(250);
  static final Duration RECONNECT = Duration.ofSeconds(10);
  private static final String PREFIX = "jobtrail:rl:";
  /** Returns {count, milliseconds left in the window}. */
  private static final String SCRIPT = """
      local count = redis.call('INCR', KEYS[1])
      if count == 1 then redis.call('PEXPIRE', KEYS[1], ARGV[1]) end
      local ttl = redis.call('PTTL', KEYS[1])
      if ttl < 0 then
        redis.call('PEXPIRE', KEYS[1], ARGV[1])
        ttl = tonumber(ARGV[1])
      end
      return {count, ttl}""";

  private final RedisClient client;
  private final InMemoryRateLimitStore fallback;
  private final AtomicLong lastWarning = new AtomicLong();
  private final AtomicLong lastConnectAttempt = new AtomicLong();
  private volatile StatefulRedisConnection<String, String> connection;
  private volatile boolean closed;

  public RedisRateLimitStore(String redisUrl, InMemoryRateLimitStore fallback) {
    RedisURI uri = RedisURI.create(redisUrl);
    uri.setTimeout(TIMEOUT);
    this.client = RedisClient.create(uri);
    this.client.setOptions(ClientOptions.builder()
        .socketOptions(SocketOptions.builder().connectTimeout(Duration.ofSeconds(2)).build())
        .build());
    this.fallback = fallback;
    commands();
  }

  /**
   * The open connection, or null while there is none. Opening one blocks, so it happens on a
   * background thread (never on a request thread), at most every {@link #RECONNECT}; requests are
   * counted in memory meanwhile. Once open, Lettuce reconnects it by itself.
   */
  private RedisReactiveCommands<String, String> commands() {
    StatefulRedisConnection<String, String> current = connection;
    if (current != null) {
      return current.reactive();
    }
    long now = System.currentTimeMillis();
    long last = lastConnectAttempt.get();
    if ((last == 0 || now - last >= RECONNECT.toMillis()) && lastConnectAttempt.compareAndSet(last, now)) {
      Mono.fromRunnable(() -> {
            synchronized (this) {
              if (closed) {
                return;
              }
              try {
                connection = client.connect();
                log.info("Connected to Redis for rate limiting");
              } catch (RuntimeException e) {
                warn(e);
              }
            }
          })
          .subscribeOn(Schedulers.boundedElastic())
          .subscribe();
    }
    return null;
  }

  /** True once the Redis connection is open (for tests and logs). */
  boolean connected() {
    return connection != null;
  }

  @Override
  public Mono<FixedWindowLimiter.Result> tryAcquire(String bucket, String key, int limit) {
    RedisReactiveCommands<String, String> redis = commands();
    if (redis == null) {
      return fallback.tryAcquire(bucket, key, limit);
    }
    // MULTI output arrives as one element: the script's {count, ttl} list.
    return redis.<List<Object>>eval(SCRIPT, ScriptOutputType.MULTI, new String[] {PREFIX + bucket + ":" + key},
            Long.toString(WINDOW_MILLIS))
        .next()
        .timeout(TIMEOUT)
        .map(values -> result(values, limit))
        .onErrorResume(e -> {
          warn(e);
          return fallback.tryAcquire(bucket, key, limit);
        });
  }

  static FixedWindowLimiter.Result result(List<?> values, int limit) {
    long count = ((Number) values.get(0)).longValue();
    long ttlMillis = ((Number) values.get(1)).longValue();
    if (count <= limit) {
      return new FixedWindowLimiter.Result(true, 0);
    }
    return new FixedWindowLimiter.Result(false, Math.max(1, (ttlMillis + 999) / 1000));
  }

  /** At most one warning per minute while Redis is unreachable. */
  private void warn(Throwable e) {
    long now = System.currentTimeMillis();
    long last = lastWarning.get();
    if (now - last > 60_000 && lastWarning.compareAndSet(last, now)) {
      log.warn("Redis rate limiting unavailable, counting in memory: {}", e.toString());
    }
  }

  /** Waits for a connect in progress, then releases the connection and Lettuce's threads. */
  @Override
  public synchronized void close() {
    closed = true;
    StatefulRedisConnection<String, String> current = connection;
    if (current != null) {
      current.close();
    }
    client.shutdown(Duration.ZERO, Duration.ofSeconds(2));
  }
}
