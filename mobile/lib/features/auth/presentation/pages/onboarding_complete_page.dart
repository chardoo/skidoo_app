import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/services/auth_service.dart';

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
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return OnboardingStepScaffold(
      currentStep: 0,
      totalSteps: 0,
      title: _name.isNotEmpty ? "You're all set, $_name!" : "You're all set!",
      subtitle: "We're scanning photos for your face. You will be notified when we find you.",
      primaryLabel: 'Go home',
      onPrimaryPressed: _goHome,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 28.h),
          decoration: BoxDecoration(
            color: ext.accentGold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14.r),
          ),
          alignment: Alignment.center,
          child: Text(
            'Loader for scanning photos',
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        ),
      ),
    );
  }
}
