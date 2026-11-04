package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;

/**
 * Accounts created by the earlier Node API (argon2id, 64 MiB, t=3, p=4) must keep logging in, so
 * the Java encoder has to accept argon2id PHC strings written by other implementations.
 */
class PasswordCompatibilityTest {

  // Produced by argon2-cffi (reference C implementation) with the same parameters and PHC layout as Node's `argon2`.
  private static final String FOREIGN_HASH =
      "$argon2id$v=19$m=65536,t=3,p=4$zv0zqeY2zLKwGpfdRP0Drg$f9wHOZgnD1zkFMsQAdH0o6nlCdk5JxHbZfocrrUB16Q";

  private final Argon2PasswordEncoder encoder = new Argon2PasswordEncoder(16, 32, 4, 65536, 3);

  @Test
  void acceptsHashesWrittenByOtherArgon2Implementations() {
    assertThat(encoder.matches("Demo@1234", FOREIGN_HASH)).isTrue();
    assertThat(encoder.matches("Demo@12345", FOREIGN_HASH)).isFalse();
  }

  @Test
  void ownHashesUseTheSameStandardFormat() {
    String hash = encoder.encode("Demo@1234");
    assertThat(hash).startsWith("$argon2id$v=19$m=65536,t=3,p=4$");
    assertThat(encoder.matches("Demo@1234", hash)).isTrue();
  }
}
