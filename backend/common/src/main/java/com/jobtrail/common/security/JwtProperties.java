package com.jobtrail.common.security;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/** {@code jobtrail.jwt.*}: HS256 secret (shared by every service) and access-token lifetime. */
@ConfigurationProperties("jobtrail.jwt")
public record JwtProperties(String secret, Duration accessTtl) {

  public JwtProperties {
    if (accessTtl == null) {
      accessTtl = Duration.ofMinutes(15);
    }
  }
}
