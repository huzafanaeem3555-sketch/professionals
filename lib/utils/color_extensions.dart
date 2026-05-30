import 'package:flutter/material.dart';

/// Small compatibility extension to support the project's historical
/// `withValues(alpha: ...)` usage. Internally forwards to `withOpacity`.
extension ColorWithValues on Color {
  /// Accepts alpha as a 0.0 - 1.0 double and returns a color with that opacity.
  Color withValues({required double alpha}) {
    return Color.fromARGB(
      (alpha * 255).toInt(),
      red,
      green,
      blue,
    );
  }
}

