package com.jobtrail.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.security.JwtProperties;
import com.jobtrail.common.security.JwtService;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.Duration;
import javax.imageio.ImageIO;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

class MeTest extends IntegrationTest {

  @Value("${jobtrail.jwt.secret}") String secret;
  @Autowired JwtService jwt;

  private String token(String email) throws Exception {
    return register(email).get("accessToken").asText();
  }

  private static byte[] image(int width, int height, String format) throws IOException {
    BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(img, format, out);
    return out.toByteArray();
  }

  /** The served avatar's bytes, fetched the way a client does. */
  private byte[] served(String avatarUrl) throws Exception {
    return mvc.perform(MockMvcRequestBuilders.get(avatarUrl.substring("http://localhost:3000".length())))
        .andExpect(status().isOk())
        .andReturn().getResponse().getContentAsByteArray();
  }

  @Test
  void authIsRequired() throws Exception {
    get("/api/v1/me", null)
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"))
        .andExpect(jsonPath("$.error.message").isNotEmpty());
    get("/api/v1/me", "garbage").andExpect(status().isUnauthorized());
    get("/api/v1/me/settings", null).andExpect(status().isUnauthorized());
  }

  @Test
  void expiredAccessTokenSaysTokenExpired() throws Exception {
    JsonNode auth = register("exp@example.com");
    long id = auth.get("user").get("id").asLong();
    String expired = new JwtService(new JwtProperties(secret, Duration.ofSeconds(-30))).sign(id);
    get("/api/v1/me", expired)
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("TOKEN_EXPIRED"));
  }

  @Test
  void tokenSignedWithAnotherSecretIsRejected() throws Exception {
    String forged = new JwtService(new JwtProperties("another-secret-another-secret-12345", Duration.ofMinutes(5))).sign(1);
    get("/api/v1/me", forged)
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
  }

  @Test
  void getAndPatchProfileButNeverTheEmail() throws Exception {
    String token = token("me@example.com");
    get("/api/v1/me", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.email").value("me@example.com"))
        .andExpect(jsonPath("$.currentRole").doesNotExist());

    patch("/api/v1/me", token, Map.of(
            "fullName", "New Name", "phone", " 012 ", "currentRole", "Engineer",
            "lookingFor", "Staff role", "location", "KL", "email", "hacker@example.com"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.email").value("me@example.com"))
        .andExpect(jsonPath("$.fullName").value("New Name"))
        .andExpect(jsonPath("$.phone").value("012"))
        .andExpect(jsonPath("$.currentRole").value("Engineer"))
        .andExpect(jsonPath("$.lookingFor").value("Staff role"))
        .andExpect(jsonPath("$.location").value("KL"));

    // An empty string clears an optional field; omitted fields stay untouched.
    patch("/api/v1/me", token, Map.of("phone", ""))
        .andExpect(jsonPath("$.phone").doesNotExist())
        .andExpect(jsonPath("$.fullName").value("New Name"));
  }

  @Test
  void patchValidatesFields() throws Exception {
    String token = token("val@example.com");
    patch("/api/v1/me", token, Map.of("fullName", "  "))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.fields.fullName").value("This field is required"));
    patch("/api/v1/me", token, Map.of("location", "x".repeat(101)))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.location").exists());
  }

  @Test
  void settingsDefaultsAndPartialUpdate() throws Exception {
    String token = token("settings@example.com");
    get("/api/v1/me/settings", token)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.theme").value("system"))
        .andExpect(jsonPath("$.interviewRemindersEnabled").value(true))
        .andExpect(jsonPath("$.followUpRemindersEnabled").value(true))
        .andExpect(jsonPath("$.statusAlertsEnabled").value(true))
        .andExpect(jsonPath("$.defaultReminderOffsetsMinutes[0]").value(1440))
        .andExpect(jsonPath("$.defaultReminderOffsetsMinutes[1]").value(60))
        .andExpect(jsonPath("$.defaultFollowUpDays").value(7));

    // Regression: a patch without offsets must not wipe the defaults.
    patch("/api/v1/me/settings", token, Map.of("theme", "dark", "statusAlertsEnabled", false))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.theme").value("dark"))
        .andExpect(jsonPath("$.statusAlertsEnabled").value(false))
        .andExpect(jsonPath("$.defaultReminderOffsetsMinutes.length()").value(2));

    patch("/api/v1/me/settings", token, Map.of("defaultReminderOffsetsMinutes", List.of(30, 30, 10)))
        .andExpect(jsonPath("$.defaultReminderOffsetsMinutes.length()").value(2));

    // null switches the default follow-up off.
    patch("/api/v1/me/settings", token, java.util.Collections.singletonMap("defaultFollowUpDays", null))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.defaultFollowUpDays").doesNotExist());
    patch("/api/v1/me/settings", token, Map.of("defaultFollowUpDays", 14))
        .andExpect(jsonPath("$.defaultFollowUpDays").value(14));
  }

  @Test
  void settingsValidation() throws Exception {
    String token = token("settings-bad@example.com");
    patch("/api/v1/me/settings", token, Map.of("defaultFollowUpDays", 4))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.defaultFollowUpDays").exists());
    patch("/api/v1/me/settings", token, Map.of("theme", "neon"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.theme").exists());
    patch("/api/v1/me/settings", token, Map.of("defaultReminderOffsetsMinutes", List.of(1, 2, 3, 4, 5, 6)))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.fields.defaultReminderOffsetsMinutes").value("At most 5 reminders"));
    patch("/api/v1/me/settings", token, Map.of("defaultReminderOffsetsMinutes", List.of(0)))
        .andExpect(status().isBadRequest());
    patch("/api/v1/me/settings", token, Map.of("defaultReminderOffsetsMinutes", List.of(43201)))
        .andExpect(status().isBadRequest());
    patch("/api/v1/me/settings", token, Map.of("statusAlertsEnabled", "yes"))
        .andExpect(status().isBadRequest());
  }

  @Test
  void avatarUploadAcceptsPngAndServesIt() throws Exception {
    JsonNode auth = register("avatar@example.com");
    String token = auth.get("accessToken").asText();
    byte[] png = image(64, 48, "png");
    var result = mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "me.png", "image/png", png))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.avatarUrl").isNotEmpty());
    String url = body(result).get("avatarUrl").asText();
    assertThat(url).startsWith("http://localhost:3000/uploads/avatars/" + auth.get("user").get("id").asLong() + "-");

    mvc.perform(MockMvcRequestBuilders.get(url.substring("http://localhost:3000".length())))
        .andExpect(status().isOk());

    // Replacing the avatar issues a new unguessable URL.
    var again = mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "me.jpg", "image/jpeg", image(32, 32, "jpeg")))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk());
    assertThat(body(again).get("avatarUrl").asText()).isNotEqualTo(url).endsWith(".jpg");
  }

  @Test
  void avatarRejectsOtherFileTypesAndFakeImages() throws Exception {
    String token = token("badavatar@example.com");
    mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "x.gif", "image/gif", new byte[] {1, 2, 3}))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.error.fields.file").exists());
    mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "x.png", "image/png", "<script>".getBytes()))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isBadRequest());
    mvc.perform(multipart("/api/v1/me/avatar").header("Authorization", "Bearer " + token))
        .andExpect(status().isBadRequest());
    // Right magic bytes but not a decodable image.
    mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "x.png", "image/png",
                new byte[] {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3}))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isBadRequest());
  }

  @Test
  void avatarIsReencodedScaledAndStrippedOfAppendedData() throws Exception {
    String token = token("clean@example.com");
    byte[] original = image(2000, 1000, "png");
    // Data hidden after the image (as in a polyglot file) must not be stored.
    byte[] tampered = new byte[original.length + 16];
    System.arraycopy(original, 0, tampered, 0, original.length);
    System.arraycopy("<script>x</script>".getBytes(), 0, tampered, original.length, 16);

    var result = mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "big.png", "image/png", tampered))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk());
    String url = body(result).get("avatarUrl").asText();
    byte[] bytes = served(url);
    BufferedImage saved = ImageIO.read(new java.io.ByteArrayInputStream(bytes));
    assertThat(saved.getWidth()).isEqualTo(512);
    assertThat(saved.getHeight()).isEqualTo(256);
    assertThat(new String(bytes)).doesNotContain("<script>");
    // Stored in the database, so every user-service instance can serve it.
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_avatars", Integer.class)).isEqualTo(1);

    // Served with nosniff so browsers never treat it as anything but an image.
    mvc.perform(MockMvcRequestBuilders.get(url.substring("http://localhost:3000".length())))
        .andExpect(status().isOk())
        .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.header()
            .string("X-Content-Type-Options", "nosniff"));
  }

  @Test
  void replacingTheAvatarRemovesTheOldOneAndUnknownNamesAre404() throws Exception {
    String token = token("swap@example.com");
    String first = body(mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "a.png", "image/png", image(10, 10, "png")))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk())).get("avatarUrl").asText();
    mvc.perform(multipart("/api/v1/me/avatar")
            .file(new MockMultipartFile("file", "b.png", "image/png", image(10, 10, "png")))
            .header("Authorization", "Bearer " + token))
        .andExpect(status().isOk());

    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_avatars", Integer.class)).isEqualTo(1);
    mvc.perform(MockMvcRequestBuilders.get(first.substring("http://localhost:3000".length())))
        .andExpect(status().isNotFound());
    mvc.perform(MockMvcRequestBuilders.get("/uploads/avatars/..%2f..%2fetc%2fpasswd"))
        .andExpect(status().isNotFound());
    mvc.perform(MockMvcRequestBuilders.get("/uploads/avatars/1-abc.png"))
        .andExpect(status().isNotFound());
  }

  @Test
  void deleteAccountNeedsThePasswordAndRemovesEverything() throws Exception {
    JsonNode auth = register("bye@example.com");
    String token = auth.get("accessToken").asText();

    delete("/api/v1/me", token, Map.of("password", "wrong"))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    delete("/api/v1/me", token, Map.of("password", PASSWORD)).andExpect(status().isNoContent());

    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM users", Integer.class)).isZero();
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_settings", Integer.class)).isZero();
    assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens", Integer.class)).isZero();
    get("/api/v1/me", token).andExpect(status().isNotFound());
  }

  @Test
  void internalSettingsEndpointIsGuardedByTheInternalKey() throws Exception {
    JsonNode auth = register("internal@example.com");
    long id = auth.get("user").get("id").asLong();

    mvc.perform(MockMvcRequestBuilders.get("/internal/users/" + id + "/settings"))
        .andExpect(status().isUnauthorized());
    mvc.perform(MockMvcRequestBuilders.get("/internal/users/" + id + "/settings").header("X-Internal-Key", "wrong"))
        .andExpect(status().isUnauthorized());
    // A user's bearer token is not a substitute for the service key.
    mvc.perform(MockMvcRequestBuilders.get("/internal/users/" + id + "/settings")
            .header("Authorization", "Bearer " + auth.get("accessToken").asText()))
        .andExpect(status().isUnauthorized());

    mvc.perform(MockMvcRequestBuilders.get("/internal/users/" + id + "/settings").header("X-Internal-Key", "test-internal-key"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.defaultFollowUpDays").value(7))
        .andExpect(jsonPath("$.interviewRemindersEnabled").value(true));
    mvc.perform(MockMvcRequestBuilders.get("/internal/users/999999/settings").header("X-Internal-Key", "test-internal-key"))
        .andExpect(status().isNotFound());
  }

  @Test
  void healthIsPublicAndUnknownRoutesUseTheErrorShape() throws Exception {
    get("/api/v1/health", null)
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("ok"))
        .andExpect(jsonPath("$.version").isNotEmpty());
    get("/api/v1/nope", register("route@example.com").get("accessToken").asText())
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
  }

  @Test
  void jwtServiceRefusesWeakSecrets() {
    org.junit.jupiter.api.Assertions.assertThrows(IllegalStateException.class,
        () -> new JwtService(new JwtProperties("too-short", Duration.ofMinutes(15))));
  }
}
