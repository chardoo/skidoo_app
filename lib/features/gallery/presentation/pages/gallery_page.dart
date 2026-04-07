import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_image_widget.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: RefreshIndicator(
        color: ext.accentGold,
        backgroundColor: ext.cardSurface,
        onRefresh: () async =>
            context.read<GalleryBloc>().add(const GalleryLoadRequested()),
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor: ext.homeBackground,
              surfaceTintColor: Colors.transparent,
              floating: true,
              snap: true,
              elevation: 0,
              titleSpacing: 20.w,
              title: Row(
                children: [
                  Text(
                    'My Gallery',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  BlocBuilder<GalleryBloc, GalleryState>(
                    builder: (context, state) {
                      if (state.photos.isEmpty) return const SizedBox.shrink();
                      return Text(
                        '${state.photos.length} photos',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 16.w),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: ext.searchHintColor.withValues(alpha: 0.12),
                ),
              ),
            ),
          ],
          body: BlocBuilder<GalleryBloc, GalleryState>(
            builder: (context, state) {
              if (state.isLoading) {
                return Center(
                  child: CircularProgressIndicator(
                    color: ext.accentGold,
                    strokeWidth: 2,
                  ),
                );
              }

              if (state.errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 56.sp, color: ext.searchHintColor),
                        SizedBox(height: 16.h),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(
                              color: ext.searchHintColor, fontSize: 14.sp),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20.h),
                        TextButton(
                          onPressed: () => context
                              .read<GalleryBloc>()
                              .add(const GalleryLoadRequested()),
                          child: Text('Retry',
                              style: TextStyle(color: ext.accentGold)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state.photos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 64.sp, color: ext.searchHintColor),
                      SizedBox(height: 16.h),
                      Text(
                        'Your gallery is empty',
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Photos from your events will appear here',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 13.sp),
                      ),
                    ],
                  ),
                );
              }

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 0),
                    child: MasonryGridView.count(
                      crossAxisCount: _columnCount(context),
                      mainAxisSpacing: 10.h,
                      crossAxisSpacing: 10.w,
                      cacheExtent: 800,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: true,
                      itemCount: state.photos.length,
                      itemBuilder: (context, index) {
                        return BlocProvider.value(
                          value: context.read<CartBloc>(),
                          child: GalleryImageWidget(
                            photo: state.photos[index],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _columnCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }
}
