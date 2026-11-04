package com.jobtrail.common.security;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** {@code jobtrail.internal.key}: shared secret for service-to-service {@code /internal/**} calls. */
@ConfigurationProperties("jobtrail.internal")
public record InternalProperties(String key) {

  private static final int MIN_CHARS = 16;

  public InternalProperties {
    // Fail at startup: a missing key would otherwise surface later as silently ignored user settings.
    if (key == null || key.length() < MIN_CHARS) {
      throw new IllegalStateException(
          "jobtrail.internal.key (INTERNAL_API_KEY) must be set to at least " + MIN_CHARS + " characters");
    }
  }
}
