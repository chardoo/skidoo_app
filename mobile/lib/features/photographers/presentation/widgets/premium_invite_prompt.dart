import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/photographers/data/premium_service.dart';
import 'package:jperg_app/features/photographers/presentation/pages/premium_rules_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The invitation a creator meets after signing in.
///
/// Paced like the feedback prompt, and for the same reason: an offer that
/// appears on every launch is an offer people learn to dismiss without reading.
/// It waits a couple of sessions, respects a "not now" for a good while, and
/// stops asking entirely once somebody has said no twice.
///
/// It never tells anybody they *cannot* join. Somebody who has not sent an ID,
/// or who is serving a cooldown, is simply not asked — an invitation whose
/// button refuses you is worse than no invitation.
class PremiumInvitePrompt {
  const PremiumInvitePrompt._();

  /// Launches before the offer is made at all.
  ///
  /// Two, so it is never the first thing somebody sees: a creator's first
  /// session is spent working out where things are, and an upsell over that is
  /// noise.
  static const _minLaunches = 2;

  /// How long a "not now" is honoured.
  static const _snoozeDays = 30;

  /// How many times somebody may be asked before it stops for good. Two is a
  /// reminder; three is nagging.
  static const _maxAsks = 2;

  static const _launchesKey = 'premium.invite.launches';
  static const _lastAskedKey = 'premium.invite.lastAsked';
  static const _asksKey = 'premium.invite.asks';
  static const _dismissedKey = 'premium.invite.dismissed';

  /// Counted once per app start, from `main`.
  static Future<void> noteLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_launchesKey, (prefs.getInt(_launchesKey) ?? 0) + 1);
  }

  /// Whether to offer it now — pacing only. Eligibility is the server's answer
  /// and is checked separately in [maybeShow].
  static Future<bool> _isDue() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_dismissedKey) ?? false) return false;
    if ((prefs.getInt(_launchesKey) ?? 0) < _minLaunches) return false;
    if ((prefs.getInt(_asksKey) ?? 0) >= _maxAsks) return false;

    final last = prefs.getInt(_lastAskedKey);
    if (last != null) {
      final since = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(last),
      );
      if (since.inDays < _snoozeDays) return false;
    }
    return true;
  }

  static Future<void> _noteAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_asksKey, (prefs.getInt(_asksKey) ?? 0) + 1);
    await prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Never ask again — set when somebody joins, and when they say no for the
  /// last time.
  static Future<void> _stopAsking() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  /// Offer it, if it is due and this account could actually accept.
  ///
  /// Silent on any failure. This is an invitation nobody asked for; an error
  /// about one would be worse than the invitation not appearing.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      if (!await _isDue()) return;

      final status = await PremiumService(sl()).status();
      // Only somebody who can say yes. `canJoin` already folds in the tier
      // being on, the door being open, the role, the cooldown and the ID — so
      // this never shows a button that would refuse them.
      if (!status.terms.enabled || !status.canJoin) return;

      // Recorded before the check below, so a screen that went away between
      // the fetch and now still counts as having been offered — otherwise the
      // pacing resets and they are asked again on the next launch.
      await _noteAsked();
      if (!context.mounted) return;
      await _show(context, status.terms);
    } catch (_) {
      // Nothing.
    }
  }

  static Future<void> _show(BuildContext context, PremiumTerms terms) async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final wantsIn = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: ext.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.r,
                height: 48.r,
                decoration: BoxDecoration(
                  color: ext.accentGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded,
                    color: ext.accentGold, size: 24.sp),
              ),
              SizedBox(height: AppSpacing.lg.h),
              Text(
                'Become a ${terms.name}',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontFamily: AppTypography.displayFontFamily,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                'Promise your clients their photos within '
                '${terms.windowLabel} of the shoot, and get work only '
                '${terms.name}s can see.',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 14.sp,
                  height: 1.5,
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
              AppButton(
                label: 'Read the rules',
                fullWidth: true,
                borderRadius: AppRadius.pill,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
              SizedBox(height: AppSpacing.sm.h),
              AppButton(
                label: 'Not now',
                variant: AppButtonVariant.text,
                fullWidth: true,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );

    if (wantsIn != true || !context.mounted) return;

    // Straight to the terms. The dialog is an invitation, not the contract —
    // nobody joins from a paragraph in a pop-up.
    final joined = await PremiumRulesPage.show(context);
    if (joined) await _stopAsking();
  }
}
