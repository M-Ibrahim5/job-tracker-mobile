import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../../domain/enums/enums.dart';

/// Rounded square with the company's first letter, tinted by the
/// application's [status] so a list of them reads at a glance.
class CompanyMonogram extends StatelessWidget {
  /// Creates a monogram for [companyName].
  const CompanyMonogram({
    required this.companyName,
    required this.status,
    this.size = 36,
    super.key,
  });

  final String companyName;
  final ApplicationStatus status;
  final double size;

  /// First letter or digit of [name], upper-cased; "?" when there is none.
  static String initialOf(String name) {
    final match = RegExp(r'[\p{L}\p{N}]', unicode: true).firstMatch(name);
    return match == null ? '?' : match.group(0)!.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status, Theme.of(context).brightness);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: style.chipBackground,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(color: style.color.withValues(alpha: 0.35)),
        ),
        child: Text(
          initialOf(companyName),
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w800,
            color: style.chipText,
            height: 1,
          ),
        ),
      ),
    );
  }
}
