import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// Full-area error state with an optional icon, message and action button.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
    this.retryLabel = 'Retry',
  });

  final String message;

  /// What the button does, or null for no button.
  ///
  /// Null is for the failures that trying again cannot fix — a code that names
  /// no event answers the same every time, and offering Retry there invites
  /// somebody to keep tapping it.
  final VoidCallback? onRetry;
  final IconData icon;

  /// The button's words. "Retry" is wrong when the way forward is a different
  /// code rather than another attempt at this one.
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56.sp, color: Colors.redAccent),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            message,
            style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: AppSpacing.md.h),
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel, style: TextStyle(color: ext.accentGold)),
            ),
          ],
        ],
      ),
    );
  }
}
