package com.jobtrail.common.error;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.Map;

/** Wire format of every non-2xx response: {@code {"error":{"code","message","fields"?}}}. */
public record ApiError(Body error) {

  @JsonInclude(JsonInclude.Include.NON_NULL)
  public record Body(String code, String message, Map<String, String> fields) {}

  public static ApiError of(String code, String message) {
    return new ApiError(new Body(code, message, null));
  }

  public static ApiError of(String code, String message, Map<String, String> fields) {
    return new ApiError(new Body(code, message, fields));
  }
}
