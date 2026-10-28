import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_photo_tile.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

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
    this.emptyIcon = AppIcons.camera,
    this.removeIcon,
    this.removeTooltip,
    this.onRemove,
    required this.onOpen,
    this.onLoadMore,
    this.loadingMore = false,
    this.header,
    this.failed = false,
    this.onRetry,
  });

  /// The last fetch for this grid failed.
  ///
  /// Distinct from having nothing, and the distinction is the whole reason
  /// this exists. The loaders behind these tabs caught their errors into a
  /// `debugPrint` and left the list as it was, so a 500 drew "Nothing liked
  /// yet" — the app stating as fact something it had just failed to find out.
  /// A real bug in the like endpoint sat behind that wording for as long as it
  /// did because the screen was reassuring about it.
  ///
  /// Only consulted when there is nothing to show. A grid that already has a
  /// page keeps drawing it: a failed *refresh* of something correct on screen
  /// is not worth replacing it with an apology.
  final bool failed;

  /// Runs the fetch again. Null leaves the failure state without a way out,
  /// which is worth avoiding wherever the caller can reload.
  final VoidCallback? onRetry;

  /// Drawn above the grid, inside the same scroll view.
  ///
  /// Inside rather than stacked above it in a Column because this tab has one
  /// scrollable and must keep having one: two would mean the header scrolling
  /// independently of the photos under it, and the pull-to-refresh wrapping
  /// this grid would stop reaching the top.
  ///
  /// Shown in every state, including the empty one. "My Events" sits above
  /// Purchased, and somebody who owns an album but has never bought a photo
  /// is precisely who needs to see it — the old empty state replaced the
  /// whole tab, header and all.
  final Widget? header;

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
  final String emptyIcon;

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

    // With a header, every state is the same scroll view with a different
    // sliver under the header — otherwise "loading" and "empty" would each
    // return a widget that throws the header away.
    if (widget.header != null) {
      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (onLoadMore == null || loadingMore) return false;
          final metrics = notification.metrics;
          if (metrics.axis != Axis.vertical) return false;
          if (metrics.pixels >= metrics.maxScrollExtent - 400) onLoadMore();
          return false;
        },
        child: CustomScrollView(
          controller: _controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: widget.header),
            if (widget.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (photos.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: widget.failed
                      ? _Failed(onRetry: widget.onRetry)
                      : AppEmptyState(
                          icon: widget.emptyIcon,
                          message: widget.emptyTitle,
                          hint: widget.emptyHint,
                        ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.all(2.w),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
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
                        onRemove:
                            onRemove == null ? null : () => onRemove(photo),
                        onOpen: () => onOpen(photo),
                      );
                    },
                    childCount: photos.length + (loadingMore ? 3 : 0),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photos.isEmpty) {
      if (widget.failed) return _Failed(onRetry: widget.onRetry);
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
  final String icon;

  @override
  Widget build(BuildContext context) => ScrollableEmptyState(
        child: AppEmptyState(icon: icon, message: title, hint: hint),
      );
}

/// "We could not load this", as opposed to "there is nothing here".
///
/// Says the app failed rather than that the reader has nothing, and offers the
/// one useful thing — asking again. Drawn through [AppEmptyState] like every
/// other empty screen, so a tab that could not load still looks like this app.
class _Failed extends StatelessWidget {
  const _Failed({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ScrollableEmptyState(
        child: AppEmptyState(
          icon: AppIcons.warning,
          message: 'Could not load this',
          hint: onRetry == null
              ? 'Check your connection and come back in a moment.'
              : ' to load it again.',
          actionLabel: onRetry == null ? null : 'Tap here',
          onAction: onRetry,
        ),
      );
}
