package com.jobtrail.gateway;

import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
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

  /** The longest text form of an IPv6 address. */
  private static final int MAX_ADDRESS_CHARS = 45;
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
    InetSocketAddress remote = exchange.getRequest().getRemoteAddress();
    InetAddress peer = remote == null ? null : remote.getAddress();
    String peerText = peer == null ? "unknown" : peer.getHostAddress();
    if (!props.trustForwardedFor() || peer == null || !isTrustedProxy(peer.getHostAddress())) {
      return peerText;
    }
    String forwarded = exchange.getRequest().getHeaders().getFirst("X-Forwarded-For");
    if (forwarded == null || forwarded.isBlank()) {
      return peerText;
    }
    // Each proxy appends the address it saw, so only entries from the right are trustworthy:
    // walk left past our own proxies; the first other address is the client.
    String[] entries = forwarded.split(",");
    for (int i = entries.length - 1; i >= 0; i--) {
      String entry = entries[i].trim();
      if (entry.isEmpty() || entry.length() > MAX_ADDRESS_CHARS) {
        return peerText;
      }
      if (!isTrustedProxy(entry)) {
        return entry;
      }
    }
    return peerText;
  }

  /** Compares as addresses, so {@code ::1} and {@code 0:0:0:0:0:0:0:1} are the same proxy. */
  private boolean isTrustedProxy(String address) {
    InetAddress candidate = literal(address);
    if (candidate == null) {
      return false;
    }
    for (String trusted : props.trustedProxies()) {
      if (candidate.equals(literal(trusted.trim()))) {
        return true;
      }
    }
    return false;
  }

  /** Parses an IP literal without any DNS lookup; null when [text] is not one. */
  private static InetAddress literal(String text) {
    boolean ipv4 = text.matches("[0-9]{1,3}(\\.[0-9]{1,3}){3}");
    boolean ipv6 = text.indexOf(':') >= 0 && text.matches("[0-9a-fA-F:.]+");
    if (!ipv4 && !ipv6) {
      return null;
    }
    try {
      return InetAddress.getByName(text);
    } catch (UnknownHostException e) {
      return null;
    }
  }

  @Override
  public int getOrder() {
    // One step behind CanonicalPathFilter, so only canonical paths are classified here.
    return Ordered.HIGHEST_PRECEDENCE + 1;
  }
}
