import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:video_player/video_player.dart';

/// Full-width swipeable photo/video carousel — Instagram / TikTok style.
class PostPhotoCarousel extends StatefulWidget {
  const PostPhotoCarousel({
    super.key,
    required this.pics,
    required this.pageController,
    required this.showBlur,
    required this.onDoubleTap,
    required this.onTap,
    this.scrollable = true,
    this.cardIndex = 0,
    this.activeCardIndex,
  });

  final List<EventPicture> pics;
  final PageController pageController;
  final bool showBlur;
  final VoidCallback onDoubleTap;
  final bool scrollable;
  final VoidCallback onTap;
  /// Which position this card occupies in the feed.
  final int cardIndex;
  /// Feed-level notifier for which card should be playing. Null = always play.
  final ValueNotifier<int>? activeCardIndex;

  @override
  State<PostPhotoCarousel> createState() => _PostPhotoCarouselState();
}

class _PostPhotoCarouselState extends State<PostPhotoCarousel> {
  /// Drives play/pause for all video slides in this carousel.
  final _activeIndex = ValueNotifier<int>(0);

  void _onPageChanged(int i) => _activeIndex.value = i;

  @override
  void dispose() {
    _activeIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      physics: widget.scrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: widget.pics.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        final pic = widget.pics[index];
        final isLastLocked =
            widget.showBlur && index == 2 && widget.pics.length > 3;

        if (pic.isVideo) {
          return Stack(
            fit: StackFit.expand,
            children: [
              _SliderVideoItem(
                url: pic.url,
                index: index,
                activeIndex: _activeIndex,
                onTap: widget.onTap,
                cardIndex: widget.cardIndex,
                activeCardIndex: widget.activeCardIndex,
              ),
              if (isLastLocked) _LockedOverlay(remaining: widget.pics.length - 3),
              // if (pic.owner) const _OwnerCornerRibbon(),
            ],
          );
        }

        return GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Blurred background so no black bars appear ────────────
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: CachedNetworkImage(
                  imageUrl: pic.url,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  placeholder: (_, __) =>
                      const ColoredBox(color: Color(0xFF111111)),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF111111)),
                ),
              ),
              // Dim the blur layer so it doesn't compete with the main image
              const ColoredBox(color: Color(0x55000000)),
              // ── Sharp full image — never cropped ─────────────────────
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  1.18, -0.06, -0.06, 0, 18,
                  -0.05,  1.16, -0.05, 0, 18,
                  -0.05, -0.05,  1.20, 0, 18,
                  0,     0,     0,     1, 0,
                ]),
                child: CachedNetworkImage(
                  imageUrl: pic.url,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  placeholder: (_, __) =>
                      const SizedBox.shrink(),
                  errorWidget: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF111111)),
                ),
              ),
              if (isLastLocked) _LockedOverlay(remaining: widget.pics.length - 3),
              // if (pic.owner) const _OwnerCornerRibbon(),
            ],
          ),
        );
      },
    );
  }
}

// ── Inline video player for the feed carousel ─────────────────────────────────

class _SliderVideoItem extends StatefulWidget {
  const _SliderVideoItem({
    required this.url,
    required this.index,
    required this.activeIndex,
    required this.onTap,
    this.cardIndex = 0,
    this.activeCardIndex,
  });

  final String url;
  final int index;
  final ValueNotifier<int> activeIndex;
  /// Called when the user taps while video is not yet initialized, or when
  /// the card's outer gesture (open EventPicturesPage) should fire.
  final VoidCallback onTap;
  final int cardIndex;
  final ValueNotifier<int>? activeCardIndex;

  @override
  State<_SliderVideoItem> createState() => _SliderVideoItemState();
}

class _SliderVideoItemState extends State<_SliderVideoItem>
    with WidgetsBindingObserver {
  /// Shared mute state across all feed carousel videos — starts unmuted on feed.
  static final _muted = ValueNotifier<bool>(false);

  late final VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _manuallyPaused = false;
  /// Tracks whether this widget is on-screen (not hidden by IndexedStack /
  /// Offstage). Updated via TickerMode which IndexedStack flips for hidden tabs.
  bool _screenActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Do NOT pass VideoPlayerOptions(mixWithOthers: true) — that forces the
    // iOS audio session into the .ambient category which is silenced by the
    // ringer switch. The default .playback category plays regardless.
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        _ctrl.setVolume(_muted.value ? 0.0 : 1.0);
        setState(() => _initialized = true);
        _syncPlayback();
      });
    widget.activeIndex.addListener(_syncPlayback);
    widget.activeCardIndex?.addListener(_syncPlayback);
    _muted.addListener(_onMuteChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode is disabled by IndexedStack / Offstage when the tab is hidden.
    // Use it as a reliable "is my tab visible?" signal.
    final active = TickerMode.valuesOf(context).enabled;
    if (active != _screenActive) {
      _screenActive = active;
      _syncPlayback();
    }
  }

  /// App lifecycle — pause when backgrounded, resume when foregrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (_initialized && _ctrl.value.isPlaying) _ctrl.pause();
      case AppLifecycleState.resumed:
        _syncPlayback();
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.activeIndex.removeListener(_syncPlayback);
    widget.activeCardIndex?.removeListener(_syncPlayback);
    _muted.removeListener(_onMuteChanged);
    _ctrl
      ..pause()
      ..dispose();
    super.dispose();
  }

  /// True when this slide is the active page within the carousel.
  bool get _isActive => widget.activeIndex.value == widget.index;

  /// True when this card is the one centred in the feed, or when no feed
  /// controller is provided (legacy/standalone use).
  bool get _isCardActive =>
      widget.activeCardIndex == null ||
      widget.activeCardIndex!.value == widget.cardIndex;

  void _onMuteChanged() {
    if (!_initialized) return;
    _ctrl.setVolume(_muted.value ? 0.0 : 1.0);
  }

  void _syncPlayback() {
    if (!_initialized) return;
    if (_isActive && _isCardActive && _screenActive && !_manuallyPaused) {
      if (!_ctrl.value.isPlaying) _ctrl.play();
    } else {
      if (_ctrl.value.isPlaying) _ctrl.pause();
      if (!_isActive) _manuallyPaused = false;
    }
  }

  void _togglePlayback() {
    if (!_initialized) {
      widget.onTap();
      return;
    }
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

  void _toggleMute() => _muted.value = !_muted.value;

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return GestureDetector(
        onTap: widget.onTap,
        child: const ColoredBox(
          color: Color(0xFF0A0A0A),
          child: Center(
            child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2),
          ),
        ),
      );
    }

    // The Stack has TWO levels:
    //  1. ValueListenableBuilder<VideoPlayerValue> — rebuilds every frame for
    //     the video, progress bar, and play/pause overlay.
    //  2. Mute button — lives OUTSIDE that listener so its GestureDetector
    //     is never destroyed mid-tap (which was silently eating all taps).
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Per-frame video layer ─────────────────────────────────────────
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _ctrl,
          builder: (context, value, _) {
            final isPlaying = value.isPlaying;
            final w = value.size.width > 0 ? value.size.width : 1.0;
            final h = value.size.height > 0 ? value.size.height : 1.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _togglePlayback,
                  child: ColoredBox(
                    color: const Color(0xFF0A0A0A),
                    child: SizedBox.expand(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          1.18, -0.06, -0.06, 0, 18,
                          -0.05,  1.16, -0.05, 0, 18,
                          -0.05, -0.05,  1.20, 0, 18,
                          0,     0,     0,     1, 0,
                        ]),
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: w,
                            height: h,
                            child: VideoPlayer(_ctrl),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: VideoProgressIndicator(
                      _ctrl,
                      allowScrubbing: false,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFFF5A623),
                        bufferedColor: Colors.white24,
                        backgroundColor: Colors.white12,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        // ── Mute button — stable widget, never rebuilt by video frames ────
        Positioned(
          bottom: 10.h,
          right: 10.w,
          child: ValueListenableBuilder<bool>(
            valueListenable: _muted,
            builder: (_, muted, __) => GestureDetector(
              onTap: _toggleMute,
                behavior: HitTestBehavior.translucent,
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(
                  muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 17.sp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Locked overlay ────────────────────────────────────────────────────────────

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.lock_rounded,
                    color: Colors.white, size: 24.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '+$remaining more photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Sign in to unlock',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient placeholder ──────────────────────────────────────────────────────

class CardGradientPlaceholder extends StatelessWidget {
  const CardGradientPlaceholder({super.key, required this.name});
  final String name;

  static const _palette = [
    [Color(0xFF1a1a2e), Color(0xFF16213e)],
    [Color(0xFF0f3460), Color(0xFF533483)],
    [Color(0xFF1a0533), Color(0xFF3d0066)],
    [Color(0xFF001a2c), Color(0xFF003366)],
    [Color(0xFF1a0000), Color(0xFF4d0000)],
    [Color(0xFF002200), Color(0xFF004d00)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _palette.length;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _palette[idx],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.08),
          fontSize: 120.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CardEmptyTile extends StatelessWidget {
  const CardEmptyTile({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(color: const Color(0xFF111111));
}

// ── Owner viewfinder overlay ──────────────────────────────────────────────────
// Camera SLR/DSLR viewfinder focus brackets — the classic L-shaped corner
// markers every photographer recognises. Metaphor: the camera was pointed at
// YOU. No social app uses this; it is purely photographic in origin.

// class _OwnerCornerRibbon extends StatelessWidget {
//   const _OwnerCornerRibbon();

//   @override
//   Widget build(BuildContext context) {
//     return Positioned.fill(
//       child: IgnorePointer(
//         child: CustomPaint(painter: _ViewfinderPainter()),
//       ),
//     );
//   }
// }

// class _ViewfinderPainter extends CustomPainter {
//   // Warm amber that reads clearly on both bright and dark images.
//   static const _color = Color(0xFFFFD166);
//   static const _stroke = 2.2;
//   // How far each bracket arm extends from the corner.
//   static const _arm = 22.0;
//   // Inset from the image edge so the brackets sit just inside.
//   static const _margin = 10.0;

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = _color
//       ..strokeWidth = _stroke
//       ..strokeCap = StrokeCap.square
//       ..style = PaintingStyle.stroke;

//     final w = size.width;
//     final h = size.height;
//     const m = _margin;
//     const a = _arm;

//     // ── top-left ─────────────────────────────────────────────────────────────
//     canvas.drawLine(const Offset(m, m + a), const Offset(m, m), paint);        // vertical
//     canvas.drawLine(const Offset(m, m), const Offset(m + a, m), paint);        // horizontal

//     // ── top-right ────────────────────────────────────────────────────────────
//     canvas.drawLine(Offset(w - m - a, m), Offset(w - m, m), paint);
//     canvas.drawLine(Offset(w - m, m), Offset(w - m, m + a), paint);

//     // ── bottom-left ───────────────────────────────────────────────────────────
//     canvas.drawLine(Offset(m, h - m - a), Offset(m, h - m), paint);
//     canvas.drawLine(Offset(m, h - m), Offset(m + a, h - m), paint);

//     // ── bottom-right ──────────────────────────────────────────────────────────
//     canvas.drawLine(Offset(w - m - a, h - m), Offset(w - m, h - m), paint);
//     canvas.drawLine(Offset(w - m, h - m - a), Offset(w - m, h - m), paint);

//     // ── "YOU ARE IN THIS FRAME" label — top centre, above the brackets ──────
//     final tp = TextPainter(
//       text: const TextSpan(
//         text: "YOU ARE IN THIS FRAME",
//         style: TextStyle(
//           color: _color,
//           fontSize: 9,
//           fontWeight: FontWeight.w700,
//           letterSpacing: 2.0,
//         ),
//       ),
//       textDirection: TextDirection.ltr,
//     )..layout();
//     tp.paint(canvas, Offset((w - tp.width) / 2, m + 6));
//   }

//   @override
//   bool shouldRepaint(_ViewfinderPainter old) => false;
// }
