package com.jobtrail.gateway;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * {@code jobtrail.gateway.*}: rate limits (requests per minute) and whether the client address is
 * taken from {@code X-Forwarded-For} (only enable behind a proxy you control).
 *
 * <ul>
 *   <li>{@code apiLimit}: everything under {@code /api/v1}, per user when the request carries a
 *       valid access token, otherwise per IP.
 *   <li>{@code authLimit}: password endpoints (login, register, forgot-password, change-password)
 *       per IP, on top of the API limit.
 *   <li>{@code tokenLimit}: refresh, device login and logout per IP. They need a long random
 *       secret, so they cannot be brute-forced and get a much higher budget than logins.
 * </ul>
 */
@ConfigurationProperties("jobtrail.gateway")
public record GatewayProperties(
    @DefaultValue("300") int apiLimit,
    @DefaultValue("10") int authLimit,
    @DefaultValue("120") int tokenLimit,
    @DefaultValue("false") boolean trustForwardedFor) {}
