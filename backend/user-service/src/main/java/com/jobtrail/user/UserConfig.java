package com.jobtrail.user;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import com.jobtrail.user.auth.BoundedPasswordEncoder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
public class UserConfig {

  private final UserProperties props;

  public UserConfig(UserProperties props) {
    this.props = props;
  }

  /**
   * Argon2id with a standard encoded format, so hashes created by other implementations verify.
   * Concurrency is capped so a burst of logins cannot exhaust memory.
   */
  @Bean
  PasswordEncoder passwordEncoder() {
    UserProperties.Argon2 a = props.argon2();
    return new BoundedPasswordEncoder(
        new Argon2PasswordEncoder(16, 32, a.parallelism(), a.memoryKb(), a.iterations()),
        a.effectiveMaxConcurrent(), a.maxWaitMillis());
  }

  @Bean
  Path uploadRoot() throws IOException {
    Path root = Path.of(props.uploadDir()).toAbsolutePath().normalize();
    Files.createDirectories(root.resolve("avatars"));
    return root;
  }
}
