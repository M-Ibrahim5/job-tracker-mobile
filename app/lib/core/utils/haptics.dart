import 'package:flutter/services.dart';

/// Thin wrapper so call sites do not depend on the platform channel.
abstract final class Haptics {
  /// Light tap for selections and toggles.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Confirms a completed action.
  static Future<void> success() => HapticFeedback.lightImpact();

  /// Signals a destructive action or error.
  static Future<void> warning() => HapticFeedback.mediumImpact();
}
