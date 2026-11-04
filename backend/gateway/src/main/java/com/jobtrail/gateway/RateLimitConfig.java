package com.jobtrail.gateway;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Picks the rate-limit store: Redis when {@code REDIS_URL} is set, otherwise in memory. (Spring
 * calls {@link RedisRateLimitStore#close()} on shutdown.)
 */
@Configuration
public class RateLimitConfig {

  private static final Logger log = LoggerFactory.getLogger(RateLimitConfig.class);

  @Bean
  RateLimitStore rateLimitStore(@Value("${jobtrail.gateway.redis-url:}") String redisUrl) {
    InMemoryRateLimitStore memory = new InMemoryRateLimitStore();
    if (redisUrl == null || redisUrl.isBlank()) {
      log.info("Rate limits are counted in memory (set REDIS_URL to share them between gateways)");
      return memory;
    }
    log.info("Rate limits are counted in Redis");
    return new RedisRateLimitStore(redisUrl, memory);
  }
}
