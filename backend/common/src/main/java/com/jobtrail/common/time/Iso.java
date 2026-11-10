package com.jobtrail.common.time;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.regex.Pattern;

/** ISO-8601 helpers for the wire format: UTC instants with millis and {@code Z}, date-only strings. */
public final class Iso {

  private static final DateTimeFormatter INSTANT =
      DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC);
  private static final Pattern DATE = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}$");
  private static final Pattern DATE_TIME_PREFIX = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}T.*");

  /** Dates outside this range are refused: MySQL cannot store every year and nobody schedules these. */
  private static final Instant EARLIEST = Instant.parse("2000-01-01T00:00:00Z");
  private static final Instant LATEST = Instant.parse("2101-01-01T00:00:00Z");

  private Iso() {}

  private static Instant inRange(Instant instant) {
    return instant.isBefore(EARLIEST) || !instant.isBefore(LATEST) ? null : instant;
  }

  public static String format(Instant instant) {
    return instant == null ? null : INSTANT.format(instant);
  }

  /** Strict {@code YYYY-MM-DD}; returns null when the text is not a real calendar date. */
  public static LocalDate parseDate(String text) {
    if (text == null || !DATE.matcher(text).matches()) {
      return null;
    }
    try {
      return LocalDate.parse(text);
    } catch (DateTimeException e) {
      return null;
    }
  }

  /** Date-time with an offset or {@code Z}; a missing zone is read as UTC. Null when invalid. */
  public static Instant parseDateTime(String text) {
    if (text == null || !DATE_TIME_PREFIX.matcher(text).matches()) {
      return null;
    }
    try {
      return inRange(OffsetDateTime.parse(text).toInstant());
    } catch (DateTimeException ignored) {
      // fall through to the zone-less form
    }
    try {
      return inRange(LocalDateTime.parse(text).toInstant(ZoneOffset.UTC));
    } catch (DateTimeException e) {
      return null;
    }
  }
}
