package com.jobtrail.common.db;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

/**
 * DATETIME(3) columns hold UTC wall-clock values. They are bound and read as {@link LocalDateTime}
 * (no driver time-zone conversion) and converted to/from {@link Instant} here.
 */
public final class Db {

  private Db() {}

  public static LocalDateTime ts(Instant instant) {
    return instant == null ? null : LocalDateTime.ofInstant(instant, ZoneOffset.UTC);
  }

  public static Instant instant(ResultSet rs, String column) throws SQLException {
    LocalDateTime value = rs.getObject(column, LocalDateTime.class);
    return value == null ? null : value.toInstant(ZoneOffset.UTC);
  }

  public static LocalDate date(ResultSet rs, String column) throws SQLException {
    return rs.getObject(column, LocalDate.class);
  }

  public static Long nullableLong(ResultSet rs, String column) throws SQLException {
    long value = rs.getLong(column);
    return rs.wasNull() ? null : value;
  }

  public static Integer nullableInt(ResultSet rs, String column) throws SQLException {
    int value = rs.getInt(column);
    return rs.wasNull() ? null : value;
  }

  /** Converts a value to something the driver binds directly (enums by name, instants as UTC). */
  public static Object param(Object value) {
    if (value instanceof Instant instant) {
      return ts(instant);
    }
    if (value instanceof Enum<?> e) {
      return e.name();
    }
    return value;
  }
}
