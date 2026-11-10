package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AuthTest extends IntegrationTest {

  @Test
  void registerCreatesUserSettingsAndTokens() throws Exception {
    var result = post("/api/v1/auth/register", null,
            Map.of("fullName", "  Ada Lovelace ", "email", "  Ada@Example.COM ", "password", PASSWORD))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.user.email").value("ada@example.com"))
        .andExpect(jsonPath("$.user.fullName").value("Ada Lovelace"))
        .andExpect(jsonPath("$.user.avatarUrl").doesNotExist())
        .andExpect(jsonPath("$.user.emailVerified").value(false));
    JsonNode auth = body(result);
    assertThat(auth.get("accessToken").asText()).isNotBlank();
    assertThat(auth.get("refreshToken").asText()).isNotBlank();
    assertThat(auth.get("user").get("id").isNumber()).isTrue();

    String offsets = jdbc.queryForObject("SELECT default_reminder_offsets FROM user_settings", String.class);
    Integer days = jdbc.queryForObject("SELECT default_followup_days FROM user_settings", Integer.class);
    assertThat(offsets.replaceAll("\\s", "")).isEqualTo("[1440,60]");
    assertThat(days).isEqualTo(7);
  }

  @Test
  void registerRejectsDuplicateEmailCaseInsensitively() throws Exception {
    register("dup@example.com");
    post("/api/v1/auth/register", null,
            Map.of("fullName", "Other", "email", "DUP@example.com", "password", PASSWORD))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.error.code").value("EMAIL_TAKEN"))
        .andExpect(jsonPath("$.error.fields.email").exists());
  }

  @Test
  void registerValidatesFieldsAndPasswordRules() throws Exception {
    post("/api/v1/auth/register", null, Map.of("fullName", "", "email", "nope", "password", "short"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.fields.fullName").value("This field is required"))
        .andExpect(jsonPath("$.error.fields.email").value("Enter a valid email address"))
        .andExpect(jsonPath("$.error.fields.password").value("Password must be at least 8 characters"));
    post("/api/v1/auth/register", null, Map.of("fullName", "A", "email", "a@b.co", "password", "NoDigits!!"))
        .andExpect(jsonPath("$.error.fields.password").value("Password must contain a digit"));
    post("/api/v1/auth/register", null, Map.of("fullName", "A", "email", "a@b.co", "password", "NoSymbol123"))
        .andExpect(jsonPath("$.error.fields.password").value("Password must contain a symbol"));
  }

  @Test
  void malformedJsonIsAValidationError() throws Exception {
    mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post("/api/v1/auth/login")
            .contentType("application/json").content("{not json"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.message").value("Invalid JSON body"));
  }

  @Test
  void loginWorksAndDoesNotRevealWhichPartWasWrong() throws Exception {
    register("login@example.com");
    post("/api/v1/auth/login", null, Map.of("email", "LOGIN@example.com", "password", PASSWORD))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.user.email").value("login@example.com"))
        .andExpect(jsonPath("$.accessToken").isNotEmpty());

    var wrongPassword = post("/api/v1/auth/login", null, Map.of("email", "login@example.com", "password", "wrong"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    var unknownEmail = post("/api/v1/auth/login", null, Map.of("email", "ghost@example.com", "password", PASSWORD))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    assertThat(body(wrongPassword)).isEqualTo(body(unknownEmail));
  }

  @Test
  void refreshRotatesTokensAndReuseRevokesEverything() throws Exception {
    JsonNode auth = register("refresh@example.com");
    String first = auth.get("refreshToken").asText();

    JsonNode second = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.accessToken").isNotEmpty()));
    String secondToken = second.get("refreshToken").asText();
    assertThat(secondToken).isNotEqualTo(first);
    // The client really received the second token: it uses it.
    String thirdToken = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", secondToken))
        .andExpect(status().isOk())).get("refreshToken").asText();

    // Replaying a rotated-out token whose replacement was used is theft: the live token dies too.
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", thirdToken))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void aLostRefreshResponseCanBeRetriedBriefly() throws Exception {
    String first = register("lost@example.com").get("refreshToken").asText();
    // The server rotates, but the response never reaches the phone.
    String lost = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isOk())).get("refreshToken").asText();

    // The phone retries with the token it still has: it gets a fresh pair, the lost one is retired.
    String retried = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isOk())).get("refreshToken").asText();
    assertThat(retried).isNotEqualTo(lost);
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", retried)).andExpect(status().isOk());
    // The retired token was never delivered; if it shows up later, that is theft.
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", lost)).andExpect(status().isUnauthorized());
  }

  @Test
  void theGraceForRetriesEndsAfterThirtySeconds() throws Exception {
    String first = register("late@example.com").get("refreshToken").asText();
    String second = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isOk())).get("refreshToken").asText();
    jdbc.update("UPDATE refresh_tokens SET rotated_at = rotated_at - INTERVAL 31 SECOND WHERE rotated_at IS NOT NULL");

    post("/api/v1/auth/refresh", null, Map.of("refreshToken", first)).andExpect(status().isUnauthorized());
    // Treated as theft: every session ends.
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", second)).andExpect(status().isUnauthorized());
  }

  @Test
  void aPasswordChangeEndsTheGraceOfTheTokenItKept() throws Exception {
    JsonNode auth = register("change@example.com");
    String first = auth.get("refreshToken").asText();
    JsonNode rotated = body(post("/api/v1/auth/refresh", null, Map.of("refreshToken", first))
        .andExpect(status().isOk()));
    String second = rotated.get("refreshToken").asText();

    // Within the 30 s grace, an older token could still trade itself in and retire the kept one.
    post("/api/v1/auth/change-password", rotated.get("accessToken").asText(),
        Map.of("currentPassword", PASSWORD, "newPassword", "N3w-Passw0rd!", "refreshToken", second))
        .andExpect(status().isNoContent());

    post("/api/v1/auth/refresh", null, Map.of("refreshToken", first)).andExpect(status().isUnauthorized());
  }

  @Test
  void aLoggedOutTokenGetsNoGrace() throws Exception {
    String token = register("out@example.com").get("refreshToken").asText();
    post("/api/v1/auth/logout", null, Map.of("refreshToken", token)).andExpect(status().isNoContent());
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", token)).andExpect(status().isUnauthorized());
  }

  @Test
  void refreshRejectsUnknownAndExpiredTokens() throws Exception {
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", "does-not-exist"))
        .andExpect(status().isUnauthorized());

    JsonNode auth = register("expired@example.com");
    jdbc.update("UPDATE refresh_tokens SET expires_at = '2000-01-01 00:00:00'");
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", auth.get("refreshToken").asText()))
        .andExpect(status().isUnauthorized());
  }

  @Test
  void logoutRevokesTheRefreshToken() throws Exception {
    JsonNode auth = register("logout@example.com");
    String token = auth.get("refreshToken").asText();
    post("/api/v1/auth/logout", null, Map.of("refreshToken", token)).andExpect(status().isNoContent());
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", token)).andExpect(status().isUnauthorized());
  }

  @Test
  void forgotPasswordAlwaysAnswersNoContent() throws Exception {
    register("known@example.com");
    post("/api/v1/auth/forgot-password", null, Map.of("email", "known@example.com"))
        .andExpect(status().isNoContent());
    post("/api/v1/auth/forgot-password", null, Map.of("email", "unknown@example.com"))
        .andExpect(status().isNoContent());
  }

  @Test
  void changePasswordKeepsOnlyTheCurrentSession() throws Exception {
    JsonNode a = register("change@example.com");
    JsonNode b = body(post("/api/v1/auth/login", null, Map.of("email", "change@example.com", "password", PASSWORD)));
    String access = a.get("accessToken").asText();

    post("/api/v1/auth/change-password", access,
            Map.of("currentPassword", "wrong", "newPassword", "N3wPassword!"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"))
        .andExpect(jsonPath("$.error.fields.currentPassword").exists());

    post("/api/v1/auth/change-password", access,
            Map.of("currentPassword", PASSWORD, "newPassword", "weak"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.newPassword").exists());

    post("/api/v1/auth/change-password", access,
            Map.of("currentPassword", PASSWORD, "newPassword", "N3wPassword!",
                "refreshToken", a.get("refreshToken").asText()))
        .andExpect(status().isNoContent());

    post("/api/v1/auth/refresh", null, Map.of("refreshToken", b.get("refreshToken").asText()))
        .andExpect(status().isUnauthorized());
    post("/api/v1/auth/login", null, Map.of("email", "change@example.com", "password", PASSWORD))
        .andExpect(status().isUnauthorized());
    post("/api/v1/auth/login", null, Map.of("email", "change@example.com", "password", "N3wPassword!"))
        .andExpect(status().isOk());
  }

  @Test
  void changePasswordWithoutRefreshTokenRevokesAllSessions() throws Exception {
    JsonNode a = register("all@example.com");
    post("/api/v1/auth/change-password", a.get("accessToken").asText(),
            Map.of("currentPassword", PASSWORD, "newPassword", "N3wPassword!"))
        .andExpect(status().isNoContent());
    post("/api/v1/auth/refresh", null, Map.of("refreshToken", a.get("refreshToken").asText()))
        .andExpect(status().isUnauthorized());
  }
}
