package com.jobtrail.user.auth;

import com.jobtrail.common.error.AppException;
import com.jobtrail.common.json.IntList;
import com.jobtrail.common.security.JwtService;
import com.jobtrail.user.UserProperties;
import com.jobtrail.user.me.UserDto;
import com.jobtrail.user.user.UserRepository;
import com.jobtrail.user.user.UserRow;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Optional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class AuthService {

  private static final Logger log = LoggerFactory.getLogger(AuthService.class);

  private final UserRepository users;
  private final RefreshTokenRepository refreshTokens;
  private final DeviceTokenRepository deviceTokens;
  private final PasswordEncoder encoder;
  private final JwtService jwt;
  private final UserProperties props;
  private final JdbcClient jdbc;
  private final TransactionTemplate tx;
  private final LoginThrottle throttle;

  /** Hash of a throwaway string so login takes similar time whether or not the e-mail exists. */
  private volatile String dummyHash;

  public AuthService(UserRepository users, RefreshTokenRepository refreshTokens, DeviceTokenRepository deviceTokens,
      PasswordEncoder encoder, JwtService jwt, UserProperties props, JdbcClient jdbc, TransactionTemplate tx,
      LoginThrottle throttle) {
    this.users = users;
    this.refreshTokens = refreshTokens;
    this.deviceTokens = deviceTokens;
    this.encoder = encoder;
    this.jwt = jwt;
    this.props = props;
    this.jdbc = jdbc;
    this.tx = tx;
    this.throttle = throttle;
  }

  /** Device tokens last this long after their most recent use. */
  private static final int DEVICE_TOKEN_DAYS = 90;
  /** Most live device tokens (enrolled phones) per user. */
  private static final int MAX_DEVICE_TOKENS = 5;

  private static AppException invalidCredentials() {
    return new AppException("INVALID_CREDENTIALS", HttpStatus.UNAUTHORIZED, "Invalid email or password");
  }

  /**
   * Checks a password whose attempt was already counted by {@link LoginThrottle#reserve}. When the
   * server is too busy to hash, the attempt is handed back so real users are not locked out by load.
   */
  private boolean matchesCounted(String email, String raw, String hash) {
    try {
      return matches(raw, hash);
    } catch (AppException e) {
      if ("SERVER_BUSY".equals(e.code())) {
        throttle.refund(email);
      }
      throw e;
    }
  }

  private boolean matches(String raw, String hash) {
    try {
      return encoder.matches(raw, hash);
    } catch (IllegalArgumentException e) {
      return false;
    }
  }

  private String issueRefreshToken(long userId) {
    String token = Tokens.newOpaque();
    refreshTokens.insert(userId, Tokens.hash(token),
        Instant.now().plus(props.refreshTtlDays(), ChronoUnit.DAYS));
    return token;
  }

  private AuthResponse authResponse(UserRow user) {
    return new AuthResponse(jwt.sign(user.id()), issueRefreshToken(user.id()),
        UserDto.from(user, props.publicBaseUrl()));
  }

  public AuthResponse register(String fullName, String email, String password) {
    String hash = encoder.encode(password);
    long id;
    try {
      id = tx.execute(status -> {
        long userId = users.insert(email, hash, fullName);
        jdbc.sql("""
                INSERT INTO user_settings (user_id, default_reminder_offsets, default_followup_days)
                VALUES (:user, CAST(:offsets AS JSON), 7)""")
            .param("user", userId)
            .param("offsets", IntList.toJson(java.util.List.of(1440, 60)))
            .update();
        return userId;
      });
    } catch (DuplicateKeyException e) {
      throw new AppException("EMAIL_TAKEN", HttpStatus.CONFLICT, "Email is already registered",
          Map.of("email", "Email is already registered"));
    }
    return authResponse(users.findById(id).orElseThrow());
  }

  public AuthResponse login(String email, String password) {
    Instant now = Instant.now();
    // The attempt is counted before hashing, so a locked account costs no CPU and parallel
    // guesses cannot all slip past the lock. Unknown e-mails are throttled too, so the lock does
    // not reveal which accounts exist.
    throttle.reserve(email, now);
    Optional<UserRow> user = users.findByEmail(email);
    String hash = user.map(UserRow::passwordHash).orElseGet(this::dummyHash);
    boolean ok = matchesCounted(email, password, hash);
    if (user.isEmpty() || !ok) {
      throw invalidCredentials();
    }
    throttle.succeeded(email);
    return authResponse(user.get());
  }

  /**
   * How long after a rotation the old refresh token may be presented again when its replacement
   * was never used: the client most likely never received the refresh response (timeout, app
   * killed). Without this, a lost response would look like theft and sign out every device.
   */
  static final Duration ROTATION_GRACE = Duration.ofSeconds(30);

  public AuthResponse.Refreshed refresh(String refreshToken) {
    Instant now = Instant.now();
    RefreshTokenRepository.Row row = refreshTokens.findByHash(Tokens.hash(refreshToken))
        .orElseThrow(() -> AppException.unauthorized("Invalid refresh token"));
    if (row.revokedAt() != null) {
      // A lost response: the replacement never reached the client. Retire it and issue a new one.
      if (withinRotationGrace(row, now) && refreshTokens.revokeIfLive(row.replacedBy(), now) == 1) {
        log.info("Refresh retried after a lost response for user {}", row.userId());
        return rotate(row, now);
      }
      // Otherwise a revoked token came back: assume it was stolen and end every session of this user.
      refreshTokens.revokeAll(row.userId(), now);
      log.warn("Refresh token reuse detected for user {}", row.userId());
      throw AppException.unauthorized("Invalid refresh token");
    }
    if (!row.expiresAt().isAfter(now)) {
      throw AppException.unauthorized("Refresh token expired");
    }
    // Claim atomically so two concurrent refreshes cannot both succeed.
    if (refreshTokens.claim(row.id(), now) == 0) {
      throw AppException.unauthorized("Invalid refresh token");
    }
    return rotate(row, now);
  }

  /** Rotated (not logged out) within the grace period, and not expired. */
  private static boolean withinRotationGrace(RefreshTokenRepository.Row row, Instant now) {
    return row.rotatedAt() != null
        && row.replacedBy() != null
        && !now.isAfter(row.rotatedAt().plus(ROTATION_GRACE))
        && row.expiresAt().isAfter(now);
  }

  /** Issues the token that replaces [old] and records the link. */
  private AuthResponse.Refreshed rotate(RefreshTokenRepository.Row old, Instant now) {
    String token = Tokens.newOpaque();
    long id = refreshTokens.insert(old.userId(), Tokens.hash(token), now.plus(props.refreshTtlDays(), ChronoUnit.DAYS));
    refreshTokens.setReplacedBy(old.id(), id);
    return new AuthResponse.Refreshed(jwt.sign(old.userId()), token);
  }

  /** Enrols a phone for fingerprint login after the account password is confirmed. */
  public String createDeviceToken(long userId, String password, String deviceName) {
    UserRow user = users.findById(userId).orElseThrow(AppException::unauthorized);
    requirePassword(user, password);
    Instant now = Instant.now();
    String token = Tokens.newOpaque();
    tx.executeWithoutResult(status -> {
      deviceTokens.insert(userId, Tokens.hash(token), deviceName, now.plus(DEVICE_TOKEN_DAYS, ChronoUnit.DAYS));
      deviceTokens.revokeOldest(userId, MAX_DEVICE_TOKENS, now);
    });
    return token;
  }

  /** Signs in with a device token (the phone checked the fingerprint before sending it). */
  public AuthResponse deviceLogin(String deviceToken) {
    Instant now = Instant.now();
    DeviceTokenRepository.Row row = deviceTokens.findByHash(Tokens.hash(deviceToken))
        .orElseThrow(() -> AppException.unauthorized("Invalid device token"));
    if (row.revokedAt() != null || !row.expiresAt().isAfter(now)) {
      throw AppException.unauthorized("Invalid device token");
    }
    UserRow user = users.findById(row.userId()).orElseThrow(AppException::unauthorized);
    deviceTokens.touch(row.id(), now, now.plus(DEVICE_TOKEN_DAYS, ChronoUnit.DAYS));
    return authResponse(user);
  }

  public void revokeDeviceToken(String deviceToken) {
    deviceTokens.revokeByHash(Tokens.hash(deviceToken), Instant.now());
  }

  public void logout(String refreshToken) {
    refreshTokens.revokeByHash(Tokens.hash(refreshToken), Instant.now());
  }

  public void forgotPassword(String email) {
    // v1 stub: there is no mailer and no reset flow yet, so nothing is sent. Reset tokens must
    // never be written to logs once the flow exists; only the request is recorded.
    users.findByEmail(email).ifPresent(user ->
        log.info("Password reset requested for user {} (no mailer configured)", user.id()));
  }

  public void changePassword(long userId, String currentPassword, String newPassword, String currentRefreshToken) {
    UserRow user = users.findById(userId).orElseThrow(AppException::unauthorized);
    Instant attemptAt = Instant.now();
    throttle.reserve(user.email(), attemptAt);
    if (!matchesCounted(user.email(), currentPassword, user.passwordHash())) {
      throw new AppException("INVALID_CREDENTIALS", HttpStatus.UNAUTHORIZED, "Current password is incorrect",
          Map.of("currentPassword", "Current password is incorrect"));
    }
    throttle.succeeded(user.email());
    String hash = encoder.encode(newPassword);
    String keep = currentRefreshToken == null ? null : Tokens.hash(currentRefreshToken);
    tx.executeWithoutResult(status -> {
      users.updatePassword(userId, hash);
      Instant now = Instant.now();
      refreshTokens.revokeAllExcept(userId, keep, now);
      // Fingerprint logins were enrolled with the old password: each phone re-enrols.
      deviceTokens.revokeAll(userId, now);
    });
  }

  /** Verifies the account password (used before destructive actions). */
  public void requirePassword(UserRow user, String password) {
    // Same throttle as login: a stolen access token must not allow guessing the password here.
    Instant now = Instant.now();
    throttle.reserve(user.email(), now);
    if (!matchesCounted(user.email(), password, user.passwordHash())) {
      throw new AppException("INVALID_CREDENTIALS", HttpStatus.UNAUTHORIZED, "Password is incorrect",
          Map.of("password", "Password is incorrect"));
    }
    throttle.succeeded(user.email());
  }

  private String dummyHash() {
    String hash = dummyHash;
    if (hash == null) {
      hash = encoder.encode("jobtrail-dummy-password");
      dummyHash = hash;
    }
    return hash;
  }
}
