package com.jobtrail.common.time;

import java.time.DateTimeException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.Locale;

public final class TimeUtil {

  private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("h:mm a", Locale.US);

  private TimeUtil() {}

  /** The zone for an IANA name, or null when the name is blank or unknown. */
  public static ZoneId zoneOrNull(String tz) {
    if (tz == null || tz.isBlank()) {
      return null;
    }
    try {
      return ZoneId.of(tz.trim());
    } catch (DateTimeException e) {
      return null;
    }
  }

  /** Time zone from an {@code X-Timezone} header value; UTC when missing or unknown. */
  public static ZoneId zoneOrUtc(String tz) {
    ZoneId zone = zoneOrNull(tz);
    return zone == null ? ZoneId.of("UTC") : zone;
  }

  public static LocalDate dateInZone(Instant instant, ZoneId zone) {
    return instant.atZone(zone).toLocalDate();
  }

  /** e.g. {@code 10:00 AM} as seen in {@code zone}. */
  public static String clock(Instant instant, ZoneId zone) {
    return CLOCK.format(instant.atZone(zone));
  }

  /** Monday of the week containing {@code date}. */
  public static LocalDate mondayOf(LocalDate date) {
    return date.minusDays(date.getDayOfWeek().getValue() - 1L);
  }

  public static long daysBetween(LocalDate from, LocalDate to) {
    return ChronoUnit.DAYS.between(from, to);
  }
}
