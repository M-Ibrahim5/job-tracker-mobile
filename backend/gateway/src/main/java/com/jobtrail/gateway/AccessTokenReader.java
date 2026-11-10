package com.jobtrail.gateway;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Reads the user id from a valid access token. The signature is checked, so a client cannot spread
 * its requests over many rate-limit buckets by inventing user ids. Authentication itself stays in
 * the services; this is only used to pick the rate-limit key.
 */
@Component
public class AccessTokenReader {

  private static final String PREFIX = "Bearer ";
  private static final int MIN_SECRET_CHARS = 32;

  private final JwtParser parser;

  /** The value shipped in backend/.env.example; anyone can mint tokens with it. */
  private static final String EXAMPLE_SECRET = "change-me-to-a-long-random-string-0000";

  public AccessTokenReader(@Value("${jobtrail.jwt.secret:}") String secret) {
    if (EXAMPLE_SECRET.equals(secret)) {
      throw new IllegalStateException(
          "JWT_SECRET is the public example value. Generate your own, e.g. `openssl rand -base64 48`");
    }
    this.parser = secret == null || secret.length() < MIN_SECRET_CHARS
        ? null
        : Jwts.parser().verifyWith(Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8))).build();
  }

  /** The {@code sub} of a valid, unexpired bearer token, or empty. */
  public Optional<String> userId(String authorizationHeader) {
    if (parser == null || authorizationHeader == null || !authorizationHeader.startsWith(PREFIX)) {
      return Optional.empty();
    }
    try {
      return Optional.ofNullable(
          parser.parseSignedClaims(authorizationHeader.substring(PREFIX.length())).getPayload().getSubject());
    } catch (JwtException | IllegalArgumentException e) {
      return Optional.empty();
    }
  }
}
