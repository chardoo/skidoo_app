import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Final onboarding screen — "You're all set, {name}!" — reached from
/// `follow_suggestions_page.dart`, the same for every role. Portfolio setup
/// + verification are no longer part of onboarding; a photographer does
/// those later, on demand, from the Account page. No progress bar, per the
/// design (`totalSteps: 0` renders an empty one via the shared scaffold
/// rather than duplicating its layout for a one-off screen).
class OnboardingCompletePage extends StatefulWidget {
  const OnboardingCompletePage({super.key});

  @override
  State<OnboardingCompletePage> createState() => _OnboardingCompletePageState();
}

class _OnboardingCompletePageState extends State<OnboardingCompletePage> {
  String _name = '';

  /// Whether a selfie was actually added during the wizard.
  ///
  /// The face step is skippable, so this screen is reached both ways. Only the
  /// people who added a face have anything being scanned — telling the rest
  /// that we're "scanning photos for your face" describes work that isn't
  /// happening and promises a notification that will never arrive.
  bool get _hasFace => AuthService.hasAddedFaces.value;

  @override
  void initState() {
    super.initState();
    sl<AuthService>().getName().then((v) {
      if (mounted) setState(() => _name = v);
    });
  }

  void _goHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 0,
      totalSteps: 0,
      title: _name.isNotEmpty ? "You're all set, $_name!" : "You're all set!",
      // No face, no scanning claim — just the confirmation and the way out.
      subtitle: _hasFace
          ? "We're scanning photos for your face. You will be notified when "
              'we find you.'
          : null,
      primaryLabel: 'Go home',
      onPrimaryPressed: _goHome,
      child: _hasFace ? const _ScanningCard() : const SizedBox.shrink(),
    );
  }
}

/// The "we're working on it" panel, shown only when there is actually a scan
/// running.
///
/// Replaces a box that rendered the literal string "Loader for scanning
/// photos" — the design mock's own placeholder label, shipped as UI.
class _ScanningCard extends StatelessWidget {
  const _ScanningCard();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
        decoration: BoxDecoration(
          color: ext.accentGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ext.accentGold,
              ),
            ),
            SizedBox(width: 12.w),
            Flexible(
              child: Text(
                'Scanning event photos…',
                style: TextStyle(color: ext.greetingColor, fontSize: 13.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
