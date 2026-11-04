package com.jobtrail.common.security;

import com.jobtrail.common.error.AppException;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

/** Issues and verifies the 15-minute access tokens; {@code sub} is the numeric user id. */
@Service
public class JwtService {

  private static final int MIN_SECRET_CHARS = 32;

  private final SecretKey key;
  private final JwtProperties props;

  public JwtService(JwtProperties props) {
    String secret = props.secret();
    if (secret == null || secret.length() < MIN_SECRET_CHARS) {
      throw new IllegalStateException(
          "jobtrail.jwt.secret (JWT_SECRET) must be set to at least "
              + MIN_SECRET_CHARS
              + " characters");
    }
    this.props = props;
    this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
  }

  public String sign(long userId) {
    Instant now = Instant.now();
    return Jwts.builder()
        .subject(Long.toString(userId))
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plus(props.accessTtl())))
        .signWith(key)
        .compact();
  }

  /** Returns the user id, or throws UNAUTHORIZED / TOKEN_EXPIRED. */
  public long verify(String token) {
    try {
      String subject = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload().getSubject();
      return Long.parseLong(subject);
    } catch (ExpiredJwtException e) {
      throw AppException.tokenExpired();
    } catch (JwtException | IllegalArgumentException e) {
      throw AppException.unauthorized("Invalid token");
    }
  }
}
