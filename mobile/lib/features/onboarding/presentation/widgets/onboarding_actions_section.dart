import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Primary Continue/Get-Started button with a Skip text button beneath it.
class OnboardingActionsSection extends StatelessWidget {
  const OnboardingActionsSection({
    super.key,
    required this.isLast,
    required this.accentColor,
    required this.onContinue,
    required this.onSkip,
  });

  final bool isLast;
  final Color accentColor;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52.h,
          child: Semantics(
            button: true,
            label: isLast ? 'Get Started' : 'Continue',
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                isLast ? 'Get Started' : 'Continue',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Semantics(
          button: true,
          label: 'Skip onboarding',
          child: TextButton(
            onPressed: onSkip,
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
