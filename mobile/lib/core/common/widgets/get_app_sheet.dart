import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Bottom sheet (mobile) / dialog (web) shown when the user taps a feature
/// that requires the native app — e.g. share. Prompts them to download Jperg.
class GetAppSheet extends StatelessWidget {
  const GetAppSheet._({required this.ext, required this.featureLabel});

  final AppThemeExtension ext;
  final String featureLabel;

  // ── Store URLs ──────────────────────────────────────────────────────────────
  // TODO: replace placeholder IDs with real store listings once published.
  static const _kAndroidUrl =
      'https://play.google.com/store/apps/details?id=app.skidoo';
  static const _kIosUrl =
      'https://apps.apple.com/app/skidoo/id000000000';
  static const _kFallbackUrl = 'https://skidoo.app';

  static String get _storeUrl {
    if (defaultTargetPlatform == TargetPlatform.android) return _kAndroidUrl;
    if (defaultTargetPlatform == TargetPlatform.iOS) return _kIosUrl;
    return _kFallbackUrl;
  }

  static IconData get _storeIcon {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Icons.android_rounded;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return Icons.apple_rounded;
    }
    return Icons.download_rounded;
  }

  static String get _storeLabel {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Get it on Google Play';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Download on the App Store';
    }
    return 'Get the app';
  }

  // ── Entry point ─────────────────────────────────────────────────────────────

  static void show(
    BuildContext context, {
    required AppThemeExtension ext,
    String featureLabel = 'Sharing',
  }) {
    if (kIsWeb) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: AppSpacing.huge.h),
          elevation: 0,
          child: GetAppSheet._(ext: ext, featureLabel: featureLabel),
        ),
      );
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => GetAppSheet._(ext: ext, featureLabel: featureLabel),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const isWeb = kIsWeb;

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, isWeb ? 28.h : 20.h, 24.w, isWeb ? 28.h : 32.h),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: isWeb
            ? BorderRadius.circular(AppRadius.xxl.r)
            : BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: isWeb
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 40,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (mobile only)
            if (!isWeb)
              Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: AppSpacing.xl.h),
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),

            // Close button (web only — top-right)
            if (isWeb)
              Align(
                alignment: Alignment.topRight,
                child: Semantics(button: true, label: 'Close', child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ext.searchFieldFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: ext.searchHintColor,
                      size: 16.sp,
                    ),
                  ),
                )),
              ),

            // Icon
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: ext.accentGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: ext.accentGold.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Icon(
                Icons.smartphone_rounded,
                color: ext.accentGold,
                size: 28.sp,
              ),
            ),

            SizedBox(height: AppSpacing.lg.h),

            Text(
              '$featureLabel is available on the app',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: AppSpacing.sm.h),

            Text(
              'Download Jperg to share, send to friends, and enjoy the full experience.',
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: 13.sp,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 28.h),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  launchUrl(
                    Uri.parse(_storeUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: Icon(_storeIcon, size: 18),
                label: Text(
                  _storeLabel,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            SizedBox(height: 10.h),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe later',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 13.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
