package com.jobtrail.seed;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Dev-only loader: {@code java -jar seed/target/seed.jar}. Creates the demo account and fills it
 * with realistic applications, history, interviews and notifications.
 */
@SpringBootApplication
public class SeedApplication {

  public static void main(String[] args) {
    System.exit(SpringApplication.exit(SpringApplication.run(SeedApplication.class, args)));
  }
}
