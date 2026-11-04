package com.jobtrail.gateway;

import java.net.ConnectException;
import java.util.concurrent.TimeoutException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebExceptionHandler;
import reactor.core.publisher.Mono;

/** Maps gateway-level failures (no route, service down) to the API error shape. */
@Component
@Order(-2)
public class ApiErrorHandler implements WebExceptionHandler {

  private static final Logger log = LoggerFactory.getLogger(ApiErrorHandler.class);

  @Override
  public Mono<Void> handle(ServerWebExchange exchange, Throwable ex) {
    if (ex instanceof ResponseStatusException rse) {
      HttpStatusCode status = rse.getStatusCode();
      if (status.value() == HttpStatus.NOT_FOUND.value()) {
        return ApiErrors.write(exchange, status, "NOT_FOUND", "Route not found");
      }
      if (status.value() == HttpStatus.SERVICE_UNAVAILABLE.value()
          || status.value() == HttpStatus.GATEWAY_TIMEOUT.value()) {
        return unavailable(exchange, status, ex);
      }
      if (status.is4xxClientError()) {
        return ApiErrors.write(exchange, status, "VALIDATION_ERROR", "Bad request");
      }
    }
    if (isConnectionProblem(ex)) {
      return unavailable(exchange, HttpStatus.SERVICE_UNAVAILABLE, ex);
    }
    log.error("Unhandled gateway error", ex);
    return ApiErrors.write(exchange, HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL", "Internal server error");
  }

  private static Mono<Void> unavailable(ServerWebExchange exchange, HttpStatusCode status, Throwable ex) {
    log.warn("Downstream service unavailable for {}: {}", exchange.getRequest().getPath(), ex.toString());
    return ApiErrors.write(exchange, status, "INTERNAL", "Service temporarily unavailable");
  }

  private static boolean isConnectionProblem(Throwable ex) {
    for (Throwable t = ex; t != null; t = t.getCause()) {
      if (t instanceof ConnectException || t instanceof TimeoutException
          || t.getClass().getName().contains("ConnectTimeout")
          || t.getClass().getName().contains("AnnotatedConnectException")) {
        return true;
      }
      if (t.getCause() == t) {
        break;
      }
    }
    return false;
  }
}
