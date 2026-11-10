package com.jobtrail.gateway;

import java.net.InetSocketAddress;
import java.util.Set;
import org.springframework.cloud.gateway.filter.GatewayFilterChain;
import org.springframework.cloud.gateway.filter.GlobalFilter;
import org.springframework.core.Ordered;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ServerWebExchange;
import reactor.core.publisher.Mono;

/**
 * Rate limits from docs/API.md, see {@link GatewayProperties}. Signed-in traffic is counted per
 * user so people sharing one public IP (carrier NAT, offices) do not use up each other's budget;
 * the password endpoints stay strictly limited per IP. Health checks are exempt.
 */
@Component
public class RateLimitFilter implements GlobalFilter, Ordered {

  private static final String API = "/api/v1/";
  private static final String AUTH = API + "auth/";
  private static final String HEALTH = "/api/v1/health";
  /**
   * Endpoints that take a long random token rather than a password. ({@code POST /auth/device-token}
   * checks the password, so it stays in the strict group.)
   */
  private static final Set<String> TOKEN_PATHS = Set.of(AUTH + "refresh", AUTH + "device-login", AUTH + "logout");

  private final GatewayProperties props;
  private final AccessTokenReader tokens;
  private final RateLimitStore store;

  public RateLimitFilter(GatewayProperties props, AccessTokenReader tokens, RateLimitStore store) {
    this.props = props;
    this.tokens = tokens;
    this.store = store;
  }

  @Override
  public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
    String path = exchange.getRequest().getPath().value();
    if (!path.startsWith(API) || path.equals(HEALTH)) {
      return chain.filter(exchange);
    }
    String ip = clientAddress(exchange);
    String apiKey = tokens.userId(exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION))
        .map(id -> "user:" + id)
        .orElse("ip:" + ip);
    return store.tryAcquire("api", apiKey, props.apiLimit())
        .flatMap(api -> {
          if (!api.allowed() || !path.startsWith(AUTH)) {
            return Mono.just(api);
          }
          return TOKEN_PATHS.contains(path)
              ? store.tryAcquire("token", ip, props.tokenLimit())
              : store.tryAcquire("auth", ip, props.authLimit());
        })
        .flatMap(result -> {
          if (result.allowed()) {
            return chain.filter(exchange);
          }
          exchange.getResponse().getHeaders().set("Retry-After", Long.toString(result.retryAfterSeconds()));
          return ApiErrors.write(exchange, HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED",
              "Too many requests, try again later");
        });
  }

  private String clientAddress(ServerWebExchange exchange) {
    if (props.trustForwardedFor()) {
      String forwarded = exchange.getRequest().getHeaders().getFirst("X-Forwarded-For");
      if (forwarded != null && !forwarded.isBlank()) {
        return forwarded.split(",")[0].trim();
      }
    }
    InetSocketAddress remote = exchange.getRequest().getRemoteAddress();
    return remote == null || remote.getAddress() == null ? "unknown" : remote.getAddress().getHostAddress();
  }

  @Override
  public int getOrder() {
    // One step behind CanonicalPathFilter, so only canonical paths are classified here.
    return Ordered.HIGHEST_PRECEDENCE + 1;
  }
}
