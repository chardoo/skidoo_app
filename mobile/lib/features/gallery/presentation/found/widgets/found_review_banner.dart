import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/repositories/found_review_repository.dart';

/// "You were found — 2 new photos at Praise Reloaded 2026".
///
/// Sits above the found grid until the person answers. It is a prompt, not a
/// gate: the photos it is asking about are already in the grid underneath,
/// because they *were* found — the question is only whether it is really them.
class FoundReviewBanner extends StatelessWidget {
  const FoundReviewBanner({
    super.key,
    required this.pending,
    required this.ext,
    required this.onTap,
  });

  final PendingFound pending;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: '${pending.title}. ${pending.subtitle}. Review them.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(AppSpacing.sm.w),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
            // Outlined in the accent: it is the one thing on this screen
            // asking for something rather than showing it.
            border: Border.all(color: ext.accentGold, width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                child: SizedBox(
                  width: 56.r,
                  height: 56.r,
                  child: pending.coverUrl == null
                      ? ColoredBox(color: ext.avatarBackground)
                      : Image.network(
                          pending.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              ColoredBox(color: ext.avatarBackground),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pending.title,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      pending.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: ext.searchHintColor, size: 22.r),
            ],
          ),
        ),
      ),
    );
  }
}
