import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The shape every search result row shares: a leading mark, a title, an
/// optional subtitle, and an optional trailing chevron.
///
/// The three row types differ only in what goes in the leading slot — a cover
/// thumbnail, an avatar, a `#` — so the title/subtitle typography, the row
/// height and the tap target are defined once here instead of drifting apart
/// across three widgets.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.semanticLabel,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Usually the chevron; null leaves the row flush.
  final Widget? trailing;
  final VoidCallback onTap;
  final String? semanticLabel;

  /// The chevron the event rows carry in the design.
  static Widget chevron(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Icon(Icons.chevron_right_rounded,
        color: ext.searchHintColor, size: 22.sp);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final sub = subtitle;

    return Semantics(
      button: true,
      label: semanticLabel ?? title,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Row(
            children: [
              leading,
              SizedBox(width: AppSpacing.md.w),
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
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: AppSpacing.sm.w),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
