import 'package:flutter/material.dart';

/// Content for a single onboarding carousel slide.
class OnboardingSlide {
  const OnboardingSlide({
    required this.image,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
  });

  final String image;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
}

const kOnboardingSlides = [
  OnboardingSlide(
    image: 'assets/Images/Welcome1.webp',
    fallbackIcon: Icons.groups_rounded,
    title: 'Find yourself',
    subtitle:
        "Every smile. Every laugh. Every photo you're in, all in one place.",
  ),
  OnboardingSlide(
    image: 'assets/Images/Welcome2.webp',
    fallbackIcon: Icons.public_rounded,
    title: "Discover creators you'll love",
    subtitle:
        'Connect with professionals and creatives who capture unforgettable moments.',
  ),
  OnboardingSlide(
    image: 'assets/Images/Welcome3.webp',
    fallbackIcon: Icons.photo_library_rounded,
    title: 'Browse what you love',
    subtitle:
        'Explore stunning photos, events and creators tailored to your interests.',
  ),
];
