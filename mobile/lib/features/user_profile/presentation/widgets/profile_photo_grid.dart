import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_photo_tile.dart';

/// The three-column grid behind the profile's Liked and Saved tabs.
///
/// Its own file because the paging is the part that keeps going wrong and it
/// was untestable as a private class: a grid that cannot ask for a second page
/// looks exactly like a grid that has reached the end.

class ProfilePhotoGrid extends StatefulWidget {
  const ProfilePhotoGrid({
    required this.photos,
    required this.loading,
    required this.ext,
    required this.emptyTitle,
    required this.emptyHint,
    this.emptyIcon = Icons.photo_library_outlined,
    this.removeIcon,
    this.removeTooltip,
    this.onRemove,
    required this.onOpen,
    this.onLoadMore,
    this.loadingMore = false,
  });

  final List<ProfilePhoto> photos;
  final bool loading;

  /// Fetches the next page, or null when there is nothing more to fetch.
  final VoidCallback? onLoadMore;

  /// Whether that fetch is in the air, so the grid can say so rather than
  /// ending in what looks like the last row.
  final bool loadingMore;
  final AppThemeExtension ext;
  final String emptyTitle;
  final String emptyHint;

  /// The glyph in the empty state. Defaults to a generic photo stack; a tab
  /// with an icon of its own should pass that one, so the empty screen looks
  /// like the tab it is in.
  final IconData emptyIcon;

  /// The filled heart / bookmark on each tile — tapping it takes the photo out
  /// of the list it is in.
  ///
  /// Omitted together for a grid with nothing to remove. The Purchased tab is
  /// the one: un-liking and un-bookmarking undo something free and reversible,
  /// and a purchase is neither.
  final IconData? removeIcon;
  final String? removeTooltip;
  final Future<void> Function(ProfilePhoto)? onRemove;

  /// Tapping the tile opens what it stands for.
  final void Function(ProfilePhoto) onOpen;

  @override
  State<ProfilePhotoGrid> createState() => _ProfilePhotoGridState();
}

class _ProfilePhotoGridState extends State<ProfilePhotoGrid> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  @override
  void didUpdateWidget(ProfilePhotoGrid old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewport());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Keep asking while the grid is too short to scroll.
  ///
  /// The scroll listener below can only fire if there is a scroll, and a first
  /// page that does not fill the screen leaves nothing to drag — so the reader
  /// sees a part-full grid, scrolls, nothing moves, and nothing more ever
  /// loads. A page of ten in a three-column grid is four rows, which on a tall
  /// phone is exactly that case.
  void _fillViewport() {
    if (!mounted) return;
    if (widget.onLoadMore == null || widget.loadingMore) return;
    if (!_controller.hasClients) return;
    if (_controller.position.maxScrollExtent > 0) return;
    widget.onLoadMore!();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final ext = widget.ext;
    final onLoadMore = widget.onLoadMore;
    final loadingMore = widget.loadingMore;
    final removeIcon = widget.removeIcon;
    final removeTooltip = widget.removeTooltip;
    final onRemove = widget.onRemove;
    final onOpen = widget.onOpen;

    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photos.isEmpty) {
      return _Empty(
        title: widget.emptyTitle,
        hint: widget.emptyHint,
        icon: widget.emptyIcon,
      );
    }

    return NotificationListener<ScrollNotification>(
      // Asked for before the reader reaches the bottom, so the next page is
      // usually there by the time they would have seen the end.
      onNotification: (notification) {
        if (onLoadMore == null || loadingMore) return false;
        final metrics = notification.metrics;
        if (metrics.axis != Axis.vertical) return false;
        if (metrics.pixels >= metrics.maxScrollExtent - 400) onLoadMore();
        return false;
      },
      child: GridView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.all(2.w),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: photos.length + (loadingMore ? 3 : 0),
        itemBuilder: (_, i) {
          // The trailing row while a page is on its way. Three cells rather
          // than one, so the grid keeps its shape instead of ending on a
          // ragged part-row.
          if (i >= photos.length) {
            return Center(
              child: SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ext.accentGold),
              ),
            );
          }
          final photo = photos[i];
          return ProfilePhotoTile(
            photo: photo,
            ext: ext,
            removeIcon: removeIcon,
            removeTooltip: removeTooltip,
            onRemove: onRemove == null ? null : () => onRemove(photo),
            onOpen: () => onOpen(photo),
          );
        },
      ),
    );
  }
}

/// Nothing in this tab yet.
///
/// Was its own drawing — a half-faded glyph 80px from the top, and a title in
/// body type where every other empty state in the app uses Syne. Now the
/// shared one, wrapped so the pull-to-refresh above it still has something to
/// drag.
class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint, required this.icon});

  final String title;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ScrollableEmptyState(
        child: AppEmptyState(icon: icon, message: title, hint: hint),
      );
}
