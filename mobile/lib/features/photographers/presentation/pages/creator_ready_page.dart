import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/config/app_links_config.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:url_launcher/url_launcher.dart';

/// "You're all set, Kwame!" — the end of becoming a creator.
///
/// A screen rather than a snackbar because it is the moment the account
/// changes what it is, and because it carries the one thing they came here to
/// do: put photos up. The wizard behind it is gone by the time this shows, so
/// there is no back button — the only ways out are forward or Home.
///
/// Note it does not claim they are verified. The ID is queued for review, and
/// the badge arrives when somebody has looked at it; what has actually
/// happened is that they can now post, which is what the copy says.
class CreatorReadyPage extends StatelessWidget {
  const CreatorReadyPage({super.key, required this.name});

  /// First name only. "You're all set, Kwame Mensah!" reads like a letter from
  /// a bank.
  final String name;

  static String firstNameOf(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  Future<void> _openUploader(BuildContext context) async {
    // Uploading a shoot is a desktop job — dozens of files, off a camera —
    // and the app has no bulk picker. The design says so on the button, and
    // this hands them the same web app the link would.
    final uri = Uri.parse('${AppLinksConfig.shareBaseUrl}/upload');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        AppSnackBar.error(context, 'Could not open the uploader.');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.error(context, 'Could not open the uploader.');
      }
    }
  }

  void _done(BuildContext context) {
    // Everything the wizard pushed goes with it. Coming back to a portfolio
    // form they have already submitted would read as it not having worked.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final greeting =
        name.trim().isEmpty ? "You're all set!" : "You're all set, $name!";

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ext.accentGold.withValues(alpha: 0.15),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.check_rounded,
                    size: 32.sp, color: ext.accentGold),
              ),
              SizedBox(height: AppSpacing.xl.h),
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Text(
                'You can now post your content and start monetising your '
                'portfolio.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 14.sp,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.sm.h,
                ),
                decoration: BoxDecoration(
                  color: ext.cardSurface,
                  borderRadius: BorderRadius.circular(AppRadius.pill.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.desktop_windows_outlined,
                        size: 14.sp, color: ext.searchHintColor),
                    SizedBox(width: AppSpacing.sm.w),
                    Flexible(
                      child: Text(
                        'Continue on the web to upload your first photos',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),
              AppButton(
                label: 'Upload photos',
                icon: Icons.north_east_rounded,
                fullWidth: true,
                borderRadius: AppRadius.pill,
                onPressed: () => _openUploader(context),
              ),
              SizedBox(height: AppSpacing.md.h),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => _done(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                    child: Text(
                      "I'll do this later",
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 14.sp,
                        decoration: TextDecoration.underline,
                        decorationColor: ext.searchHintColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
