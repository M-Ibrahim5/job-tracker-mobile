package com.jobtrail.user.me;

import java.time.Duration;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code GET /uploads/avatars/{file}}: public by design, the name carries an unguessable random
 * part. A new upload gets a new name, so responses can be cached for a long time.
 */
@RestController
public class AvatarController {

  private final AvatarStorage avatars;

  public AvatarController(AvatarStorage avatars) {
    this.avatars = avatars;
  }

  @GetMapping("/uploads/avatars/{file}")
  ResponseEntity<byte[]> avatar(@PathVariable String file) {
    return avatars.load(file)
        .map(image -> ResponseEntity.ok()
            .contentType(MediaType.parseMediaType(image.contentType()))
            .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePublic().immutable())
            .header("Content-Disposition", "inline")
            .body(image.bytes()))
        .orElseGet(() -> ResponseEntity.status(HttpStatus.NOT_FOUND).build());
  }
}
