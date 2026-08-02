import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_loading_indicator.dart';
import 'package:skidoo_app/core/utils/video_mute_preference.dart';
import 'package:skidoo_app/core/utils/video_pause_notifier.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:video_player/video_player.dart';

// ── Public widget ─────────────────────────────────────────────────────────────

/// A fully-featured, reusable video player for Skidoo.
///
/// Handles play/pause, seek ±10 s, mute/unmute, draggable progress bar,
/// full-screen, auto-play, looping, carousel coordination, TickerMode-based
/// tab-visibility pausing, app-lifecycle pausing, and
/// [VideoPauseNotifier] sync — all in one drop-in widget.
///
/// Playback runs on the platform's own player — AVPlayer on iOS, ExoPlayer on
/// Android, `<video>` on web — through `video_player`. That is the reason this
/// widget exists in this shape: the app used to carry libmpv + FFmpeg for the
/// same job, which cost ~20 MB of the iOS download for decoders the OS already
/// ships. Everything below is the same player, driven by a different engine.
///
/// **Sizing** (mutually exclusive, evaluated top-to-bottom):
/// 1. Both [width] & [height] set → fixed SizedBox.
/// 2. Only [aspectRatio] set → AspectRatio widget.
/// 3. One of [width] / [height] → SizedBox on that axis.
/// 4. None → the video's own aspect ratio.
///
/// **Usage:**
/// ```dart
/// // Feed card — fills a fixed-height container, cover fit
/// SkidooVideoPlayer(url: url, autoPlay: true)
///
/// // Chat bubble — natural aspect ratio
/// SkidooVideoPlayer(url: url, showControls: true)
///
/// // Fullscreen page — contain fit
/// SkidooVideoPlayer(url: url, fit: BoxFit.contain, autoPlay: true, isActive: isThisPage)
///
/// // Carousel slide — only plays when isActive
/// SkidooVideoPlayer(url: url, autoPlay: true, isActive: slideIndex == activeIndex)
///
/// // Local file thumbnail
/// SkidooVideoPlayer(url: 'file://$filePath', autoPlay: false, showControls: false)
/// ```
class SkidooVideoPlayer extends StatefulWidget {
  const SkidooVideoPlayer({
    super.key,
    required this.url,
    // ── Sizing ─────────────────────────────────────────────────────────────
    this.width,
    this.height,
    this.aspectRatio,
    this.fit = BoxFit.contain,
    // ── Playback ───────────────────────────────────────────────────────────
    this.autoPlay = false,
    this.loop = true,
    this.initiallyMuted,
    // ── Controls ───────────────────────────────────────────────────────────
    this.showControls = true,
    this.allowFullscreen = true,
    this.borderRadius,
    this.backgroundColor = Colors.black,
    // ── Coordination ──────────────────────────────────────────────────────
    this.isActive = true,
    this.listenToPauseNotifier = true,
    // ── Look ────────────────────────────────────────────────────────────────
    this.colorFilter,
  });

  /// Network URL (`https://…`) or local path (`file:///…`) of the video.
  final String url;

  final double? width;
  final double? height;

  /// Desired aspect ratio (width ÷ height). E.g. `16 / 9` or `9 / 16`.
  final double? aspectRatio;

  /// How the video fits its bounding box. Defaults to [BoxFit.contain].
  final BoxFit fit;

  /// Begin playback as soon as the media is loaded. Defaults to false.
  final bool autoPlay;

  /// Loop the video indefinitely. Defaults to true.
  final bool loop;

  /// Whether to start muted. `null` (default) → follows [VideoMutePreference].
  final bool? initiallyMuted;

  /// Show the tap-to-reveal controls overlay. Defaults to true.
  final bool showControls;

  /// Include a full-screen button in the controls bar. Defaults to true.
  final bool allowFullscreen;

  /// Clip radius applied to the whole player container.
  final BorderRadius? borderRadius;

  /// Fill colour for letterbox / pillarbox areas.
  final Color backgroundColor;

  /// Set false when this player is not the active slide/page in a parent
  /// PageView or carousel. The player auto-pauses until it becomes active
  /// again.
  final bool isActive;

  /// Subscribe to [VideoPauseNotifier.pauseAll]. Defaults to true.
  final bool listenToPauseNotifier;

  /// Optional colour grade applied to the video surface (e.g.
  /// [SkidooFilters.vibrant]) so feed video matches the photo grading.
  /// Null leaves the video ungraded — used for chat where fidelity matters.
  final ColorFilter? colorFilter;

  @override
  State<SkidooVideoPlayer> createState() => _SkidooVideoPlayerState();
}

/// Builds the controller for [url], picking the network or file constructor.
/// `file://` paths are what the chat's staged-media preview passes.
VideoPlayerController _controllerFor(String url) {
  if (!kIsWeb && url.startsWith('file://')) {
    return VideoPlayerController.file(File(Uri.parse(url).toFilePath()));
  }
  return VideoPlayerController.networkUrl(Uri.parse(url));
}

// ── State ─────────────────────────────────────────────────────────────────────

class _SkidooVideoPlayerState extends State<SkidooVideoPlayer>
    with WidgetsBindingObserver {
  // Nullable until _initPlayer() fires on the first post-frame callback, which
  // keeps the decoder/surface setup off the first render frame.
  VideoPlayerController? _ctrl;
  bool _playerReady = false;

  bool _muted = false;
  bool _manuallyPaused = false;
  bool _controlsVisible = true;
  bool _tickerEnabled = true;
  bool _appActive = true;

  /// Last seen playing/buffering flags. The controller notifies on every
  /// position tick; comparing against these keeps rebuilds to real changes —
  /// the scrubber redraws through its own [ValueListenableBuilder].
  bool _wasPlaying = false;
  bool _buffering = false;
  Size? _videoSize;

  Timer? _hideTimer;
  StreamSubscription<void>? _pauseSub;

  bool get _startMuted => widget.initiallyMuted ?? VideoMutePreference.muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = _startMuted;

    // Subscribed once for the widget's lifetime, not per controller: a url
    // change rebuilds the controller, and re-subscribing there would stack a
    // second listener on every swap.
    if (widget.listenToPauseNotifier) {
      _pauseSub = VideoPauseNotifier.listen(_onGlobalPause);
    }
    if (widget.initiallyMuted == null) {
      VideoMutePreference.notifier.addListener(_onGlobalMuteChanged);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayer();
    });
  }

  Future<void> _initPlayer() async {
    final ctrl = _controllerFor(widget.url);
    _ctrl = ctrl;
    ctrl.addListener(_onValue);

    try {
      await ctrl.initialize();
    } catch (_) {
      // A dead URL leaves the surface on its background colour rather than
      // throwing out of a post-frame callback.
      return;
    }
    if (!mounted) {
      ctrl.dispose();
      return;
    }

    await ctrl.setLooping(widget.loop);
    await ctrl.setVolume(_muted ? 0 : 1);

    setState(() {
      _playerReady = true;
      _videoSize = ctrl.value.size;
      _controlsVisible = true;
    });

    _syncPlayback();
  }

  /// Single listener for the controller's value. Only meaningful transitions
  /// rebuild this widget.
  void _onValue() {
    final value = _ctrl?.value;
    if (value == null || !mounted) return;

    if (value.isPlaying != _wasPlaying) {
      _wasPlaying = value.isPlaying;
      if (value.isPlaying) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    }
    if (value.isBuffering != _buffering) {
      setState(() => _buffering = value.isBuffering);
    }
    if (value.isInitialized && value.size != _videoSize) {
      setState(() => _videoSize = value.size);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ignore: deprecated_member_use
    final enabled = TickerMode.of(context);
    if (_tickerEnabled != enabled) {
      _tickerEnabled = enabled;
      if (_playerReady) _syncPlayback();
    }
  }

  @override
  void didUpdateWidget(SkidooVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      // A new source means a new controller — video_player has no re-open.
      _disposeController();
      setState(() {
        _playerReady = false;
        _videoSize = null;
      });
      _initPlayer();
    } else if (_playerReady && old.isActive != widget.isActive) {
      _syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        if (_ctrl?.value.isPlaying == true) _ctrl!.pause();
      case AppLifecycleState.resumed:
        _appActive = true;
        if (_playerReady) _syncPlayback();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onGlobalPause() {
    if (_ctrl?.value.isPlaying == true) {
      _ctrl!.pause();
      _manuallyPaused = true;
    }
  }

  void _onGlobalMuteChanged() {
    if (!mounted) return;
    final globalMuted = VideoMutePreference.muted;
    if (_muted == globalMuted) return;
    setState(() => _muted = globalMuted);
    _ctrl?.setVolume(_muted ? 0 : 1);
  }

  void _syncPlayback() {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final shouldPlay = widget.autoPlay &&
        widget.isActive &&
        _tickerEnabled &&
        _appActive &&
        !_manuallyPaused;

    if (shouldPlay && !ctrl.value.isPlaying) {
      ctrl.play();
    } else if (!shouldPlay && ctrl.value.isPlaying) {
      if (!widget.isActive) _manuallyPaused = false;
      ctrl.pause();
    }
  }

  // ── Controls ────────────────────────────────────────────────────────────────

  void _onTap() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      if (_ctrl?.value.isPlaying == true) _scheduleHide();
    } else {
      _togglePlayback();
    }
  }

  void _togglePlayback() {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      ctrl.pause();
      _manuallyPaused = true;
    } else {
      ctrl.play();
      _manuallyPaused = false;
      _scheduleHide();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl?.setVolume(_muted ? 0 : 1);
    VideoMutePreference.muted = _muted;
  }

  void _seekBy(Duration delta) {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final target = ctrl.value.position + delta;
    final dur = ctrl.value.duration;
    ctrl.seekTo(
      target < Duration.zero ? Duration.zero : (target > dur ? dur : target),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _ctrl?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _openFullscreen() {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position;
    final wasPlaying = ctrl.value.isPlaying;
    ctrl.pause();

    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullscreenVideoPage(
        url: widget.url,
        initialPosition: pos,
        autoPlay: wasPlaying,
        muted: _muted,
        loop: widget.loop,
        onExit: (finalPos, finalMuted) {
          setState(() => _muted = finalMuted);
          ctrl.setVolume(_muted ? 0 : 1);
          ctrl.seekTo(finalPos);
          _syncPlayback();
        },
      ),
    ));
  }

  void _disposeController() {
    final ctrl = _ctrl;
    _ctrl = null;
    if (ctrl == null) return;
    ctrl.removeListener(_onValue);
    ctrl.pause();
    ctrl.dispose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.initiallyMuted == null) {
      VideoMutePreference.notifier.removeListener(_onGlobalMuteChanged);
    }
    _pauseSub?.cancel();
    _hideTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  Widget _buildVideoSurface() {
    final ctrl = _ctrl;
    final size = _videoSize;

    if (ctrl == null || !_playerReady || size == null || size.isEmpty) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: const AppLoadingIndicator(),
      );
    }

    // [VideoPlayer] fills whatever box it is given, so the fit has to be
    // applied around it: the sized box below carries the video's real pixel
    // dimensions and FittedBox scales that to the slot.
    return ColoredBox(
      color: widget.backgroundColor,
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget video = _buildVideoSurface();
    // Apply the optional colour grade so feed video matches the photo look.
    if (widget.colorFilter != null) {
      video = ColorFiltered(colorFilter: widget.colorFilter!, child: video);
    }

    // ── Sizing ─────────────────────────────────────────────────────────────
    //
    // Every branch has to end up bounded on both axes. The surface scales the
    // video's pixel dimensions to its slot, so an unbounded axis would let it
    // lay out at the source's full pixel height (1080, 2160…) instead of at
    // the size the screen wanted.
    final size = _videoSize;
    final ratio =
        (size != null && size.height > 0) ? size.width / size.height : 16 / 9;

    Widget sized;
    if (widget.width != null && widget.height != null) {
      sized =
          SizedBox(width: widget.width, height: widget.height, child: video);
    } else if (widget.aspectRatio != null) {
      sized = AspectRatio(aspectRatio: widget.aspectRatio!, child: video);
    } else if (widget.width != null) {
      sized = SizedBox(
          width: widget.width, height: widget.width! / ratio, child: video);
    } else if (widget.height != null) {
      sized = SizedBox(
          width: widget.height! * ratio, height: widget.height, child: video);
    } else {
      sized = AspectRatio(aspectRatio: ratio, child: video);
    }

    // ── Controls overlay ───────────────────────────────────────────────────
    final ctrl = _ctrl;
    Widget playerWidget = Stack(
      alignment: Alignment.center,
      children: [
        sized,
        if (_buffering)
          const IgnorePointer(
            child: AppLoadingIndicator(),
          ),
        if (widget.showControls && ctrl != null && _playerReady)
          Positioned.fill(
            child: Semantics(
                button: true,
                label: 'Video',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onTap,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: _ControlsOverlay(
                      controller: ctrl,
                      muted: _muted,
                      onPlayPause: _togglePlayback,
                      onMute: _toggleMute,
                      onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                      onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                      onFullscreen:
                          widget.allowFullscreen ? _openFullscreen : null,
                    ),
                  ),
                )),
          ),
      ],
    );

    if (widget.borderRadius != null) {
      playerWidget =
          ClipRRect(borderRadius: widget.borderRadius!, child: playerWidget);
    }

    // ── Web: reveal the controls (mute, scrubber, fullscreen…) as soon as the
    //    pointer enters the video, and hide again on exit while playing. ──────
    if (kIsWeb && widget.showControls && ctrl != null) {
      playerWidget = MouseRegion(
        onEnter: (_) {
          _hideTimer?.cancel();
          if (!_controlsVisible) setState(() => _controlsVisible = true);
        },
        onExit: (_) {
          if (_ctrl?.value.isPlaying == true && _controlsVisible) {
            setState(() => _controlsVisible = false);
          }
        },
        child: playerWidget,
      );
    }

    return playerWidget;
  }
}

// ── Controls overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.controller,
    required this.muted,
    required this.onPlayPause,
    required this.onMute,
    required this.onSeekBack,
    required this.onSeekForward,
    this.onFullscreen,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onPlayPause;
  final VoidCallback onMute;
  final VoidCallback onSeekBack;
  final VoidCallback onSeekForward;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x88000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0xAA000000),
          ],
          stops: [0.0, 0.2, 0.72, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Mute — top-right ─────────────────────────────────────────────
          Positioned(
            top: 10.h,
            right: 12.w,
            child: _CircleButton(
              icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              onTap: onMute,
            ),
          ),

          // ── Center: seek-back | play/pause | seek-forward ────────────────
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CircleButton(
                  icon: Icons.replay_10_rounded,
                  onTap: onSeekBack,
                  size: 26.sp,
                ),
                SizedBox(width: AppSpacing.xxl.w),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (_, value, __) => _CircleButton(
                    icon: value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: onPlayPause,
                    size: 36.sp,
                    padding: 12,
                  ),
                ),
                SizedBox(width: AppSpacing.xxl.w),
                _CircleButton(
                  icon: Icons.forward_10_rounded,
                  onTap: onSeekForward,
                  size: 26.sp,
                ),
              ],
            ),
          ),

          // ── Bottom: progress + timestamps + fullscreen ────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(controller: controller, onFullscreen: onFullscreen),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.size,
    this.padding = 8,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double? size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        label: 'Player control',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: const BoxDecoration(
              color: Color(0x66000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size ?? 20.sp),
          ),
        ));
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.controller, this.onFullscreen});

  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 6.h),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, __) {
          final dur = value.duration;
          final pos = value.position;
          final frac = dur.inMilliseconds > 0
              ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
              : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  overlayShape: SliderComponentShape.noOverlay,
                  trackHeight: 2.5,
                  activeTrackColor: const Color(0xFF1D9E75),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: SizedBox(
                  height: 20.h,
                  child: Slider(
                    value: frac,
                    onChanged: dur.inMilliseconds > 0
                        ? (v) => controller.seekTo(Duration(
                            milliseconds: (v * dur.inMilliseconds).round()))
                        : null,
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    _fmt(pos),
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  ),
                  const Spacer(),
                  Text(
                    _fmt(dur),
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  ),
                  if (onFullscreen != null) ...[
                    SizedBox(width: AppSpacing.sm.w),
                    Semantics(
                        button: true,
                        label: 'Fullscreen',
                        child: GestureDetector(
                          onTap: onFullscreen,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white70,
                            size: 20.sp,
                          ),
                        )),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Fullscreen page ───────────────────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.url,
    required this.initialPosition,
    required this.autoPlay,
    required this.muted,
    required this.loop,
    required this.onExit,
  });

  final String url;
  final Duration initialPosition;
  final bool autoPlay;
  final bool muted;
  final bool loop;
  final void Function(Duration finalPos, bool finalMuted) onExit;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  bool _muted = false;
  bool _controlsVisible = true;
  bool _wasPlaying = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = widget.muted;

    _ctrl = _controllerFor(widget.url);
    _ctrl.addListener(_onValue);
    _open();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _open() async {
    try {
      await _ctrl.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) return;

    await _ctrl.setLooping(widget.loop);
    await _ctrl.setVolume(_muted ? 0 : 1);
    if (widget.initialPosition > Duration.zero) {
      await _ctrl.seekTo(widget.initialPosition);
    }
    if (widget.autoPlay) await _ctrl.play();

    if (mounted) setState(() => _ready = true);
  }

  void _onValue() {
    final playing = _ctrl.value.isPlaying;
    if (playing != _wasPlaying) {
      _wasPlaying = playing;
      if (playing) _scheduleHide();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_ctrl.value.isPlaying) _ctrl.pause();
      case AppLifecycleState.resumed:
        if (_ready) _ctrl.play();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _ctrl.value.isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible && _ctrl.value.isPlaying) _scheduleHide();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _ctrl.setVolume(_muted ? 0 : 1);
    VideoMutePreference.muted = _muted;
  }

  void _seekBy(Duration delta) {
    final target = _ctrl.value.position + delta;
    final dur = _ctrl.value.duration;
    _ctrl.seekTo(
      target < Duration.zero ? Duration.zero : (target > dur ? dur : target),
    );
  }

  void _exit() {
    widget.onExit(_ctrl.value.position, _muted);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _ctrl.removeListener(_onValue);
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
          button: true,
          label: 'Video',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready && !_ctrl.value.size.isEmpty)
                  ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _ctrl.value.aspectRatio,
                        child: VideoPlayer(_ctrl),
                      ),
                    ),
                  )
                else
                  const ColoredBox(color: Colors.black),
                if (_ready)
                  AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _ControlsOverlay(
                      controller: _ctrl,
                      muted: _muted,
                      onPlayPause: () {
                        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                        if (_ctrl.value.isPlaying) _scheduleHide();
                      },
                      onMute: _toggleMute,
                      onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                      onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                      onFullscreen: null,
                    ),
                  ),
                Positioned(
                  top: safePad.top + 8.h,
                  left: 12.w,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _CircleButton(
                      icon: Icons.close_rounded,
                      onTap: _exit,
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
          )),
    );
  }
}
