import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/enums/enums.dart';

/// Change this one value to re-skin the app.
const Color kSeedColor = Color(0xFF3F51B5);

/// Light-theme design tokens from `DESIGN.md §2`.
abstract final class AppColors {
  static const primaryContainer = Color(0xFFE3E7FA);
  static const onPrimaryContainer = Color(0xFF283593);
  static const background = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const cardOutline = Color(0xFFE6E8F0);
  static const inputOutline = Color(0xFFB9BED2);
  static const divider = Color(0xFFEEF0F6);
  static const text = Color(0xFF1B1E2B);
  static const textSecondary = Color(0xFF4A4F66);
  static const placeholder = Color(0xFF6B7088);
  static const error = Color(0xFFB3261C);
  static const warningContainer = Color(0xFFFFF1D0);
  static const onWarningContainer = Color(0xFF4A3000);

  /// Chart bars for non-current weeks.
  static const chartMuted = Color(0xFFC5CBEF);
}

/// Material 3 light and dark themes.
abstract final class AppTheme {
  /// Light theme. Pass [useGoogleFonts] false (tests, offline builds) to use
  /// the platform font instead of Plus Jakarta Sans.
  static ThemeData light({bool useGoogleFonts = true}) =>
      _build(Brightness.light, useGoogleFonts);

  /// Dark theme: same structure, Material 3 dark scheme from [kSeedColor].
  static ThemeData dark({bool useGoogleFonts = true}) =>
      _build(Brightness.dark, useGoogleFonts);

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: kSeedColor,
      brightness: brightness,
    );
    if (brightness == Brightness.dark) return base;
    return base.copyWith(
      primary: kSeedColor,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.inputOutline,
      outlineVariant: AppColors.cardOutline,
      error: AppColors.error,
      onError: Colors.white,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.background,
      surfaceContainerHigh: AppColors.primaryContainer,
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color color,
    bool useGoogleFonts,
  ) {
    final themed = useGoogleFonts
        ? GoogleFonts.plusJakartaSansTextTheme(base)
        : base;
    return themed
        .copyWith(
          // Screen title (H1).
          headlineMedium: themed.headlineMedium?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          // Auth title.
          headlineLarge: themed.headlineLarge?.copyWith(
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
          // Section title (H2).
          titleLarge: themed.titleLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          // Card title.
          titleMedium: themed.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          titleSmall: themed.titleSmall?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: themed.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          bodyMedium: themed.bodyMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          // Caption.
          bodySmall: themed.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          labelLarge: themed.labelLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          labelMedium: themed.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(bodyColor: color, displayColor: color);
  }

  static ThemeData _build(Brightness brightness, bool useGoogleFonts) {
    final scheme = _scheme(brightness);
    final isLight = brightness == Brightness.light;
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = _textTheme(
      base.textTheme,
      scheme.onSurface,
      useGoogleFonts,
    );
    final scaffold = isLight ? AppColors.background : scheme.surface;
    final cardSurface = isLight
        ? AppColors.surface
        : scheme.surfaceContainerLow;
    final inputRadius = BorderRadius.circular(Radii.input);

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.button),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: isLight ? AppColors.divider : scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardSurface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: TextStyle(
          color: isLight ? AppColors.placeholder : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: inputBorder(scheme.outline, 1),
        enabledBorder: inputBorder(scheme.outline, 1),
        disabledBorder: inputBorder(scheme.outlineVariant, 1),
        focusedBorder: inputBorder(scheme.primary, 2),
        errorBorder: inputBorder(scheme.error, 2),
        focusedErrorBorder: inputBorder(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonHeight),
          shape: buttonShape,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Sizes.buttonHeight),
          shape: buttonShape,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardSurface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outline),
        labelStyle: textTheme.labelMedium?.copyWith(fontSize: 14),
        checkmarkColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : cardSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
          textStyle: WidgetStateProperty.resolveWith(
            (s) => textTheme.labelMedium?.copyWith(
              fontSize: 14,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: inputRadius),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.fab),
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
      ),
      // Icon-only floating pill: the selected tab is a filled primary circle.
      navigationBarTheme: NavigationBarThemeData(
        height: Sizes.navBarHeight,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary,
        indicatorShape: const CircleBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.summary),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.input),
        ),
      ),
    );
  }
}

/// Color + icon pairing for each [ApplicationStatus]; icon + label are always
/// shown with the color so status is not conveyed by color alone.
class StatusStyle {
  const StatusStyle({
    required this.color,
    required this.icon,
    required this.chipBackground,
    required this.chipText,
  });

  /// Accent for dots, charts and fills.
  final Color color;
  final IconData icon;

  /// Chip fill.
  final Color chipBackground;

  /// Chip text/icon color (darker than [color] for contrast).
  final Color chipText;

  /// Style lookup used by chips, dashboard and calendar. Dark variants lighten
  /// the text and use a translucent accent as the fill.
  static StatusStyle of(
    ApplicationStatus s, [
    Brightness brightness = Brightness.light,
  ]) {
    final light = switch (s) {
      ApplicationStatus.applied => const StatusStyle(
        color: Color(0xFF1E88E5),
        icon: Icons.send_rounded,
        chipBackground: Color(0xFFE3F0FC),
        chipText: Color(0xFF0D47A1),
      ),
      ApplicationStatus.screening => const StatusStyle(
        color: Color(0xFFFFA000),
        icon: Icons.manage_search_rounded,
        chipBackground: Color(0xFFFFF1D0),
        chipText: Color(0xFF7A4F00),
      ),
      ApplicationStatus.interview => const StatusStyle(
        color: Color(0xFF8E24AA),
        icon: Icons.groups_rounded,
        chipBackground: Color(0xFFF1E3F7),
        chipText: Color(0xFF6A1B80),
      ),
      ApplicationStatus.offer => const StatusStyle(
        color: Color(0xFF43A047),
        icon: Icons.workspace_premium_rounded,
        chipBackground: Color(0xFFE0F2E1),
        chipText: Color(0xFF1B5E20),
      ),
      ApplicationStatus.rejected => const StatusStyle(
        color: Color(0xFFE53935),
        icon: Icons.cancel_rounded,
        chipBackground: Color(0xFFFDE3E1),
        chipText: Color(0xFFB71C1C),
      ),
    };
    if (brightness == Brightness.light) return light;
    return StatusStyle(
      color: light.color,
      icon: light.icon,
      chipBackground: light.color.withValues(alpha: 0.24),
      chipText: Color.lerp(light.color, Colors.white, 0.6)!,
    );
  }

  /// Teal used for follow-up markers. Deliberately not orange: orange is the
  /// Screening status, so status-change dots looked identical to follow-ups.
  static const followUpColor = Color(0xFF00897B);

  /// Follow-up text color and tonal tile fill (`DESIGN.md §4.9`).
  static const followUpText = Color(0xFF00695C);
  static const followUpContainer = Color(0xFFD3F0EC);
}
