import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

// ── Empty state ───────────────────────────────────────────────────────────────

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.ext,
    required this.icon,
    required this.message,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text(
            message,
            style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
          ),
        ],
      ),
    );
  }
}
