import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:video_player/video_player.dart';

class PicturesFullscreenViewer extends StatefulWidget {
  const PicturesFullscreenViewer({
    super.key,
    required this.pictures,
    required this.initialIndex,
  });

  final List<EventPicture> pictures;
  final int initialIndex;

  @override
  State<PicturesFullscreenViewer> createState() =>
      _PicturesFullscreenViewerState();
}

class _PicturesFullscreenViewerState extends State<PicturesFullscreenViewer> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.pictures.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) {
              final pic = widget.pictures[i];
              final isActive = i == _currentIndex;
              return pic.isVideo
                  ? _FullscreenVideo(
                      url: pic.url,
                      isActive: isActive,
                    )
                  : _FullscreenPhoto(url: pic.url);
            },
          ),

          // ── Top bar: close + counter ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12.w, vertical: 8.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 36.w,
                        height: 36.w,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close,
                            color: Colors.white, size: 20.sp),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.pictures[_currentIndex].isVideo)
                            Padding(
                              padding: EdgeInsets.only(right: 4.w),
                              child: Icon(Icons.videocam_rounded,
                                  color: Colors.white70, size: 12.sp),
                            ),
                          Text(
                            '${_currentIndex + 1} / ${widget.pictures.length}',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fullscreen photo ──────────────────────────────────────────────────────────

class _FullscreenPhoto extends StatelessWidget {
  const _FullscreenPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          placeholder: (_, __) => const CircularProgressIndicator(
              color: Colors.white30, strokeWidth: 2),
          errorWidget: (_, __, ___) => Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 64.sp),
        ),
      ),
    );
  }
}

// ── Fullscreen video ──────────────────────────────────────────────────────────

class _FullscreenVideo extends StatefulWidget {
  const _FullscreenVideo({required this.url, required this.isActive});

  final String url;
  final bool isActive;

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _muted = kIsWeb; // start muted on web — mobile browsers block audio autoplay
  bool _screenActive = true;
  bool _tabActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl.setVolume(_muted ? 0.0 : 1.0);
        setState(() => _initialized = true);
        _syncPlayback();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active != _tabActive) {
      _tabActive = active;
      _syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_screenActive != active) {
      _screenActive = active;
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (!_initialized) return;
    if (widget.isActive && _screenActive && _tabActive) {
      if (!_ctrl.value.isPlaying) _ctrl.play();
    } else {
      if (_ctrl.value.isPlaying) _ctrl.pause();
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _ctrl.setVolume(_muted ? 0.0 : 1.0);
    });
  }

  @override
  void didUpdateWidget(_FullscreenVideo old) {
    super.didUpdateWidget(old);
    if (!_initialized) return;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_initialized) return;
    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(
            color: Colors.white30, strokeWidth: 2),
      );
    }

    // Outer Stack keeps the mute button STABLE (never rebuilt by video frames).
    // ValueListenableBuilder handles per-frame video state without recreating
    // the mute GestureDetector — eliminates any chance of a tap being lost
    // mid-gesture when a position update triggers a rebuild.
    return Stack(
      alignment: Alignment.center,
      children: [
        // 0: Per-frame video layer — play/pause and progress bar live here
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _ctrl,
          builder: (context, value, _) {
            final isPlaying = value.isPlaying;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Video
                Center(
                  child: AspectRatio(
                    aspectRatio: value.size.width > 0 && value.size.height > 0
                        ? value.size.width / value.size.height
                        : 9 / 16,
                    child: VideoPlayer(_ctrl),
                  ),
                ),

                // Full-area play/pause tap target
                Positioned.fill(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayback,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // Pause indicator (IgnorePointer — taps fall through to play/pause)
                if (!isPlaying)
                  IgnorePointer(
                    child: Container(
                      width: 64.w,
                      height: 64.w,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 34.sp),
                    ),
                  ),

                // Progress bar — opaque wrapper absorbs its area
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36.h,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
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
                              Text(_fmt(value.position),
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11.sp)),
                              Text(_fmt(value.duration),
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 11.sp)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // 1: Mute toggle — STABLE, rebuilt only when _muted changes via setState,
        //    not on every video frame. Sits above ValueListenableBuilder so its
        //    opaque hit area absorbs mute taps before play/pause can fire.
        Positioned(
          top: 80.h,
          right: 16.w,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _toggleMute,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(
                  _muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 18.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
