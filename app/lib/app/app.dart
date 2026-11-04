import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import 'app_coordinator.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// Root widget.
class JobTrailApp extends ConsumerWidget {
  /// Creates the app. Tests pass `useGoogleFonts: false` to avoid network
  /// font downloads.
  const JobTrailApp({this.useGoogleFonts = true, super.key});

  final bool useGoogleFonts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(useGoogleFonts: useGoogleFonts),
      darkTheme: AppTheme.dark(useGoogleFonts: useGoogleFonts),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          AppCoordinator(child: child ?? const SizedBox.shrink()),
    );
  }
}
