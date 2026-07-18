import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Gradient/icon treatment shown if a slide's bundled hero image fails to load.
class OnboardingHeroFallback extends StatelessWidget {
  const OnboardingHeroFallback({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            accentColor.withValues(alpha: 0.22),
            backgroundColor,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 96.w,
          height: 96.w,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Icon(icon, color: accentColor, size: 44.sp),
        ),
      ),
    );
  }
}
