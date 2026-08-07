import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/auth/domain/usecases/become_photographer_usecase.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

enum _Audience { discover, share }

/// Onboarding step 2/4 (or 2/6 for photographers) — also the real role
/// selection now: picking "I'm here to discover" keeps today's default
/// `user` role (local preference only, same as before); picking "Share my
/// work" calls [BecomePhotographerUseCase] to actually upgrade the account
/// before continuing, so the wizard can branch into the photographer-only
/// portfolio/verification steps afterward.
class AudiencePreferencePage extends StatefulWidget {
  const AudiencePreferencePage({super.key});

  @override
  State<AudiencePreferencePage> createState() => _AudiencePreferencePageState();
}

class _AudiencePreferencePageState extends State<AudiencePreferencePage> {
  _Audience? _selected;
  bool _submitting = false;

  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() => _submitting = true);

    if (selected == _Audience.share) {
      try {
        await sl<BecomePhotographerUseCase>().call(const NoParams());
        await sl<AuthService>().setRole('photographer');
      } catch (e) {
        if (mounted) {
          setState(() => _submitting = false);
          AppSnackBar.error(context, 'Could not switch to a creator account: $e');
        }
        return;
      }
    }

    await sl<AuthService>()
        .setAudiencePreference(selected == _Audience.discover ? 'discover' : 'share');
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InterestsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      currentStep: 2,
      totalSteps: 4,
      title: 'What best describes you?',
      primaryLabel: 'Continue',
      primaryEnabled: _selected != null,
      primaryLoading: _submitting,
      onPrimaryPressed: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AudienceOption(
            title: "I'm here to discover",
            subtitle: 'Find my photos and browse photography I love',
            icon: Icons.search_rounded,
            selected: _selected == _Audience.discover,
            onTap: () => setState(() => _selected = _Audience.discover),
          ),
          SizedBox(height: 14.h),
          _AudienceOption(
            title: 'Share my work',
            subtitle: 'Upload, manage and share my event photography',
            icon: Icons.camera_alt_rounded,
            selected: _selected == _Audience.share,
            onTap: () => setState(() => _selected = _Audience.share),
          ),
        ],
      ),
    );
  }
}

class _AudienceOption extends StatelessWidget {
  const _AudienceOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(AppSpacing.lg.w),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: selected ? ext.accentGold : ext.searchHintColor.withValues(alpha: 0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: ext.accentGold, size: 20.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp, height: 1.3),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? ext.accentGold : ext.searchHintColor,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
