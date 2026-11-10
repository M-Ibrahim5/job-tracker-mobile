package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;

import com.jobtrail.common.error.AppException;
import com.jobtrail.user.auth.AuthService;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;

/**
 * The per-account lock must count an attempt before its password is hashed. Otherwise a burst of
 * parallel guesses all pass the lock check and every one of them is evaluated.
 */
@TestPropertySource(properties = {
    // Slow, scarce hashing so a burst queues up behind the hash slots, like under attack.
    "jobtrail.argon2.memory-kb=65536",
    "jobtrail.argon2.iterations=3",
    "jobtrail.argon2.max-concurrent=2",
    "jobtrail.argon2.max-wait-millis=30000"})
class LoginThrottleRaceTest extends IntegrationTest {

  private static final String EMAIL = "race@example.com";
  private static final int ATTEMPTS = 30;

  @Autowired AuthService auth;

  @Test
  void parallelGuessesAreCountedBeforeTheyAreHashed() throws Exception {
    register(EMAIL);

    ExecutorService pool = Executors.newFixedThreadPool(ATTEMPTS);
    CountDownLatch start = new CountDownLatch(1);
    AtomicInteger evaluatedWrong = new AtomicInteger();
    AtomicInteger succeeded = new AtomicInteger();
    AtomicInteger locked = new AtomicInteger();
    List<Future<?>> futures = new ArrayList<>();
    for (int i = 0; i < ATTEMPTS; i++) {
      // One of the parallel guesses is the right password.
      String password = i == ATTEMPTS / 2 ? PASSWORD : "wrong-guess-" + i;
      futures.add(pool.submit(() -> {
        start.await();
        try {
          auth.login(EMAIL, password);
          succeeded.incrementAndGet();
        } catch (AppException e) {
          switch (e.code()) {
            case "INVALID_CREDENTIALS" -> evaluatedWrong.incrementAndGet();
            case "RATE_LIMITED" -> locked.incrementAndGet();
            default -> throw e;
          }
        }
        return null;
      }));
    }
    start.countDown();
    for (Future<?> f : futures) {
      f.get(60, TimeUnit.SECONDS);
    }
    pool.shutdownNow();

    // At most the five free attempts may reach the password check; everything else is refused.
    assertThat(evaluatedWrong.get() + succeeded.get())
        .as("guesses that were hashed (wrong %s, right %s, locked out %s)", evaluatedWrong, succeeded, locked)
        .isLessThanOrEqualTo(5);
    assertThat(locked.get()).isGreaterThanOrEqualTo(ATTEMPTS - 5);
  }
}
