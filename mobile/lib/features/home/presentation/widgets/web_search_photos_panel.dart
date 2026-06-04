import 'dart:ui';

import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/search_results_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Full-page, routed version of [WebSearchPhotosPanel] used on web so that
/// selecting an event from the sidebar search opens the photos regardless of
/// which page/tab the user is currently on. The back/close arrow pops the
/// route, returning to wherever the user was. The caller must provide the
/// [HomeBloc] (already loaded via HomeImagesSearched) above this widget.
class WebSearchPhotosPage extends StatelessWidget {
  const WebSearchPhotosPage({super.key, required this.eventName});

  final String eventName;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: webWrap(
        WebSearchPhotosPanel(
          ext: ext,
          eventName: eventName,
          onBack: () => Navigator.of(context).maybePop(),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        backgroundColor: ext.homeBackground,
        width: kWebColumnWidthWide,
      ),
    );
  }
}

/// Web-desktop inline photo-results panel.
///
/// Shown as a [Positioned.fill] overlay inside the home content column when
/// the user taps an event from the search suggestions on a laptop/desktop
/// browser.  Results appear immediately — no Navigator page push.
///
/// Free photos can be saved in one tap.  Paid / selection flows navigate to
/// [SearchResultsPage] for the full purchase UI.
class WebSearchPhotosPanel extends StatelessWidget {
  const WebSearchPhotosPanel({
    super.key,
    required this.ext,
    required this.eventName,
    required this.onBack,
    required this.onClose,
  });

  final AppThemeExtension ext;
  final String eventName;

  /// Return to the event-suggestions list.
  final VoidCallback onBack;

  /// Close the entire search overlay.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          prev.savedFreeCount != curr.savedFreeCount ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        if (state.savedFreeCount != null) {
          AppSnackBar.success(
            context,
            '${state.savedFreeCount} photo(s) saved to your gallery.',
          );
        } else if (state.errorMessage != null) {
          AppSnackBar.error(context, state.errorMessage!);
        }
      },
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              ext: ext,
              eventName: eventName,
              onBack: onBack,
              onClose: onClose,
            ),
            // Thin progress bar while saving
            if (state.isSavingFree)
              LinearProgressIndicator(
                color: ext.accentGold,
                backgroundColor: ext.accentGold.withValues(alpha: 0.15),
                minHeight: 2,
              ),
            Expanded(child: _Body(ext: ext, state: state)),
            if (state.searchImages.isNotEmpty && !state.isLoadingImages)
              _BottomBar(ext: ext, state: state),
          ],
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.ext,
    required this.eventName,
    required this.onBack,
    required this.onClose,
  });

  final AppThemeExtension ext;
  final String eventName;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 16.w, 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // ← back to event list
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Semantics(button: true, label: 'Back', child: GestureDetector(
              onTap: onBack,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded,
                        color: ext.greetingColor, size: 14.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'Search results',
                      style: TextStyle(
                          color: ext.searchHintColor, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            )),
          ),
          SizedBox(width: 8.w),
          Icon(Icons.chevron_right_rounded,
              color: ext.searchHintColor.withValues(alpha: 0.5), size: 14),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.w700,
                fontSize: 14.sp,
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Semantics(button: true, label: 'Close', child: GestureDetector(
              onTap: onClose,
              child: Icon(Icons.close_rounded,
                  color: ext.searchHintColor, size: 20),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.ext, required this.state});

  final AppThemeExtension ext;
  final HomeState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingImages && state.searchImages.isEmpty) {
      return _Loading(ext: ext);
    }
    if (state.searchImages.isEmpty) {
      return _Empty(ext: ext);
    }
    return _PhotoGrid(ext: ext, photos: state.searchImages,
        loadingMore: state.isLoadingImages);
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  const _Loading({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_rounded,
              size: 52.sp, color: ext.accentGold.withValues(alpha: 0.7)),
          SizedBox(height: 20.h),
          SizedBox(
            width: 200.w,
            child: LinearProgressIndicator(
              color: ext.accentGold,
              backgroundColor: ext.accentGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4.r),
              minHeight: 4.h,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'Scanning photos…',
            style: TextStyle(
                color: ext.greetingColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            'This may take a moment',
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_search_outlined, size: 56.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text('No photos found for this event',
              style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp)),
        ],
      ),
    );
  }
}

// ── Photo grid ────────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.ext,
    required this.photos,
    required this.loadingMore,
  });

  final AppThemeExtension ext;
  final List<Photo> photos;
  final bool loadingMore;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = responsiveColumnCount(constraints.maxWidth, minColWidth: 160);
        return CustomScrollView(
          cacheExtent: 800,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(10.w, 12.h, 10.w, 16.h),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: cols,
                mainAxisSpacing: 8.h,
                crossAxisSpacing: 8.w,
                childCount: photos.length,
                itemBuilder: (_, i) => _PhotoCard(photo: photos[i], ext: ext),
              ),
            ),
            if (loadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Center(
                    child: SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Single photo card ─────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo, required this.ext});

  final Photo photo;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isPaid = photo.price > 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Stack(
        children: [
          SkidooImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            width: double.infinity,
            semanticLabel: 'Photo',
            placeholder: (_, __) => Container(
              height: 150.h,
              color: ext.searchFieldFill,
              child: Center(
                child: SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                      color: ext.accentGold, strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 150.h,
              color: ext.searchFieldFill,
              child: Icon(Icons.broken_image_outlined,
                  color: ext.searchHintColor, size: 24.sp),
            ),
          ),
          // Price badge
          Positioned(
            left: 8.w,
            bottom: 8.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: isPaid
                          ? ext.accentGold.withValues(alpha: 0.60)
                          : Colors.white.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaid
                            ? Icons.sell_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isPaid
                            ? ext.accentGold
                            : Colors.white.withValues(alpha: 0.90),
                        size: 9.sp,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        isPaid
                            ? 'GHS ${photo.price.toStringAsFixed(2)}'
                            : 'Free',
                        style: TextStyle(
                          color: isPaid
                              ? ext.accentGold
                              : Colors.white.withValues(alpha: 0.92),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ─────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.ext, required this.state});

  final AppThemeExtension ext;
  final HomeState state;

  double _total(Iterable<Photo> photos) =>
      photos.fold(0.0, (s, p) => s + p.price);

  @override
  Widget build(BuildContext context) {
    final photos = state.searchImages;
    final allTotal = _total(photos);
    final freePhotos = photos.where((p) => p.price == 0).toList();
    final hasPaid = allTotal > 0;
    final busy = state.isSavingFree;

    return Container(
      decoration: BoxDecoration(
        color: ext.glassFill,
        border: Border(top: BorderSide(color: ext.glassBorder, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
          child: Row(
            children: [
              // Primary action
              Expanded(
                child: _PanelBtn(
                  ext: ext,
                  label: hasPaid
                      ? 'Pay  ·  GHS ${allTotal.toStringAsFixed(2)}'
                      : 'Save All ${photos.length} Photos',
                  icon: hasPaid
                      ? Icons.lock_open_rounded
                      : Icons.download_for_offline_rounded,
                  primary: true,
                  loading: !hasPaid && busy,
                  disabled: busy,
                  onTap: hasPaid
                      ? () => _openFull(context)
                      : () {
                          context
                              .read<HomeBloc>()
                              .add(HomeFreeImagesSaved(freePhotos));
                        },
                ),
              ),
              SizedBox(width: 10.w),
              // Secondary: open SearchResultsPage for selection / pick mode
              _PanelBtn(
                ext: ext,
                label: 'Pick Photos',
                icon: Icons.checklist_rounded,
                primary: false,
                loading: false,
                disabled: busy,
                onTap: () => _openFull(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens [SearchResultsPage] for detailed selection / payment flows.
  void _openFull(BuildContext context) {
    final homeBloc = context.read<HomeBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: homeBloc,
          child: const SearchResultsPage(),
        ),
      ),
    );
  }
}

class _PanelBtn extends StatelessWidget {
  const _PanelBtn({
    required this.ext,
    required this.label,
    required this.icon,
    required this.primary,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final AppThemeExtension ext;
  final String label;
  final IconData icon;
  final bool primary;
  final bool loading;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? ext.accentGold : ext.searchFieldFill;
    final fg = primary ? Colors.black : ext.greetingColor;

    return Semantics(button: true, label: label, child: GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          height: 44.h,
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: primary
                ? null
                : Border.all(
                    color: ext.searchHintColor.withValues(alpha: 0.3),
                    width: 1),
          ),
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(color: fg, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: fg, size: 16.sp),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ));
  }
}
