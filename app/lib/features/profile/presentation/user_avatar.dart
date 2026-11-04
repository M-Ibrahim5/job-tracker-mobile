import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/models/user.dart';

/// Circular avatar: the photo when there is one, otherwise (or while it loads
/// or fails) the user's initials on the primary color.
class UserAvatar extends StatelessWidget {
  /// Creates an avatar of [size] logical pixels.
  const UserAvatar({
    required this.user,
    this.size = 64,
    this.previewPath,
    super.key,
  });

  final User user;
  final double size;

  /// Local image shown instead of the saved photo: a pick the user has not
  /// saved yet.
  final String? previewPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = user.avatarUrl;
    return Semantics(
      label: user.fullName,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: scheme.primary,
                child: Center(
                  child: Text(
                    user.initials,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (previewPath != null)
                Image.file(
                  File(previewPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              else if (url != null)
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
