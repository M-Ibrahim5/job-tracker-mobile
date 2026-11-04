package com.jobtrail.common.security;

import com.jobtrail.common.error.AppException;
import java.util.List;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.MethodParameter;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Wires JWT auth for {@code /api/v1/**}, the internal key for {@code /internal/**}, {@link CurrentUser}. */
@Configuration
@EnableConfigurationProperties({JwtProperties.class, InternalProperties.class})
public class CommonWebConfig implements WebMvcConfigurer {

  /** Endpoints that work without a bearer token. */
  private static final List<String> PUBLIC = List.of(
      "/api/v1/health",
      "/api/v1/auth/register",
      "/api/v1/auth/login",
      "/api/v1/auth/refresh",
      "/api/v1/auth/logout",
      "/api/v1/auth/device-login",
      "/api/v1/auth/forgot-password");

  private final JwtService jwt;
  private final InternalProperties internal;

  public CommonWebConfig(JwtService jwt, InternalProperties internal) {
    this.jwt = jwt;
    this.internal = internal;
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(new JwtAuthInterceptor(jwt))
        .addPathPatterns("/api/v1/**")
        .excludePathPatterns(PUBLIC);
    registry.addInterceptor(new InternalKeyInterceptor(internal.key()))
        .addPathPatterns("/internal/**");
  }

  @Override
  public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
    resolvers.add(new HandlerMethodArgumentResolver() {
      @Override
      public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentUser.class);
      }

      @Override
      public Object resolveArgument(MethodParameter parameter, ModelAndViewContainer mav,
          NativeWebRequest request, WebDataBinderFactory binder) {
        Object id = request.getAttribute(JwtAuthInterceptor.USER_ID_ATTRIBUTE, RequestAttributes.SCOPE_REQUEST);
        if (id == null) {
          throw AppException.unauthorized();
        }
        return id;
      }
    });
  }
}
