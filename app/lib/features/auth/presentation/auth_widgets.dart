import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Logo tile (48, primary) + app name shown above auth forms.
class AuthLogo extends StatelessWidget {
  /// Creates the logo row.
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(Radii.input),
          ),
          child: Icon(
            Icons.work_rounded,
            color: theme.colorScheme.onPrimary,
            semanticLabel: AppStrings.appName,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(AppStrings.appName, style: theme.textTheme.titleLarge),
          ),
        ),
      ],
    );
  }
}
