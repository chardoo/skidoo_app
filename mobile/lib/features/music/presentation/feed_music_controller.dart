import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jperg_app/features/music/domain/entities/music_track.dart';
import 'package:jperg_app/features/music/presentation/feed_music_player.dart';

/// What is playing, for whoever is drawing the pill.
@immutable
class FeedMusicNowPlaying {
  const FeedMusicNowPlaying({required this.eventId, required this.track});

  /// The event whose card owns the sound right now. A card compares this
  /// against its own id — that is the whole reason it is here, and it is why
  /// only one pill can ever be lit.
  final String eventId;
  final MusicTrack track;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeedMusicNowPlaying &&
          other.eventId == eventId &&
          other.track == track;

  @override
  int get hashCode => Object.hash(eventId, track);
}

/// The feed's music, for the whole app.
///
/// **One player, not one per card.** A feed builds and destroys cards as fast
/// as a thumb moves; an [AudioPlayer] each would mean a platform-level decoder
/// per card, all of them buffering, most of them never heard. So cards do not
/// own audio. They say "I am the card in focus and here is my soundtrack", and
/// this decides.
///
/// ## Ownership
///
/// Exactly one card holds playback at a time, tracked by [_owner] — the
/// claiming [State] object itself. Cards do not stop each other's music; they
/// only ever [release] what they still own. That is what makes the handover
/// safe: swiping A → B fires A's release and B's claim in no guaranteed order,
/// and if A's release arrives second it is ignored, because A is no longer the
/// owner. Without that guard the outgoing card silences the incoming one and
/// the feed goes quiet on every second swipe.
///
/// ## Async races
///
/// Loading a URL and starting playback are both awaited, and a thumb is faster
/// than either. Every await is followed by a [_generation] check: any claim or
/// release bumps the counter, so work started for a card that has since lost
/// focus discards itself instead of playing over its successor.
class FeedMusicController with WidgetsBindingObserver {
  FeedMusicController({
    FeedMusicPlayer? player,
    Duration settleDelay = const Duration(milliseconds: 250),
    Duration fadeDuration = const Duration(milliseconds: 200),
    Future<void> Function(bool muted)? persistMuted,
  })  : _player = player ?? JustAudioFeedMusicPlayer(),
        _settleDelay = settleDelay,
        _fadeDuration = fadeDuration,
        _persistMuted = persistMuted {
    WidgetsBinding.instance.addObserver(this);
    _indexSub = _player.currentIndexStream.listen(_onTrackIndexChanged);
  }

  final FeedMusicPlayer _player;
  final Duration _settleDelay;
  final Duration _fadeDuration;
  final Future<void> Function(bool muted)? _persistMuted;

  /// Sound on until someone says otherwise, and remembered once they do.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  /// The lit pill, or null when nothing is playing.
  final ValueNotifier<FeedMusicNowPlaying?> nowPlaying =
      ValueNotifier<FeedMusicNowPlaying?>(null);

  Object? _owner;
  String? _eventId;
  List<MusicTrack> _tracks = const [];
  int _trackIndex = 0;

  /// Bumped on every claim and release; async work carries the value it began
  /// with and abandons itself if it no longer matches.
  int _generation = 0;

  Timer? _settle;
  Timer? _fade;
  StreamSubscription<int?>? _indexSub;

  /// False while the app is backgrounded. Playback is held rather than given
  /// up, so coming back resumes the card still on screen instead of leaving a
  /// silent feed until the next swipe.
  bool _appActive = true;

  bool _disposed = false;

  /// Restores a remembered mute preference. Called once at startup; silent if
  /// nothing was stored.
  void restoreMuted(bool value) {
    if (muted.value != value) muted.value = value;
    unawaited(_applyVolume());
  }

  /// [owner] is the card in focus, and [tracks] is what it wants played.
  ///
  /// Cheap to call repeatedly: a card re-claiming what it already owns is a
  /// no-op, which matters because the conditions that trigger it (focus, the
  /// current slide, tab visibility) are recomputed on every rebuild.
  void claim(Object owner, String eventId, List<MusicTrack> tracks) {
    if (_disposed) return;
    if (identical(_owner, owner) && _eventId == eventId) return;

    _owner = owner;
    _eventId = eventId;
    _tracks = tracks.where((t) => t.isPlayable).toList(growable: false);
    _trackIndex = 0;
    final generation = ++_generation;

    _settle?.cancel();
    // The pill goes dark immediately. Leaving the old track named while a new
    // card is on screen is worse than a moment with no pill at all.
    nowPlaying.value = null;
    unawaited(_silence());

    if (_tracks.isEmpty) return;

    // Nothing starts until the card has been still for a beat. A flick through
    // fifteen cards should cost one load and one play, not fifteen of each —
    // this is the single most important thing here for how the feed feels and
    // what it costs.
    _settle = Timer(_settleDelay, () => unawaited(_start(generation)));
  }

  /// [owner] no longer wants music — it lost focus, reached a video slide, or
  /// left the tree.
  ///
  /// Ignored unless [owner] still holds playback; see the class doc on why
  /// that guard is what makes swiping work.
  void release(Object owner) {
    if (_disposed) return;
    if (!identical(_owner, owner)) return;

    _owner = null;
    _eventId = null;
    _tracks = const [];
    _generation++;
    _settle?.cancel();
    nowPlaying.value = null;
    unawaited(_silence());
  }

  /// Mute without stopping. The track keeps running underneath, so unmuting
  /// lands where the sound would have been rather than restarting it — which
  /// is what every feed with a speaker icon does, and what people expect.
  Future<void> setMuted(bool value) async {
    if (muted.value == value) return;
    muted.value = value;
    await _applyVolume();
    await _persistMuted?.call(value);
  }

  Future<void> toggleMute() => setMuted(!muted.value);

  // ── Internals ────────────────────────────────────────────────────────────

  Future<void> _start(int generation) async {
    if (_disposed || generation != _generation || !_appActive) return;

    final tracks = _tracks;
    if (tracks.isEmpty) return;

    try {
      await _player.load([for (final t in tracks) t.streamUrl]);
      if (generation != _generation) return;

      // Come up from silence rather than punching in at full volume: the load
      // above may have taken a moment, and starting loud is jarring.
      await _player.setVolume(0);
      await _player.play();
      if (generation != _generation) {
        await _player.pause();
        return;
      }

      _publish();
      _fadeTo(muted.value ? 0 : 1, generation);
    } catch (e) {
      // Music is decoration on a feed. A dead URL, an unplayable format or a
      // provider outage means no pill and no sound — never a message, because
      // there is nothing the viewer asked for or could act on.
      debugPrint('[Music] could not play soundtrack: $e');
      if (generation == _generation) nowPlaying.value = null;
    }
  }

  /// Stop what is audible now, without disturbing ownership.
  Future<void> _silence() async {
    _fade?.cancel();
    try {
      await _player.setVolume(0);
      await _player.pause();
    } catch (e) {
      debugPrint('[Music] could not stop playback: $e');
    }
  }

  Future<void> _applyVolume() async {
    if (_disposed) return;
    _fade?.cancel();
    if (nowPlaying.value == null) return;
    try {
      await _player.setVolume(muted.value ? 0 : 1);
    } catch (e) {
      debugPrint('[Music] could not set volume: $e');
    }
  }

  /// Ramps volume in steps. A hard cut between cards clicks audibly; this is
  /// short enough to read as immediate.
  void _fadeTo(double target, int generation) {
    _fade?.cancel();
    if (_fadeDuration == Duration.zero) {
      unawaited(_player.setVolume(target));
      return;
    }

    const steps = 8;
    var step = 0;
    final stepDuration = Duration(
      microseconds: (_fadeDuration.inMicroseconds / steps).round(),
    );

    _fade = Timer.periodic(stepDuration, (timer) {
      // A claim or release during the ramp wins: whatever it did to the volume
      // must not be undone by a fade still finishing for the previous card.
      if (_disposed || generation != _generation) {
        timer.cancel();
        return;
      }
      step++;
      final volume = target * (step / steps);
      unawaited(_player.setVolume(volume.clamp(0.0, 1.0)));
      if (step >= steps) timer.cancel();
    });
  }

  void _onTrackIndexChanged(int? index) {
    if (index == null || index == _trackIndex) return;
    _trackIndex = index;
    // Only meaningful for a multi-track soundtrack advancing to its next
    // entry; the pill follows along.
    if (nowPlaying.value != null) _publish();
  }

  void _publish() {
    final eventId = _eventId;
    final tracks = _tracks;
    if (eventId == null || tracks.isEmpty) {
      nowPlaying.value = null;
      return;
    }
    final index = _trackIndex.clamp(0, tracks.length - 1);
    nowPlaying.value =
        FeedMusicNowPlaying(eventId: eventId, track: tracks[index]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _appActive = false;
        // Ownership is kept deliberately — see [_appActive].
        unawaited(_silence());
      case AppLifecycleState.resumed:
        _appActive = true;
        if (_owner != null && _tracks.isNotEmpty) {
          unawaited(_start(_generation));
        }
      case AppLifecycleState.inactive:
        // Transient on iOS — a control-centre pull, a permission sheet. Cutting
        // the music for those and not resuming reads as a bug.
        break;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _settle?.cancel();
    _fade?.cancel();
    await _indexSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    muted.dispose();
    nowPlaying.dispose();
    await _player.dispose();
  }
}
