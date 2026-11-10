package com.jobtrail.user.auth;

import com.jobtrail.common.db.Db;
import java.time.Instant;
import java.util.Optional;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Repository;

@Repository
public class RefreshTokenRepository {

  /**
   * A stored token. {@code rotatedAt} / {@code replacedBy} are set when the token was exchanged for
   * a new one by {@code /auth/refresh} (as opposed to logout or a revoke-all).
   */
  public record Row(long id, long userId, Instant expiresAt, Instant revokedAt, Instant rotatedAt, Long replacedBy) {}

  private static final String COLUMNS = "id, user_id, expires_at, revoked_at, rotated_at, replaced_by";

  private static final RowMapper<Row> MAPPER = (rs, i) -> new Row(
      rs.getLong("id"),
      rs.getLong("user_id"),
      Db.instant(rs, "expires_at"),
      Db.instant(rs, "revoked_at"),
      Db.instant(rs, "rotated_at"),
      Db.nullableLong(rs, "replaced_by"));

  private final JdbcClient jdbc;

  public RefreshTokenRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** Inserts a token and returns its id. */
  public long insert(long userId, String tokenHash, Instant expiresAt) {
    GeneratedKeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES (:user, :hash, :exp)")
        .param("user", userId)
        .param("hash", tokenHash)
        .param("exp", Db.ts(expiresAt))
        .update(keys);
    return keys.getKey().longValue();
  }

  public Optional<Row> findByHash(String tokenHash) {
    return jdbc.sql("SELECT " + COLUMNS + " FROM refresh_tokens WHERE token_hash = :hash")
        .param("hash", tokenHash)
        .query(MAPPER)
        .optional();
  }

  public Optional<Row> findById(long id) {
    return jdbc.sql("SELECT " + COLUMNS + " FROM refresh_tokens WHERE id = :id")
        .param("id", id)
        .query(MAPPER)
        .optional();
  }

  /**
   * Atomically marks a live token as rotated; returns 0 when someone else already revoked or
   * rotated it (a concurrent refresh).
   */
  public int claim(long id, Instant now) {
    return jdbc.sql("""
            UPDATE refresh_tokens SET revoked_at = :now, rotated_at = :now
            WHERE id = :id AND revoked_at IS NULL""")
        .param("now", Db.ts(now))
        .param("id", id)
        .update();
  }

  /** Records which token replaced a rotated one. */
  public void setReplacedBy(long id, long replacementId) {
    jdbc.sql("UPDATE refresh_tokens SET replaced_by = :replacement WHERE id = :id")
        .param("replacement", replacementId)
        .param("id", id)
        .update();
  }

  /**
   * Atomically revokes a token that is still live; returns 0 when it was used (rotated) or revoked
   * in the meantime.
   */
  public int revokeIfLive(long id, Instant now) {
    return jdbc.sql("UPDATE refresh_tokens SET revoked_at = :now WHERE id = :id AND revoked_at IS NULL")
        .param("now", Db.ts(now))
        .param("id", id)
        .update();
  }

  public int revokeByHash(String tokenHash, Instant now) {
    return jdbc.sql("UPDATE refresh_tokens SET revoked_at = :now WHERE token_hash = :hash AND revoked_at IS NULL")
        .param("now", Db.ts(now))
        .param("hash", tokenHash)
        .update();
  }

  public int revokeAll(long userId, Instant now) {
    return jdbc.sql("UPDATE refresh_tokens SET revoked_at = :now WHERE user_id = :user AND revoked_at IS NULL")
        .param("now", Db.ts(now))
        .param("user", userId)
        .update();
  }

  /** Revokes every live token except the one whose hash is {@code keepHash} (may be null). */
  public int revokeAllExcept(long userId, String keepHash, Instant now) {
    if (keepHash == null) {
      return revokeAll(userId, now);
    }
    int revoked = jdbc.sql("""
            UPDATE refresh_tokens SET revoked_at = :now
            WHERE user_id = :user AND revoked_at IS NULL AND token_hash <> :keep""")
        .param("now", Db.ts(now))
        .param("user", userId)
        .param("keep", keepHash)
        .update();
    // The kept token's predecessor could still trade itself in during the rotation grace and retire
    // it. After a password change that old token must count as reuse instead.
    jdbc.sql("""
            UPDATE refresh_tokens old JOIN refresh_tokens kept ON old.replaced_by = kept.id
            SET old.rotated_at = NULL
            WHERE kept.user_id = :user AND kept.token_hash = :keep""")
        .param("user", userId)
        .param("keep", keepHash)
        .update();
    return revoked;
  }
}
