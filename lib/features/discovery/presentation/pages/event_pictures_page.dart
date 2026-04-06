import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/pictures_fullscreen_viewer.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:video_player/video_player.dart';

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

  /// One GlobalKey per item — only items in cache extent have a live context.
  late final List<GlobalKey> _itemKeys;

  bool _fullscreenOpen = false;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(
      widget.event.pictures.length,
      (_) => GlobalKey(),
    );
    _scrollCtrl.addListener(_scheduleActiveUpdate);
    // Seed the first active item once layout is done.
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _updateActiveItem());
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_scheduleActiveUpdate);
    _scrollCtrl.dispose();
    _activeIndex.dispose();
    super.dispose();
  }

  void _scheduleActiveUpdate() {
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _updateActiveItem());
  }

  /// O(visible items) — iterates only items currently built by ListView.
  void _updateActiveItem() {
    if (!mounted || _fullscreenOpen) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final screenCenterY = screenH / 2;

    int best = _activeIndex.value;
    double bestDist = double.infinity;

    for (int i = 0; i < _itemKeys.length; i++) {
      final ctx = _itemKeys[i].currentContext;
      if (ctx == null) continue; // not built yet → skip
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
    _activeIndex.value = -1; // pause all videos

    Navigator.of(context)
        .push(PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => PicturesFullscreenViewer(
            pictures: widget.event.pictures,
            initialIndex: initialIndex,
          ),
        ))
        .then((_) {
      _fullscreenOpen = false;
      _updateActiveItem(); // resume the correct video
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = widget.event.pictures;
    final screenW = MediaQuery.sizeOf(context).width;
    // 4:5 portrait card — same ratio as the discovery feed, fits naturally.
    final itemH = screenW * (5 / 4);
    // Cache one item above and below the viewport in memory.
    final cacheExtent = itemH * 0.8;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.eventName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            Text(
              'by ${widget.event.photographerName}',
              style: TextStyle(color: Colors.white60, fontSize: 11.sp),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 14.w),
            child: Center(
              child: Text(
                '${pics.length} items',
                style: TextStyle(color: Colors.white60, fontSize: 12.sp),
              ),
            ),
          ),
        ],
      ),
      body: pics.isEmpty
          ? Center(
              child: Text(
                'No media available',
                style: TextStyle(
                    color: ext.searchHintColor, fontSize: 15.sp),
              ),
            )
          : ListView.builder(
              controller: _scrollCtrl,
              cacheExtent: cacheExtent,
              itemCount: pics.length,
              itemBuilder: (context, i) {
                final pic = pics[i];
                return _MediaCard(
                  key: _itemKeys[i],
                  picture: pic,
                  index: i,
                  itemHeight: itemH,
                  activeIndex: _activeIndex,
                  onTap: () => _openFullscreen(i),
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
  });

  final EventPicture picture;
  final int index;
  final double itemHeight;
  final ValueNotifier<int> activeIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: itemHeight,
      child: picture.isVideo
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
    return CachedNetworkImage(
      imageUrl: url,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
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
  final VoidCallback onTap; // opens fullscreen

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
    _ctrl = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
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
              // ── Video (cover fill, no stretch) ────────────────────────────
              GestureDetector(
                onTap: _togglePlayback,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: VideoPlayer(_ctrl),
                    ),
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
                          // ── Mute/unmute ───────────────────────────────────
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
