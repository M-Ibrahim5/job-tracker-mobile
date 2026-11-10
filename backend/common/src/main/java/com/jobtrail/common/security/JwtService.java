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
  /** Marks access tokens, so a future JWT of another kind signed with this key is not accepted as one. */
  private static final String TYPE_CLAIM = "typ";
  private static final String ACCESS = "access";

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
        .claim(TYPE_CLAIM, ACCESS)
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plus(props.accessTtl())))
        .signWith(key)
        .compact();
  }

  /** Returns the user id, or throws UNAUTHORIZED / TOKEN_EXPIRED. */
  public long verify(String token) {
    try {
      var claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
      Object type = claims.get(TYPE_CLAIM);
      if (type == null) {
        // Issued before the claim existed: looks expired, so clients refresh and get a current token.
        throw AppException.tokenExpired();
      }
      if (!ACCESS.equals(type)) {
        throw AppException.unauthorized("Invalid token");
      }
      return Long.parseLong(claims.getSubject());
    } catch (ExpiredJwtException e) {
      throw AppException.tokenExpired();
    } catch (JwtException | IllegalArgumentException e) {
      throw AppException.unauthorized("Invalid token");
    }
  }
}
