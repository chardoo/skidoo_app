import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';

/// "Request Boosted!" — the whole screen, after the money has landed.
///
/// A full page rather than a snackbar because it is the receipt for something
/// that was paid for: it says what was bought, for which request, and for how
/// long. Only reached once the server has confirmed the payment, so it never
/// claims a boost that did not happen.
class BoostSuccessPage extends StatelessWidget {
  const BoostSuccessPage({
    super.key,
    required this.requestTitle,
    required this.days,
  });

  /// The request that was boosted, named back so there is no doubt which one.
  final String requestTitle;

  /// How many days were bought.
  final int days;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84.w,
                  height: 84.w,
                  decoration: BoxDecoration(
                    color: ext.accentGold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 44.sp,
                    color: ext.accentGold,
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'Request Boosted!',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppSpacing.md.h),
                // The request's own name is emphasised inside the sentence, so
                // somebody boosting one of several similar requests can see at
                // a glance which one they just paid for.
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 14.sp,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'Your request for '),
                      TextSpan(
                        text: requestTitle,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: ' is now boosted for $days '
                            '${days == 1 ? 'day' : 'days'}. It will occupy top '
                            'spots in photographer feeds.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 36.h),
                SizedBox(
                  width: 205.w,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ext.accentGold,
                      foregroundColor: Colors.white,
                      minimumSize: Size.fromHeight(52.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
