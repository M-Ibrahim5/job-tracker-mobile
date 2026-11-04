package com.jobtrail.common.json;

import com.jobtrail.common.time.Iso;
import java.time.Instant;
import org.springframework.boot.jackson.autoconfigure.JsonMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.core.JsonGenerator;
import tools.jackson.databind.SerializationContext;
import tools.jackson.databind.ValueSerializer;
import tools.jackson.databind.module.SimpleModule;

/** Instants always leave the API as {@code 2026-10-27T02:00:00.000Z}. */
@Configuration
public class JacksonConfig {

  @Bean
  JsonMapperBuilderCustomizer isoInstantCustomizer() {
    return builder -> builder.addModule(new SimpleModule("jobtrail-instants")
        .addSerializer(Instant.class, new IsoInstantSerializer()));
  }

  static final class IsoInstantSerializer extends ValueSerializer<Instant> {
    @Override
    public void serialize(Instant value, JsonGenerator gen, SerializationContext context) {
      gen.writeString(Iso.format(value));
    }
  }
}
