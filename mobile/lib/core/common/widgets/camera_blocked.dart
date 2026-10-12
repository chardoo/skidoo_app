import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';

/// What a camera screen becomes when there is no camera to show.
///
/// A whole screen rather than a message laid over the capture UI. On the
/// selfie page the error used to be drawn into it — over the "Take a Selfie"
/// title, above "Centre your face inside the oval" and a working shutter —
/// which asked somebody to do the one thing the same screen had just said was
/// impossible. The QR scanner had the same shape of problem: the plugin's own
/// error sat over a live scan frame, with nothing to tap and nothing to read
/// but "permission denied".
///
/// Shared by both, so neither grows its own answer to the same question.
///
/// [onOpenSettings] is null when the camera failed for a reason Settings
/// cannot fix — a camera already in use, a simulator, a failing device —
/// and the button is simply absent then. Sending somebody to a switch that
/// is already on is worse than saying nothing.
class CameraBlocked extends StatelessWidget {
  const CameraBlocked({
    super.key,
    required this.message,
    required this.onBack,
    this.onOpenSettings,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _BackBtn(onTap: onBack),
        leadingWidth: 36.w + AppSpacing.lg.w * 2,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.no_photography_rounded,
                    size: 44.sp, color: Colors.white38),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTypography.displayFontFamily,
                  ),
                ),
                if (onOpenSettings != null) ...[
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    'Allow camera access, then come back to this screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                  Semantics(
                    button: true,
                    label: 'Open Settings',
                    child: GestureDetector(
                      onTap: onOpenSettings,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxl.w,
                            vertical: AppSpacing.md.h),
                        decoration: BoxDecoration(
                          color: ext.accentGold,
                          borderRadius: BorderRadius.circular(AppRadius.pill.r),
                        ),
                        child: Text(
                          'Open Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The back arrow, as a dark disc so it reads over a black screen.
class _BackBtn extends StatelessWidget {
  const _BackBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: const BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
          ),
          child: Icon(AppBackButton.icon, color: Colors.white, size: 18.sp),
        ),
      ),
    );
  }
}
