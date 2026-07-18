import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/features/onboarding/presentation/widgets/onboarding_hero_fallback.dart';
import 'package:skidoo_app/features/onboarding/presentation/widgets/onboarding_page_indicator.dart';

/// Full-bleed hero image for a single onboarding slide, with the page
/// progress dots overlaid near the bottom edge of the photo.
class OnboardingHeroSection extends StatelessWidget {
  const OnboardingHeroSection({
    super.key,
    required this.image,
    required this.fallbackIcon,
    required this.slideCount,
    required this.activeIndex,
    required this.accentColor,
    required this.backgroundColor,
  });

  final String image;
  final IconData fallbackIcon;
  final int slideCount;
  final int activeIndex;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => OnboardingHeroFallback(
            icon: fallbackIcon,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20.h,
          child: Center(
            child: OnboardingPageIndicator(
              count: slideCount,
              activeIndex: activeIndex,
              activeColor: accentColor,
              inactiveColor: Colors.white54,
            ),
          ),
        ),
      ],
    );
  }
}
