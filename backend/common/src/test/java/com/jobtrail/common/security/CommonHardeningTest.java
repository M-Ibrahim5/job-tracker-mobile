package com.jobtrail.common.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.jobtrail.common.error.AppException;
import com.jobtrail.common.time.Iso;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;
import org.junit.jupiter.api.Test;

class CommonHardeningTest {

  private static final String SECRET = "test-secret-test-secret-test-secret-123";
  private final JwtService jwt = new JwtService(new JwtProperties(SECRET, Duration.ofMinutes(15)));

  private static String token(String type) {
    var builder = Jwts.builder().subject("7").expiration(Date.from(java.time.Instant.now().plusSeconds(60)));
    if (type != null) {
      builder.claim("typ", type);
    }
    return builder.signWith(Keys.hmacShaKeyFor(SECRET.getBytes(StandardCharsets.UTF_8))).compact();
  }

  @Test
  void accessTokensCarryTheirTypeAndOnlyAccessTokensAreAccepted() {
    assertThat(jwt.verify(jwt.sign(7))).isEqualTo(7);
    assertThatThrownBy(() -> jwt.verify(token("password-reset")))
        .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.code()).isEqualTo("UNAUTHORIZED"));
    // Tokens from before the claim existed look expired, so the app refreshes and gets a current one.
    assertThatThrownBy(() -> jwt.verify(token(null)))
        .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.code()).isEqualTo("TOKEN_EXPIRED"));
  }

  @Test
  void dateTimesOutsideTheSupportedYearsAreRefused() {
    assertThat(Iso.parseDateTime("2030-06-01T10:00:00Z")).isNotNull();
    assertThat(Iso.parseDateTime("0001-01-01T00:00:00Z")).isNull();
    assertThat(Iso.parseDateTime("9999-12-31T23:59:59Z")).isNull();
    assertThat(Iso.parseDateTime("1999-12-31T23:59:59Z")).isNull();
  }
}
