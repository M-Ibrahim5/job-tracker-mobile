package com.jobtrail.common.security;

import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Refuses to start, in every profile, with the secrets published in {@code backend/.env.example}.
 * Anyone can read those values, so a service using them accepts forged access tokens and internal
 * calls. {@link ProductionGuard} adds stricter checks when the {@code prod} profile is active.
 */
@Component
public class ExampleSecretGuard {

  /** The values shipped in backend/.env.example; keep in sync with that file. */
  static final Set<String> EXAMPLE_VALUES =
      Set.of("change-me-to-a-long-random-string-0000", "change-me-internal-key-0000000000");

  private final String jwtSecret;
  private final String internalKey;

  public ExampleSecretGuard(
      @Value("${jobtrail.jwt.secret:}") String jwtSecret,
      @Value("${jobtrail.internal.key:}") String internalKey) {
    this.jwtSecret = jwtSecret;
    this.internalKey = internalKey;
  }

  @PostConstruct
  void check() {
    List<String> problems = new ArrayList<>();
    if (EXAMPLE_VALUES.contains(jwtSecret)) {
      problems.add("JWT_SECRET is the public example value");
    }
    if (EXAMPLE_VALUES.contains(internalKey)) {
      problems.add("INTERNAL_API_KEY is the public example value");
    }
    if (!problems.isEmpty()) {
      throw new IllegalStateException(String.join("; ", problems)
          + ". Generate your own, e.g. `openssl rand -base64 48`, and put it in backend/.env");
    }
  }
}
