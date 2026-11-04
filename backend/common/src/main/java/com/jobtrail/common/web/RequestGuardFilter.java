package com.jobtrail.common.web;

import com.jobtrail.common.error.ApiError;
import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ReadListener;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletInputStream;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.unit.DataSize;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Applied to every request a service handles:
 *
 * <ul>
 *   <li>Caps non-multipart request bodies (JSON) at {@code jobtrail.max-body-size}: a declared
 *       {@code Content-Length} over the cap gets 413 straight away, and a streamed (chunked) body
 *       stops being read once it passes the cap. Without this, a huge body is parsed into memory
 *       before validation can reject it. Multipart uploads have their own limits.
 *   <li>Sets {@code X-Content-Type-Options: nosniff} so browsers never reinterpret a response, for
 *       example an uploaded avatar, as another content type.
 * </ul>
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class RequestGuardFilter extends OncePerRequestFilter {

  private final long maxBytes;
  private final ObjectMapper json;

  public RequestGuardFilter(@Value("${jobtrail.max-body-size:1MB}") DataSize maxBodySize, ObjectMapper json) {
    this.maxBytes = maxBodySize.toBytes();
    this.json = json;
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    response.setHeader("X-Content-Type-Options", "nosniff");
    String type = request.getContentType();
    boolean multipart = type != null && type.toLowerCase().startsWith("multipart/");
    if (multipart) {
      chain.doFilter(request, response);
      return;
    }
    if (request.getContentLengthLong() > maxBytes) {
      response.setStatus(HttpServletResponse.SC_REQUEST_ENTITY_TOO_LARGE);
      response.setContentType(MediaType.APPLICATION_JSON_VALUE);
      json.writeValue(response.getOutputStream(), ApiError.of("PAYLOAD_TOO_LARGE", "Request body too large"));
      return;
    }
    chain.doFilter(new LimitedRequest(request, maxBytes), response);
  }

  /** Thrown when a streamed body passes the cap; Jackson surfaces it as an unreadable body. */
  public static final class BodyTooLargeException extends IOException {
    BodyTooLargeException() {
      super("Request body too large");
    }
  }

  private static final class LimitedRequest extends HttpServletRequestWrapper {

    private final long maxBytes;
    private ServletInputStream stream;

    LimitedRequest(HttpServletRequest request, long maxBytes) {
      super(request);
      this.maxBytes = maxBytes;
    }

    @Override
    public ServletInputStream getInputStream() throws IOException {
      if (stream == null) {
        stream = new LimitedStream(super.getInputStream(), maxBytes);
      }
      return stream;
    }
  }

  private static final class LimitedStream extends ServletInputStream {

    private final ServletInputStream in;
    private final long maxBytes;
    private long read;

    LimitedStream(ServletInputStream in, long maxBytes) {
      this.in = in;
      this.maxBytes = maxBytes;
    }

    private int count(int n) throws IOException {
      if (n > 0) {
        read += n;
        if (read > maxBytes) {
          throw new BodyTooLargeException();
        }
      }
      return n;
    }

    @Override
    public int read() throws IOException {
      int b = in.read();
      if (b >= 0) {
        count(1);
      }
      return b;
    }

    @Override
    public int read(byte[] b, int off, int len) throws IOException {
      return count(in.read(b, off, len));
    }

    @Override
    public boolean isFinished() {
      return in.isFinished();
    }

    @Override
    public boolean isReady() {
      return in.isReady();
    }

    @Override
    public void setReadListener(ReadListener listener) {
      in.setReadListener(listener);
    }
  }
}
