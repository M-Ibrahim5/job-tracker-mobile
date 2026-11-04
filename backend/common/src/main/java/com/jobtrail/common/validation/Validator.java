package com.jobtrail.common.validation;

import com.jobtrail.common.error.AppException;
import java.util.LinkedHashMap;
import java.util.Map;

/** Collects per-field problems (first message per field wins) and raises one VALIDATION_ERROR. */
public final class Validator {

  public static final String REQUIRED = "This field is required";

  private final Map<String, String> errors = new LinkedHashMap<>();

  public static String tooLong(int max) {
    return "Must be at most " + max + " characters";
  }

  public void error(String field, String message) {
    errors.putIfAbsent(field, message);
  }

  public boolean valid() {
    return errors.isEmpty();
  }

  public boolean failed(String field) {
    return errors.containsKey(field);
  }

  public void throwIfInvalid() {
    if (!errors.isEmpty()) {
      throw AppException.validation(new LinkedHashMap<>(errors));
    }
  }
}
