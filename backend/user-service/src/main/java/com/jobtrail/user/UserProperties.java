package com.jobtrail.user;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/** {@code jobtrail.*} settings owned by the user service. */
@ConfigurationProperties("jobtrail")
public record UserProperties(
    @DefaultValue("http://localhost:3000") String publicBaseUrl,
    @DefaultValue("./uploads") String uploadDir,
    @DefaultValue("30") int refreshTtlDays,
    @DefaultValue Argon2 argon2) {

  /**
   * New hashes use OWASP's argon2id baseline (19 MiB, 2 passes, 1 lane). Hashes keep their own
   * parameters, so accounts hashed with the old Node settings (64 MiB, t=3, p=4) still verify.
   * {@code maxConcurrent} hashes run at once (0 = one per CPU core); a caller waits at most
   * {@code maxWaitMillis} for a slot.
   */
  public record Argon2(
      @DefaultValue("19456") int memoryKb,
      @DefaultValue("2") int iterations,
      @DefaultValue("1") int parallelism,
      @DefaultValue("0") int maxConcurrent,
      @DefaultValue("5000") long maxWaitMillis) {

    public int effectiveMaxConcurrent() {
      return maxConcurrent > 0 ? maxConcurrent : Runtime.getRuntime().availableProcessors();
    }
  }
}
