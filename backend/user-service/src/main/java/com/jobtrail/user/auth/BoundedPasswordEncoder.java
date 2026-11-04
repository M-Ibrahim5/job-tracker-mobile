package com.jobtrail.user.auth;

import com.jobtrail.common.error.AppException;
import java.util.concurrent.Semaphore;
import java.util.concurrent.TimeUnit;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * Runs at most {@code maxConcurrent} password hashes at once. Each Argon2 hash allocates its full
 * memory cost, so without a cap a login burst (or a password-guessing attack) on 200 request
 * threads can exhaust the heap. Callers that cannot get a slot within {@code waitMillis} get
 * 503 {@code SERVER_BUSY} instead of queueing indefinitely.
 */
public final class BoundedPasswordEncoder implements PasswordEncoder {

  private final PasswordEncoder delegate;
  private final Semaphore slots;
  private final long waitMillis;

  public BoundedPasswordEncoder(PasswordEncoder delegate, int maxConcurrent, long waitMillis) {
    this.delegate = delegate;
    this.slots = new Semaphore(Math.max(1, maxConcurrent), true);
    this.waitMillis = waitMillis;
  }

  @Override
  public String encode(CharSequence rawPassword) {
    acquire();
    try {
      return delegate.encode(rawPassword);
    } finally {
      slots.release();
    }
  }

  @Override
  public boolean matches(CharSequence rawPassword, String encodedPassword) {
    acquire();
    try {
      return delegate.matches(rawPassword, encodedPassword);
    } finally {
      slots.release();
    }
  }

  @Override
  public boolean upgradeEncoding(String encodedPassword) {
    return delegate.upgradeEncoding(encodedPassword);
  }

  private void acquire() {
    try {
      if (slots.tryAcquire(waitMillis, TimeUnit.MILLISECONDS)) {
        return;
      }
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
    throw new AppException("SERVER_BUSY", HttpStatus.SERVICE_UNAVAILABLE, "Server is busy, try again shortly");
  }
}
