import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/found/bloc/found_album_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_photo_grid.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Every photo of one event, in the same grid the Found feed previews it with.
///
/// The feed's [FoundAlbum] only holds the server's preview slice, so this page
/// fetches the full set itself — see [FoundAlbumBloc].
class FoundAlbumPage extends StatelessWidget {
  const FoundAlbumPage({
    super.key,
    required this.album,
    this.filters = FoundFilters.none,
  });

  final FoundAlbum album;

  /// The feed's active selection, so the album shows the same subset the user
  /// was looking at rather than silently widening.
  final FoundFilters filters;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FoundAlbumBloc(
        getFoundPhotosUseCase: sl<GetFoundPhotosUseCase>(),
        eventId: album.id,
        filters: filters,
      )..add(const FoundAlbumPhotosRequested()),
      child: _FoundAlbumView(album: album),
    );
  }
}

class _FoundAlbumView extends StatelessWidget {
  const _FoundAlbumView({required this.album});

  final FoundAlbum album;

  void _openViewer(BuildContext context, List<Photo> photos, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoundPhotoViewerPage(photos: photos, initialIndex: index),
      ),
    );
  }

  bool _onScroll(BuildContext context, ScrollNotification n, FoundAlbumState s) {
    if (!s.hasMore || s.isLoadingMore || s.isLoading) return false;
    if (n.metrics.pixels >=
        n.metrics.maxScrollExtent - n.metrics.viewportDimension) {
      context.read<FoundAlbumBloc>().add(
            const FoundAlbumPhotosRequested(loadMore: true),
          );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        centerTitle: true,
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          album.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocBuilder<FoundAlbumBloc, FoundAlbumState>(
        builder: (context, state) {
          // The preview photos are already in hand, so show them immediately
          // and let the full set replace them — no empty spinner screen.
          final photos = state.photos.isEmpty ? album.photos : state.photos;

          if (state.errorMessage != null && state.photos.isEmpty) {
            return AppErrorView(
              message: state.errorMessage!,
              icon: Icons.wifi_off_outlined,
              onRetry: () => context
                  .read<FoundAlbumBloc>()
                  .add(const FoundAlbumPhotosRequested()),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (n) => _onScroll(context, n, state),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                  sliver: SliverToBoxAdapter(
                    child: FoundPhotoGrid(
                      photos: photos,
                      onPhotoTap: (i) => _openViewer(context, photos, i),
                    ),
                  ),
                ),
                if (state.isLoading || state.isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: AppSpacing.xl.h),
                      child: const AppLoadingIndicator(),
                    ),
                  ),
                // Clears the floating bottom nav bar.
                SliverToBoxAdapter(child: SizedBox(height: 96.h)),
              ],
            ),
          );
        },
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
