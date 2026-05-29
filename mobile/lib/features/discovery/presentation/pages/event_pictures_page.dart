import 'dart:ui' show ImageFilter;

import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/api/dio_client_service.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/common/widgets/get_app_sheet.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/models/photo_comment/photo_comment.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

// ── Flat entry: one picture + its parent event metadata ──────────────────────

class _PicEntry {
  const _PicEntry({
    required this.picture,
    required this.eventName,
    required this.photographerName,
    required this.eventCommentsEnabled,
  });

  final EventPicture picture;
  final String eventName;
  final String photographerName;
  final bool eventCommentsEnabled;

  bool get commentsAllowed => eventCommentsEnabled && picture.commentsEnabled;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class EventPicturesPage extends StatefulWidget {
  const EventPicturesPage({super.key, required this.event});
  final EventDiscovery event;

  @override
  State<EventPicturesPage> createState() => _EventPicturesPageState();
}

class _EventPicturesPageState extends State<EventPicturesPage> {
  List<_PicEntry> get _entries => widget.event.pictures
      .map((p) => _PicEntry(
            picture: p,
            eventName: widget.event.eventName,
            photographerName: widget.event.photographerName,
            eventCommentsEnabled: widget.event.commentsEnabled,
          ))
      .toList();

  @override
  void initState() {
    super.initState();
    // Fire-and-forget view signal — non-fatal if it fails.
    sl<Api>()
        .dio
        .post('/recommend/${widget.event.id}/view')
        .then((_) => debugPrint(
            '[EventView] tracked view for event ${widget.event.id}'))
        .catchError((e) => debugPrint('[EventView] view tracking failed: $e'));
  }

  void _openFullscreen(BuildContext context, int idx) {
    final entries = _entries;
    if (entries.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _FullscreenViewerPage(
        entries: entries,
        initialIndex: idx.clamp(0, entries.length - 1),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = event.pictures;

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        cacheExtent: 600,
        slivers: [
          // ── App bar ───────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: kIsWeb ? null : IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: ext.greetingColor, size: 18.sp),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.eventName,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 16.sp,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.photographerName.isNotEmpty) ...[
                  SizedBox(height: 1.h),
                  Row(
                    children: [
                      Icon(Icons.photo_camera_rounded,
                          size: 10.sp,
                          color: ext.searchHintColor.withValues(alpha: 0.7)),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: Text(
                          event.photographerName,
                          style: TextStyle(
                            color: ext.searchHintColor
                                .withValues(alpha: 0.7),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              if (pics.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: ext.accentGold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(
                        color: ext.accentGold.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_outlined,
                            size: 11.sp, color: ext.accentGold),
                        SizedBox(width: 3.w),
                        Text(
                          '${pics.length}',
                          style: TextStyle(
                            color: ext.accentGold,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 0.5,
                color: ext.searchHintColor.withValues(alpha: 0.12),
              ),
            ),
          ),

          // ── Masonry grid ──────────────────────────────────────────────────
          if (pics.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12.w, 14.h, 12.w, 24.h),
              sliver: SliverToBoxAdapter(
                child: _MasonryGrid(
                  pictures: pics,
                  extraCount: 0,
                  startIndex: 0,
                  onTap: (idx) => _openFullscreen(context, idx),
                ),
              ),
            ),

          // ── Empty state ───────────────────────────────────────────────────
          if (pics.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        size: 48.sp, color: ext.searchHintColor),
                    SizedBox(height: 12.h),
                    Text('No media available',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 14.sp)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}

// ── Masonry grid (2-column) ───────────────────────────────────────────────────

class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({
    required this.pictures,
    required this.extraCount,
    required this.startIndex,
    required this.onTap,
  });

  final List<EventPicture> pictures;
  final int extraCount;
  final int startIndex;
  final void Function(int globalIdx) onTap;

  static const _leftH  = [210.0, 170.0, 195.0, 165.0, 200.0, 175.0];
  static const _rightH = [175.0, 200.0, 165.0, 195.0, 170.0, 210.0];

  @override
  Widget build(BuildContext context) {
    final leftItems  = <(int, EventPicture)>[];
    final rightItems = <(int, EventPicture)>[];
    int lc = 0, rc = 0;
    for (int i = 0; i < pictures.length; i++) {
      if (i.isEven) {
        leftItems.add((lc++, pictures[i]));
      } else {
        rightItems.add((rc++, pictures[i]));
      }
    }

    Widget tile(int colIdx, EventPicture pic, bool isLeft) {
      final picGlobal = isLeft
          ? startIndex + colIdx * 2
          : startIndex + colIdx * 2 + 1;
      final h = isLeft
          ? _leftH[colIdx % _leftH.length].h
          : _rightH[colIdx % _rightH.length].h;

      return Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: RepaintBoundary(
          child: _MediaTile(
            picture: pic,
            height: h,
            onTap: () => onTap(picGlobal),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (final (ci, pic) in leftItems) tile(ci, pic, true),
            ],
          ),
        ),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            children: [
              SizedBox(height: 44.h),
              for (final (ci, pic) in rightItems) tile(ci, pic, false),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Media tile (image or video) ───────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.picture,
    required this.height,
    required this.onTap,
  });

  final EventPicture picture;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: picture.isVideo
              ? _VideoThumbTile(url: picture.url)
              : _PhotoTile(url: picture.url),
        ),
      ),
    );
  }
}

// ── Photo tile ────────────────────────────────────────────────────────────────

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return SkidooImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 280),
      placeholder: (_, __) => const ColoredBox(color: Color(0xFF141414)),
      errorWidget: (_, __, ___) => ColoredBox(
        color: const Color(0xFF141414),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white12, size: 22.sp),
        ),
      ),
    );
  }
}

// ── Video thumbnail tile ──────────────────────────────────────────────────────
/// Shows the first video frame (paused, no controls) as a grid thumbnail
/// with a play badge overlay.

class _VideoThumbTile extends StatelessWidget {
  const _VideoThumbTile({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SkidooVideoPlayer(
          url: url,
          autoPlay: false,
          showControls: false,
          fit: BoxFit.cover,
          backgroundColor: const Color(0xFF141414),
        ),
        // Play badge
        Center(
          child: Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.2),
            ),
            child: Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 20.sp),
          ),
        ),
      ],
    );
  }
}

// ── Fullscreen viewer page ─────────────────────────────────────────────────────

class _FullscreenViewerPage extends StatefulWidget {
  const _FullscreenViewerPage({
    required this.entries,
    required this.initialIndex,
  });

  final List<_PicEntry> entries;
  final int initialIndex;

  @override
  State<_FullscreenViewerPage> createState() => _FullscreenViewerPageState();
}

class _FullscreenViewerPageState extends State<_FullscreenViewerPage> {
  late final PageController _pageCtrl;
  final _activeIndex = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _activeIndex.value = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _pageCtrl.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onPageChanged);
    _pageCtrl.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _onPageChanged() {
    final page = _pageCtrl.page?.round() ?? 0;
    if (page != _activeIndex.value) _activeIndex.value = page;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen vertical PageView
          PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            physics: const PageScrollPhysics(),
            itemCount: widget.entries.length,
            itemBuilder: (_, i) => _FeedCard(
              key: ValueKey(widget.entries[i].picture.id),
              entry: widget.entries[i],
              index: i,
              activeIndex: _activeIndex,
            ),
          ),

          // Back button — hidden on web (no back button on desktop/laptop)
          if (!kIsWeb)
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(left: 14.w, top: 10.h),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16.sp),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Full-screen feed card ─────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  const _FeedCard({
    super.key,
    required this.entry,
    required this.index,
    required this.activeIndex,
  });

  final _PicEntry entry;
  final int index;
  final ValueNotifier<int> activeIndex;

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  PhotoComment? _topComment;
  bool _commentFetched = false;

  @override
  void initState() {
    super.initState();
    widget.activeIndex.addListener(_onActiveChanged);
    if (widget.activeIndex.value == widget.index) _fetchComment();
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onActiveChanged);
    super.dispose();
  }

  void _onActiveChanged() {
    if (widget.activeIndex.value == widget.index && !_commentFetched) {
      _fetchComment();
    }
  }

  void _fetchComment() {
    if (_commentFetched) return;
    _commentFetched = true;
    sl<PhotoCommentRemoteDataSource>()
        .getComments(widget.entry.picture.id, page: 1, limit: 1)
        .then((list) {
      if (mounted && list.isNotEmpty) setState(() => _topComment = list.first);
    }).catchError((_) {});
  }

  static List<String> _hashtags(String eventName, String photographerName) {
    final words = eventName
        .split(RegExp(r'[\s\-_&]+'))
        .where((w) => w.length > 2)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .toList();
    final tags = <String>[];
    if (words.isNotEmpty) tags.add('#${words.join('')}');
    if (photographerName.isNotEmpty) {
      final clean = photographerName.replaceAll(RegExp(r'\s+'), '');
      tags.add('#${clean}Photography');
    }
    tags.add('#skidoo');
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pic = widget.entry.picture;
    final eventName = widget.entry.eventName;
    final photographerName = widget.entry.photographerName;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final sidebarBottom = (pic.isVideo ? 110.h : 64.h) + bottomPad;
    final infoBottom = (pic.isVideo ? 100.h : 54.h) + bottomPad;

    return Stack(
      fit: StackFit.expand,
      children: [
        pic.isVideo
            ? _VideoBackground(
                url: pic.url,
                index: widget.index,
                activeIndex: widget.activeIndex,
              )
            : _PhotoBackground(url: pic.url),

        // Bottom gradient
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Top gradient
        Positioned(
          left: 0, right: 0, top: 0,
          child: SizedBox(
            height: 120.h,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Action sidebar
        Positioned(
          right: 10.w,
          bottom: sidebarBottom,
          child: MediaActionButtons(
            imageId: pic.id,
            pictureId: pic.id,
            imageUrl: pic.url,
            eventName: eventName,
            photographerName: photographerName,
            initialLikeCount: pic.likeCount,
            initialCommentCount: pic.commentCount,
            initiallyLiked: pic.isLikedByUser,
            axis: Axis.vertical,
            showDownload: false,
            showComment: widget.entry.commentsAllowed,
            onSend: () {
              if (kIsWeb) {
                final ext = Theme.of(context).extension<AppThemeExtension>()!;
                GetAppSheet.show(context, ext: ext);
                return;
              }
              GalleryShareSheet.show(
                context,
                imageUrl: pic.url,
                photoLabel: eventName,
              );
            },
          ),
        ),

        // Info overlay
        Positioned(
          left: 16.w,
          right: 76.w,
          bottom: infoBottom,
          child: _InfoOverlay(
            eventName: eventName,
            photographerName: photographerName,
            hashtags: _hashtags(eventName, photographerName),
            topComment: _topComment,
          ),
        ),
      ],
    );
  }
}

// ── Info overlay ──────────────────────────────────────────────────────────────

class _InfoOverlay extends StatelessWidget {
  const _InfoOverlay({
    required this.eventName,
    required this.photographerName,
    required this.hashtags,
    required this.topComment,
  });

  final String eventName;
  final String photographerName;
  final List<String> hashtags;
  final PhotoComment? topComment;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _InitialsAvatar(name: photographerName, size: 30.w),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                photographerName.isNotEmpty ? photographerName : 'Creator',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5A623).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: Text(
                'creator',
                style: TextStyle(
                  color: const Color(0xFFF5A623),
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 9.h),
        Text(
          eventName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            height: 1.2,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 1)),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 7.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 2.h,
          children: hashtags
              .map((tag) => Text(
                    tag,
                    style: TextStyle(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.9),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ))
              .toList(),
        ),
        if (topComment != null) ...[
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14), width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1.h),
                  child: Icon(Icons.chat_bubble_rounded,
                      color: Colors.white54, size: 11.sp),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${topComment!.userName}  ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp,
                          ),
                        ),
                        TextSpan(
                          text: topComment!.content,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Initials avatar ───────────────────────────────────────────────────────────

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5A623), Color(0xFFD4840F)],
        ),
      ),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.38,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Photo background ──────────────────────────────────────────────────────────

class _PhotoBackground extends StatelessWidget {
  const _PhotoBackground({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: Color(0xFF0D0D0D),
      child: Center(
        child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
      ),
    );
    const errorWidget = ColoredBox(
      color: Color(0xFF0D0D0D),
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 48),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Blurred background fill so letterbox bars look intentional
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: SkidooImage(
            imageUrl: url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            placeholder: (_, __) => placeholder,
            errorWidget: (_, __, ___) => errorWidget,
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        // Full image — physical-pixel resolution, no cap
        SkidooImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => placeholder,
          errorWidget: (_, __, ___) => errorWidget,
          colorFilter: const ColorFilter.matrix(<double>[
            1.18, -0.06, -0.06, 0, 18,
            -0.05,  1.16, -0.05, 0, 18,
            -0.05, -0.05,  1.20, 0, 18,
            0,     0,     0,     1, 0,
          ]),
        ),
      ],
    );
  }
}

// ── Video background ──────────────────────────────────────────────────────────
/// Full-screen video for the event viewer carousel. Plays only when this
/// page is the active one (activeIndex == index).

class _VideoBackground extends StatefulWidget {
  const _VideoBackground({
    required this.url,
    required this.index,
    required this.activeIndex,
  });

  final String url;
  final int index;
  final ValueNotifier<int> activeIndex;

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  @override
  void initState() {
    super.initState();
    widget.activeIndex.addListener(_onIndexChanged);
  }

  void _onIndexChanged() => setState(() {});

  @override
  void dispose() {
    widget.activeIndex.removeListener(_onIndexChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SkidooVideoPlayer(
      url: widget.url,
      isActive: widget.activeIndex.value == widget.index,
      autoPlay: true,
      loop: true,
      fit: BoxFit.contain,
      backgroundColor: Colors.black,
      showControls: true,
      allowFullscreen: true,
    );
  }
}
