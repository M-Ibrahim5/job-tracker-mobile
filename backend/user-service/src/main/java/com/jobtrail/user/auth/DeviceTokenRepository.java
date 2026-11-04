package com.jobtrail.user.auth;

import com.jobtrail.common.db.Db;
import java.time.Instant;
import java.util.Optional;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Fingerprint-login tokens ({@code device_tokens}); only hashes are stored. */
@Repository
public class DeviceTokenRepository {

  public record Row(long id, long userId, Instant expiresAt, Instant revokedAt) {}

  private static final RowMapper<Row> MAPPER = (rs, i) -> new Row(
      rs.getLong("id"),
      rs.getLong("user_id"),
      Db.instant(rs, "expires_at"),
      Db.instant(rs, "revoked_at"));

  private final JdbcClient jdbc;

  public DeviceTokenRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void insert(long userId, String tokenHash, String deviceName, Instant expiresAt) {
    jdbc.sql("""
            INSERT INTO device_tokens (user_id, token_hash, device_name, expires_at)
            VALUES (:user, :hash, :name, :exp)""")
        .param("user", userId)
        .param("hash", tokenHash)
        .param("name", deviceName)
        .param("exp", Db.ts(expiresAt))
        .update();
  }

  public Optional<Row> findByHash(String tokenHash) {
    return jdbc.sql("SELECT id, user_id, expires_at, revoked_at FROM device_tokens WHERE token_hash = :hash")
        .param("hash", tokenHash)
        .query(MAPPER)
        .optional();
  }

  /** Records a use and slides the expiry forward. */
  public void touch(long id, Instant now, Instant newExpiry) {
    jdbc.sql("UPDATE device_tokens SET last_used_at = :now, expires_at = :exp WHERE id = :id")
        .param("now", Db.ts(now))
        .param("exp", Db.ts(newExpiry))
        .param("id", id)
        .update();
  }

  public int revokeByHash(String tokenHash, Instant now) {
    return jdbc.sql("UPDATE device_tokens SET revoked_at = :now WHERE token_hash = :hash AND revoked_at IS NULL")
        .param("now", Db.ts(now))
        .param("hash", tokenHash)
        .update();
  }

  public int revokeAll(long userId, Instant now) {
    return jdbc.sql("UPDATE device_tokens SET revoked_at = :now WHERE user_id = :user AND revoked_at IS NULL")
        .param("now", Db.ts(now))
        .param("user", userId)
        .update();
  }

  /** Keeps the newest {@code keep} live tokens of the user and revokes the rest. */
  public int revokeOldest(long userId, int keep, Instant now) {
    return jdbc.sql("""
            UPDATE device_tokens SET revoked_at = :now
            WHERE user_id = :user AND revoked_at IS NULL AND id NOT IN (
              SELECT id FROM (
                SELECT id FROM device_tokens WHERE user_id = :user AND revoked_at IS NULL
                ORDER BY id DESC LIMIT :keep) newest)""")
        .param("now", Db.ts(now))
        .param("user", userId)
        .param("keep", keep)
        .update();
  }
}
