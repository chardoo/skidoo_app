import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/suggested_creators_list.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';

/// A slice of suggested creators, dealt between posts in the Following feed.
///
/// As tall as its contents and no taller. It used to be a page of its own in a
/// vertical [PageView], which meant it was stretched to the full viewport
/// whatever it contained: five rows of creators and then half a screen of
/// nothing. Anchoring the rows top, bottom or centre only moved that hole
/// around — the fix was for the feed to stop paging, so this can be an item
/// the reader scrolls past rather than a screen they have to swipe away.
class FeedSuggestionsCard extends StatelessWidget {
  const FeedSuggestionsCard({super.key, required this.suggestions});

  final List<SuggestedPhotographer> suggestions;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.md.h,
      ),
      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: ext.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Sized by its rows: the card ends where the last creator does, and
        // the next post starts just below it.
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Text(
              'Creators you might like',
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          const AppSectionLabel('Suggested creators',
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg)),
          SizedBox(height: AppSpacing.sm.h),
          SuggestedCreatorsList(suggestions: suggestions),
        ],
      ),
    );
  }
}
