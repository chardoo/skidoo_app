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
    _loaded = List.unmodifiable(urls);

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
  Future<void> pause() => _player.pause();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> dispose() async {
    _loaded = null;
    await _player.dispose();
  }
}
