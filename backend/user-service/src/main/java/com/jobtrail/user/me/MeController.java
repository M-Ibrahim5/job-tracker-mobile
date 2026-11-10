package com.jobtrail.user.me;

import tools.jackson.databind.JsonNode;
import com.jobtrail.common.error.AppException;
import com.jobtrail.common.security.CurrentUser;
import com.jobtrail.common.validation.JsonBody;
import com.jobtrail.user.UserProperties;
import com.jobtrail.user.auth.AuthService;
import com.jobtrail.user.user.UserRepository;
import com.jobtrail.user.user.UserRow;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/me")
public class MeController {

  private static AppException badImage() {
    return AppException.invalidField("file", "A JPEG or PNG image is required");
  }

  private final UserRepository users;
  private final AuthService auth;
  private final AvatarStorage avatars;
  private final UserProperties props;
  private final TransactionTemplate tx;

  public MeController(UserRepository users, AuthService auth, AvatarStorage avatars, UserProperties props,
      TransactionTemplate tx) {
    this.tx = tx;
    this.users = users;
    this.auth = auth;
    this.avatars = avatars;
    this.props = props;
  }

  private UserRow current(long id) {
    return users.findById(id).orElseThrow(() -> AppException.notFound("User not found"));
  }

  private UserDto dto(UserRow user) {
    return UserDto.from(user, props.publicBaseUrl());
  }

  @GetMapping
  UserDto get(@CurrentUser long userId) {
    return dto(current(userId));
  }

  @PatchMapping
  UserDto patch(@CurrentUser long userId, @RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    Map<String, Object> columns = new LinkedHashMap<>();
    if (body.has("fullName")) {
      columns.put("full_name", body.requiredText("fullName", 100));
    }
    optional(body, columns, "phone", "phone", 30);
    optional(body, columns, "currentRole", "job_role", 100);
    optional(body, columns, "lookingFor", "looking_for", 100);
    optional(body, columns, "location", "location", 100);
    body.finish();
    current(userId);
    users.updateColumns(userId, columns);
    return dto(current(userId));
  }

  private static void optional(JsonBody body, Map<String, Object> columns, String field, String column, int max) {
    if (body.has(field)) {
      columns.put(column, body.optionalText(field, max));
    }
  }

  @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  UserDto avatar(@CurrentUser long userId, @RequestPart(value = "file", required = false) MultipartFile file)
      throws IOException {
    if (file == null || file.isEmpty()) {
      throw badImage();
    }
    byte[] bytes = file.getBytes();
    String extension;
    // The declared content type is not trusted on its own: check the magic bytes too.
    if ("image/png".equals(file.getContentType()) && isPng(bytes)) {
      extension = "png";
    } else if ("image/jpeg".equals(file.getContentType()) && isJpeg(bytes)) {
      extension = "jpg";
    } else {
      throw badImage();
    }
    // Store a re-encoded copy: strips metadata such as GPS location and anything hidden in the file.
    byte[] clean = AvatarImages.normalise(bytes, extension).orElseThrow(MeController::badImage);
    current(userId);
    // Uploads by one user run one after the other: each replaces exactly the avatar it found, so two
    // at once cannot leave an orphaned image behind.
    tx.executeWithoutResult(status -> {
      String old = users.lockAvatarPath(userId);
      users.setAvatarPath(userId, avatars.save(userId, clean, extension));
      avatars.delete(old);
    });
    return dto(current(userId));
  }

  private static boolean isPng(byte[] b) {
    return b.length >= 4 && (b[0] & 0xff) == 0x89 && b[1] == 0x50 && b[2] == 0x4e && b[3] == 0x47;
  }

  private static boolean isJpeg(byte[] b) {
    return b.length >= 2 && (b[0] & 0xff) == 0xff && (b[1] & 0xff) == 0xd8;
  }

  @DeleteMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void delete(@CurrentUser long userId, @RequestBody JsonNode json) {
    JsonBody body = JsonBody.of(json);
    String password = body.requiredRaw("password", 128);
    body.finish();
    UserRow user = current(userId);
    auth.requirePassword(user, password);
    users.delete(userId);
    avatars.delete(user.avatarPath());
  }
}
