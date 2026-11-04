package com.jobtrail.user.user;

import java.time.Instant;

public record UserRow(
    long id,
    String email,
    String passwordHash,
    String fullName,
    String phone,
    String jobRole,
    String lookingFor,
    String location,
    String avatarPath,
    Instant emailVerifiedAt) {}
