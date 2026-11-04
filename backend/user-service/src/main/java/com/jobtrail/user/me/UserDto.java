package com.jobtrail.user.me;

import com.jobtrail.user.user.UserRow;

/** The {@code User} object of docs/API.md. */
public record UserDto(
    long id,
    String email,
    String fullName,
    String phone,
    String currentRole,
    String lookingFor,
    String location,
    String avatarUrl,
    boolean emailVerified) {

  public static UserDto from(UserRow user, String publicBaseUrl) {
    String base = publicBaseUrl.endsWith("/") ? publicBaseUrl.substring(0, publicBaseUrl.length() - 1) : publicBaseUrl;
    return new UserDto(
        user.id(),
        user.email(),
        user.fullName(),
        user.phone(),
        user.jobRole(),
        user.lookingFor(),
        user.location(),
        user.avatarPath() == null ? null : base + "/uploads/" + user.avatarPath(),
        user.emailVerifiedAt() != null);
  }
}
