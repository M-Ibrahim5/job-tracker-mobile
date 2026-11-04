package com.jobtrail.gateway;

import java.nio.charset.StandardCharsets;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.MediaType;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/** Writes the docs/API.md error shape from the gateway itself (limits, unknown routes, outages). */
final class ApiErrors {

  private ApiErrors() {}

  static Mono<Void> write(ServerWebExchange exchange, HttpStatusCode status, String code, String message) {
    if (exchange.getResponse().isCommitted()) {
      return Mono.empty();
    }
    String json = "{\"error\":{\"code\":\"" + code + "\",\"message\":\"" + message + "\"}}";
    exchange.getResponse().setStatusCode(status);
    exchange.getResponse().getHeaders().setContentType(MediaType.APPLICATION_JSON);
    DataBuffer buffer = exchange.getResponse().bufferFactory().wrap(json.getBytes(StandardCharsets.UTF_8));
    return exchange.getResponse().writeWith(Mono.just(buffer));
  }
}
