package com.jobtrail.gateway;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class AccessTokenReaderTest {

  @Test
  void theExampleSecretIsRefused() {
    assertThatThrownBy(() -> new AccessTokenReader("change-me-to-a-long-random-string-0000"))
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("JWT_SECRET");
    assertThatCode(() -> new AccessTokenReader("a-real-secret-0123456789abcdefghijklmnop")).doesNotThrowAnyException();
    // An empty secret still means "key rate limits by IP only".
    assertThatCode(() -> new AccessTokenReader("")).doesNotThrowAnyException();
  }
}
