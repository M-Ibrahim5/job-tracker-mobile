package com.jobtrail.user.me;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.HexFormat;
import java.util.Optional;
import java.util.regex.Pattern;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * Avatar images, stored in the {@code user_avatars} table so every user-service instance can serve
 * them (V4). The database path stays {@code avatars/<userId>-<random>.<ext>}. Files written to
 * {@code UPLOAD_DIR/avatars} before V4 are still served and deleted from disk.
 */
@Component
public class AvatarStorage {

  /** An avatar's bytes and media type. */
  public record Image(byte[] bytes, String contentType) {}

  private static final SecureRandom RANDOM = new SecureRandom();
  private static final String PREFIX = "avatars/";
  /** What generated file names look like; anything else is not an avatar. */
  private static final Pattern FILE_NAME = Pattern.compile("\\d+-[0-9a-f]{24}\\.(png|jpg)");

  private final Path root;
  private final JdbcClient jdbc;

  public AvatarStorage(Path uploadRoot, JdbcClient jdbc) {
    this.root = uploadRoot;
    this.jdbc = jdbc;
  }

  /** Stores the image and returns its path (kept in {@code users.avatar_path}). */
  public String save(long userId, byte[] bytes, String extension) {
    byte[] suffix = new byte[12];
    RANDOM.nextBytes(suffix);
    String fileName = userId + "-" + HexFormat.of().formatHex(suffix) + "." + extension;
    jdbc.sql("""
            INSERT INTO user_avatars (file_name, user_id, content_type, bytes)
            VALUES (:name, :user, :type, :bytes)""")
        .param("name", fileName)
        .param("user", userId)
        .param("type", extension.equals("png") ? "image/png" : "image/jpeg")
        .param("bytes", bytes)
        .update();
    return PREFIX + fileName;
  }

  /** The avatar called [fileName], from the database or (older uploads) the upload directory. */
  public Optional<Image> load(String fileName) {
    if (!FILE_NAME.matcher(fileName).matches()) {
      return Optional.empty();
    }
    Optional<Image> stored = jdbc.sql("SELECT bytes, content_type FROM user_avatars WHERE file_name = :name")
        .param("name", fileName)
        .query((rs, i) -> new Image(rs.getBytes("bytes"), rs.getString("content_type")))
        .optional();
    if (stored.isPresent()) {
      return stored;
    }
    Path legacy = legacyFile(PREFIX + fileName);
    try {
      if (legacy != null && Files.isRegularFile(legacy)) {
        return Optional.of(new Image(Files.readAllBytes(legacy),
            fileName.endsWith(".png") ? "image/png" : "image/jpeg"));
      }
    } catch (IOException ignored) {
      // Unreadable: treated as missing.
    }
    return Optional.empty();
  }

  public void delete(String relativePath) {
    if (relativePath == null || !relativePath.startsWith(PREFIX)) {
      return;
    }
    jdbc.sql("DELETE FROM user_avatars WHERE file_name = :name")
        .param("name", relativePath.substring(PREFIX.length()))
        .update();
    Path legacy = legacyFile(relativePath);
    if (legacy == null) {
      return;
    }
    try {
      Files.deleteIfExists(legacy);
    } catch (IOException ignored) {
      // A leftover file is harmless; the DB no longer points at it.
    }
  }

  /** The pre-V4 file for [relativePath], or null when it would escape the upload directory. */
  private Path legacyFile(String relativePath) {
    Path target = root.resolve(relativePath).normalize();
    return target.startsWith(root) ? target : null;
  }
}
