import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/password_strength.dart';

/// Four-segment strength bar with a Weak/Fair/Good/Strong label.
class PasswordStrengthMeter extends StatelessWidget {
  /// Creates a meter for [password].
  const PasswordStrengthMeter({required this.password, super.key});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = passwordStrength(password);
    final color = switch (strength) {
      PasswordStrength.empty => theme.colorScheme.outlineVariant,
      PasswordStrength.weak => theme.colorScheme.error,
      PasswordStrength.fair => const Color(0xFFFFA000),
      PasswordStrength.good => const Color(0xFF1E88E5),
      PasswordStrength.strong => const Color(0xFF43A047),
    };
    return Semantics(
      label: strength == PasswordStrength.empty
          ? null
          : 'Password strength: ${strength.label}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: i < strength.segments
                      ? color
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: Spacing.xs),
          ],
          const SizedBox(width: Spacing.sm),
          SizedBox(
            width: 56,
            child: Text(
              strength.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
