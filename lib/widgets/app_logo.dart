import 'package:flutter/material.dart';

import '../utils/constants.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.radius,
    this.padding = 8,
    this.backgroundColor = Colors.white,
    this.shadow = true,
  });

  final double size;
  final double? radius;
  final double padding;
  final Color backgroundColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final resolvedRadius = radius ?? size * 0.18;
    final borderRadius = BorderRadius.circular(resolvedRadius);
    final innerPadding = (padding * 0.75).clamp(2.0, 10.0).toDouble();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDark],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: AppColors.accent,
          width: (size * 0.035).clamp(1.5, 4.0).toDouble(),
        ),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (resolvedRadius - 5).clamp(6.0, 48.0).toDouble(),
        ),
        child: Container(
          padding: EdgeInsets.all(innerPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.9),
              width: (size * 0.018).clamp(1.0, 2.5).toDouble(),
            ),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
