import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/domain/usecases/get_random_images_usecase.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/pictures_fullscreen_viewer.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:video_player/video_player.dart';

// ── Flat entry: one picture + its parent event metadata ──────────────────────

class _PicEntry {
  const _PicEntry({
    required this.picture,
    required this.eventName,
    required this.photographerName,
  });

  final EventPicture picture;
  final String eventName;
  final String photographerName;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class EventPicturesPage extends StatefulWidget {
  const EventPicturesPage({super.key, required this.event});

  final EventDiscovery event;

  @override
  State<EventPicturesPage> createState() => _EventPicturesPageState();
}

class _EventPicturesPageState extends State<EventPicturesPage> {
  final _scrollCtrl = ScrollController();

  /// Index of the item whose center is closest to the screen center.
  /// -1 = no video should play (fullscreen viewer is open).
  final _activeIndex = ValueNotifier<int>(0);

  /// Flat list of all pictures across all loaded events.
  late final List<_PicEntry> _entries;

  /// One GlobalKey per entry — only items in cache extent have a live context.
  late final List<GlobalKey> _itemKeys;

  bool _fullscreenOpen = false;
  bool _isLoadingMore = false;

  // Track item height so scroll-to-end threshold is correct.
  double _itemH = 0;

  @override
  void initState() {
    super.initState();
    _entries = widget.event.pictures
        .map((p) => _PicEntry(
              picture: p,
              eventName: widget.event.eventName,
              photographerName: widget.event.photographerName,
            ))
        .toList();
    _itemKeys = List.generate(_entries.length, (_) => GlobalKey());
    _scrollCtrl.addListener(_onScroll);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _updateActiveItem());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _onScroll() {
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _updateActiveItem());
    _maybeLoadMore();
  }

  void _maybeLoadMore() {
    if (_isLoadingMore) return;
    if (!_scrollCtrl.hasClients) return;
    final maxExt = _scrollCtrl.position.maxScrollExtent;
    final threshold = _itemH > 0 ? _itemH * 2.5 : 600;
    if (_scrollCtrl.position.pixels >= maxExt - threshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      String? userId;
      try {
        userId = await sl<AuthService>().getUserId();
      } catch (_) {}

      final events = await sl<GetRandomImagesUseCase>().call(
        take: 5,
        userId: userId,
      );

      if (!mounted) return;

      final newEntries = <_PicEntry>[];
      for (final event in events) {
        for (final pic in event.pictures) {
          newEntries.add(_PicEntry(
            picture: pic,
            eventName: event.eventName,
            photographerName: event.photographerName,
          ));
        }
      }

      if (newEntries.isEmpty) {
        setState(() => _isLoadingMore = false);
        return;
      }

      setState(() {
        _entries.addAll(newEntries);
        _itemKeys.addAll(List.generate(newEntries.length, (_) => GlobalKey()));
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// O(visible items) — iterates only items currently built by ListView.
  void _updateActiveItem() {
    if (!mounted || _fullscreenOpen) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final screenCenterY = screenH / 2;

    int best = _activeIndex.value.clamp(0, _entries.length - 1);
    double bestDist = double.infinity;

    for (int i = 0; i < _itemKeys.length; i++) {
      final ctx = _itemKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final centerY = top + box.size.height / 2;
      final dist = (centerY - screenCenterY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        best = i;
      }
    }

    if (best != _activeIndex.value) _activeIndex.value = best;
  }

  void _openFullscreen(int initialIndex) {
    _fullscreenOpen = true;
    _activeIndex.value = -1;

    // Build the pictures list for the fullscreen viewer scoped to the
    // current event segment so tapping fullscreen stays in context.
    final entry = _entries[initialIndex];
    final segmentPics = _entries
        .where((e) => e.eventName == entry.eventName)
        .map((e) => e.picture)
        .toList();
    final segmentIndex =
        segmentPics.indexWhere((p) => p.id == entry.picture.id);

    Navigator.of(context)
        .push(PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => PicturesFullscreenViewer(
            pictures: segmentPics,
            initialIndex: segmentIndex < 0 ? 0 : segmentIndex,
          ),
        ))
        .then((_) {
      _fullscreenOpen = false;
      _updateActiveItem();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final screenW = MediaQuery.sizeOf(context).width;
    // Full-bleed cards — no horizontal margin.
    _itemH = screenW * (5 / 4);
    final cacheExtent = _itemH * 0.8;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ValueListenableBuilder<int>(
          valueListenable: _activeIndex,
          builder: (_, idx, __) {
            final safeIdx = idx < 0 || idx >= _entries.length ? 0 : idx;
            final entry = _entries[safeIdx];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                      parent: animation, curve: Curves.easeOut)),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(entry.eventName),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.eventName,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                    ),
                  ),
                  Text(
                    'by ${entry.photographerName}',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 11.sp),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _activeIndex,
            builder: (_, idx, __) {
              final safeIdx = idx < 0 || idx >= _entries.length ? 0 : idx;
              // Count pictures in the same event segment as the active item.
              final eventName = _entries[safeIdx].eventName;
              final count = _entries
                  .where((e) => e.eventName == eventName)
                  .length;
              return Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: Center(
                  child: Text(
                    '$count items',
                    style:
                        TextStyle(color: Colors.white60, fontSize: 12.sp),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(
              child: Text(
                'No media available',
                style:
                    TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              cacheExtent: cacheExtent,
              padding: EdgeInsets.zero,
              itemCount: _entries.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, i) {
                // Subtle loading indicator appended after the last real item.
                if (i == _entries.length) {
                  return SizedBox(
                    height: 80.h,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white24,
                        strokeWidth: 1.5,
                      ),
                    ),
                  );
                }

                final entry = _entries[i];
                final isLast = i == _entries.length - 1;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MediaCard(
                      key: _itemKeys[i],
                      picture: entry.picture,
                      index: i,
                      itemHeight: _itemH,
                      activeIndex: _activeIndex,
                      onTap: () => _openFullscreen(i),
                      eventName: entry.eventName,
                      photographerName: entry.photographerName,
                    ),
                    if (!isLast) const _CardSeparator(),
                  ],
                );
              },
            ),
    );
  }
}

// ── Media card ────────────────────────────────────────────────────────────────

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    super.key,
    required this.picture,
    required this.index,
    required this.itemHeight,
    required this.activeIndex,
    required this.onTap,
    required this.eventName,
    required this.photographerName,
  });

  final EventPicture picture;
  final int index;
  final double itemHeight;
  final ValueNotifier<int> activeIndex;
  final VoidCallback onTap;
  final String eventName;
  final String photographerName;

  @override
  Widget build(BuildContext context) {
    final sidebarBottom = picture.isVideo ? 100.h : 24.h;

    return SizedBox(
      width: double.infinity,
      height: itemHeight,
      child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photo or video ──────────────────────────────────────────────
            picture.isVideo
                ? _VideoItem(
                    url: picture.url,
                    index: index,
                    height: itemHeight,
                    activeIndex: activeIndex,
                    onTap: onTap,
                  )
                : GestureDetector(
                    onTap: onTap,
                    child: _PhotoItem(url: picture.url, height: itemHeight),
                  ),

            // ── TikTok-style action sidebar ─────────────────────────────────
            Positioned(
              right: 10.w,
              bottom: sidebarBottom,
              child: MediaActionButtons(
                imageId: picture.imageId,
                pictureId: picture.id,
                imageUrl: picture.url,
                eventName: eventName,
                photographerName: photographerName,
                initialLikeCount: picture.likeCount,
                initialCommentCount: picture.commentCount,
                initiallyLiked: picture.isLikedByUser,
                axis: Axis.vertical,
              ),
            ),
          ],
      ),
    );
  }
}

// ── Photo item ────────────────────────────────────────────────────────────────

class _PhotoItem extends StatelessWidget {
  const _PhotoItem({required this.url, required this.height});

  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0A0A0A),
      child: CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: height,
      fit: BoxFit.contain,
      memCacheWidth: 800,
      filterQuality: FilterQuality.medium,
      placeholder: (_, __) => const ColoredBox(
        color: Color(0xFF111111),
        child: Center(
          child: CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => const ColoredBox(
        color: Color(0xFF111111),
        child: Center(
          child: Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 40),
        ),
      ),
    ),
    );
  }
}

// ── Video item ────────────────────────────────────────────────────────────────

class _VideoItem extends StatefulWidget {
  const _VideoItem({
    required this.url,
    required this.index,
    required this.height,
    required this.activeIndex,
    required this.onTap,
  });

  final String url;
  final int index;
  final double height;
  final ValueNotifier<int> activeIndex;
  final VoidCallback onTap;

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _manuallyPaused = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _syncPlayback();
      });
    widget.activeIndex.addListener(_syncPlayback);
  }

  @override
  void dispose() {
    widget.activeIndex.removeListener(_syncPlayback);
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  bool get _isActive => widget.activeIndex.value == widget.index;

  void _syncPlayback() {
    if (!_initialized) return;
    if (_isActive && !_manuallyPaused) {
      if (!_ctrl.value.isPlaying) _ctrl.play();
    } else {
      if (_ctrl.value.isPlaying) _ctrl.pause();
      if (!_isActive) _manuallyPaused = false;
    }
  }

  void _togglePlayback() {
    if (!_initialized) return;
    setState(() {
      if (_ctrl.value.isPlaying) {
        _ctrl.pause();
        _manuallyPaused = true;
      } else {
        _ctrl.play();
        _manuallyPaused = false;
      }
    });
  }

  void _toggleMute() {
    final newMuted = !_muted;
    setState(() => _muted = newMuted);
    _ctrl.setVolume(newMuted ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return SizedBox(
        height: widget.height,
        child: const ColoredBox(
          color: Color(0xFF0A0A0A),
          child: Center(
            child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2),
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (context, value, _) {
        final isPlaying = value.isPlaying;
        final duration = value.duration;
        final position = value.position;
        final w = value.size.width > 0 ? value.size.width : 1.0;
        final h = value.size.height > 0 ? value.size.height : 1.0;

        return SizedBox(
          width: double.infinity,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Video (fully contained, nothing cropped) ──────────────────
              GestureDetector(
                onTap: _togglePlayback,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: w / h,
                    child: VideoPlayer(_ctrl),
                  ),
                ),
              ),

              // ── Play/pause hint ───────────────────────────────────────────
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: ColoredBox(
                    color: Colors.black38,
                    child: Center(
                      child: Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white54, width: 1.5),
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 34.sp),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Duration badge (top right) ────────────────────────────────
              Positioned(
                top: 12.h,
                right: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam_rounded,
                          color: Colors.white70, size: 12.sp),
                      SizedBox(width: 4.w),
                      Text(
                        _fmt(duration),
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Fullscreen button (top left) ──────────────────────────────
              Positioned(
                top: 12.h,
                left: 12.w,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fullscreen_rounded,
                        color: Colors.white, size: 20.sp),
                  ),
                ),
              ),

              // ── Progress bar + time + mute (bottom) ───────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                      stops: [0.0, 1.0],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 10.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        _ctrl,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Color(0xFFF5A623),
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white12,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(position),
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.sp),
                          ),
                          GestureDetector(
                            onTap: _toggleMute,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white24, width: 1),
                              ),
                              child: Icon(
                                _muted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                            ),
                          ),
                          Text(
                            _fmt(duration),
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10.sp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Branded card separator ─────────────────────────────────────────────────────

class _CardSeparator extends StatelessWidget {
  const _CardSeparator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.18);

    return SizedBox(
      height: 28.h,
      child: Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }
}
