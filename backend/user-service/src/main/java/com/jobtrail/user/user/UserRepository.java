package com.jobtrail.user.user;

import com.jobtrail.common.db.Db;
import com.jobtrail.common.db.UpdateBuilder;
import com.jobtrail.common.error.AppException;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Repository;

@Repository
public class UserRepository {

  private static final RowMapper<UserRow> MAPPER = (rs, i) -> new UserRow(
      rs.getLong("id"),
      rs.getString("email"),
      rs.getString("password_hash"),
      rs.getString("full_name"),
      rs.getString("phone"),
      rs.getString("job_role"),
      rs.getString("looking_for"),
      rs.getString("location"),
      rs.getString("avatar_path"),
      Db.instant(rs, "email_verified_at"));

  private final JdbcClient jdbc;

  public UserRepository(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public Optional<UserRow> findById(long id) {
    return jdbc.sql("SELECT * FROM users WHERE id = :id").param("id", id).query(MAPPER).optional();
  }

  public Optional<UserRow> findByEmail(String email) {
    return jdbc.sql("SELECT * FROM users WHERE email = :email")
        .param("email", email)
        .query(MAPPER)
        .optional();
  }

  /** Inserts the account row; a duplicate e-mail raises {@code DuplicateKeyException}. */
  public long insert(String email, String passwordHash, String fullName) {
    KeyHolder keys = new GeneratedKeyHolder();
    jdbc.sql("INSERT INTO users (email, password_hash, full_name) VALUES (:email, :hash, :name)")
        .param("email", email)
        .param("hash", passwordHash)
        .param("name", fullName)
        .update(keys);
    return keys.getKey().longValue();
  }

  /** Applies only the given profile columns (e.g. {@code full_name}, {@code job_role}). */
  public void updateColumns(long id, Map<String, Object> columns) {
    UpdateBuilder update = UpdateBuilder.table("users");
    columns.forEach(update::set);
    update.execute(jdbc, "id = :id", Map.of("id", id));
  }

  public void updatePassword(long id, String passwordHash) {
    jdbc.sql("UPDATE users SET password_hash = :hash WHERE id = :id")
        .param("hash", passwordHash)
        .param("id", id)
        .update();
  }

  /**
   * Reads the avatar path (null when there is none) and locks the user row until the surrounding
   * transaction ends. Throws 404 when the user is gone.
   */
  public String lockAvatarPath(long id) {
    List<String> rows = jdbc.sql("SELECT avatar_path FROM users WHERE id = :id FOR UPDATE")
        .param("id", id)
        .query((rs, i) -> rs.getString("avatar_path"))
        .list();
    if (rows.isEmpty()) {
      throw AppException.notFound("User not found");
    }
    return rows.get(0);
  }

  public void setAvatarPath(long id, String path) {
    jdbc.sql("UPDATE users SET avatar_path = :path WHERE id = :id")
        .param("path", path)
        .param("id", id)
        .update();
  }

  /** Foreign keys cascade to settings, tokens and every tracker table. */
  public void delete(long id) {
    jdbc.sql("DELETE FROM users WHERE id = :id").param("id", id).update();
  }
}
