package com.jobtrail.common.error;

import java.util.Map;
import org.springframework.http.HttpStatus;

/** Typed API error: maps to the {@code error} object documented in docs/API.md. */
public class AppException extends RuntimeException {

  private final String code;
  private final HttpStatus status;
  private final Map<String, String> fields;

  public AppException(String code, HttpStatus status, String message, Map<String, String> fields) {
    super(message);
    this.code = code;
    this.status = status;
    this.fields = fields;
  }

  public AppException(String code, HttpStatus status, String message) {
    this(code, status, message, null);
  }

  public String code() {
    return code;
  }

  public HttpStatus status() {
    return status;
  }

  public Map<String, String> fields() {
    return fields;
  }

  public static AppException unauthorized(String message) {
    return new AppException("UNAUTHORIZED", HttpStatus.UNAUTHORIZED, message);
  }

  public static AppException unauthorized() {
    return unauthorized("Authentication required");
  }

  public static AppException tokenExpired() {
    return new AppException("TOKEN_EXPIRED", HttpStatus.UNAUTHORIZED, "Access token expired");
  }

  public static AppException notFound(String message) {
    return new AppException("NOT_FOUND", HttpStatus.NOT_FOUND, message);
  }

  public static AppException validation(String message, Map<String, String> fields) {
    return new AppException("VALIDATION_ERROR", HttpStatus.BAD_REQUEST, message, fields);
  }

  public static AppException validation(Map<String, String> fields) {
    return validation("Validation failed", fields);
  }

  /** A VALIDATION_ERROR about one field. */
  public static AppException invalidField(String field, String message) {
    return validation(message, Map.of(field, message));
  }

  /** A VALIDATION_ERROR without per-field detail. */
  public static AppException badRequest(String message) {
    return new AppException("VALIDATION_ERROR", HttpStatus.BAD_REQUEST, message);
  }
}
