package com.jobtrail.common.error;

import com.jobtrail.common.web.RequestGuardFilter;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.support.MissingServletRequestPartException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.Map;

/** Turns every failure into the API.md error shape. */
@RestControllerAdvice
public class GlobalExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

  @ExceptionHandler(AppException.class)
  ResponseEntity<ApiError> app(AppException e) {
    return ResponseEntity.status(e.status())
        .body(ApiError.of(e.code(), e.getMessage(), e.fields()));
  }

  @ExceptionHandler(HttpMessageNotReadableException.class)
  ResponseEntity<ApiError> unreadable(HttpMessageNotReadableException e) {
    for (Throwable t = e; t != null; t = t.getCause()) {
      if (t instanceof RequestGuardFilter.BodyTooLargeException) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
            .body(ApiError.of("PAYLOAD_TOO_LARGE", "Request body too large"));
      }
    }
    return validation("Invalid JSON body", null);
  }

  /** Foreign keys to {@code users} are named {@code fk_<table>_user} (V1__init.sql, V2). */
  private static final Pattern USER_FOREIGN_KEY = Pattern.compile("`fk_[a-z]+_user`");

  /**
   * A write that references a user who no longer exists: the account was deleted while one of its
   * access tokens (valid for up to 15 minutes) was still in use. That is a session problem, not a
   * server error.
   */
  @ExceptionHandler(DataIntegrityViolationException.class)
  ResponseEntity<ApiError> integrity(DataIntegrityViolationException e) {
    String message = e.getMostSpecificCause().getMessage();
    if (message != null && message.contains("foreign key constraint fails")
        && USER_FOREIGN_KEY.matcher(message).find()) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
          .body(ApiError.of("UNAUTHORIZED", "Account no longer exists"));
    }
    return unexpected(e);
  }

  @ExceptionHandler({
    MethodArgumentTypeMismatchException.class,
    MissingServletRequestParameterException.class
  })
  ResponseEntity<ApiError> badParam(Exception e) {
    return validation("Invalid request parameter", null);
  }

  @ExceptionHandler(MissingServletRequestPartException.class)
  ResponseEntity<ApiError> missingPart(MissingServletRequestPartException e) {
    return validation(
        "A JPEG or PNG image is required", Map.of("file", "A JPEG or PNG image is required"));
  }

  @ExceptionHandler(MaxUploadSizeExceededException.class)
  ResponseEntity<ApiError> tooLarge(MaxUploadSizeExceededException e) {
    return validation("File too large (max 2 MB)", Map.of("file", "File too large (max 2 MB)"));
  }

  @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
  ResponseEntity<ApiError> mediaType(HttpMediaTypeNotSupportedException e) {
    return validation("Unsupported content type", null);
  }

  @ExceptionHandler({NoResourceFoundException.class, HttpRequestMethodNotSupportedException.class})
  ResponseEntity<ApiError> notFound(Exception e) {
    return ResponseEntity.status(HttpStatus.NOT_FOUND)
        .body(ApiError.of("NOT_FOUND", "Route not found"));
  }

  @ExceptionHandler(Exception.class)
  ResponseEntity<ApiError> unexpected(Exception e) {
    log.error("Unhandled error", e);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(ApiError.of("INTERNAL", "Internal server error"));
  }

  private static ResponseEntity<ApiError> validation(String message, Map<String, String> fields) {
    return ResponseEntity.status(HttpStatus.BAD_REQUEST)
        .body(ApiError.of("VALIDATION_ERROR", message, fields));
  }
}
