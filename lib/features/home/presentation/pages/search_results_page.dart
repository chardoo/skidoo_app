import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';

class SearchResultsPage extends StatelessWidget {
  static const routeName = '/searchresults';
  const SearchResultsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: ext.greetingColor,
        ),
        title: Text(
          'Search Results',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
          // Initial full-screen loader — no images yet and still loading.
          if (state.isLoadingImages && state.searchImages.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                  color: ext.accentGold, strokeWidth: 2),
            );
          }

          if (state.searchImages.isEmpty && !state.isLoadingImages) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_search_outlined,
                      size: 64.sp, color: ext.searchHintColor),
                  SizedBox(height: 12.h),
                  Text(
                    'No images found',
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 15.sp),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(10.w),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: responsiveColumnCount(constraints.maxWidth, minColWidth: 200),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childCount: state.searchImages.length,
                  itemBuilder: (context, index) {
                    final photo = state.searchImages[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: CachedNetworkImage(
                        imageUrl: photo.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 150.h,
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white38, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 150.h,
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white38, size: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Streaming indicator — shown at the bottom while more images arrive.
              if (state.isLoadingImages)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                                color: ext.accentGold, strokeWidth: 2),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Loading more…',
                            style: TextStyle(
                                color: ext.searchHintColor, fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        ),
      ),
    );
  }
}
