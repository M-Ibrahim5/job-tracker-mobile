package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Fingerprint login: device tokens (docs/API.md → Auth). */
class DeviceTokenTest extends IntegrationTest {

  private String enrol(String access) throws Exception {
    JsonNode res = body(post("/api/v1/auth/device-token", access,
            Map.of("password", PASSWORD, "deviceName", "Pixel"))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.deviceToken").isNotEmpty()));
    return res.get("deviceToken").asText();
  }

  @Test
  void deviceTokenSignsInAndOnlyItsHashIsStored() throws Exception {
    JsonNode auth = register("device@example.com");
    String token = enrol(auth.get("accessToken").asText());

    post("/api/v1/auth/device-login", null, Map.of("deviceToken", token))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.accessToken").isNotEmpty())
        .andExpect(jsonPath("$.refreshToken").isNotEmpty())
        .andExpect(jsonPath("$.user.email").value("device@example.com"));

    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens WHERE token_hash = ?", Integer.class, token))
        .isZero();
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens WHERE last_used_at IS NOT NULL",
        Integer.class)).isEqualTo(1);
  }

  @Test
  void enrollingNeedsTheRightPasswordAndASession() throws Exception {
    JsonNode auth = register("pw@example.com");
    post("/api/v1/auth/device-token", auth.get("accessToken").asText(), Map.of("password", "wrong-Pass1!"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    post("/api/v1/auth/device-token", null, Map.of("password", PASSWORD))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void unknownAndRevokedTokensAreRejected() throws Exception {
    post("/api/v1/auth/device-login", null, Map.of("deviceToken", "nope"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

    JsonNode auth = register("revoke@example.com");
    String access = auth.get("accessToken").asText();
    String token = enrol(access);
    delete("/api/v1/auth/device-token", access, Map.of("deviceToken", token)).andExpect(status().isNoContent());
    post("/api/v1/auth/device-login", null, Map.of("deviceToken", token)).andExpect(status().isUnauthorized());
  }

  @Test
  void expiredTokensAreRejected() throws Exception {
    JsonNode auth = register("old@example.com");
    String token = enrol(auth.get("accessToken").asText());
    jdbc.update("UPDATE device_tokens SET expires_at = '2000-01-01 00:00:00'");
    post("/api/v1/auth/device-login", null, Map.of("deviceToken", token)).andExpect(status().isUnauthorized());
  }

  @Test
  void changingThePasswordRevokesDeviceTokens() throws Exception {
    JsonNode auth = register("pwchange@example.com");
    String access = auth.get("accessToken").asText();
    String token = enrol(access);

    post("/api/v1/auth/change-password", access,
            Map.of("currentPassword", PASSWORD, "newPassword", "N3wPassword!",
                "refreshToken", auth.get("refreshToken").asText()))
        .andExpect(status().isNoContent());
    post("/api/v1/auth/device-login", null, Map.of("deviceToken", token)).andExpect(status().isUnauthorized());

    // The phone re-enrols with the new password.
    post("/api/v1/auth/device-token", access, Map.of("password", "N3wPassword!"))
        .andExpect(status().isCreated());
  }

  @Test
  void atMostFiveLiveTokensPerUser() throws Exception {
    JsonNode auth = register("many@example.com");
    String access = auth.get("accessToken").asText();
    String first = enrol(access);
    for (int i = 0; i < 5; i++) {
      enrol(access);
    }
    post("/api/v1/auth/device-login", null, Map.of("deviceToken", first)).andExpect(status().isUnauthorized());
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens WHERE revoked_at IS NULL", Integer.class))
        .isEqualTo(5);
  }

  @Test
  void deletingTheAccountRemovesDeviceTokens() throws Exception {
    JsonNode auth = register("gone@example.com");
    String access = auth.get("accessToken").asText();
    enrol(access);
    delete("/api/v1/me", access, Map.of("password", PASSWORD)).andExpect(status().isNoContent());
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM device_tokens", Integer.class)).isZero();
  }
}
