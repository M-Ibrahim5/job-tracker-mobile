package com.jobtrail.user.auth;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.validation.JsonBody;
import java.util.Map;
import java.util.regex.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

  private static final Pattern DIGIT = Pattern.compile("\\d");
  private static final Pattern SYMBOL = Pattern.compile("[^A-Za-z0-9]");

  private final AuthService auth;

  public AuthController(AuthService auth) {
    this.auth = auth;
  }

  /** ≥ 8 chars, a digit and a symbol (docs/API.md). Reports the first rule that fails. */
  static String passwordRules(JsonBody body, String field) {
    String password = body.requiredRaw(field, 128);
    if (password == null) {
      return null;
    }
    String problem = null;
    if (password.length() < 8) {
      problem = "Password must be at least 8 characters";
    } else if (!DIGIT.matcher(password).find()) {
      problem = "Password must contain a digit";
    } else if (!SYMBOL.matcher(password).find()) {
      problem = "Password must contain a symbol";
    }
    if (problem != null) {
      body.validator().error(field, problem);
      return null;
    }
    return password;
  }

  @PostMapping("/register")
  @ResponseStatus(HttpStatus.CREATED)
  AuthResponse register(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String fullName = body.requiredText("fullName", 100);
    String email = body.requiredEmail("email");
    String password = passwordRules(body, "password");
    body.finish();
    return auth.register(fullName, email, password);
  }

  @PostMapping("/login")
  AuthResponse login(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String email = body.requiredText("email", 254);
    String password = body.requiredRaw("password", 128);
    body.finish();
    return auth.login(email.toLowerCase(java.util.Locale.ROOT), password);
  }

  @PostMapping("/refresh")
  AuthResponse.Refreshed refresh(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String token = body.requiredRaw("refreshToken", 512);
    body.finish();
    return auth.refresh(token);
  }

  @PostMapping("/device-token")
  @ResponseStatus(HttpStatus.CREATED)
  Map<String, String> createDeviceToken(@CurrentUser long userId, @RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String password = body.requiredRaw("password", 128);
    String deviceName = body.optionalText("deviceName", 100);
    body.finish();
    return Map.of("deviceToken", auth.createDeviceToken(userId, password, deviceName));
  }

  @PostMapping("/device-login")
  AuthResponse deviceLogin(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String token = body.requiredRaw("deviceToken", 512);
    body.finish();
    return auth.deviceLogin(token);
  }

  @DeleteMapping("/device-token")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void revokeDeviceToken(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String token = body.requiredRaw("deviceToken", 512);
    body.finish();
    auth.revokeDeviceToken(token);
  }

  @PostMapping("/logout")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void logout(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String token = body.requiredRaw("refreshToken", 512);
    body.finish();
    auth.logout(token);
  }

  @PostMapping("/forgot-password")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void forgotPassword(@RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String email = body.requiredText("email", 254);
    body.finish();
    auth.forgotPassword(email.toLowerCase(java.util.Locale.ROOT));
  }

  @PostMapping("/change-password")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void changePassword(@CurrentUser long userId, @RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String current = body.requiredRaw("currentPassword", 128);
    String next = passwordRules(body, "newPassword");
    String refreshToken = body.optionalRaw("refreshToken");
    body.finish();
    auth.changePassword(userId, current, next, refreshToken);
  }
}
