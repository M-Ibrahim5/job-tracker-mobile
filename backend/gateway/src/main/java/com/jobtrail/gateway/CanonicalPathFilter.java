package com.jobtrail.gateway;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * Rejects paths that could be read differently by the rate limits and by routing. {@link
 * RateLimitFilter} compares the raw path with plain string prefixes, while route predicates and the
 * services match decoded segments without {@code ;params}: {@code /api/v1/%61uth/login} would
 * skip the login limit yet still reach the login handler. No client sends percent-encoding,
 * {@code ;}, {@code \}, {@code //} or dot segments in this API (ids are numeric and search text
 * travels in the query string), so such paths get the same 404 as an unknown route.
 */
@Component
public class CanonicalPathFilter implements GlobalFilter, Ordered {

  private static final Logger log = LoggerFactory.getLogger(CanonicalPathFilter.class);

  @Override
  public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
    String raw = exchange.getRequest().getURI().getRawPath();
    if (isCanonical(raw)) {
      return chain.filter(exchange);
    }
    log.debug("Rejected non-canonical request path");
    return ApiErrors.write(exchange, HttpStatus.NOT_FOUND, "NOT_FOUND", "Route not found");
  }

  /** True for a path with no encoding, parameters, backslashes, empty or dot segments. */
  static boolean isCanonical(String raw) {
    if (raw == null || raw.isEmpty()) {
      return true;
    }
    if (raw.indexOf('%') >= 0 || raw.indexOf(';') >= 0 || raw.indexOf('\\') >= 0 || raw.contains("//")) {
      return false;
    }
    for (String segment : raw.split("/", -1)) {
      if (segment.equals(".") || segment.equals("..")) {
        return false;
      }
    }
    return true;
  }

  /** Runs before {@link RateLimitFilter}, which sits one step behind. */
  @Override
  public int getOrder() {
    return Ordered.HIGHEST_PRECEDENCE;
  }
}
