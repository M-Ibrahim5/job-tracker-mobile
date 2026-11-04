package com.jobtrail.user.auth;

import com.jobtrail.user.me.UserDto;

public record AuthResponse(String accessToken, String refreshToken, UserDto user) {

  public record Refreshed(String accessToken, String refreshToken) {}
}
