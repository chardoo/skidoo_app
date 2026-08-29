import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:jperg_app/core/cache/jperg_music_cache.dart';
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
    Future<String?> Function(String streamUrl)? resolveSource,
  })  : _player = player ?? JustAudioFeedMusicPlayer(),
        _resolveSource = resolveSource ?? _defaultResolveSource,
        _settleDelay = settleDelay,
        _fadeDuration = fadeDuration,
        _persistMuted = persistMuted {
    WidgetsBinding.instance.addObserver(this);
    // `onError` is not optional here. A listener without one lets a stream
    // error escape as an unhandled async error — fatal to the zone in debug,
    // silent in release — so a platform that could not play would take the
    // feed down or say nothing at all, depending on the build.
    _indexSub = _player.currentIndexStream.listen(
      _onTrackIndexChanged,
      onError: (Object e) => _reportPlaybackFailure(e),
    );
    _errorSub = _player.errorStream.listen(
      _reportPlaybackFailure,
      onError: (Object e) => _reportPlaybackFailure(e),
    );
  }

  /// The one place a playback failure is written down.
  ///
  /// Music is decoration, so nothing is shown to a viewer and nothing is
  /// retried. What this exists for is the report that starts "it does not work
  /// on Android": audio is where the platforms diverge, and until this landed
  /// a failure on one of them produced no error anywhere to go on.
  ///
  /// The pill is cleared too. A lit pill on a card producing no sound is worse
  /// than no pill — it claims something the card is not doing.
  void _reportPlaybackFailure(Object error) {
    if (_disposed) return;
    debugPrint('[Music] playback failed: $error');
    if (nowPlaying.value != null) _publishNowPlaying(null);
  }

  final FeedMusicPlayer _player;
  final Duration _settleDelay;
  final Duration _fadeDuration;
  final Future<void> Function(bool muted)? _persistMuted;

  /// Sound on until someone says otherwise, and remembered once they do.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  /// The lit pill, or null when nothing is playing.
  ///
  /// Written through [_publishNowPlaying], never directly — see there for why
  /// a plain assignment crashed the feed.
  final ValueNotifier<FeedMusicNowPlaying?> nowPlaying =
      ValueNotifier<FeedMusicNowPlaying?>(null);

  /// Set while a publish is waiting for the current frame to finish.
  ///
  /// Holds the *latest* intended value rather than a queue: a card leaving and
  /// its successor claiming inside one frame should end on the successor's
  /// track, and replaying both in order would land there by a longer route.
  FeedMusicNowPlaying? _deferredNowPlaying;
  bool _publishScheduled = false;

  /// Publishes to [nowPlaying] without notifying listeners mid-build.
  ///
  /// [claim] and [release] are called from widget lifecycle callbacks —
  /// `didChangeDependencies` among them, which runs *during* build. Assigning
  /// a ValueNotifier there notifies its listeners synchronously, so every
  /// ValueListenableBuilder on the pill called setState while the tree was
  /// being built, and Flutter threw "setState() or markNeedsBuild() called
  /// during build". The feed then failed to lay out the card that was
  /// mid-build when it happened.
  ///
  /// Deferring is safe because nothing reads this back: it is a notification
  /// to whoever draws the pill, and the controller's own state — [_owner],
  /// [_tracks], [_generation] — is set synchronously either way.
  void _publishNowPlaying(FeedMusicNowPlaying? value) {
    if (_disposed) return;

    final phase = SchedulerBinding.instance.schedulerPhase;
    // Idle and postFrameCallbacks are both outside the build/layout/paint
    // window, so a listener may rebuild immediately.
    final safeNow = phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;
    if (safeNow) {
      nowPlaying.value = value;
      return;
    }

    _deferredNowPlaying = value;
    if (_publishScheduled) return;
    _publishScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _publishScheduled = false;
      if (_disposed) return;
      nowPlaying.value = _deferredNowPlaying;
      _deferredNowPlaying = null;
    });
  }

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
  StreamSubscription<Object>? _errorSub;

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
    _publishNowPlaying(null);
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
    _publishNowPlaying(null);
    unawaited(_silence());
  }

  /// Stops everything and forgets whose card was playing.
  ///
  /// For sign-out. The controller is a singleton holding one player for the
  /// whole app, so nothing about replacing the navigation stack reaches it —
  /// the previous account's soundtrack would go on playing over the login
  /// screen, which is as odd as it sounds.
  ///
  /// [muted] is deliberately untouched: it is a statement about this phone and
  /// the room it is in, not about the account. See [AuthService.removeToken],
  /// which keeps the stored preference for the same reason.
  void endSession() {
    if (_disposed) return;
    _owner = null;
    _eventId = null;
    _tracks = const [];
    _generation++;
    _settle?.cancel();
    _publishNowPlaying(null);
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

  /// Local file paths for these tracks, downloading any this device has not
  /// heard before.
  ///
  /// Injected rather than called directly so a widget test can play a whole
  /// feed without a disk or a network — the default is the real cache.
  final Future<String?> Function(String streamUrl) _resolveSource;

  /// The real one: cache on disk, fetch once, play from the file thereafter.
  /// The real one: play what is already on disk, and never wait for what is
  /// not.
  ///
  /// A cache hit returns the local file and playback starts instantly. A miss
  /// returns null — which the caller turns into the track's own URL — and
  /// starts the download in the background for next time.
  ///
  /// The order matters more than it looks. Fetching the file first and playing
  /// it afterwards is the obvious reading of "cache the audio", and it makes
  /// the *first* encounter with every track worse than having no cache at all:
  /// half a megabyte has to arrive before a single note, so the card sits
  /// silent on a slow connection while a progress-free download runs. Streaming
  /// starts in a moment and the disk copy lands quietly behind it.
  static Future<String?> _defaultResolveSource(String streamUrl) async {
    final file = await cachedAudioFileIfPresent(streamUrl);
    if (file == null) {
      // Not held yet: stream it now, keep it for later.
      unawaited(warmAudioCache(streamUrl));
      return null;
    }
    // `file.uri`, not `file.path`. A path is `/var/mobile/…`, and parsing that
    // as a URI gives one with no scheme at all — which AVPlayer rejects
    // outright as `-1002 unsupported URL`, so every cached track failed to play
    // on iOS while the download had worked perfectly. `File.uri` produces the
    // `file:///var/mobile/…` form the platform players expect.
    return file.uri.toString();
  }

  Future<List<String>> _resolveSources(List<MusicTrack> tracks) async {
    // Concurrently: a four-track soundtrack on a cold cache is one download's
    // wait rather than four, and this sits between the card appearing and the
    // sound starting.
    final resolved = await Future.wait([
      for (final t in tracks) _resolveSource(t.streamUrl),
    ]);

    // A track the cache could not provide falls back to its URL, which is what
    // the player was given before any of this existed.
    //
    // This is the difference between a cache and a gate, and getting it wrong
    // silenced the whole feed: the first version dropped anything the cache
    // missed, so a failure to *save a request* became a failure to play. On
    // web that was total — flutter_cache_manager stores through path_provider,
    // which has no web implementation, so every resolution returned null, the
    // list came back empty, and the card published no pill and no sound.
    //
    // The cache exists to avoid paying for the same audio twice. When it
    // cannot help, the right outcome is the old one: fetch and play. Never
    // silence.
    return [
      for (var i = 0; i < tracks.length; i++)
        resolved[i] ?? tracks[i].streamUrl,
    ];
  }

  Future<void> _start(int generation) async {
    if (_disposed || generation != _generation || !_appActive) return;

    final tracks = _tracks;
    if (tracks.isEmpty) return;

    try {
      // From disk where we already hold it, from the network only the first
      // time this device meets the track. Audiomack bills per request and the
      // feed is the one path that would otherwise generate them without limit
      // — see JpergMusicCache. Anything the cache cannot provide falls back to
      // its URL, so playback never depends on the cache working.
      final sources = await _resolveSources(tracks);
      if (generation != _generation) return;
      if (sources.isEmpty) return;

      await _player.load(sources);
      if (generation != _generation) return;

      // Come up from silence rather than punching in at full volume: the load
      // above may have taken a moment, and starting loud is jarring.
      await _player.setVolume(0);

      // Started, not awaited to completion. [FeedMusicPlayer.play] promises to
      // return once playback has begun, and this deliberately does not depend
      // on that promise being kept: the volume is at zero right now, so a
      // `play()` that never resolves would leave the feed silent with nothing
      // to show for it — which is exactly what the just_audio adapter used to
      // do, and it cost a release. Nothing below may sit behind a player call.
      unawaited(_player.play());

      if (generation != _generation) {
        unawaited(_player.pause());
        return;
      }

      _publish();
      _fadeTo(muted.value ? 0 : 1, generation);
    } catch (e) {
      // Music is decoration on a feed. A dead URL, an unplayable format or a
      // provider outage means no pill and no sound — never a message, because
      // there is nothing the viewer asked for or could act on.
      debugPrint('[Music] could not play soundtrack: $e');
      if (generation == _generation) _publishNowPlaying(null);
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
      _publishNowPlaying(null);
      return;
    }
    final index = _trackIndex.clamp(0, tracks.length - 1);
    _publishNowPlaying(
      FeedMusicNowPlaying(eventId: eventId, track: tracks[index]),
    );
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
    await _errorSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    muted.dispose();
    nowPlaying.dispose();
    await _player.dispose();
  }
}
