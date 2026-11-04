package com.jobtrail.common.validation;

import com.jobtrail.common.time.Iso;
import com.jobtrail.common.time.TimeUtil;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.springframework.util.MultiValueMap;

/** Validating view over query-string parameters; mirrors {@link JsonBody}'s collect-then-throw style. */
public final class QueryParams {

  private final MultiValueMap<String, String> params;
  private final Validator validator = new Validator();

  public QueryParams(MultiValueMap<String, String> params) {
    this.params = params;
  }

  public Validator validator() {
    return validator;
  }

  public void finish() {
    validator.throwIfInvalid();
  }

  public String text(String name) {
    String value = params.getFirst(name);
    return value == null || value.isBlank() ? null : value.trim();
  }

  /** Highest page number accepted; keeps {@code (page - 1) * pageSize} far from int overflow. */
  public static final int MAX_PAGE = 10_000;

  public int page() {
    return intParam("page", 1, 1, MAX_PAGE);
  }

  public int pageSize() {
    return intParam("pageSize", 20, 1, 100);
  }

  public Long optionalId(String name) {
    String value = text(name);
    if (value == null) {
      return null;
    }
    try {
      long id = Long.parseLong(value);
      if (id > 0) {
        return id;
      }
    } catch (NumberFormatException ignored) {
      // reported below
    }
    validator.error(name, "Must be a positive integer");
    return null;
  }

  private int intParam(String name, int fallback, int min, int max) {
    String value = text(name);
    if (value == null) {
      return fallback;
    }
    try {
      int n = Integer.parseInt(value);
      if (n >= min && n <= max) {
        return n;
      }
    } catch (NumberFormatException ignored) {
      // reported below
    }
    validator.error(name, "Must be a whole number between " + min + " and " + max);
    return fallback;
  }

  public LocalDate optionalDate(String name) {
    String value = text(name);
    if (value == null) {
      return null;
    }
    LocalDate date = Iso.parseDate(value);
    if (date == null) {
      validator.error(name, "Use YYYY-MM-DD");
    }
    return date;
  }

  public LocalDate requiredDate(String name) {
    if (text(name) == null) {
      validator.error(name, Validator.REQUIRED);
      return null;
    }
    return optionalDate(name);
  }

  /** Accepts a date-time or a plain date; returns the raw text when it parses, else null. */
  public String optionalDateOrDateTime(String name) {
    String value = text(name);
    if (value == null) {
      return null;
    }
    if (Iso.parseDate(value) == null && Iso.parseDateTime(value) == null) {
      validator.error(name, "Invalid date");
      return null;
    }
    return value;
  }

  /** {@code ?tz=Area/City}; UTC when omitted. */
  public ZoneId zone(String name) {
    String value = text(name);
    if (value == null) {
      return ZoneId.of("UTC");
    }
    ZoneId zone = TimeUtil.zoneOrNull(value);
    if (zone == null) {
      validator.error(name, "Unknown time zone");
      return ZoneId.of("UTC");
    }
    return zone;
  }

  public <E extends Enum<E>> E optionalEnum(String name, Class<E> type) {
    String value = text(name);
    if (value == null) {
      return null;
    }
    E parsed = parse(value, type);
    if (parsed == null) {
      validator.error(name, "Invalid value");
    }
    return parsed;
  }

  /** {@code status=a,b} and {@code status=a&status=b} both work. */
  public <E extends Enum<E>> List<E> enumList(String name, Class<E> type) {
    List<String> raw = params.get(name);
    List<E> out = new ArrayList<>();
    if (raw == null) {
      return out;
    }
    for (String entry : raw) {
      for (String part : entry.split(",")) {
        if (part.isBlank()) {
          continue;
        }
        E parsed = parse(part.trim(), type);
        if (parsed == null) {
          validator.error(name, "Invalid value: " + part.trim());
        } else {
          out.add(parsed);
        }
      }
    }
    return out;
  }

  private static <E extends Enum<E>> E parse(String value, Class<E> type) {
    for (E constant : type.getEnumConstants()) {
      if (constant.name().equals(value)) {
        return constant;
      }
    }
    return null;
  }

  /** Lower-cased helper for case-insensitive keys such as {@code format}. */
  public String lower(String name, String fallback) {
    String value = text(name);
    return value == null ? fallback : value.toLowerCase(Locale.ROOT);
  }

  public static Instant parseInstantOrDate(String text, boolean endExclusiveDay) {
    LocalDate date = Iso.parseDate(text);
    if (date != null) {
      LocalDate d = endExclusiveDay ? date.plusDays(1) : date;
      return d.atStartOfDay(ZoneId.of("UTC")).toInstant();
    }
    return Iso.parseDateTime(text);
  }
}
