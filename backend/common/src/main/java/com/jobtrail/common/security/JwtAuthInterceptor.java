package com.jobtrail.common.security;

import com.jobtrail.common.error.AppException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.servlet.HandlerInterceptor;

/** Requires {@code Authorization: Bearer <jwt>} and exposes the user id to {@link CurrentUser}. */
public class JwtAuthInterceptor implements HandlerInterceptor {

  static final String USER_ID_ATTRIBUTE = "jobtrail.userId";
  private static final String PREFIX = "Bearer ";

  private final JwtService jwt;

  public JwtAuthInterceptor(JwtService jwt) {
    this.jwt = jwt;
  }

  @Override
  public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
    if ("OPTIONS".equals(request.getMethod())) {
      return true;
    }
    String header = request.getHeader("Authorization");
    if (header == null || !header.startsWith(PREFIX)) {
      throw AppException.unauthorized();
    }
    request.setAttribute(USER_ID_ATTRIBUTE, jwt.verify(header.substring(PREFIX.length())));
    return true;
  }
}
