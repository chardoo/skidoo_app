import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// The audio engine, reduced to what the feed actually asks of it.
///
/// Two reasons this is an interface rather than a bare [AudioPlayer]:
///
/// * [FeedMusicController] holds every playback rule worth testing — focus,
///   video slides, mute, lifecycle — and none of them should need a platform
///   channel to exercise. A fake implementing this plays a whole feed in a
///   widget test.
/// * It is the second thing that would change if the audio package ever did,
///   and it keeps that change out of the controller.
abstract class FeedMusicPlayer {
  /// Queue [urls] and make the first one current, without starting playback.
  ///
  /// The list is a soundtrack in the order the photographer chose. Playing
  /// past the end returns to the start — a card held long enough to exhaust
  /// the queue keeps playing rather than falling silent.
  Future<void> load(List<String> urls);

  /// Start playing, and return once playback has **started**.
  ///
  /// Spelled out because the obvious implementation gets it wrong.
  /// `just_audio`'s own `play()` resolves when playback *finishes* — "completes
  /// when the playback completes or is paused or stopped" — and this feed
  /// loops forever, so awaiting that is awaiting something that never happens.
  /// Everything after the await becomes unreachable, including the fade that
  /// takes the volume off zero, and the feed plays perfect silence with no
  /// error anywhere. See [JustAudioFeedMusicPlayer.play].
  Future<void> play();

  Future<void> pause();

  /// 0.0 to 1.0. Set directly rather than ramped — [FeedMusicController] owns
  /// the fade, because it is the thing that knows what a fade is for.
  Future<void> setVolume(double volume);

  /// Which entry of the last [load] is playing, so a pill can name it. Null
  /// before anything is queued.
  Stream<int?> get currentIndexStream;

  /// Whatever the platform said when it could not play something.
  ///
  /// Music is decoration and none of this is shown to a viewer, but a failure
  /// that reports nothing anywhere is a failure nobody can fix — and audio is
  /// exactly where the two platforms diverge, so "it works on one of them" is
  /// a report that needs the other one's error to go anywhere.
  Stream<Object> get errorStream;

  Future<void> dispose();
}

/// [FeedMusicPlayer] on top of `just_audio`.
class JustAudioFeedMusicPlayer implements FeedMusicPlayer {
  JustAudioFeedMusicPlayer({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  /// What is currently queued, so re-claiming the same event does not tear
  /// down and re-buffer audio that is already loaded and playing.
  List<String>? _loaded;

  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  @override
  Future<void> load(List<String> urls) async {
    if (_loaded != null && listEquals(_loaded, urls)) return;

    // LoopMode.all over the whole queue: with one track it repeats that track,
    // with several it cycles them. Either way the card never goes quiet on its
    // own — which matters more than usual here, because the stand-in provider
    // serves 30-second previews and almost every card outlives one.
    await _player.setLoopMode(LoopMode.all);
    await _player.setAudioSource(
      ConcatenatingAudioSource(
        children: [
          for (final url in urls) AudioSource.uri(Uri.parse(url)),
        ],
      ),
      // Queued, not started. The controller decides when sound begins, and it
      // has gates to check first.
      preload: false,
    );

    // Recorded only once the source is actually set.
    //
    // This used to be assigned before the await, which turned any single
    // failure into a permanent one: the throw left `_loaded` holding urls the
    // player had never accepted, so every later attempt at the same soundtrack
    // matched the guard above and returned immediately — skipping the load
    // that would have fixed it, on a player with no source at all. The card
    // then reported itself as playing and produced silence, for the rest of
    // the session.
    _loaded = List.unmodifiable(urls);
  }

  @override
  Future<void> play() async {
    // Deliberately not awaited. `AudioPlayer.play()` resolves when playback
    // completes, is paused, or is stopped — and this player loops with
    // LoopMode.all, so none of those ever happens. Awaiting it stranded the
    // caller forever: the controller sets the volume to zero before playing so
    // it can fade in afterwards, and the fade sat on the far side of an await
    // that never returned. The feed played, at volume zero, with no error to
    // show for it.
    //
    // Playback is already under way when this returns — `play()` flips the
    // player's `playing` state and sends the platform request before it starts
    // waiting on the completion future, so the interface's contract holds.
    unawaited(_player.play().catchError((Object error) {
      // The only place a start failure can surface now. Music is decoration on
      // a feed, so this is a log and nothing more.
      debugPrint('[Music] playback failed: $error');
    }));
  }

  @override
  Stream<Object> get errorStream => _player.playbackEventStream.transform(
        // `playbackEventStream` is where just_audio reports a source that
        // would not load or decode. With `preload: false` nothing touches the
        // network until `play()`, so this — not the `setAudioSource` above —
        // is the only place a bad URL, a refused redirect or an unsupported
        // codec surfaces.
        //
        // The transform turns those errors into ordinary values and drops the
        // events themselves. Both halves matter: an error on a stream nobody
        // handles becomes an unhandled async error, which takes out the zone
        // in debug and vanishes in release — which is exactly how a
        // platform-specific playback failure ends up with nothing anywhere
        // saying what went wrong.
        StreamTransformer<PlaybackEvent, Object>.fromHandlers(
          handleData: (_, __) {},
          handleError: (error, _, sink) => sink.add(error),
        ),
      );

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    _loaded = null;
    await _player.dispose();
  }
}
