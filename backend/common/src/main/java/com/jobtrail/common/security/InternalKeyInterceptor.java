package com.jobtrail.common.security;

import com.jobtrail.common.error.AppException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import org.springframework.web.servlet.HandlerInterceptor;

/** Guards {@code /internal/**}: only callers that know the shared key (other services) get in. */
public class InternalKeyInterceptor implements HandlerInterceptor {

  public static final String HEADER = "X-Internal-Key";

  private final byte[] expected;

  public InternalKeyInterceptor(String key) {
    this.expected = key == null ? new byte[0] : key.getBytes(StandardCharsets.UTF_8);
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    String given = request.getHeader(HEADER);
    boolean ok =
        expected.length > 0
            && given != null
            && MessageDigest.isEqual(expected, given.getBytes(StandardCharsets.UTF_8));
    if (!ok) {
      throw AppException.unauthorized();
    }
    return true;
  }
}
