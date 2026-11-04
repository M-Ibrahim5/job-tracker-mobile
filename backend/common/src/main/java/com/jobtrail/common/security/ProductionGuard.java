package com.jobtrail.common.security;

import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * With the {@code prod} profile, refuses to start on a placeholder secret, a non-https base URL or
 * an unencrypted connection to a database on another host.
 */
@Component
@Profile("prod")
public class ProductionGuard {

  private static final Pattern PLACEHOLDER =
      Pattern.compile("change|example|secret|password", Pattern.CASE_INSENSITIVE);

  private final String jwtSecret;
  private final String internalKey;
  private final String publicBaseUrl;
  private final String dbUrl;

  public ProductionGuard(
      @Value("${jobtrail.jwt.secret:}") String jwtSecret,
      @Value("${jobtrail.internal.key:}") String internalKey,
      @Value("${jobtrail.public-base-url:https://localhost}") String publicBaseUrl,
      @Value("${spring.datasource.url:}") String dbUrl) {
    this.jwtSecret = jwtSecret;
    this.internalKey = internalKey;
    this.publicBaseUrl = publicBaseUrl;
    this.dbUrl = dbUrl;
  }

  private static final Pattern LOCAL_DB = Pattern.compile("^jdbc:mysql://(localhost|127\\.0\\.0\\.1|\\[::1\\])[:/]");
  private static final Pattern NO_TLS = Pattern.compile("useSSL=false|sslMode=DISABLED", Pattern.CASE_INSENSITIVE);

  /** True when the JDBC URL reaches another host without TLS. */
  static boolean remoteWithoutTls(String dbUrl) {
    return dbUrl != null && !LOCAL_DB.matcher(dbUrl).find() && NO_TLS.matcher(dbUrl).find();
  }

  @PostConstruct
  void check() {
    List<String> problems = new ArrayList<>();
    if (PLACEHOLDER.matcher(jwtSecret).find()) {
      problems.add("JWT_SECRET looks like a placeholder");
    }
    if (internalKey.length() < 32 || PLACEHOLDER.matcher(internalKey).find()) {
      problems.add("INTERNAL_API_KEY must be a random value of at least 32 characters");
    }
    if (!publicBaseUrl.startsWith("https://")) {
      problems.add("PUBLIC_BASE_URL must use https");
    }
    if (remoteWithoutTls(dbUrl)) {
      problems.add("DB_URL reaches a remote database without TLS: use sslMode=VERIFY_IDENTITY");
    }
    if (!problems.isEmpty()) {
      throw new IllegalStateException("Invalid production config: " + String.join("; ", problems));
    }
  }
}
