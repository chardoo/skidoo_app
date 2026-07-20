import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Full-area error state with an optional icon, message and retry button.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

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
          SizedBox(height: AppSpacing.md.h),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: ext.accentGold)),
          ),
        ],
      ),
    );
  }
}
