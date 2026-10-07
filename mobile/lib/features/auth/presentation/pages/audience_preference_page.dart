import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/features/auth/presentation/widgets/onboarding_step_scaffold.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

enum _Audience { discover, share }

/// Onboarding step 2 of 4 — the fork in the wizard.
///
/// "I'm here to discover" continues into interests and creators-to-follow.
/// "Share my work" goes to the portfolio and verification steps instead, and
/// gets neither of those: a creator's feed is ranked on what they shoot, and
/// asking somebody who came here to upload which photography they enjoy is a
/// question for a different person.
///
/// Both branches were the same branch until now. Whichever was picked, this
/// pushed [InterestsPage] — so "Share my work" delivered the discover flow,
/// and the portfolio and verification screens, which exist and are finished,
/// could only be reached afterwards from Account & Security.
///
/// The answer is still recorded in [AuthService.setAudiencePreference], but
/// the navigation no longer depends on reading it back.
class AudiencePreferencePage extends StatefulWidget {
  const AudiencePreferencePage({super.key});

  @override
  State<AudiencePreferencePage> createState() => _AudiencePreferencePageState();
}

class _AudiencePreferencePageState extends State<AudiencePreferencePage> {
  _Audience? _selected;
  bool _submitting = false;

  /// Records the answer, then takes the matching branch.
  ///
  /// The account is *not* upgraded here. It used to be — Continue called
  /// `BecomePhotographerUseCase` and `setRole('photographer')` on the spot —
  /// which made a photographer out of anybody who tapped the second option,
  /// with no portfolio, no ID on file and nothing agreed to, and then walked
  /// them through a flow that asked for none of it.
  ///
  /// The role moves when the verification is submitted, which is where the
  /// server moves it too (see the comment in `photographer/samples.py`, and
  /// the same reasoning on the Account & Security path). Somebody who starts
  /// the portfolio and changes their mind stays an ordinary user.
  Future<void> _continue() async {
    final selected = _selected;
    if (selected == null || _submitting) return;
    setState(() => _submitting = true);

    await sl<AuthService>().setAudiencePreference(
        selected == _Audience.discover ? 'discover' : 'share');
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => selected == _Audience.share
            ? const PortfolioEditPage(entry: CreatorSetupEntry.onboarding)
            : const InterestsPage(),
      ),
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
                        fontWeight: FontWeight.w500,
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
