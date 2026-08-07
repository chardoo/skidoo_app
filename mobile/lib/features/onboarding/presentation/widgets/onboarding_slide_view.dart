import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/features/onboarding/presentation/models/onboarding_slide.dart';
import 'package:jperg_app/features/onboarding/presentation/widgets/onboarding_copy_section.dart';
import 'package:jperg_app/features/onboarding/presentation/widgets/onboarding_hero_section.dart';

/// One page of the onboarding carousel: full-bleed hero photo (with the
/// progress dots overlaid) followed by the slide's title/subtitle copy.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    super.key,
    required this.slide,
    required this.slideCount,
    required this.activeIndex,
    required this.accentColor,
    required this.backgroundColor,
  });

  final OnboardingSlide slide;
  final int slideCount;
  final int activeIndex;
  final Color accentColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: OnboardingHeroSection(
            image: slide.image,
            fallbackIcon: slide.fallbackIcon,
            slideCount: slideCount,
            activeIndex: activeIndex,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 0),
          child: OnboardingCopySection(
            title: slide.title,
            subtitle: slide.subtitle,
          ),
        ),
      ],
    );
  }
}
