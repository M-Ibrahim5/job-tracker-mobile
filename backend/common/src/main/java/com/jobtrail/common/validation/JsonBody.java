package com.jobtrail.common.validation;

import static com.jobtrail.common.validation.Validator.REQUIRED;
import static com.jobtrail.common.validation.Validator.tooLong;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.error.AppException;
import com.jobtrail.common.time.Iso;
import java.net.URI;
import java.net.URISyntaxException;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * Typed, validating view over a JSON request body. Each accessor records problems in the shared
 * {@link Validator} and returns null on failure; call {@link #finish()} once everything is read.
 * Presence ({@link #has}) is separate from value so PATCH can tell "omitted" from "set to null".
 */
public final class JsonBody {

  private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");

  private final JsonNode node;
  private final Validator validator = new Validator();

  private JsonBody(JsonNode node) {
    this.node = node;
  }

  public static JsonBody of(JsonNode node) {
    if (node == null || !node.isObject()) {
      throw AppException.badRequest("Request body must be a JSON object");
    }
    return new JsonBody(node);
  }

  public Validator validator() {
    return validator;
  }

  public void finish() {
    validator.throwIfInvalid();
  }

  public boolean has(String field) {
    return node.has(field);
  }

  private JsonNode value(String field) {
    JsonNode n = node.get(field);
    return n == null || n.isNull() ? null : n;
  }

  /** Trimmed, non-empty text of at most {@code max} chars. */
  public String requiredText(String field, int max) {
    JsonNode n = value(field);
    if (n == null || !n.isTextual() || n.asText().trim().isEmpty()) {
      validator.error(field, REQUIRED);
      return null;
    }
    String text = n.asText().trim();
    if (text.length() > max) {
      validator.error(field, tooLong(max));
      return null;
    }
    return text;
  }

  /** Trimmed text; null or blank becomes null. */
  public String optionalText(String field, int max) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    if (!n.isTextual()) {
      validator.error(field, "Must be a string");
      return null;
    }
    String text = n.asText().trim();
    if (text.length() > max) {
      validator.error(field, tooLong(max));
      return null;
    }
    return text.isEmpty() ? null : text;
  }

  /** Untrimmed, non-empty text (passwords, tokens). */
  public String requiredRaw(String field, int max) {
    JsonNode n = value(field);
    if (n == null || !n.isTextual() || n.asText().isEmpty()) {
      validator.error(field, REQUIRED);
      return null;
    }
    if (n.asText().length() > max) {
      validator.error(field, tooLong(max));
      return null;
    }
    return n.asText();
  }

  public String optionalRaw(String field) {
    JsonNode n = value(field);
    return n != null && n.isTextual() && !n.asText().isEmpty() ? n.asText() : null;
  }

  /** Trimmed, lower-cased e-mail address. */
  public String requiredEmail(String field) {
    String text = requiredText(field, 254);
    if (text == null) {
      return null;
    }
    text = text.toLowerCase(Locale.ROOT);
    if (!EMAIL.matcher(text).matches()) {
      validator.error(field, "Enter a valid email address");
      return null;
    }
    return text;
  }

  public String optionalEmail(String field) {
    String text = optionalText(field, 254);
    if (text == null) {
      return null;
    }
    if (!EMAIL.matcher(text).matches()) {
      validator.error(field, "Enter a valid email address");
      return null;
    }
    return text;
  }

  public String optionalHttpUrl(String field) {
    String text = optionalText(field, 2048);
    if (text == null) {
      return null;
    }
    try {
      URI uri = new URI(text);
      String scheme = uri.getScheme();
      boolean http = "http".equalsIgnoreCase(scheme) || "https".equalsIgnoreCase(scheme);
      if (!http || uri.getHost() == null) {
        throw new URISyntaxException(text, "not an http(s) url");
      }
      return text;
    } catch (URISyntaxException e) {
      validator.error(field, "Enter a valid http(s) URL");
      return null;
    }
  }

  public <E extends Enum<E>> E requiredEnum(String field, Class<E> type) {
    JsonNode n = value(field);
    if (n == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    return parseEnum(field, n, type);
  }

  public <E extends Enum<E>> E optionalEnum(String field, Class<E> type) {
    JsonNode n = value(field);
    return n == null ? null : parseEnum(field, n, type);
  }

  private <E extends Enum<E>> E parseEnum(String field, JsonNode n, Class<E> type) {
    if (n.isTextual()) {
      for (E constant : type.getEnumConstants()) {
        if (constant.name().equals(n.asText())) {
          return constant;
        }
      }
    }
    validator.error(
        field, "Must be one of " + String.join(", ", names(type)));
    return null;
  }

  private static <E extends Enum<E>> List<String> names(Class<E> type) {
    return Arrays.stream(type.getEnumConstants()).map(Enum::name).toList();
  }

  public Integer optionalInt(String field, int min, int max) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    if (!n.isIntegralNumber() || !n.canConvertToInt()) {
      validator.error(field, "Must be an integer");
      return null;
    }
    int number = n.asInt();
    if (number < min || number > max) {
      validator.error(field, "Must be between " + min + " and " + max);
      return null;
    }
    return number;
  }

  public Integer requiredInt(String field, int min, int max) {
    if (value(field) == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    return optionalInt(field, min, max);
  }

  /** Integer restricted to {@code allowed}; null (JSON null or absent) is returned as null. */
  public Integer optionalIntOneOf(String field, int... allowed) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    if (n.isIntegralNumber() && n.canConvertToInt()) {
      for (int a : allowed) {
        if (a == n.asInt()) {
          return a;
        }
      }
    }
    validator.error(field, "Must be one of " + Arrays.toString(allowed).replaceAll("[\\[\\]]", ""));
    return null;
  }

  public Boolean optionalBool(String field) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    if (!n.isBoolean()) {
      validator.error(field, "Must be true or false");
      return null;
    }
    return n.asBoolean();
  }

  public Boolean requiredBool(String field) {
    if (value(field) == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    return optionalBool(field);
  }

  public List<Integer> requiredIntList(String field, int maxItems, int itemMax, String tooManyMessage) {
    if (value(field) == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    return optionalIntList(field, maxItems, itemMax, tooManyMessage);
  }

  /** Array of positive ints (each ≤ {@code itemMax}), at most {@code maxItems} entries. */
  public List<Integer> optionalIntList(String field, int maxItems, int itemMax, String tooManyMessage) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    if (!n.isArray()) {
      validator.error(field, "Must be a list of numbers");
      return null;
    }
    if (n.size() > maxItems) {
      validator.error(field, tooManyMessage);
      return null;
    }
    List<Integer> out = new ArrayList<>();
    for (JsonNode item : n) {
      if (!item.isIntegralNumber() || !item.canConvertToInt() || item.asInt() < 1 || item.asInt() > itemMax) {
        validator.error(field, "Each value must be a whole number between 1 and " + itemMax);
        return null;
      }
      out.add(item.asInt());
    }
    return out;
  }

  public Instant requiredInstant(String field) {
    if (value(field) == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    return optionalInstant(field);
  }

  public Instant optionalInstant(String field) {
    JsonNode n = value(field);
    if (n == null) {
      return null;
    }
    Instant parsed = n.isTextual() ? Iso.parseDateTime(n.asText()) : null;
    if (parsed == null) {
      validator.error(field, "Invalid date-time");
    }
    return parsed;
  }

  public LocalDate requiredDate(String field) {
    JsonNode n = value(field);
    if (n == null) {
      validator.error(field, REQUIRED);
      return null;
    }
    LocalDate parsed = n.isTextual() ? Iso.parseDate(n.asText()) : null;
    if (parsed == null) {
      validator.error(field, "Use YYYY-MM-DD");
    }
    return parsed;
  }

  /** Exact-match literal, e.g. the {@code DELETE} confirmation. */
  public void requireLiteral(String field, String expected, String message) {
    JsonNode n = value(field);
    if (n == null || !n.isTextual() || !expected.equals(n.asText())) {
      validator.error(field, message);
    }
  }
}
