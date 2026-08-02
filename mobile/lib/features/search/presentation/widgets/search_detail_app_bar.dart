import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/common/widgets/app_back_button.dart';

/// Back arrow and a title, shared by the two screens a search result opens.
///
/// A plain row rather than an [AppBar] so it lines up with [SearchTopBar] —
/// the two are the same bar in two states as far as the user is concerned, and
/// an AppBar's own insets would put the title a few pixels off.
class SearchDetailAppBar extends StatelessWidget {
  const SearchDetailAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
  });

  final String title;
  final String? subtitle;

  /// Defaults to popping the route.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final sub = subtitle;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.sm.w, AppSpacing.sm.h, AppSpacing.lg.w, AppSpacing.sm.h),
      child: Row(
        children: [
          AppBackButton(onPressed: onBack),
          SizedBox(width: AppSpacing.xs.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sub != null && sub.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
