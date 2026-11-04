package com.jobtrail.gateway;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

class FixedWindowLimiterTest {

  @Test
  void allowsUpToTheLimitThenBlocksUntilTheWindowPasses() {
    AtomicLong now = new AtomicLong(1_000);
    FixedWindowLimiter limiter = new FixedWindowLimiter(3, 60_000, now::get);

    for (int i = 0; i < 3; i++) {
      assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
    }
    now.addAndGet(15_000);
    FixedWindowLimiter.Result blocked = limiter.tryAcquire("ip");
    assertThat(blocked.allowed()).isFalse();
    assertThat(blocked.retryAfterSeconds()).isEqualTo(45);

    now.addAndGet(45_000);
    assertThat(limiter.tryAcquire("ip").allowed()).isTrue();
  }

  @Test
  void clientsHaveIndependentBudgets() {
    AtomicLong now = new AtomicLong(0);
    FixedWindowLimiter limiter = new FixedWindowLimiter(1, 60_000, now::get);
    assertThat(limiter.tryAcquire("a").allowed()).isTrue();
    assertThat(limiter.tryAcquire("a").allowed()).isFalse();
    assertThat(limiter.tryAcquire("b").allowed()).isTrue();
  }
}
