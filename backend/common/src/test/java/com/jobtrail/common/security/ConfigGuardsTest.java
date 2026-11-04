package com.jobtrail.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class ConfigGuardsTest {

  @Test
  void theExampleSecretsAreRefusedInEveryProfile() {
    assertThatThrownBy(() -> new ExampleSecretGuard("change-me-to-a-long-random-string-0000", "a".repeat(40)).check())
        .isInstanceOf(IllegalStateException.class)
        .hasMessageContaining("JWT_SECRET");
    assertThatThrownBy(() -> new ExampleSecretGuard("b".repeat(40), "change-me-internal-key-0000000000").check())
        .hasMessageContaining("INTERNAL_API_KEY");
    assertThatCode(() -> new ExampleSecretGuard("b".repeat(40), "a".repeat(40)).check()).doesNotThrowAnyException();
  }

  @Test
  void productionRefusesUnencryptedRemoteDatabases() {
    assertThat(ProductionGuard.remoteWithoutTls("jdbc:mysql://db.internal:3306/jobtrail?useSSL=false")).isTrue();
    assertThat(ProductionGuard.remoteWithoutTls("jdbc:mysql://10.0.0.5/jobtrail?sslMode=DISABLED")).isTrue();
    assertThat(ProductionGuard.remoteWithoutTls("jdbc:mysql://db.internal/jobtrail?sslMode=VERIFY_IDENTITY")).isFalse();
    assertThat(ProductionGuard.remoteWithoutTls("jdbc:mysql://localhost:3306/jobtrail?useSSL=false")).isFalse();
    assertThat(ProductionGuard.remoteWithoutTls("jdbc:mysql://127.0.0.1/jobtrail?useSSL=false")).isFalse();
  }
}
