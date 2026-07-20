import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Shared chrome for every step of the post-signup onboarding wizard — back
/// arrow, segmented step-progress bar, title/subtitle, scrollable content,
/// and a pinned primary button (with an optional "Skip" link). One class so
/// every step (face capture, role selection, interests, creators-to-follow,
/// and the photographer-only portfolio/verification steps) shares the exact
/// same layout instead of each hand-rolling its own Scaffold.
///
/// The back arrow only renders when [Navigator.canPop] is actually true —
/// several onboarding transitions intentionally clear the back stack
/// (`pushReplacement`/`pushNamedAndRemoveUntil`) so a completed step can't be
/// revisited; this widget doesn't change that, it just doesn't show a dead
/// button where there's nowhere to go back to.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    this.subtitle,
    required this.child,
    this.primaryLabel,
    this.onPrimaryPressed,
    this.primaryLoading = false,
    this.primaryEnabled = true,
    this.onSkip,
    this.skipLabel = 'Skip',
    this.showBackButton = true,
    this.scrollable = true,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget child;
  final String? primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final bool primaryLoading;
  final bool primaryEnabled;
  final VoidCallback? onSkip;
  final String skipLabel;
  final bool showBackButton;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final content = scrollable ? SingleChildScrollView(child: child) : child;
    final canPop = showBackButton && Navigator.of(context).canPop();

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: AppSpacing.sm.h),
                  SizedBox(
                    height: 40.h,
                    child: canPop
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              button: true,
                              label: 'Back',
                              child: IconButton(
                                icon: Icon(Icons.arrow_back_ios_rounded,
                                    color: ext.greetingColor, size: 18.sp),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          )
                        : null,
                  ),
                  _StepProgressBar(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                    ext: ext,
                  ),
                  SizedBox(height: 28.h),
                  Text(
                    title,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    Text(
                      subtitle!,
                      style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 13.sp,
                          height: 1.4),
                    ),
                  ],
                  SizedBox(height: AppSpacing.xxl.h),
                  Expanded(child: content),
                  if (primaryLabel != null) ...[
                    SizedBox(height: AppSpacing.lg.h),
                    AppButton(
                      fullWidth: true,
                      height: 52.h,
                      label: primaryLabel!,
                      isLoading: primaryLoading,
                      onPressed: primaryEnabled && !primaryLoading
                          ? onPrimaryPressed
                          : null,
                    ),
                  ],
                  if (onSkip != null) ...[
                    SizedBox(height: AppSpacing.lg.h),
                    Center(
                      child: Semantics(
                        button: true,
                        label: skipLabel,
                        child: TextButton(
                          onPressed: onSkip,
                          child: Text(
                            skipLabel,
                            style: TextStyle(
                                color: ext.searchHintColor, fontSize: 14.sp),
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: AppSpacing.xxl.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

/// Dot-and-line step progress bar — [currentStep] (1-based) of [totalSteps]
/// dots filled solid, the rest shown hollow/light.
class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
    required this.ext,
  });

  final int currentStep;
  final int totalSteps;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final dim = ext.accentGold.withValues(alpha: 0.2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var step = 1; step <= totalSteps; step++) ...[
          if (step > 1)
            Container(
              width: 24.w,
              height: 2,
              color: step - 1 < currentStep ? ext.accentGold : dim,
            ),
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step <= currentStep ? ext.accentGold : dim,
            ),
          ),
        ],
      ],
    );
  }
}
