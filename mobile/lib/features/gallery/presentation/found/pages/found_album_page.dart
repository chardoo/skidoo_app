import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_album_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:jperg_app/core/purchase/photo_checkout.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_grid.dart';
import 'package:jperg_app/core/purchase/photo_purchase_bar.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Every photo of one event, in the same grid the Found feed previews it with.
///
/// The feed's [FoundAlbum] only holds the server's preview slice, so this page
/// fetches the full set itself — see [FoundAlbumBloc].
class FoundAlbumPage extends StatelessWidget {
  const FoundAlbumPage({
    super.key,
    required this.album,
    this.filters = FoundFilters.none,
    this.reviewMode = false,
  });

  final FoundAlbum album;

  /// True for the screen a scan lands on: every match arrives selected and the
  /// page asks which ones aren't you. False — the default — is browsing the
  /// album from the Found tab, where nothing is selected until it is chosen.
  /// See PhotoSelection.
  final bool reviewMode;

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
      child: _FoundAlbumView(album: album, reviewMode: reviewMode),
    );
  }
}

class _FoundAlbumView extends StatefulWidget {
  const _FoundAlbumView({required this.album, required this.reviewMode});

  final FoundAlbum album;
  final bool reviewMode;

  @override
  State<_FoundAlbumView> createState() => _FoundAlbumViewState();
}

class _FoundAlbumViewState extends State<_FoundAlbumView> {
  /// Scoped to this page and discarded with it — see [PhotoSelection].
  late final _selection = PhotoSelection(reviewMode: widget.reviewMode);

  bool _checkingOut = false;

  FoundAlbum get album => widget.album;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _openViewer(BuildContext context, List<Photo> photos, int index) {
    Navigator.of(context).push(
      NoSwipeBackPageRoute<void>(
        builder: (_) => FoundPhotoViewerPage(
          photos: photos,
          initialIndex: index,
          selection: _selection,
          // Found you: see FoundPhotoViewerPage.purchaseGated.
          purchaseGated: true,
          // Puts the album name in the bar and the counter on the photo.
          title: album.title,
          // Popped back to this page first, so checkout runs against the
          // album's CartBloc listener.
          onCheckout: () => _checkout(context),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context) async {
    setState(() => _checkingOut = true);
    try {
      await runPhotoCheckout(context, _selection);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  bool _onScroll(
      BuildContext context, ScrollNotification n, FoundAlbumState s) {
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
        leading: const AppBackButton(),
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
      body: PhotoCheckoutListener(
        // The kept set has been bought; reopening the album should show it
        // owned rather than still up for sale.
        onSuccess: _selection.clear,
        child: BlocBuilder<FoundAlbumBloc, FoundAlbumState>(
          builder: (context, state) {
            // The preview photos are already in hand, so show them immediately
            // and let the full set replace them — no empty spinner screen.
            final photos = state.photos.isEmpty ? album.photos : state.photos;

            // Keeps the selection's totals in step as more pages arrive. After
            // the frame, because this runs during build.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selection.updatePhotos(photos);
            });

            if (state.errorMessage != null && state.photos.isEmpty) {
              return AppErrorView(
                message: state.errorMessage!,
                icon: Icons.wifi_off_outlined,
                onRetry: () => context
                    .read<FoundAlbumBloc>()
                    .add(const FoundAlbumPhotosRequested()),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) => _onScroll(context, n, state),
                    child: CustomScrollView(
                      slivers: [
                        // Review only. On the browsing screen nothing is
                        // selected, so an instruction to deselect would be
                        // describing something that is not on screen.
                        if (widget.reviewMode)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(AppSpacing.md.w, 0,
                                  AppSpacing.md.w, AppSpacing.md.h),
                              child: Text(
                                "Tap to deselect photos that aren't you",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ext.searchHintColor,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding:
                              EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
                          sliver: SliverToBoxAdapter(
                            child: FoundPhotoGrid(
                              photos: photos,
                              selection: _selection,
                              onPhotoTap: (i) =>
                                  _openViewer(context, photos, i),
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
                  ),
                ),
                PhotoPurchaseBar(
                  selection: _selection,
                  isBusy: _checkingOut,
                  onCheckout: () => _checkout(context),
                ),
              ],
            );
          },
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
