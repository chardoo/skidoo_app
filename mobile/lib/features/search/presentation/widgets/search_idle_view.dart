import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/search/presentation/bloc/search_bloc.dart';
import 'package:skidoo_app/features/search/presentation/widgets/recent_searches_list.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photo_grid.dart';
import 'package:skidoo_app/features/search/presentation/widgets/section_header.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// What the screen shows before anything is typed: the device's recent
/// searches, then the "You may like" grid with its refresh button.
///
/// The two scroll as one list — the design has the recents pushed up and off
/// as the grid is explored, not pinned above it.
class SearchIdleView extends StatelessWidget {
  const SearchIdleView({
    super.key,
    required this.state,
    required this.onRecentTap,
    required this.onRecentRemove,
    required this.onRefresh,
    required this.onPhotoTap,
  });

  final SearchState state;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onRecentRemove;
  final VoidCallback onRefresh;
  final void Function(List<Photo> photos, int index) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final photos = state.youMayLike;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: RecentSearchesList(
            queries: state.recents,
            onTap: onRecentTap,
            onRemove: onRecentRemove,
          ),
        ),
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'You may like',
            actionIcon: Icons.refresh_rounded,
            actionLabel: 'Refresh suggestions',
            // Only the first load blocks the button — a background page fetch
            // shouldn't make ↻ look busy.
            isActionBusy: state.isLoadingYouMayLike,
            onAction: onRefresh,
          ),
        ),

        if (photos.isEmpty && state.isLoadingYouMayLike)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.huge.h),
              child: Center(
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                      color: ext.accentGold, strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (photos.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w, vertical: AppSpacing.xxl.h),
              child: Text(
                state.youMayLikeError ?? 'Nothing to show here yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              ),
            ),
          )
        else
          SearchPhotoGridSliver(
            photos: photos,
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
            onPhotoTap: (index) => onPhotoTap(photos, index),
          ),

        if (state.isLoadingMoreYouMayLike)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                      color: ext.accentGold, strokeWidth: 2),
                ),
              ),
            ),
          ),

        SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge.h)),
      ],
    );
  }
}
