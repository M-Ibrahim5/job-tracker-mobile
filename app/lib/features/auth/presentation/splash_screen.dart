import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Shown while the stored session is being restored.
class SplashScreen extends StatelessWidget {
  /// Creates the splash.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: AppStrings.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
