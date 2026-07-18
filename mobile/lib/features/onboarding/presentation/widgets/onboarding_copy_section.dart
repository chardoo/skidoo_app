import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Left-aligned title + subtitle copy block for a single onboarding slide.
class OnboardingCopySection extends StatelessWidget {
  const OnboardingCopySection({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 26.sp,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
