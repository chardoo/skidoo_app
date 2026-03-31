import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Centred empty-state with an icon and a message.
/// Optionally shows an [action] button beneath the message.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[SizedBox(height: 8.h), action!],
        ],
      ),
    );
  }
}
