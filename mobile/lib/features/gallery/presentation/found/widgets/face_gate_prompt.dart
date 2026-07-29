import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_typography.dart';

/// Why the Found tab has nothing to show yet.
///
/// Both cases render the same "Add your face to get found" panel and differ
/// only in where the button goes and whether a sign-in link appears, so they
/// are one widget with two configurations rather than two near-identical
/// screens that would drift apart.
enum FaceGateReason {
  /// Not signed in. The button starts the create-account flow; a sign-in link
  /// is offered underneath for people who already have an account.
  signedOut,

  /// Signed in, but no reference selfie has been uploaded, so face matching
  /// has nothing to match against. The button goes straight to face capture
  /// and no sign-in link is shown — they are already signed in.
  noFaceAdded,
}

/// Empty state for the Found tab: a headline, a primary action, and (when
/// signed out) a sign-in link.
///
/// Kept free of navigation and auth lookups on purpose — the caller decides
/// what [onPrimaryAction] and [onSignIn] do, so the same widget serves the
/// guest gate, the no-face gate, and anything later that needs to ask for a
/// face.
class FaceGatePrompt extends StatelessWidget {
  const FaceGatePrompt({
    super.key,
    required this.reason,
    required this.onPrimaryAction,
    this.onSignIn,
    this.title,
    this.subtitle,
    this.actionLabel,
  });

  final FaceGateReason reason;

  /// "Add my face". For [FaceGateReason.signedOut] this is expected to route
  /// into sign-up first and continue to face capture afterwards.
  final VoidCallback onPrimaryAction;

  /// Required in practice for [FaceGateReason.signedOut]; ignored otherwise.
  final VoidCallback? onSignIn;

  /// Copy overrides, for callers that need to ask for a face in a different
  /// context (e.g. after a failed match) without a new widget.
  final String? title;
  final String? subtitle;
  final String? actionLabel;

  bool get _showSignIn =>
      reason == FaceGateReason.signedOut && onSignIn != null;

  String get _title => title ?? 'Add your face to get found';

  String get _subtitle =>
      subtitle ?? 'Upload a selfie so we can match you in photos from events.';

  String get _actionLabel => actionLabel ?? 'Add my face';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl.w,
          vertical: AppSpacing.xxl.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FaceGateIcon(ext: ext),
            SizedBox(height: AppSpacing.xxl.h),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: AppTypography.headline.copyWith(color: ext.greetingColor),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: ext.searchHintColor),
            ),
            SizedBox(height: AppSpacing.xxxl.h),
            _PrimaryAction(
              label: _actionLabel,
              onTap: onPrimaryAction,
              ext: ext,
            ),
            if (_showSignIn) ...[
              SizedBox(height: AppSpacing.lg.h),
              _SignInLine(onTap: onSignIn!, ext: ext),
            ],
          ],
        ),
      ),
    );
  }
}

class _FaceGateIcon extends StatelessWidget {
  const _FaceGateIcon({required this.ext});

  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96.w,
      height: 96.w,
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.face_retouching_natural_rounded,
        size: 44.sp,
        color: ext.searchHintColor,
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.onTap,
    required this.ext,
  });

  final String label;
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl.w,
            vertical: AppSpacing.md.h,
          ),
          decoration: BoxDecoration(
            color: ext.accentGold,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
          child: Text(
            label,
            style: AppTypography.bodyLargeBold.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SignInLine extends StatelessWidget {
  const _SignInLine({required this.onTap, required this.ext});

  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    // Wrap, not Row: at large OS text sizes (or on a narrow phone) the two
    // labels exceed one line, and a Row overflows rather than reflowing.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: AppTypography.caption.copyWith(color: ext.searchHintColor),
        ),
        Semantics(
          button: true,
          label: 'Sign in',
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              'Sign in',
              style:
                  AppTypography.captionBold.copyWith(color: ext.accentGold),
            ),
          ),
        ),
      ],
    );
  }
}
