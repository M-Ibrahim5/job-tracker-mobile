package com.jobtrail.gateway;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;

/** A tiny downstream service that echoes what the gateway forwarded to it. */
final class StubService {

  private final HttpServer server;
  private final String name;
  /** How many health probes reached this stub. */
  final java.util.concurrent.atomic.AtomicInteger healthCalls = new java.util.concurrent.atomic.AtomicInteger();

  StubService(String name) {
    this.name = name;
    try {
      server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
    } catch (IOException e) {
      throw new IllegalStateException(e);
    }
    server.createContext("/", exchange -> {
      String path = exchange.getRequestURI().getPath();
      if (path.equals("/api/v1/health")) {
        healthCalls.incrementAndGet();
      }
      String body = path.equals("/api/v1/health")
          ? "{\"status\":\"ok\"}"
          : "{\"service\":\"" + name + "\",\"method\":\"" + exchange.getRequestMethod()
              + "\",\"uri\":\"" + exchange.getRequestURI() + "\",\"timezone\":\""
              + header(exchange.getRequestHeaders().getFirst("X-Timezone")) + "\",\"authorization\":\""
              + header(exchange.getRequestHeaders().getFirst("Authorization")) + "\"}";
      byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
      exchange.getResponseHeaders().add("Content-Type", "application/json");
      exchange.sendResponseHeaders(200, bytes.length);
      try (OutputStream out = exchange.getResponseBody()) {
        out.write(bytes);
      }
    });
    server.start();
  }

  private static String header(String value) {
    return value == null ? "" : value;
  }

  String url() {
    return "http://127.0.0.1:" + server.getAddress().getPort();
  }

  String name() {
    return name;
  }

  void stop() {
    server.stop(0);
  }
}
