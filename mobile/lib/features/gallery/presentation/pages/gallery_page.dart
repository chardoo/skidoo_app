import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_image_widget.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: ext.accentGold,
        backgroundColor: ext.cardSurface,
        onRefresh: () async =>
            context.read<GalleryBloc>().add(const GalleryLoadRequested()),
        child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
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
                if (state.isLoading) return const AppLoadingIndicator();

                if (state.errorMessage != null) {
                  return AppErrorView(
                    message: state.errorMessage!,
                    icon: Icons.cloud_off_rounded,
                    onRetry: () => context
                        .read<GalleryBloc>()
                        .add(const GalleryLoadRequested()),
                  );
                }

                if (state.photos.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.photo_library_outlined,
                    message: 'Your gallery is empty\nPhotos from your events will appear here',
                  );
                }

                return Padding(
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
                );
              },
            ),
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground, width: kWebColumnWidthWide);
  }

  // On web the grid is constrained to 3 columns (~160 px each at 480 px wide).
  // On mobile use viewport width as before.
  int _columnCount(BuildContext context) {
    if (kIsWeb) return 3;
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 600) return 3;
    return 2;
  }

}
