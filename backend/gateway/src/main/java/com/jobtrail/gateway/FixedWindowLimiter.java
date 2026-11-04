package com.jobtrail.gateway;

import java.util.Iterator;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;

/** In-memory fixed-window counter per key (client IP). Not shared between gateway instances. */
final class FixedWindowLimiter {

  private static final class Window {
    final long startedAt;
    int count;

    Window(long startedAt) {
      this.startedAt = startedAt;
    }
  }

  /** Outcome of one attempt; {@code retryAfterSeconds} is only meaningful when not allowed. */
  record Result(boolean allowed, long retryAfterSeconds) {}

  private final int limit;
  private final long windowMillis;
  private final LongSupplier clock;
  private final Map<String, Window> windows = new ConcurrentHashMap<>();
  private long lastSweep;

  FixedWindowLimiter(int limit, long windowMillis, LongSupplier clock) {
    this.limit = limit;
    this.windowMillis = windowMillis;
    this.clock = clock;
    this.lastSweep = clock.getAsLong();
  }

  Result tryAcquire(String key) {
    long now = clock.getAsLong();
    sweep(now);
    Window window = windows.compute(key, (k, existing) -> {
      Window w = existing == null || now - existing.startedAt >= windowMillis ? new Window(now) : existing;
      w.count++;
      return w;
    });
    if (window.count <= limit) {
      return new Result(true, 0);
    }
    long remaining = windowMillis - (now - window.startedAt);
    return new Result(false, Math.max(1, (remaining + 999) / 1000));
  }

  /** Drops expired windows now and then so the map cannot grow without bound. */
  private synchronized void sweep(long now) {
    if (now - lastSweep < windowMillis) {
      return;
    }
    lastSweep = now;
    Iterator<Window> it = windows.values().iterator();
    while (it.hasNext()) {
      if (now - it.next().startedAt >= windowMillis) {
        it.remove();
      }
    }
  }
}
