package com.jobtrail.tracker;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = {"com.jobtrail.tracker", "com.jobtrail.common"})
@ConfigurationPropertiesScan("com.jobtrail.tracker")
@EnableScheduling
public class TrackerServiceApplication {

  public static void main(String[] args) {
    SpringApplication.run(TrackerServiceApplication.class, args);
  }
}
