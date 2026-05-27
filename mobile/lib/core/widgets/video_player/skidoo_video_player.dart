import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:skidoo_app/core/utils/video_mute_preference.dart';
import 'package:skidoo_app/core/utils/video_pause_notifier.dart';

export 'package:media_kit/media_kit.dart' show PlaylistMode;

// ── Public widget ─────────────────────────────────────────────────────────────

/// A fully-featured, reusable video player for Skidoo.
///
/// Handles play/pause, seek ±10 s, mute/unmute, draggable progress bar,
/// full-screen, auto-play, looping, carousel coordination, TickerMode-based
/// tab-visibility pausing, app-lifecycle pausing, and
/// [VideoPauseNotifier] sync — all in one drop-in widget.
///
/// **Sizing** (mutually exclusive, evaluated top-to-bottom):
/// 1. Both [width] & [height] set → fixed SizedBox.
/// 2. Only [aspectRatio] set → AspectRatio widget.
/// 3. One of [width] / [height] → SizedBox on that axis.
/// 4. None → fills available space ([SizedBox.expand]).
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

  /// Whether to start muted. `null` (default) → muted on web, unmuted on native.
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

  @override
  State<SkidooVideoPlayer> createState() => _SkidooVideoPlayerState();
}

// ── State ─────────────────────────────────────────────────────────────────────

class _SkidooVideoPlayerState extends State<SkidooVideoPlayer>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;

  bool _muted = false;
  bool _manuallyPaused = false;
  bool _controlsVisible = true;
  bool _tickerEnabled = true;
  bool _appActive = true;

  // Video pixel dimensions — populated from the player stream once media loads.
  // Used to compute the exact aspect ratio for reliable centering.
  int? _videoW;
  int? _videoH;

  Timer? _hideTimer;
  StreamSubscription<void>? _pauseSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;

  /// Resolve initial mute state:
  /// - explicit [widget.initiallyMuted] wins if provided
  /// - otherwise use the global session preference (updated by user toggles)
  bool get _startMuted => widget.initiallyMuted ?? VideoMutePreference.muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = _startMuted;

    _player = Player();
    // Hardware acceleration enables 4K/HDR decoding via libmpv on native and
    // GPU compositing on web. It is the default but we make it explicit so the
    // config is easy to find and extend (e.g. add hwdec/bufferSize later).
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    // Capture initial dimensions if already available (e.g. reused player).
    _videoW = _player.state.width;
    _videoH = _player.state.height;

    // Track dimension changes so we can use AspectRatio + Center for reliable
    // centering once the actual video size is known.
    _widthSub = _player.stream.width.listen((w) {
      if (mounted && w != null && w > 0 && w != _videoW) {
        setState(() => _videoW = w);
      }
    });
    _heightSub = _player.stream.height.listen((h) {
      if (mounted && h != null && h > 0 && h != _videoH) {
        setState(() => _videoH = h);
      }
    });

    _player.setVolume(_muted ? 0 : 100);
    _player.setPlaylistMode(
      widget.loop ? PlaylistMode.loop : PlaylistMode.none,
    );

    _player
        .open(Media(widget.url), play: false)
        .then((_) { if (mounted) _syncPlayback(); })
        .catchError((_) {});

    if (widget.listenToPauseNotifier) {
      _pauseSub = VideoPauseNotifier.listen(_onGlobalPause);
    }

    // Mirror global mute-preference changes in real-time — when any other
    // player unmutes (or mutes), this player immediately follows suit.
    // Only active when initiallyMuted is null (not an explicit override).
    if (widget.initiallyMuted == null) {
      VideoMutePreference.notifier.addListener(_onGlobalMuteChanged);
    }

    // Auto-hide controls once playing starts; re-show when paused.
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _scheduleHide();
      } else {
        _hideTimer?.cancel();
        setState(() => _controlsVisible = true);
      }
    });

    if (!widget.autoPlay) _controlsVisible = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = TickerMode.valuesOf(context).enabled;
    if (_tickerEnabled != enabled) {
      _tickerEnabled = enabled;
      _syncPlayback();
    }
  }

  @override
  void didUpdateWidget(SkidooVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _player
          .open(Media(widget.url), play: false)
          .then((_) { if (mounted) _syncPlayback(); })
          .catchError((_) {});
    } else if (old.isActive != widget.isActive) {
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
        if (_player.state.playing) _player.pause();
      case AppLifecycleState.resumed:
        _appActive = true;
        _syncPlayback();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onGlobalPause() {
    if (_player.state.playing) {
      _player.pause();
      _manuallyPaused = true;
    }
  }

  /// Called when any other player writes to [VideoMutePreference].
  /// Syncs this player's volume immediately so all active players share
  /// the same mute state without needing to be re-created.
  void _onGlobalMuteChanged() {
    if (!mounted) return;
    final globalMuted = VideoMutePreference.muted;
    if (_muted == globalMuted) return; // already in sync — nothing to do
    setState(() {
      _muted = globalMuted;
      _player.setVolume(_muted ? 0 : 100);
    });
  }

  void _syncPlayback() {
    final shouldPlay = widget.autoPlay &&
        widget.isActive &&
        _tickerEnabled &&
        _appActive &&
        !_manuallyPaused;

    if (shouldPlay && !_player.state.playing) {
      _player.play();
    } else if (!shouldPlay && _player.state.playing) {
      if (!widget.isActive) _manuallyPaused = false; // reset when slide leaves
      _player.pause();
    }
  }

  // ── Controls ────────────────────────────────────────────────────────────────

  void _onTap() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      if (_player.state.playing) _scheduleHide();
    } else {
      _togglePlayback();
    }
  }

  void _togglePlayback() {
    if (_player.state.playing) {
      _player.pause();
      _manuallyPaused = true;
    } else {
      _player.play();
      _manuallyPaused = false;
      _scheduleHide();
    }
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _player.setVolume(_muted ? 0 : 100);
    });
    // Persist so the next video opens in the same mute state.
    VideoMutePreference.muted = _muted;
  }

  void _seekBy(Duration delta) {
    final cur = _player.state.position + delta;
    final dur = _player.state.duration;
    _player.seek(
      cur < Duration.zero ? Duration.zero : (cur > dur ? dur : cur),
    );
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _openFullscreen() {
    // Capture current state before going fullscreen
    final pos = _player.state.position;
    final wasPlaying = _player.state.playing;
    _player.pause();

    Navigator.of(context)
        .push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullscreenVideoPage(
            url: widget.url,
            initialPosition: pos,
            autoPlay: wasPlaying,
            muted: _muted,
            loop: widget.loop,
            onExit: (finalPos, finalMuted) {
              setState(() => _muted = finalMuted);
              _player.setVolume(_muted ? 0 : 100);
              _player.seek(finalPos);
              _syncPlayback();
            },
          ),
        ));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.initiallyMuted == null) {
      VideoMutePreference.notifier.removeListener(_onGlobalMuteChanged);
    }
    _pauseSub?.cancel();
    _playingSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _hideTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  /// Builds the video surface.
  ///
  /// For [BoxFit.contain] we use Flutter's own [AspectRatio] + [Center] once
  /// the video's pixel dimensions are known — this is far more reliable than
  /// relying on the [Video] widget's internal fit/alignment rendering, which
  /// can be off-centre on certain platforms.
  ///
  /// For [BoxFit.cover] (thumbnails) we delegate directly to [Video.fit].
  Widget _buildVideoSurface() {
    final w = _videoW;
    final h = _videoH;

    // Contain: use AspectRatio + Center — no platform surprises.
    if (widget.fit == BoxFit.contain && w != null && h != null && h > 0) {
      return ColoredBox(
        color: widget.backgroundColor,
        child: Center(
          child: AspectRatio(
            aspectRatio: w / h,
            child: Video(
              controller: _controller,
              fit: BoxFit.fill, // fills the exactly-sized AspectRatio box
              fill: widget.backgroundColor,
              filterQuality: FilterQuality.high,
              controls: NoVideoControls,
            ),
          ),
        ),
      );
    }

    // Cover / unknown dimensions — let Video handle it with ClipRect guard.
    return ClipRect(
      child: Video(
        controller: _controller,
        fit: widget.fit,
        fill: widget.backgroundColor,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        controls: NoVideoControls,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = _buildVideoSurface();

    // ── Sizing ─────────────────────────────────────────────────────────────
    Widget sized;
    if (widget.width != null && widget.height != null) {
      sized = SizedBox(width: widget.width, height: widget.height, child: video);
    } else if (widget.aspectRatio != null) {
      sized = AspectRatio(aspectRatio: widget.aspectRatio!, child: video);
    } else if (widget.width != null) {
      sized = SizedBox(width: widget.width, child: video);
    } else if (widget.height != null) {
      sized = SizedBox(height: widget.height, child: video);
    } else {
      // No explicit size — use the video's natural aspect ratio so the widget
      // sizes itself correctly in Columns, ListViews, etc.
      // Falls back to 16:9 while dimensions are still loading.
      final ratio = (_videoW != null && _videoH != null && _videoH! > 0)
          ? _videoW! / _videoH!
          : 16 / 9;
      sized = AspectRatio(aspectRatio: ratio, child: video);
    }

    // ── Controls overlay ───────────────────────────────────────────────────
    Widget player = Stack(
      alignment: Alignment.center,
      children: [
        sized,
        if (widget.showControls)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: _ControlsOverlay(
                  player: _player,
                  muted: _muted,
                  onPlayPause: _togglePlayback,
                  onMute: _toggleMute,
                  onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                  onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                  onFullscreen: widget.allowFullscreen ? _openFullscreen : null,
                ),
              ),
            ),
          ),
      ],
    );

    if (widget.borderRadius != null) {
      player = ClipRRect(borderRadius: widget.borderRadius!, child: player);
    }

    return player;
  }
}

// ── Controls overlay ──────────────────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.player,
    required this.muted,
    required this.onPlayPause,
    required this.onMute,
    required this.onSeekBack,
    required this.onSeekForward,
    this.onFullscreen,
  });

  final Player player;
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
                SizedBox(width: 24.w),
                StreamBuilder<bool>(
                  stream: player.stream.playing,
                  initialData: player.state.playing,
                  builder: (_, snap) => _CircleButton(
                    icon: (snap.data ?? false)
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: onPlayPause,
                    size: 36.sp,
                    padding: 12,
                  ),
                ),
                SizedBox(width: 24.w),
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
            child: _BottomBar(player: player, onFullscreen: onFullscreen),
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
    return GestureDetector(
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
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.player, this.onFullscreen});

  final Player player;
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
      child: StreamBuilder<Duration>(
        stream: player.stream.duration,
        initialData: player.state.duration,
        builder: (_, durSnap) {
          final dur = durSnap.data ?? Duration.zero;
          return StreamBuilder<Duration>(
            stream: player.stream.position,
            initialData: player.state.position,
            builder: (_, posSnap) {
              final pos = posSnap.data ?? Duration.zero;
              final frac = dur.inMilliseconds > 0
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seek slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: SliderComponentShape.noOverlay,
                      trackHeight: 2.5,
                      activeTrackColor: const Color(0xFFF5A623),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: SizedBox(
                      height: 20.h,
                      child: Slider(
                        value: frac,
                        onChanged: dur.inMilliseconds > 0
                            ? (v) => player.seek(Duration(
                                milliseconds:
                                    (v * dur.inMilliseconds).round()))
                            : null,
                      ),
                    ),
                  ),
                  // Time labels + fullscreen
                  Row(
                    children: [
                      Text(
                        _fmt(pos),
                        style: TextStyle(
                            color: Colors.white70, fontSize: 10.sp),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(dur),
                        style: TextStyle(
                            color: Colors.white70, fontSize: 10.sp),
                      ),
                      if (onFullscreen != null) ...[
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: onFullscreen,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white70,
                            size: 20.sp,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ── Fullscreen page ───────────────────────────────────────────────────────────

/// Dedicated fullscreen player that creates its own [Player] at the same URL
/// and position. On pop it calls [onExit] with the final position and mute
/// state so the inline player can resync.
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
  late final Player _player;
  late final VideoController _controller;

  bool _muted = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  int? _videoW;
  int? _videoH;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muted = widget.muted;

    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _videoW = _player.state.width;
    _videoH = _player.state.height;

    _widthSub = _player.stream.width.listen((w) {
      if (mounted && w != null && w > 0 && w != _videoW) {
        setState(() => _videoW = w);
      }
    });
    _heightSub = _player.stream.height.listen((h) {
      if (mounted && h != null && h > 0 && h != _videoH) {
        setState(() => _videoH = h);
      }
    });

    _player.setVolume(_muted ? 0 : 100);
    _player.setPlaylistMode(
      widget.loop ? PlaylistMode.loop : PlaylistMode.none,
    );

    _player.open(Media(widget.url), play: false).then((_) async {
      if (!mounted) return;
      if (widget.initialPosition > Duration.zero) {
        await _player.seek(widget.initialPosition);
      }
      if (widget.autoPlay) _player.play();
    }).catchError((_) {});

    _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) _scheduleHide();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_player.state.playing) _player.pause();
      case AppLifecycleState.resumed:
        _player.play();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible && _player.state.playing) _scheduleHide();
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _player.setVolume(_muted ? 0 : 100);
    });
    // Persist so the next video opens in the same mute state.
    VideoMutePreference.muted = _muted;
  }

  void _seekBy(Duration delta) {
    final cur = _player.state.position + delta;
    final dur = _player.state.duration;
    _player.seek(
      cur < Duration.zero ? Duration.zero : (cur > dur ? dur : cur),
    );
  }

  void _exit() {
    widget.onExit(_player.state.position, _muted);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safePad = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Video — AspectRatio + Center for reliable centering ──────────
            Builder(builder: (_) {
              final w = _videoW;
              final h = _videoH;
              if (w != null && h != null && h > 0) {
                return ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: w / h,
                      child: Video(
                        controller: _controller,
                        fit: BoxFit.fill,
                        fill: Colors.black,
                        filterQuality: FilterQuality.high,
                        controls: NoVideoControls,
                      ),
                    ),
                  ),
                );
              }
              // Dimensions not yet known — show background while loading.
              return const ColoredBox(color: Colors.black);
            }),

            // ── Controls overlay ────────────────────────────────────────────
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _ControlsOverlay(
                player: _player,
                muted: _muted,
                onPlayPause: () {
                  _player.state.playing ? _player.pause() : _player.play();
                  if (_player.state.playing) _scheduleHide();
                },
                onMute: _toggleMute,
                onSeekBack: () => _seekBy(const Duration(seconds: -10)),
                onSeekForward: () => _seekBy(const Duration(seconds: 10)),
                onFullscreen: null, // no nested fullscreen
              ),
            ),

            // ── Close button ────────────────────────────────────────────────
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
      ),
    );
  }
}
